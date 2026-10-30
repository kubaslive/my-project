import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/models/models.dart';
import '../../core/network/api_client.dart';
import '../../core/network/websocket_client.dart';

class DispatcherScreen extends StatefulWidget {
  final ApiClient apiClient;
  final WebSocketService wsService;

  const DispatcherScreen({
    super.key,
    required this.apiClient,
    required this.wsService,
  });

  @override
  State<DispatcherScreen> createState() => _DispatcherScreenState();
}

class _DispatcherScreenState extends State<DispatcherScreen> {
  final List<ZRMUnit> _units = [];
  final List<Dispatch> _dispatches = [];
  StreamSubscription? _wsSub;

  // Kontrolery formularza KZW
  String _priority = 'KOD_1';
  String _assignedUnitId = 'ZRM-01';
  final _complaintController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController(text: 'Warszawa');
  final _patientController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _subscribeWebSocket();
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final units = await widget.apiClient.getUnits();
      final dispatches = await widget.apiClient.getDispatches();
      setState(() {
        _units.clear();
        _units.addAll(units);
        _dispatches.clear();
        _dispatches.addAll(dispatches);
      });
    } catch (_) {}
  }

  void _subscribeWebSocket() {
    _wsSub = widget.wsService.messages.listen((msg) {
      if (msg.type == 'STATUS_UPDATE') {
        final payload = msg.payload;
        if (payload is Map && payload['unit'] != null) {
          final updatedUnit = ZRMUnit.fromJson(payload['unit']);
          setState(() {
            final idx = _units.indexWhere((u) => u.id == updatedUnit.id);
            if (idx != -1) {
              _units[idx] = updatedUnit;
            } else {
              _units.add(updatedUnit);
            }
          });
        }
      } else if (msg.type == 'DISPATCH_NEW') {
        if (msg.payload is Map) {
          final newDispatch = Dispatch.fromJson(msg.payload);
          setState(() {
            _dispatches.insert(0, newDispatch);
          });
        }
      } else if (msg.type == 'UNITS_LIST') {
        if (msg.payload is List) {
          final list = (msg.payload as List)
              .map((e) => ZRMUnit.fromJson(e))
              .toList();
          setState(() {
            _units.clear();
            _units.addAll(list);
          });
        }
      }
    });
  }

  Color _getStatusColor(StatusType status) {
    switch (status) {
      case StatusType.wyjazd:
        return const Color(0xFF1D4ED8);
      case StatusType.naMiejscu:
        return const Color(0xFF6D28D9);
      case StatusType.przejeciePacjenta:
        return const Color(0xFFBE185D);
      case StatusType.transport:
        return const Color(0xFFC2410C);
      case StatusType.wSzpitalu:
        return const Color(0xFFA16207);
      case StatusType.gotowosc:
        return const Color(0xFF047857);
      default:
        return const Color(0xFF475569);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: Row(
          children: [
            const Text('🖥️ Stanowisko Dyspozytora Medycznego (SWD PRM)'),
            const SizedBox(width: 16),
            StreamBuilder<bool>(
              stream: widget.wsService.isConnectedStream,
              initialData: widget.wsService.isConnected,
              builder: (context, snapshot) {
                final isConn = snapshot.data ?? false;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isConn
                        ? Colors.green.withOpacity(0.2)
                        : Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isConn ? Colors.green : Colors.red,
                    ),
                  ),
                  child: Text(
                    isConn ? 'POŁĄCZONO (mTLS / LAN)' : 'ROZŁĄCZONO',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isConn ? Colors.greenAccent : Colors.redAccent,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Lewa kolumna: Monitor karetek ZRM
          Expanded(
            flex: 4,
            child: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ZESPOŁY RATOWNICTWA MEDYCZNEGO (ZRM)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _units.length,
                      itemBuilder: (context, index) {
                        final u = _units[index];
                        final stColor = _getStatusColor(u.currentStatus);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0B1120),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF334155)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${u.callsign} (${u.type == "P" ? "Podstawowy" : u.type == "S" ? "Specjalistyczny" : "Moto"})',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    u.baseStation,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: stColor,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  u.currentStatus.label,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              )
                            ],
                          ),
                        );
                      },
                    ),
                  )
                ],
              ),
            ),
          ),

          // Środkowa kolumna: Formularz KZW
          Expanded(
            flex: 4,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      '➕ NOWA KARTA ZLECENIA WYJAZDU (KZW)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF60A5FA),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _priority,
                            dropdownColor: const Color(0xFF1E293B),
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: 'PRIORYTET',
                              labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                            ),
                            items: const [
                              DropdownMenuItem(
                                  value: 'KOD_1',
                                  child: Text('KOD 1 (Pilny 🚨)')),
                              DropdownMenuItem(
                                  value: 'KOD_2', child: Text('KOD 2 (Zwykły)')),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _priority = val);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _assignedUnitId,
                            dropdownColor: const Color(0xFF1E293B),
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: 'ZESPÓŁ',
                              labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                            ),
                            items: _units.map((u) {
                              return DropdownMenuItem(
                                value: u.id,
                                child: Text('${u.callsign} (${u.type})'),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _assignedUnitId = val);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _complaintController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'POWÓD WEZWANIA / GŁÓWNY OBJAW',
                        labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                        hintText: 'np. Ból w klatce piersiowej, duszność',
                        hintStyle: TextStyle(color: Color(0xFF64748B)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _addressController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'ADRES ZDARZENIA',
                        labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                        hintText: 'np. ul. Marszałkowska 10/12 m. 5',
                        hintStyle: TextStyle(color: Color(0xFF64748B)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _patientController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'DANE PACJENTA / WYWIAD',
                        labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                        hintText: 'Jan Kowalski, 60 lat',
                        hintStyle: TextStyle(color: Color(0xFF64748B)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _submitDispatch,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('🚨 ZADYSPONUJ ZESPÓŁ (WYŚLIJ KZW)'),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Prawa kolumna: Aktywne zgłoszenia
          Expanded(
            flex: 4,
            child: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'REJESTR ZLECEŃ WYJAZDU (KZW)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _dispatches.isEmpty
                        ? const Center(
                            child: Text(
                              'Brak aktywnych zleceń',
                              style: TextStyle(color: Color(0xFF94A3B8)),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _dispatches.length,
                            itemBuilder: (context, index) {
                              final d = _dispatches[index];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0B1120),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border(
                                    left: BorderSide(
                                      color: d.isUrgent
                                          ? Colors.redAccent
                                          : Colors.blueAccent,
                                      width: 4,
                                    ),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '[${d.priority}] ${d.assignedUnitId}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: d.isUrgent
                                                ? Colors.redAccent
                                                : Colors.blueAccent,
                                          ),
                                        ),
                                        Text(
                                          d.status,
                                          style: const TextStyle(
                                            color: Color(0xFF60A5FA),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      d.chiefComplaint,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Text(
                                      '${d.incidentAddress}, ${d.incidentCity}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitDispatch() async {
    final complaint = _complaintController.text.trim();
    final address = _addressController.text.trim();
    if (complaint.isEmpty || address.isEmpty) return;

    final newDispatch = Dispatch(
      id: '',
      createdTime: DateTime.now(),
      priority: _priority,
      chiefComplaint: complaint,
      description: _patientController.text.trim(),
      incidentAddress: address,
      incidentCity: _cityController.text.trim(),
      latitude: 52.23,
      longitude: 21.01,
      assignedUnitId: _assignedUnitId,
      status: 'ZADYSPONOWANE',
    );

    try {
      await widget.apiClient.createDispatch(newDispatch);
      _complaintController.clear();
      _addressController.clear();
      _patientController.clear();
    } catch (_) {}
  }
}
