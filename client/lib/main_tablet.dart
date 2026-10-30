import 'package:flutter/material.dart';
import 'core/network/api_client.dart';
import 'core/network/websocket_client.dart';
import 'features/tablet_zrm/tablet_screen.dart';

void main() {
  const host = 'localhost:8080';
  const unitId = 'ZRM-01'; // Domyślna jednostka dla tabletu (może być pobierana z konfiguracji urządzenia)

  final apiClient = ApiClient(baseUrl: 'http://$host');
  final wsService = WebSocketService(
    serverHost: host,
    role: 'TABLET_ZRM',
    clientId: unitId,
  );
  wsService.connect();

  runApp(
    MaterialApp(
      title: 'SWD PRM - Terminal Mobilny ZRM',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF2563EB),
          surface: Color(0xFF1E293B),
        ),
        useMaterial3: true,
      ),
      home: TabletScreen(
        unitId: unitId,
        apiClient: apiClient,
        wsService: wsService,
      ),
    ),
  );
}
