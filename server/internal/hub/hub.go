package hub

import (
	"encoding/json"
	"log"
	"net/http"
	"sync"
	"time"

	"github.com/gorilla/websocket"
	"swd-prm-backend/internal/models"
	"swd-prm-backend/internal/store"
)

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool {
		// Dozwolone połączenia w sieci lokalnej / zabezpieczonej
		return true
	},
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
}

// Client reprezentuje aktywne połączenie WebSocket
type Client struct {
	hub      *Hub
	conn     *websocket.Conn
	send     chan []byte
	role     string // "DISPATCHER" lub "TABLET_ZRM"
	clientID string // np. "DYS-01" lub "ZRM-01"
}

// Hub zarządza wszystkimi aktywnymi połączeniami
type Hub struct {
	store *store.Store

	clients    map[*Client]bool
	tablets    map[string]*Client // unitID -> Client
	dispatchers map[*Client]bool

	register   chan *Client
	unregister chan *Client
	broadcast  chan []byte

	mu sync.RWMutex
}

// NewHub tworzy instancję Huba WebSocket
func NewHub(s *store.Store) *Hub {
	return &Hub{
		store:       s,
		clients:     make(map[*Client]bool),
		tablets:     make(map[string]*Client),
		dispatchers: make(map[*Client]bool),
		register:    make(chan *Client),
		unregister:  make(chan *Client),
		broadcast:   make(chan []byte, 256),
	}
}

// Run uruchamia pętlę zdarzeń Huba
func (h *Hub) Run() {
	for {
		select {
		case client := <-h.register:
			h.mu.Lock()
			h.clients[client] = true
			if client.role == "DISPATCHER" {
				h.dispatchers[client] = true
				log.Printf("[HUB] Zarejestrowano stację dyspozytorską: %s", client.clientID)
			} else if client.role == "TABLET_ZRM" {
				h.tablets[client.clientID] = client
				h.store.SetUnitConnected(client.clientID, true)
				log.Printf("[HUB] Zarejestrowano tablet ZRM: %s", client.clientID)
				h.broadcastUnitsListLocked()
			}
			h.mu.Unlock()

		case client := <-h.unregister:
			h.mu.Lock()
			if _, ok := h.clients[client]; ok {
				delete(h.clients, client)
				close(client.send)
				if client.role == "DISPATCHER" {
					delete(h.dispatchers, client)
					log.Printf("[HUB] Rozłączono dyspozytora: %s", client.clientID)
				} else if client.role == "TABLET_ZRM" {
					delete(h.tablets, client.clientID)
					h.store.SetUnitConnected(client.clientID, false)
					log.Printf("[HUB] Rozłączono tablet ZRM: %s", client.clientID)
					h.broadcastUnitsListLocked()
				}
			}
			h.mu.Unlock()

		case message := <-h.broadcast:
			h.mu.RLock()
			for client := range h.clients {
				select {
				case client.send <- message:
				default:
					close(client.send)
					delete(h.clients, client)
				}
			}
			h.mu.RUnlock()
		}
	}
}

// broadcastUnitsListLocked rozsyła aktualną listę jednostek do dyspozytorów
func (h *Hub) broadcastUnitsListLocked() {
	units := h.store.GetAllUnits()
	msg := models.WSMessage{
		Type:       models.MsgUnitsList,
		SenderRole: "SERVER",
		SenderID:   "CORE",
		Payload:    units,
		Timestamp:  time.Now(),
	}
	data, err := json.Marshal(msg)
	if err == nil {
		for d := range h.dispatchers {
			select {
			case d.send <- data:
			default:
			}
		}
	}
}

// BroadcastToDispatchers wysyła komunikat do wszystkich stacji dyspozytorskich
func (h *Hub) BroadcastToDispatchers(msg models.WSMessage) {
	data, err := json.Marshal(msg)
	if err != nil {
		return
	}
	h.mu.RLock()
	defer h.mu.RUnlock()

	for d := range h.dispatchers {
		select {
		case d.send <- data:
		default:
		}
	}
}

// SendToTablet wysyła komunikat bezpośrednio do wskazanego tabletu ZRM
func (h *Hub) SendToTablet(unitID string, msg models.WSMessage) bool {
	data, err := json.Marshal(msg)
	if err != nil {
		return false
	}
	h.mu.RLock()
	defer h.mu.RUnlock()

	tablet, exists := h.tablets[unitID]
	if !exists {
		return false
	}
	select {
	case tablet.send <- data:
		return true
	default:
		return false
	}
}

// ServeWS obsługuje żądanie WebSocket
func (h *Hub) ServeWS(w http.ResponseWriter, r *http.Request) {
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Printf("[WS] Błąd upgrade: %v", err)
		return
	}

	role := r.URL.Query().Get("role")
	clientID := r.URL.Query().Get("id")

	if role == "" {
		role = "DISPATCHER"
	}
	if clientID == "" {
		clientID = "ANONYMOUS"
	}

	client := &Client{
		hub:      h,
		conn:     conn,
		send:     make(chan []byte, 256),
		role:     role,
		clientID: clientID,
	}

	h.register <- client

	// Start goroutine do zapisu i odczytu
	go client.writePump()
	go client.readPump()
}

