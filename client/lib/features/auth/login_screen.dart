import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../core/network/websocket_client.dart';
import '../dispatcher/dispatcher_screen.dart';
import '../tablet_zrm/tablet_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _hostController = TextEditingController(text: 'localhost:8080');
  String _selectedRole = 'DISPATCHER'; // 'DISPATCHER' lub 'TABLET_ZRM'
  String _selectedUnitId = 'ZRM-01';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: 480,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF334155)),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black45,
                  blurRadius: 20,
                  offset: Offset(0, 8),
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('🚑', style: TextStyle(fontSize: 32)),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SWD PRM Core',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'System Wspomagania Dowodzenia',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Host sieciowy (localhost / VPN IP)
                const Text(
                  'ADRES WĘZŁA SIECIOWEGO (LAN / LOCALHOST / VPN)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _hostController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.dns, color: Color(0xFF64748B)),
                    filled: true,
                    fillColor: const Color(0xFF0B1120),
                    hintText: 'np. localhost:8080 lub 10.8.0.1:8080',
                    hintStyle: const TextStyle(color: Color(0xFF64748B)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF334155)),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Wybór roli
                const Text(
                  'ROLA STANOWISKA ROBOCZEGO',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'DISPATCHER',
                      label: Text('🖥️ Dyspozytor'),
                    ),
                    ButtonSegment(
                      value: 'TABLET_ZRM',
                      label: Text('📱 Tablet ZRM'),
                    ),
                  ],
                  selected: {_selectedRole},
                  onSelectionChanged: (set) {
                    setState(() {
                      _selectedRole = set.first;
                    });
                  },
                ),
                const SizedBox(height: 20),

                // Jeśli wybrano tablet, wybór karetki
                if (_selectedRole == 'TABLET_ZRM') ...[
                  const Text(
                    'PRZYPISANY ZESPÓŁ / POJAZD (ZRM)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedUnitId,
                    dropdownColor: const Color(0xFF1E293B),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.emergency, color: Colors.redAccent),
                      filled: true,
                      fillColor: const Color(0xFF0B1120),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF334155)),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'ZRM-01',
                        child: Text('W01-01 (Zespół Podstawowy P)'),
                      ),
                      DropdownMenuItem(
                        value: 'ZRM-02',
                        child: Text('W01-02 (Zespół Specjalistyczny S)'),
                      ),
                      DropdownMenuItem(
                        value: 'ZRM-03',
                        child: Text('M01-01 (Motoambulans M)'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedUnitId = val);
                    },
                  ),
                  const SizedBox(height: 24),
                ],

                // Przycisk Start
                ElevatedButton(
                  onPressed: _startSession,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    _selectedRole == 'DISPATCHER'
                        ? 'URUCHOM STANOWISKO DYSPOZYTORA'
                        : 'URUCHOM TERMINAL TABLETOWY',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _startSession() {
    final host = _hostController.text.trim();
    final apiClient = ApiClient(baseUrl: 'http://$host');

    if (_selectedRole == 'DISPATCHER') {
      final wsService = WebSocketService(
        serverHost: host,
        role: 'DISPATCHER',
        clientId: 'DYS-${DateTime.now().millisecondsSinceEpoch % 1000}',
      );
      wsService.connect();

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DispatcherScreen(
            apiClient: apiClient,
            wsService: wsService,
          ),
        ),
      );
    } else {
      final wsService = WebSocketService(
        serverHost: host,
        role: 'TABLET_ZRM',
        clientId: _selectedUnitId,
      );
      wsService.connect();

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => TabletScreen(
            unitId: _selectedUnitId,
            apiClient: apiClient,
            wsService: wsService,
          ),
        ),
      );
    }
  }
}
