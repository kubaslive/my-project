package api

import (
	"encoding/json"
	"net/http"
	"strings"
	"time"

	"swd-prm-backend/internal/hub"
	"swd-prm-backend/internal/models"
	"swd-prm-backend/internal/store"
)

type Server struct {
	store *store.Store
	hub   *hub.Hub
	mux   *http.ServeMux
}

func NewServer(s *store.Store, h *hub.Hub, webDir string) *Server {
	srv := &Server{
		store: s,
		hub:   h,
		mux:   http.NewServeMux(),
	}
	srv.routes(webDir)
	return srv
}

func (s *Server) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	// CORS Middleware dla sieci lokalnej / zabezpieczonej
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")

	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusOK)
		return
	}

	s.mux.ServeHTTP(w, r)
}

func (s *Server) routes(webDir string) {
	// WebSocket endpoint
	s.mux.HandleFunc("/ws", s.hub.ServeWS)

	// API REST
	s.mux.HandleFunc("/api/v1/health", s.handleHealth)
	s.mux.HandleFunc("/api/v1/units", s.handleUnits)
	s.mux.HandleFunc("/api/v1/dispatches", s.handleDispatches)
	s.mux.HandleFunc("/api/v1/dispatches/", s.handleSingleDispatch)
	s.mux.HandleFunc("/api/v1/kmcr", s.handleKMCR)
	s.mux.HandleFunc("/api/v1/kmcr/", s.handleSingleKMCR)

	// Web console (HTML/JS)
	if webDir != "" {
		fs := http.FileServer(http.Dir(webDir))
		s.mux.Handle("/", fs)
	}
}

func (s *Server) handleHealth(w http.ResponseWriter, r *http.Request) {
	jsonResponse(w, http.StatusOK, map[string]any{
		"status":      "UP",
		"system":      "SWD-PRM-CORE",
		"server_time": time.Now().Format(time.RFC3339),
		"version":     "1.0.0",
	})
}

func (s *Server) handleUnits(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Metoda niedozwolona", http.StatusMethodNotAllowed)
		return
	}
	units := s.store.GetAllUnits()
	jsonResponse(w, http.StatusOK, units)
}

func (s *Server) handleDispatches(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		dispatches := s.store.GetAllDispatches()
		jsonResponse(w, http.StatusOK, dispatches)

	case http.MethodPost:
		var d models.Dispatch
		if err := json.NewDecoder(r.Body).Decode(&d); err != nil {
			http.Error(w, "Nieprawidłowy JSON", http.StatusBadRequest)
			return
		}

		created, err := s.store.CreateDispatch(&d)
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}

		// Powiadomienie przez WebSocket
		msg := models.WSMessage{
			Type:       models.MsgDispatchNew,
			SenderRole: "SERVER",
			SenderID:   "API",
			Payload:    created,
			Timestamp:  time.Now(),
		}
		s.hub.SendToTablet(created.AssignedUnitID, msg)
		s.hub.BroadcastToDispatchers(msg)

		jsonResponse(w, http.StatusCreated, created)

	default:
		http.Error(w, "Metoda niedozwolona", http.StatusMethodNotAllowed)
	}
}

func (s *Server) handleSingleDispatch(w http.ResponseWriter, r *http.Request) {
	id := strings.TrimPrefix(r.URL.Path, "/api/v1/dispatches/")
	if id == "" {
		http.NotFound(w, r)
		return
	}

	d, found := s.store.GetDispatch(id)
	if !found {
		http.NotFound(w, r)
		return
	}
	jsonResponse(w, http.StatusOK, d)
}

func (s *Server) handleKMCR(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Metoda niedozwolona", http.StatusMethodNotAllowed)
		return
	}

	var kmcr models.KMCR
	if err := json.NewDecoder(r.Body).Decode(&kmcr); err != nil {
		http.Error(w, "Nieprawidłowy JSON", http.StatusBadRequest)
		return
	}

	saved := s.store.SaveKMCR(&kmcr)

	msg := models.WSMessage{
		Type:       models.MsgKMCRUpdate,
		SenderRole: "SERVER",
		SenderID:   "API",
		Payload:    saved,
		Timestamp:  time.Now(),
	}
	s.hub.BroadcastToDispatchers(msg)

	jsonResponse(w, http.StatusOK, saved)
}

func (s *Server) handleSingleKMCR(w http.ResponseWriter, r *http.Request) {
	dispatchID := strings.TrimPrefix(r.URL.Path, "/api/v1/kmcr/")
	if dispatchID == "" {
		http.NotFound(w, r)
		return
	}

	kmcr, found := s.store.GetKMCR(dispatchID)
	if !found {
		http.NotFound(w, r)
		return
	}
	jsonResponse(w, http.StatusOK, kmcr)
}

func jsonResponse(w http.ResponseWriter, status int, data any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(data)
}
