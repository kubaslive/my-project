package models

import "time"

// StatusType reprezentuje status operacyjny zespołu ratownictwa (standard 1-6 w SWD PRM)
type StatusType int

const (
	StatusBrak               StatusType = 0
	Status1_Wyjazd           StatusType = 1 // 1: Wyjazd do zdarzenia
	Status2_NaMiejscu        StatusType = 2 // 2: Przybycie na miejsce zdarzenia
	Status3_PrzejeciePacjenta StatusType = 3 // 3: Rozpoczęcie czynności / przejęcie pacjenta
	Status4_Transport        StatusType = 4 // 4: Rozpoczęcie transportu do szpitala
	Status5_WSzpitalu        StatusType = 5 // 5: Przybycie do SOR / przekazanie pacjenta
	Status6_Gotowosc         StatusType = 6 // 6: Zakończenie działań / gotowość operacyjna
)

func (s StatusType) String() string {
	switch s {
	case Status1_Wyjazd:
		return "1 - Wyjazd"
	case Status2_NaMiejscu:
		return "2 - Na miejscu"
	case Status3_PrzejeciePacjenta:
		return "3 - Pacjent przejęty"
	case Status4_Transport:
		return "4 - Transport"
	case Status5_WSzpitalu:
		return "5 - W szpitalu"
	case Status6_Gotowosc:
		return "6 - Gotowość"
	default:
		return "0 - Brak / Niedostępny"
	}
}

// ZRMUnit reprezentuje karetkę / zespół ratownictwa medycznego
type ZRMUnit struct {
	ID                string      `json:"id"`                  // np. "ZRM-01"
	Callsign          string      `json:"callsign"`            // np. "W01-01"
	Type              string      `json:"type"`                // "P" (Podstawowy), "S" (Specjalistyczny), "M" (Motoambulans)
	BaseStation       string      `json:"base_station"`        // Stacja wyczekiwania
	CurrentStatus     StatusType  `json:"current_status"`      // Status 1-6
	CurrentDispatchID *string     `json:"current_dispatch_id"` // ID aktywnego KZW lub nil
	Latitude          float64     `json:"latitude"`            // Ostatnia znana pozycja GPS
	Longitude         float64     `json:"longitude"`
	LastStatusTime    time.Time   `json:"last_status_time"`
	IsConnected       bool        `json:"is_connected"`        // Czy tablet ma aktywne połączenie z serwerem
}

// DispatchPriority określa priorytet wyjazdu
type DispatchPriority string

const (
	PriorityKod1 DispatchPriority = "KOD_1" // Wyjazd w trybie pilnym (sygnały uprzywilejowania)
	PriorityKod2 DispatchPriority = "KOD_2" // Wyjazd w trybie zwykłym
)

// DispatchStatus określa stan zlecenia wyjazdu
type DispatchStatus string

const (
	DispatchStatusNowe         DispatchStatus = "NOWE"
	DispatchStatusZadysponowane DispatchStatus = "ZADYSPONOWANE"
	DispatchStatusWRealizacji  DispatchStatus = "W_REALIZACJI"
	DispatchStatusZakonczone   DispatchStatus = "ZAKONCZONE"
	DispatchStatusAnulowane    DispatchStatus = "ANULOWANE"
)

// Dispatch reprezentuje Kartę Zlecenia Wyjazdu (KZW)
type Dispatch struct {
	ID               string           `json:"id"`
	CreatedTime      time.Time        `json:"created_time"`
	DispatchedTime   *time.Time       `json:"dispatched_time,omitempty"`
	Priority         DispatchPriority `json:"priority"`
	ChiefComplaint   string           `json:"chief_complaint"` // Powód wezwania, np. "Utrata przytomności"
	Description      string           `json:"description"`     // Wywiad wstępny dyspozytora
	IncidentAddress  string           `json:"incident_address"`
	IncidentCity     string           `json:"incident_city"`
	Latitude         float64          `json:"latitude"`
	Longitude        float64          `json:"longitude"`
	PatientName      string           `json:"patient_name,omitempty"`
	PatientAge       int              `json:"patient_age,omitempty"`
	PatientGender    string           `json:"patient_gender,omitempty"` // "M", "K"
	AssignedUnitID   string           `json:"assigned_unit_id"`
	Status           DispatchStatus   `json:"status"`
	DispatcherNotes  string           `json:"dispatcher_notes,omitempty"`
	Timeline         map[int]time.Time `json:"timeline"` // Mapa czasów statusów 1-6
}

