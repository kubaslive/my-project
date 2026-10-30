package main

import (
	"flag"
	"fmt"
	"log"
	"net/http"
	"os"
	"path/filepath"

	"swd-prm-backend/internal/api"
	"swd-prm-backend/internal/hub"
	"swd-prm-backend/internal/store"
)

func main() {
	port := flag.String("port", "8080", "Port serwera HTTP i WebSocket")
	webDir := flag.String("web", "./web", "Katalog plików statycznych konsoli WWW")
	flag.Parse()

	// Jeśli zmienna środowiskowa PORT jest ustawiona, ma pierwszeństwo
	if envPort := os.Getenv("PORT"); envPort != "" {
		*port = envPort
	}

	// Sprawdzenie ścieżki do web/
	absWebDir, err := filepath.Abs(*webDir)
	if err != nil {
		absWebDir = *webDir
	}

	log.Printf("==================================================")
	log.Printf("   SWD PRM Core Server (Węzeł Operacyjny)")
	log.Printf("   Zabezpieczona Sieć Lokalna • Port: :%s", *port)
	log.Printf("   Katalog UI: %s", absWebDir)
	log.Printf("==================================================")

	// 1. Inicjalizacja magazynu stanu
	st := store.NewStore()

	// 2. Inicjalizacja Huba WebSocket
	h := hub.NewHub(st)
	go h.Run()

	// 3. Konfiguracja API i serwera HTTP
	srv := api.NewServer(st, h, absWebDir)

	addr := fmt.Sprintf("0.0.0.0:%s", *port)
	log.Printf("[SWD] Serwer nasłuchuje na http://localhost:%s oraz http://%s", *port, addr)
	log.Printf("[SWD] Konsola dyspozytorska i tabletowa dostępna w przeglądarce pod: http://localhost:%s", *port)
	log.Printf("[SWD] Węzeł WebSocket pod adresem: ws://localhost:%s/ws", *port)

	if err := http.ListenAndServe(addr, srv); err != nil {
		log.Fatalf("Błąd krytyczny serwera: %v", err)
	}
}
