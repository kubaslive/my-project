import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/models.dart';

class WebSocketService {
  final String serverHost; // np. 'localhost:8080'
  final String role;       // 'DISPATCHER' lub 'TABLET_ZRM'
  final String clientId;   // np. 'DYS-01' lub 'ZRM-01'

  WebSocketChannel? _channel;
  Timer? _reconnectTimer;
  bool _isConnected = false;

  final _messagesController = StreamController<WSMessage>.broadcast();
  final _connectionStateController = StreamController<bool>.broadcast();

  Stream<WSMessage> get messages => _messagesController.stream;
  Stream<bool> get isConnectedStream => _connectionStateController.stream;
  bool get isConnected => _isConnected;

  WebSocketService({
    this.serverHost = 'localhost:8080',
    required this.role,
    required this.clientId,
  });

  void connect() {
    if (_isConnected) return;

    try {
      final wsUrl = Uri.parse('ws://$serverHost/ws?role=$role&id=$clientId');
      _channel = WebSocketChannel.connect(wsUrl);

      _channel!.stream.listen(
        (data) {
          if (!_isConnected) {
            _isConnected = true;
            _connectionStateController.add(true);
          }
          try {
            final json = jsonDecode(data.toString());
            final msg = WSMessage.fromJson(json);
            _messagesController.add(msg);
          } catch (e) {
            // Ignoruj lub loguj błędy parsowania
          }
        },
        onError: (err) {
          _handleDisconnect();
        },
        onDone: () {
          _handleDisconnect();
        },
      );

      _isConnected = true;
      _connectionStateController.add(true);
    } catch (e) {
      _handleDisconnect();
    }
  }

  void _handleDisconnect() {
    _isConnected = false;
    _connectionStateController.add(false);
    _channel = null;

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      connect();
    });
  }

  /// Wysyła aktualizację statusu 1-6 z tabletu
  void sendStatusUpdate({
    required String unitId,
    String? dispatchId,
    required StatusType newStatus,
    double latitude = 52.2297,
    double longitude = 21.0122,
    int? seqId,
  }) {
    final payload = {
      'unit_id': unitId,
      'dispatch_id': dispatchId,
      'new_status': newStatus.code,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': DateTime.now().toIso8601String(),
      'seq_id': seqId ?? DateTime.now().millisecondsSinceEpoch,
    };

    final msg = WSMessage(
      type: 'STATUS_UPDATE',
      senderRole: role,
      senderId: clientId,
      payload: payload,
      timestamp: DateTime.now(),
    );

    send(msg);
  }

  /// Wysyła nowe zlecenie wyjazdu (KZW)
  void sendNewDispatch(Dispatch dispatch) {
    final msg = WSMessage(
      type: 'DISPATCH_NEW',
      senderRole: role,
      senderId: clientId,
      payload: dispatch.toJson(),
      timestamp: DateTime.now(),
    );
    send(msg);
  }

  /// Wysyła surową wiadomość
  void send(WSMessage msg) {
    if (_channel != null && _isConnected) {
      _channel!.sink.add(jsonEncode(msg.toJson()));
    }
  }

  void dispose() {
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _messagesController.close();
    _connectionStateController.close();
  }
}
