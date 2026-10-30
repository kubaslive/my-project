import 'dart:convert';

/// Status operacyjny zespołu ratownictwa medycznego (1-6)
enum StatusType {
  brak(0, '0 - Brak'),
  wyjazd(1, '1 - Wyjazd'),
  naMiejscu(2, '2 - Na miejscu'),
  przejeciePacjenta(3, '3 - Pacjent przejęty'),
  transport(4, '4 - Transport'),
  wSzpitalu(5, '5 - W szpitalu'),
  gotowosc(6, '6 - Gotowość');

  final int code;
  final String label;
  const StatusType(this.code, this.label);

  static StatusType fromCode(int code) {
    return StatusType.values.firstWhere(
      (s) => s.code == code,
      orElse: () => StatusType.brak,
    );
  }
}

/// Zespół Ratownictwa Medycznego (karetka)
class ZRMUnit {
  final String id;
  final String callsign;
  final String type; // 'P', 'S', 'M'
  final String baseStation;
  final StatusType currentStatus;
  final String? currentDispatchId;
  final double latitude;
  final double longitude;
  final DateTime lastStatusTime;
  final bool isConnected;

  ZRMUnit({
    required this.id,
    required this.callsign,
    required this.type,
    required this.baseStation,
    required this.currentStatus,
    this.currentDispatchId,
    required this.latitude,
    required this.longitude,
    required this.lastStatusTime,
    required this.isConnected,
  });