func (c *Client) readPump() {
	defer func() {
		c.hub.unregister <- c
		c.conn.Close()
	}()

	c.conn.SetReadLimit(512 * 1024) // 512KB
	c.conn.SetReadDeadline(time.Now().Add(60 * time.Second))
	c.conn.SetPongHandler(func(string) error {
		c.conn.SetReadDeadline(time.Now().Add(60 * time.Second))
		return nil
	})

	for {
		_, message, err := c.conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				log.Printf("[WS] Błąd klienta %s: %v", c.clientID, err)
			}
			break
		}

		var wsMsg models.WSMessage
		if err := json.Unmarshal(message, &wsMsg); err != nil {
			log.Printf("[WS] Niepoprawny format wiadomości od %s: %v", c.clientID, err)
			continue
		}

		c.handleIncomingMessage(wsMsg)
	}
}

func (c *Client) handleIncomingMessage(msg models.WSMessage) {
	switch msg.Type {
	case models.MsgStatusUpdate:
		// Zmiana statusu 1-6 z tabletu ZRM
		payloadBytes, _ := json.Marshal(msg.Payload)
		var payload models.StatusUpdatePayload
		if err := json.Unmarshal(payloadBytes, &payload); err == nil {
			if payload.UnitID == "" {
				payload.UnitID = c.clientID
			}
			if payload.Timestamp.IsZero() {
				payload.Timestamp = time.Now()
			}

			updatedUnit, updatedDispatch, err := c.hub.store.UpdateUnitStatus(payload)
			if err != nil {
				log.Printf("[HUB] Błąd aktualizacji statusu: %v", err)
				return
			}

			// Odpowiedź ACK do tabletu
			ackMsg := models.WSMessage{
				Type:       models.MsgAck,
				SenderRole: "SERVER",
				SenderID:   "CORE",
				Payload: map[string]any{
					"status": "OK",
					"seq_id": payload.SeqID,
					"unit":   updatedUnit,
				},
				Timestamp: time.Now(),
			}
			ackBytes, _ := json.Marshal(ackMsg)
			c.send <- ackBytes

			// Rozgłoszenie aktualizacji statusu do wszystkich dyspozytorów
			broadcastMsg := models.WSMessage{
				Type:       models.MsgStatusUpdate,
				SenderRole: "TABLET_ZRM",
				SenderID:   payload.UnitID,
				Payload: map[string]any{
					"unit":     updatedUnit,
					"dispatch": updatedDispatch,
				},
				Timestamp: time.Now(),
			}
			c.hub.BroadcastToDispatchers(broadcastMsg)
		}

	case models.MsgDispatchNew:
		// Nowe zlecenie od dyspozytora
		payloadBytes, _ := json.Marshal(msg.Payload)
		var dispatch models.Dispatch
		if err := json.Unmarshal(payloadBytes, &dispatch); err == nil {
			createdDispatch, err := c.hub.store.CreateDispatch(&dispatch)
			if err != nil {
				return
			}

			// Wysłanie zlecenia bezpośrednio na tablet przypisanej karetki
			dispatchMsg := models.WSMessage{
				Type:       models.MsgDispatchNew,
				SenderRole: "DISPATCHER",
				SenderID:   c.clientID,
				Payload:    createdDispatch,
				Timestamp:  time.Now(),
			}
			c.hub.SendToTablet(createdDispatch.AssignedUnitID, dispatchMsg)

			// Rozgłoszenie do wszystkich stacji dyspozytorskich
			c.hub.BroadcastToDispatchers(dispatchMsg)
		}

	case models.MsgKMCRUpdate:
		// Aktualizacja karty KMCR z tabletu
		payloadBytes, _ := json.Marshal(msg.Payload)
		var kmcr models.KMCR
		if err := json.Unmarshal(payloadBytes, &kmcr); err == nil {
			saved := c.hub.store.SaveKMCR(&kmcr)

			// Zwrotne potwierdzenie
			ackMsg := models.WSMessage{
				Type:       models.MsgAck,
				SenderRole: "SERVER",
				SenderID:   "CORE",
				Payload:    map[string]any{"status": "KMCR_SAVED", "id": saved.ID},
				Timestamp:  time.Now(),
			}
			ackBytes, _ := json.Marshal(ackMsg)
			c.send <- ackBytes

			// Poinformowanie dyspozytorów o zmianie w karcie medycznej
			kmcrMsg := models.WSMessage{
				Type:       models.MsgKMCRUpdate,
				SenderRole: "TABLET_ZRM",
				SenderID:   c.clientID,
				Payload:    saved,
				Timestamp:  time.Now(),
			}
			c.hub.BroadcastToDispatchers(kmcrMsg)
		}
	}
}

func (c *Client) writePump() {
	ticker := time.NewTicker(25 * time.Second)
	defer func() {
		ticker.Stop()
		c.conn.Close()
	}()

	for {
		select {
		case message, ok := <-c.send:
			c.conn.SetWriteDeadline(time.Now().Add(10 * time.Second))
			if !ok {
				c.conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}

			w, err := c.conn.NextWriter(websocket.TextMessage)
			if err != nil {
				return
			}
			w.Write(message)

			// Opróżnienie kolejki wiadomości
			n := len(c.send)
			for i := 0; i < n; i++ {
				w.Write([]byte{'\n'})
				w.Write(<-c.send)
			}

			if err := w.Close(); err != nil {
				return
			}

		case <-ticker.C:
			c.conn.SetWriteDeadline(time.Now().Add(10 * time.Second))
			if err := c.conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}
