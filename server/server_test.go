package main_test

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"swd-prm-backend/internal/api"
	"swd-prm-backend/internal/hub"
	"swd-prm-backend/internal/models"
	"swd-prm-backend/internal/store"
)

func setupTestServer() (*api.Server, *store.Store) {
	st := store.NewStore()
	h := hub.NewHub(st)
	go h.Run()
	srv := api.NewServer(st, h, "")
	return srv, st
}

func TestHealthEndpoint(t *testing.T) {
	srv, _ := setupTestServer()

	req, _ := http.NewRequest(http.MethodGet, "/api/v1/health", nil)
	rr := httptest.NewRecorder()

	srv.ServeHTTP(rr, req)

	if rr.Code != http.StatusOK {
		t.Fatalf("Oczekiwano statusu 200, otrzymano: %d", rr.Code)
	}

	var body map[string]any
	if err := json.Unmarshal(rr.Body.Bytes(), &body); err != nil {
		t.Fatalf("Błąd parsowania odpowiedzi JSON: %v", err)
	}

	if body["status"] != "UP" {
		t.Errorf("Oczekiwano status == UP, otrzymano: %v", body["status"])
	}
}

func TestUnitsList(t *testing.T) {
	srv, _ := setupTestServer()

	req, _ := http.NewRequest(http.MethodGet, "/api/v1/units", nil)
	rr := httptest.NewRecorder()

	srv.ServeHTTP(rr, req)

	if rr.Code != http.StatusOK {
		t.Fatalf("Oczekiwano statusu 200, otrzymano: %d", rr.Code)
	}

	var units []*models.ZRMUnit
	if err := json.Unmarshal(rr.Body.Bytes(), &units); err != nil {
		t.Fatalf("Błąd parsowania listy jednostek: %v", err)
	}

	if len(units) < 3 {
		t.Errorf("Oczekiwano co najmniej 3 jednostek początkowych, otrzymano: %d", len(units))
	}
}

func TestCreateDispatchAndStatusTransitions(t *testing.T) {
	srv, st := setupTestServer()

	// 1. Dyspozytor tworzy nowe zlecenie wyjazdu (KZW)
	newDispatch := models.Dispatch{
		Priority:        models.PriorityKod1,
		ChiefComplaint:  "Podejrzenie udaru mózgu (FAST)",
		IncidentAddress: "ul. Puławska 45 m. 12",
		IncidentCity:    "Warszawa",
		AssignedUnitID:  "ZRM-01",
	}

	bodyBytes, _ := json.Marshal(newDispatch)
	req, _ := http.NewRequest(http.MethodPost, "/api/v1/dispatches", bytes.NewBuffer(bodyBytes))
	rr := httptest.NewRecorder()

	srv.ServeHTTP(rr, req)

	if rr.Code != http.StatusCreated {
		t.Fatalf("Oczekiwano statusu 201 Created, otrzymano: %d - %s", rr.Code, rr.Body.String())
	}

	var created models.Dispatch
	if err := json.Unmarshal(rr.Body.Bytes(), &created); err != nil {
		t.Fatalf("Błąd odczytu zlecenia: %v", err)
	}

	if created.ID == "" || created.AssignedUnitID != "ZRM-01" {
		t.Errorf("Błąd przypisania zlecenia: %+v", created)
	}

	// 2. Symulacja zmiany statusów przez tablet ZRM: Status 1 -> Status 2 -> Status 6
	// Status 1: Wyjazd
	u1, d1, err := st.UpdateUnitStatus(models.StatusUpdatePayload{
		UnitID:     "ZRM-01",
		DispatchID: created.ID,
		NewStatus:  models.Status1_Wyjazd,
		Timestamp:  time.Now(),
	})
	if err != nil {
		t.Fatalf("Błąd aktualizacji do statusu 1: %v", err)
	}
	if u1.CurrentStatus != models.Status1_Wyjazd || d1.Status != models.DispatchStatusWRealizacji {
		t.Errorf("Niepoprawny stan po Status 1: UnitStatus=%v, DispatchStatus=%v", u1.CurrentStatus, d1.Status)
	}

	// Status 6: Gotowość (zakończenie działań)
	u6, d6, err := st.UpdateUnitStatus(models.StatusUpdatePayload{
		UnitID:     "ZRM-01",
		DispatchID: created.ID,
		NewStatus:  models.Status6_Gotowosc,
		Timestamp:  time.Now(),
	})
	if err != nil {
		t.Fatalf("Błąd aktualizacji do statusu 6: %v", err)
	}
	if u6.CurrentStatus != models.Status6_Gotowosc || d6.Status != models.DispatchStatusZakonczone {
		t.Errorf("Niepoprawny stan po Status 6: UnitStatus=%v, DispatchStatus=%v", u6.CurrentStatus, d6.Status)
	}
}
