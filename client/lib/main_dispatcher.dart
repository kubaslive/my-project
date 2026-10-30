import 'package:flutter/material.dart';
import 'core/network/api_client.dart';
import 'core/network/websocket_client.dart';
import 'features/dispatcher/dispatcher_screen.dart';

void main() {
  const host = 'localhost:8080';
  final apiClient = ApiClient(baseUrl: 'http://$host');
  final wsService = WebSocketService(
    serverHost: host,
    role: 'DISPATCHER',
    clientId: 'DYS-DESKTOP',
  );
  wsService.connect();

  runApp(
    MaterialApp(
      title: 'SWD PRM - Stanowisko Dyspozytora',
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
      home: DispatcherScreen(
        apiClient: apiClient,
        wsService: wsService,
      ),
    ),
  );
}