  factory ZRMUnit.fromJson(Map<String, dynamic> json) {
    return ZRMUnit(
      id: json['id'] ?? '',
      callsign: json['callsign'] ?? '',
      type: json['type'] ?? 'P',
      baseStation: json['base_station'] ?? '',
      currentStatus: StatusType.fromCode(json['current_status'] ?? 0),
      currentDispatchId: json['current_dispatch_id'],
      latitude: (json['latitude'] as num?)?.toDouble() ?? 52.2297,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 21.0122,
      lastStatusTime: json['last_status_time'] != null
          ? DateTime.tryParse(json['last_status_time']) ?? DateTime.now()
          : DateTime.now(),
      isConnected: json['is_connected'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'callsign': callsign,
        'type': type,
        'base_station': baseStation,
        'current_status': currentStatus.code,
        'current_dispatch_id': currentDispatchId,
        'latitude': latitude,
        'longitude': longitude,
        'last_status_time': lastStatusTime.toIso8601String(),
        'is_connected': isConnected,
      };
}

/// Karta Zlecenia Wyjazdu (KZW)
class Dispatch {
  final String id;
  final DateTime createdTime;
  final DateTime? dispatchedTime;
  final String priority; // 'KOD_1' lub 'KOD_2'
  final String chiefComplaint;
  final String description;
  final String incidentAddress;
  final String incidentCity;
  final double latitude;
  final double longitude;
  final String? patientName;
  final int? patientAge;
  final String? patientGender;
  final String assignedUnitId;
  final String status;
  final String? dispatcherNotes;
  final Map<int, String>? timeline;

  Dispatch({
    required this.id,
    required this.createdTime,
    this.dispatchedTime,
    required this.priority,
    required this.chiefComplaint,
    required this.description,
    required this.incidentAddress,
    required this.incidentCity,
    required this.latitude,
    required this.longitude,
    this.patientName,
    this.patientAge,
    this.patientGender,
    required this.assignedUnitId,
    required this.status,
    this.dispatcherNotes,
    this.timeline,
  });

  bool get isUrgent => priority == 'KOD_1';

  factory Dispatch.fromJson(Map<String, dynamic> json) {
    Map<int, String>? tl;
    if (json['timeline'] is Map) {
      tl = {};
      (json['timeline'] as Map).forEach((k, v) {
        final keyInt = int.tryParse(k.toString()) ?? 0;
        tl![keyInt] = v.toString();
      });
    }

    return Dispatch(
      id: json['id'] ?? '',
      createdTime: json['created_time'] != null
          ? DateTime.tryParse(json['created_time']) ?? DateTime.now()
          : DateTime.now(),
      dispatchedTime: json['dispatched_time'] != null
          ? DateTime.tryParse(json['dispatched_time'])
          : null,
      priority: json['priority'] ?? 'KOD_2',
      chiefComplaint: json['chief_complaint'] ?? '',
      description: json['description'] ?? '',
      incidentAddress: json['incident_address'] ?? '',
      incidentCity: json['incident_city'] ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 52.2297,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 21.0122,
      patientName: json['patient_name'],
      patientAge: json['patient_age'],
      patientGender: json['patient_gender'],
      assignedUnitId: json['assigned_unit_id'] ?? '',
      status: json['status'] ?? 'NOWE',
      dispatcherNotes: json['dispatcher_notes'],
      timeline: tl,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'created_time': createdTime.toIso8601String(),
        'dispatched_time': dispatchedTime?.toIso8601String(),
        'priority': priority,
        'chief_complaint': chiefComplaint,
        'description': description,
        'incident_address': incidentAddress,
        'incident_city': incidentCity,
        'latitude': latitude,
        'longitude': longitude,
        'patient_name': patientName,
        'patient_age': patientAge,
        'patient_gender': patientGender,
        'assigned_unit_id': assignedUnitId,
        'status': status,
        'dispatcher_notes': dispatcherNotes,
      };
}

/// Parametry życiowe pacjenta
class VitalSigns {
  final int heartRate;
  final int systolicBP;
  final int diastolicBP;
  final int spO2;
  final double? bloodGlucose;
  final double? temperature;
  final int? gcsScore;
  final DateTime measuredAt;

  VitalSigns({
    required this.heartRate,
    required this.systolicBP,
    required this.diastolicBP,
    required this.spO2,
    this.bloodGlucose,
    this.temperature,
    this.gcsScore,
    required this.measuredAt,
  });

  factory VitalSigns.fromJson(Map<String, dynamic> json) {
    return VitalSigns(
      heartRate: json['heart_rate'] ?? 0,
      systolicBP: json['systolic_bp'] ?? 0,
      diastolicBP: json['diastolic_bp'] ?? 0,
      spO2: json['spo2'] ?? 0,
      bloodGlucose: (json['blood_glucose'] as num?)?.toDouble(),
      temperature: (json['temperature'] as num?)?.toDouble(),
      gcsScore: json['gcs_score'],
      measuredAt: json['measured_at'] != null
          ? DateTime.tryParse(json['measured_at']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'heart_rate': heartRate,
        'systolic_bp': systolicBP,
        'diastolic_bp': diastolicBP,
        'spo2': spO2,
        'blood_glucose': bloodGlucose,
        'temperature': temperature,
        'gcs_score': gcsScore,
        'measured_at': measuredAt.toIso8601String(),
      };
}

/// Karta Medycznych Czynności Ratunkowych (KMCR)
class KMCR {
  final String id;
  final String dispatchId;
  final String unitId;
  final String? crewLead;
  final String? sampleS; // Objawy
  final String? sampleA; // Alergie
  final String? sampleM; // Medykamenty
  final String? sampleP; // Przeszłość chorobowa
  final String? sampleL; // Lunch / posiłek
  final String? sampleE; // Event / okoliczności
  final List<VitalSigns> vitalSignsHistory;
  final int gcsScore;
  final String? icd10Code;
  final String? icd10Description;
  final String? targetHospital;
  final bool isFinalized;
  final DateTime updatedAt;

  KMCR({
    required this.id,
    required this.dispatchId,
    required this.unitId,
    this.crewLead,
    this.sampleS,
    this.sampleA,
    this.sampleM,
    this.sampleP,
    this.sampleL,
    this.sampleE,
    this.vitalSignsHistory = const [],
    this.gcsScore = 15,
    this.icd10Code,
    this.icd10Description,
    this.targetHospital,
    this.isFinalized = false,
    required this.updatedAt,
  });

  factory KMCR.fromJson(Map<String, dynamic> json) {
    final vitals = (json['vital_signs_history'] as List<dynamic>?)
            ?.map((e) => VitalSigns.fromJson(e))
            .toList() ??
        [];

    return KMCR(
      id: json['id'] ?? '',
      dispatchId: json['dispatch_id'] ?? '',
      unitId: json['unit_id'] ?? '',
      crewLead: json['crew_lead'],
      sampleS: json['sample_s'],
      sampleA: json['sample_a'],
      sampleM: json['sample_m'],
      sampleP: json['sample_p'],
      sampleL: json['sample_l'],
      sampleE: json['sample_e'],
      vitalSignsHistory: vitals,
      gcsScore: json['gcs']?['total_score'] ?? json['gcs_score'] ?? 15,
      icd10Code: json['icd10_code'],
      icd10Description: json['icd10_description'],
      targetHospital: json['target_hospital'],
      isFinalized: json['is_finalized'] ?? false,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'dispatch_id': dispatchId,
        'unit_id': unitId,
        'crew_lead': crewLead,
        'sample_s': sampleS,
        'sample_a': sampleA,
        'sample_m': sampleM,
        'sample_p': sampleP,
        'sample_l': sampleL,
        'sample_e': sampleE,
        'vital_signs_history': vitalSignsHistory.map((e) => e.toJson()).toList(),
        'gcs_score': gcsScore,
        'icd10_code': icd10Code,
        'icd10_description': icd10Description,
        'target_hospital': targetHospital,
        'is_finalized': isFinalized,
        'updated_at': updatedAt.toIso8601String(),
      };
}

/// Wiadomość WebSocket
class WSMessage {
  final String type;
  final String senderRole;
  final String senderId;
  final dynamic payload;
  final DateTime timestamp;

  WSMessage({
    required this.type,
    required this.senderRole,
    required this.senderId,
    required this.payload,
    required this.timestamp,
  });

  factory WSMessage.fromJson(Map<String, dynamic> json) {
    return WSMessage(
      type: json['type'] ?? '',
      senderRole: json['sender_role'] ?? '',
      senderId: json['sender_id'] ?? '',
      payload: json['payload'],
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'sender_role': senderRole,
        'sender_id': senderId,
        'payload': payload,
        'timestamp': timestamp.toIso8601String(),
      };
}