// VitalSigns zawiera zmierzone parametry życiowe pacjenta
type VitalSigns struct {
	HeartRate        int     `json:"heart_rate"`        // Tętno [bpm]
	SystolicBP       int     `json:"systolic_bp"`       // Skurczowe [mmHg]
	DiastolicBP      int     `json:"diastolic_bp"`      // Rozkurczowe [mmHg]
	SpO2             int     `json:"spo2"`              // Saturacja [%]
	EtCO2            float64 `json:"etco2,omitempty"`   // EtCO2 [mmHg]
	BloodGlucose     float64 `json:"blood_glucose"`     // Cukier [mg/dl]
	Temperature      float64 `json:"temperature"`       // Temp [C]
	RespiratoryRate  int     `json:"respiratory_rate"`  // Oddechy [/min]
	MeasuredAt       time.Time `json:"measured_at"`
}

// GCS zawiera składowe skali Glasgow (3-15)
type GCS struct {
	EyeOpening     int `json:"eye_opening"`     // 1-4
	VerbalResponse int `json:"verbal_response"` // 1-5
	MotorResponse  int `json:"motor_response"`  // 1-6
	TotalScore     int `json:"total_score"`     // 3-15
}

// MedicationAdministered reprezentuje lek podany przez zespół
type MedicationAdministered struct {
	Name      string    `json:"name"`       // np. "Adrenalina"
	Dose      string    `json:"dose"`       // np. "1 mg"
	Route     string    `json:"route"`      // np. "i.v.", "i.m.", "p.o."
	GivenAt   time.Time `json:"given_at"`
	GivenBy   string    `json:"given_by"`
}

// MedicalProcedure reprezentuje procedurę medyczną wykonaną przez zespół
type MedicalProcedure struct {
	Name        string    `json:"name"` // np. "Kaniulacja żyły obwodowej", "Intubacja", "Defibrylacja"
	PerformedAt time.Time `json:"performed_at"`
	Notes       string    `json:"notes,omitempty"`
}

// KMCR reprezentuje Kartę Medycznych Czynności Ratunkowych
type KMCR struct {
	ID                 string                   `json:"id"`
	DispatchID         string                   `json:"dispatch_id"`
	UnitID             string                   `json:"unit_id"`
	CrewLead           string                   `json:"crew_lead"`
	CrewMembers        []string                 `json:"crew_members"`
	SampleS            string                   `json:"sample_s"` // Objawy (Symptoms)
	SampleA            string                   `json:"sample_a"` // Alergie
	SampleM            string                   `json:"sample_m"` // Leki stale przyjmowane
	SampleP            string                   `json:"sample_p"` // Przebyte choroby
	SampleL            string                   `json:"sample_l"` // Ostatni posiłek
	SampleE            string                   `json:"sample_e"` // Okoliczności zdarzenia
	VitalSignsHistory  []VitalSigns             `json:"vital_signs_history"`
	GCS                GCS                      `json:"gcs"`
	PainScoreVAS       int                      `json:"pain_score_vas"` // 0-10
	Procedures         []MedicalProcedure       `json:"procedures"`
	Medications        []MedicationAdministered `json:"medications"`
	ICD10Code          string                   `json:"icd10_code"`
	ICD10Description   string                   `json:"icd10_description"`
	TargetHospital     string                   `json:"target_hospital,omitempty"`
	ReceivingDoctor    string                   `json:"receiving_doctor,omitempty"`
	HandoverTime       *time.Time               `json:"handover_time,omitempty"`
	IsFinalized        bool                     `json:"is_finalized"`
	UpdatedAt          time.Time                `json:"updated_at"`
}

// WSMessageType typ komunikatu WebSocket
type WSMessageType string

const (
	MsgRegister          WSMessageType = "REGISTER"
	MsgStatusUpdate      WSMessageType = "STATUS_UPDATE"
	MsgDispatchNew       WSMessageType = "DISPATCH_NEW"
	MsgDispatchUpdate    WSMessageType = "DISPATCH_UPDATE"
	MsgKMCRUpdate        WSMessageType = "KMCR_UPDATE"
	MsgUnitsList         WSMessageType = "UNITS_LIST"
	MsgAck               WSMessageType = "ACK"
	MsgError             WSMessageType = "ERROR"
)

// WSMessage format ramki sieciowej dla protokołu WebSocket
type WSMessage struct {
	Type       WSMessageType `json:"type"`
	SenderRole string        `json:"sender_role"` // "DISPATCHER" lub "TABLET_ZRM"
	SenderID   string        `json:"sender_id"`
	TargetID   string        `json:"target_id,omitempty"` // Opcjonalny adresat (np. konkretny ZRM)
	Payload    any           `json:"payload"`
	Timestamp  time.Time     `json:"timestamp"`
}

// StatusUpdatePayload payload dla zmiany statusu 1-6
type StatusUpdatePayload struct {
	UnitID     string     `json:"unit_id"`
	DispatchID string     `json:"dispatch_id,omitempty"`
	NewStatus  StatusType `json:"new_status"`
	Latitude   float64    `json:"latitude"`
	Longitude  float64    `json:"longitude"`
	Timestamp  time.Time  `json:"timestamp"`
	SeqID      int64      `json:"seq_id,omitempty"` // Numer sekwencyjny bufora offline
}
