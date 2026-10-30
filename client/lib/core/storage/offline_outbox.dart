import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../network/websocket_client.dart';

/// Element w kolejce Outbox
class OutboxItem {
  final int seqId;
  final String type; // 'STATUS' lub 'KMCR'
  final Map<String, dynamic> payload;
  final DateTime createdAt;

  OutboxItem({
    required this.seqId,
    required this.type,
    required this.payload,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'seq_id': seqId,
        'type': type,
        'payload': payload,
        'created_at': createdAt.toIso8601String(),
      };

  factory OutboxItem.fromJson(Map<String, dynamic> json) => OutboxItem(
        seqId: json['seq_id'] ?? 0,
        type: json['type'] ?? '',
        payload: json['payload'] ?? {},
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at']) ?? DateTime.now()
            : DateTime.now(),
      );
}

/// Menedżer kolejki offline (Outbox Pattern)
class OfflineOutboxManager {
  static const String _storageKey = 'swd_offline_outbox_queue';
  final List<OutboxItem> _queue = [];
  final WebSocketService wsService;

  OfflineOutboxManager({required this.wsService}) {
    _loadFromStorage();
    // Nasłuchiwanie powrotu łączności
    wsService.isConnectedStream.listen((connected) {
      if (connected) {
        flushQueue();
      }
    });
  }

  int get pendingCount => _queue.length;

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null) {
        final List<dynamic> list = jsonDecode(raw);
        _queue.clear();
        for (var item in list) {
          _queue.add(OutboxItem.fromJson(item));
        }
      }
    } catch (_) {}
  }

  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonEncode(_queue.map((e) => e.toJson()).toList());
      await prefs.setString(_storageKey, raw);
    } catch (_) {}
  }

  /// Dodaje zdarzenie statusowe do bufora
  Future<void> enqueueStatusUpdate({
    required String unitId,
    String? dispatchId,
    required StatusType newStatus,
    double latitude = 52.2297,
    double longitude = 21.0122,
  }) async {
    final item = OutboxItem(
      seqId: DateTime.now().millisecondsSinceEpoch,
      type: 'STATUS',
      payload: {
        'unit_id': unitId,
        'dispatch_id': dispatchId,
        'new_status': newStatus.code,
        'latitude': latitude,
        'longitude': longitude,
        'timestamp': DateTime.now().toIso8601String(),
      },
      createdAt: DateTime.now(),
    );

    if (wsService.isConnected) {
      // Wyślij od razu
      wsService.sendStatusUpdate(
        unitId: unitId,
        dispatchId: dispatchId,
        newStatus: newStatus,
        latitude: latitude,
        longitude: longitude,
        seqId: item.seqId,
      );
    } else {
      // Zbuforuj w pamięci trwałej
      _queue.add(item);
      await _saveToStorage();
    }
  }

  /// Opróżnia kolejkę bufora po odzyskaniu sygnału
  Future<void> flushQueue() async {
    if (_queue.isEmpty || !wsService.isConnected) return;

    final itemsToSend = List<OutboxItem>.from(_queue);
    for (var item in itemsToSend) {
      if (item.type == 'STATUS') {
        final payload = item.payload;
        wsService.sendStatusUpdate(
          unitId: payload['unit_id'],
          dispatchId: payload['dispatch_id'],
          newStatus: StatusType.fromCode(payload['new_status']),
          latitude: (payload['latitude'] as num?)?.toDouble() ?? 52.2297,
          longitude: (payload['longitude'] as num?)?.toDouble() ?? 21.0122,
          seqId: item.seqId,
        );
      }
      _queue.remove(item);
    }
    await _saveToStorage();
  }
}
