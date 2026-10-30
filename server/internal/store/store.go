package store

import (
	"fmt"
	"sync"
	"time"

	"swd-prm-backend/internal/models"
)

// Store przechowuje stan systemu w pamięci (z możliwością persystencji)
type Store struct {
	mu         sync.RWMutex
	units      map[string]*models.ZRMUnit
	dispatches map[string]*models.Dispatch
	kmcr       map[string]*models.KMCR // klucz: dispatch_id
}

// NewStore tworzy nowy Store ze startową konfiguracją jednostek ZRM
func NewStore() *Store {
	s := &Store{
		units:      make(map[string]*models.ZRMUnit),
		dispatches: make(map[string]*models.Dispatch),
		kmcr:       make(map[string]*models.KMCR),
	}
	s.seedDefaultUnits()
	return s
}

func (s *Store) seedDefaultUnits() {
	now := time.Now()
	defaults := []*models.ZRMUnit{
		{
			ID:             "ZRM-01",
			Callsign:       "W01-01",
			Type:           "P",
			BaseStation:    "Stacja Pogotowia Śródmieście",
			CurrentStatus:  models.Status6_Gotowosc,
			Latitude:       52.2297,
			Longitude:      21.0122,
			LastStatusTime: now,
			IsConnected:    false,
		},
		{
			ID:             "ZRM-02",
			Callsign:       "W01-02",
			Type:           "S",
			BaseStation:    "Stacja Pogotowia Mokotów",
			CurrentStatus:  models.Status6_Gotowosc,
			Latitude:       52.1939,
			Longitude:      21.0315,
			LastStatusTime: now,
			IsConnected:    false,
		},
		{
			ID:             "ZRM-03",
			Callsign:       "M01-01",
			Type:           "M",
			BaseStation:    "Stacja Pogotowia Wola",
			CurrentStatus:  models.Status6_Gotowosc,
			Latitude:       52.2384,
			Longitude:      20.9856,
			LastStatusTime: now,
			IsConnected:    false,
		},
	}

	for _, u := range defaults {
		s.units[u.ID] = u
	}
}

// GetAllUnits pobiera listę wszystkich jednostek ZRM
func (s *Store) GetAllUnits() []*models.ZRMUnit {
	s.mu.RLock()
	defer s.mu.RUnlock()

	result := make([]*models.ZRMUnit, 0, len(s.units))
	for _, u := range s.units {
		// Kopia obiektu dla bezpieczeństwa
		unitCopy := *u
		result = append(result, &unitCopy)
	}
	return result
}

// GetUnit pobiera jednostkę o wskazanym ID
func (s *Store) GetUnit(id string) (*models.ZRMUnit, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	u, exists := s.units[id]
	if !exists {
		return nil, false
	}
	unitCopy := *u
	return &unitCopy, true
}

// SetUnitConnected aktualizuje stan połączenia urządzenia
func (s *Store) SetUnitConnected(id string, connected bool) {
	s.mu.Lock()
	defer s.mu.Unlock()

	if u, exists := s.units[id]; exists {
		u.IsConnected = connected
	}
}

// UpdateUnitStatus aktualizuje status jednostki ZRM oraz odpowiednie zlecenie wyjazdu
func (s *Store) UpdateUnitStatus(payload models.StatusUpdatePayload) (*models.ZRMUnit, *models.Dispatch, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	unit, exists := s.units[payload.UnitID]
	if !exists {
		return nil, nil, fmt.Errorf("nie znaleziono jednostki o ID: %s", payload.UnitID)
	}

	unit.CurrentStatus = payload.NewStatus
	unit.LastStatusTime = payload.Timestamp
	if payload.Latitude != 0 && payload.Longitude != 0 {
		unit.Latitude = payload.Latitude
		unit.Longitude = payload.Longitude
	}

	var updatedDispatch *models.Dispatch

	// Jeśli wskazano dispatch lub jednostka ma przypisany dispatch
	dispatchID := payload.DispatchID
	if dispatchID == "" && unit.CurrentDispatchID != nil {
		dispatchID = *unit.CurrentDispatchID
	}

	if dispatchID != "" {
		if d, dExists := s.dispatches[dispatchID]; dExists {
			if d.Timeline == nil {
				d.Timeline = make(map[int]time.Time)
			}
			d.Timeline[int(payload.NewStatus)] = payload.Timestamp

			switch payload.NewStatus {
			case models.Status1_Wyjazd, models.Status2_NaMiejscu, models.Status3_PrzejeciePacjenta, models.Status4_Transport, models.Status5_WSzpitalu:
				d.Status = models.DispatchStatusWRealizacji
			case models.Status6_Gotowosc:
				d.Status = models.DispatchStatusZakonczone
				unit.CurrentDispatchID = nil // Zwolnienie jednostki
			}
			updatedDispatch = d
		}
	}

	unitCopy := *unit
	return &unitCopy, updatedDispatch, nil
}

// CreateDispatch tworzy i zapisuje nowe zlecenie wyjazdu (KZW)
func (s *Store) CreateDispatch(d *models.Dispatch) (*models.Dispatch, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	if d.ID == "" {
		d.ID = fmt.Sprintf("KZW-%s-%03d", time.Now().Format("20060102-1504"), len(s.dispatches)+1)
	}
	d.CreatedTime = time.Now()
	now := time.Now()
	d.DispatchedTime = &now
	d.Status = models.DispatchStatusZadysponowane
	if d.Timeline == nil {
		d.Timeline = make(map[int]time.Time)
	}

	// Przypisanie do jednostki ZRM
	if unit, exists := s.units[d.AssignedUnitID]; exists {
		unit.CurrentDispatchID = &d.ID
	}

	s.dispatches[d.ID] = d

	// Inicjalizacja pustej karty KMCR dla tego zlecenia
	s.kmcr[d.ID] = &models.KMCR{
		ID:                 fmt.Sprintf("KMCR-%s", d.ID),
		DispatchID:         d.ID,
		UnitID:             d.AssignedUnitID,
		VitalSignsHistory:  make([]models.VitalSigns, 0),
		Procedures:         make([]models.MedicalProcedure, 0),
		Medications:        make([]models.MedicationAdministered, 0),
		UpdatedAt:          time.Now(),
	}

	return d, nil
}

// GetAllDispatches zwraca listę wszystkich zleceń
func (s *Store) GetAllDispatches() []*models.Dispatch {
	s.mu.RLock()
	defer s.mu.RUnlock()

	result := make([]*models.Dispatch, 0, len(s.dispatches))
	for _, d := range s.dispatches {
		dCopy := *d
		result = append(result, &dCopy)
	}
	return result
}

// GetDispatch zwraca pojedyncze zlecenie
func (s *Store) GetDispatch(id string) (*models.Dispatch, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	d, exists := s.dispatches[id]
	if !exists {
		return nil, false
	}
	dCopy := *d
	return &dCopy, true
}

// GetKMCR pobiera kartę medyczną dla wskazanego zlecenia
func (s *Store) GetKMCR(dispatchID string) (*models.KMCR, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	k, exists := s.kmcr[dispatchID]
	if !exists {
		return nil, false
	}
	kCopy := *k
	return &kCopy, true
}

// SaveKMCR zapisuje lub aktualizuje kartę medyczną
func (s *Store) SaveKMCR(kmcr *models.KMCR) *models.KMCR {
	s.mu.Lock()
	defer s.mu.Unlock()

	kmcr.UpdatedAt = time.Now()
	s.kmcr[kmcr.DispatchID] = kmcr
	return kmcr
}
