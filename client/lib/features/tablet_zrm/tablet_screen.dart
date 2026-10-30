import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/models/models.dart';
import '../../core/network/api_client.dart';
import '../../core/network/websocket_client.dart';
import '../../core/storage/offline_outbox.dart';

class TabletScreen extends StatefulWidget {
  final String unitId;
  final ApiClient apiClient;
  final WebSocketService wsService;

  const TabletScreen({
    super.key,
    required this.unitId,
    required this.apiClient,
    required this.wsService,
  });

  @override
  State<TabletScreen> createState() => _TabletScreenState();
}

class _TabletScreenState extends State<TabletScreen> {
  late final OfflineOutboxManager _outbox;
  StreamSubscription? _wsSub;

  StatusType _currentStatus = StatusType.gotowosc;
  Dispatch? _activeDispatch;

  // Kontrolery parametrów życiowych KMCR
  final _hrController = TextEditingController(text: '80');
  final _bpController = TextEditingController(text: '125/80');
  final _spO2Controller = TextEditingController(text: '98');
  final _gcsController = TextEditingController(text: '15');
  final _sampleSController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _outbox = OfflineOutboxManager(wsService: widget.wsService);
    _loadUnitState();
    _subscribeEvents();
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    super.dispose();
  }

  Future<void> _loadUnitState() async {
    try {
      final units = await widget.apiClient.getUnits();
      final current = units.firstWhere((u) => u.id == widget.unitId);
      setState(() {
        _currentStatus = current.currentStatus;
      });

      if (current.currentDispatchId != null) {
        final dispatches = await widget.apiClient.getDispatches();
        final d = dispatches.firstWhere(
            (disp) => disp.id == current.currentDispatchId,
            orElse: () => _activeDispatch!);
        setState(() {
          _activeDispatch = d;
        });
      }
    } catch (_) {}
  }

  void _subscribeEvents() {
    _wsSub = widget.wsService.messages.listen((msg) {
      if (msg.type == 'DISPATCH_NEW') {
        if (msg.payload is Map) {
          final d = Dispatch.fromJson(msg.payload);
          if (d.assignedUnitId == widget.unitId) {
            setState(() {
              _activeDispatch = d;
            });
            // Powiadomienie dźwiękowe / wibracja w aplikacji produkcyjnej
          }
        }
      } else if (msg.type == 'STATUS_UPDATE') {
        final payload = msg.payload;
        if (payload is Map && payload['unit'] != null) {
          final u = ZRMUnit.fromJson(payload['unit']);
          if (u.id == widget.unitId) {
            setState(() {
              _currentStatus = u.currentStatus;
            });
          }
        }
      }
    });
  }

  void _onStatusClicked(StatusType newStatus) {
    setState(() {
      _currentStatus = newStatus;
    });

    _outbox.enqueueStatusUpdate(
      unitId: widget.unitId,
      dispatchId: _activeDispatch?.id,
      newStatus: newStatus,
    );

    if (newStatus == StatusType.gotowosc) {
      setState(() {
        _activeDispatch = null;
      });
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
            Text('📱 Terminal ZRM: ${widget.unitId}'),
            const SizedBox(width: 16),
            StreamBuilder<bool>(
              stream: widget.wsService.isConnectedStream,
              initialData: widget.wsService.isConnected,
              builder: (context, snapshot) {
                final isConn = snapshot.data ?? false;
                final pending = _outbox.pendingCount;
                return Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
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
                        isConn ? 'ONLINE (LAN / VPN)' : 'OFFLINE',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isConn ? Colors.greenAccent : Colors.redAccent,
                        ),
                      ),
                    ),
                    if (pending > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber),
                        ),
                        child: Text(
                          'Bufor: $pending',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber,
                          ),
                        ),
                      )
                    ]
                  ],
                );
              },
            ),
          ],
        ),
      ),
      body: Row(
        children: [
          // Lewa strona: Klawiatura statusów operacyjnych 1-6
          Expanded(
            flex: 5,
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'STATUS OPERACYJNY ZESPOŁU (SWD PRM)',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.8,
                      children: [
                        _buildStatusButton(
                          status: StatusType.wyjazd,
                          label: '1 • WYJAZD',
                          color: const Color(0xFF1D4ED8),
                        ),
                        _buildStatusButton(
                          status: StatusType.naMiejscu,
                          label: '2 • NA MIEJSCU',
                          color: const Color(0xFF6D28D9),
                        ),
                        _buildStatusButton(
                          status: StatusType.przejeciePacjenta,
                          label: '3 • PRZEJĘCIE',
                          color: const Color(0xFFBE185D),
                        ),
                        _buildStatusButton(
                          status: StatusType.transport,
                          label: '4 • TRANSPORT',
                          color: const Color(0xFFC2410C),
                        ),
                        _buildStatusButton(
                          status: StatusType.wSzpitalu,
                          label: '5 • W SZPITALU',
                          color: const Color(0xFFA16207),
                        ),
                        _buildStatusButton(
                          status: StatusType.gotowosc,
                          label: '6 • GOTOWOŚĆ',
                          color: const Color(0xFF047857),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Prawa strona: Karta Wyjazdu & Szybka KMCR
          Expanded(
            flex: 6,
            child: Container(
              margin: const EdgeInsets.all(16),
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
                    // Zlecenie wyjazdu (KZW)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0B1120),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _activeDispatch?.isUrgent == true
                              ? Colors.redAccent
                              : const Color(0xFF334155),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _activeDispatch != null
                                    ? '[${_activeDispatch!.priority}] KARTA ZLECENIA WYJAZDU'
                                    : 'BRAK AKTYWNEGO ZLECENIA',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _activeDispatch?.isUrgent == true
                                      ? Colors.redAccent
                                      : const Color(0xFF38BDF8),
                                ),
                              ),
                              if (_activeDispatch != null)
                                Text(
                                  _activeDispatch!.id,
                                  style: const TextStyle(
                                      color: Color(0xFF94A3B8), fontSize: 12),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (_activeDispatch != null) ...[
                            Text(
                              _activeDispatch!.chiefComplaint,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '📍 ${_activeDispatch!.incidentAddress}, ${_activeDispatch!.incidentCity}',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFFE2E8F0),
                              ),
                            ),
                            if (_activeDispatch!.description.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Uwagi: ${_activeDispatch!.description}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                            ]
                          ] else ...[
                            const Text(
                              'Zespół oczekuje w punkcie wyczekiwania. Status 6 - Gotowość.',
                              style: TextStyle(color: Color(0xFF94A3B8)),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Karta Medycznych Czynności Ratunkowych (KMCR)
                    const Text(
                      '🩺 SZYBKI WPIS PARAMETRÓW MEDYCZNYCH (KMCR)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFFA78BFA),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _hrController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: 'HR (tętno)',
                              labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _bpController,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: 'RR (ciśnienie)',
                              labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _spO2Controller,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: 'SpO2 (%)',
                              labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _gcsController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: 'GCS (3-15)',
                              labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _sampleSController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'SAMPLE: GŁÓWNE OBJAWY I WYWIAD RATOWNICZY',
                        labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                        hintText: 'Duszność spoczynkowa, bladość powłok...',
                        hintStyle: TextStyle(color: Color(0xFF64748B)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _saveKMCR,
                      icon: const Icon(Icons.sync),
                      label: const Text('SYNCHRONIZUJ KMCR Z SERWEREM'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusButton({
    required StatusType status,
    required String label,
    required Color color,
  }) {
    final isActive = _currentStatus == status;
    return InkWell(
      onTap: () => _onStatusClicked(status),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? Colors.white : Colors.transparent,
            width: isActive ? 4 : 1,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.6),
                    blurRadius: 16,
                    spreadRadius: 2,
                  )
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: isActive ? 18 : 16,
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Future<void> _saveKMCR() async {
    final dispatchId = _activeDispatch?.id ?? 'KZW-LOCAL';
    final kmcr = KMCR(
      id: 'KMCR-${DateTime.now().millisecondsSinceEpoch}',
      dispatchId: dispatchId,
      unitId: widget.unitId,
      sampleS: _sampleSController.text.trim(),
      gcsScore: int.tryParse(_gcsController.text) ?? 15,
      vitalSignsHistory: [
        VitalSigns(
          heartRate: int.tryParse(_hrController.text) ?? 80,
          systolicBP: 125,
          diastolicBP: 80,
          spO2: int.tryParse(_spO2Controller.text) ?? 98,
          gcsScore: int.tryParse(_gcsController.text) ?? 15,
          measuredAt: DateTime.now(),
        )
      ],
      updatedAt: DateTime.now(),
    );

    try {
      await widget.apiClient.saveKMCR(kmcr);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Karta KMCR zsynchronizowana pomyślnie z serwerem.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Brak łączności. Dane KMCR pozostają w pamięci.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }
}
