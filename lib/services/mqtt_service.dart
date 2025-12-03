import 'dart:async';
import 'dart:convert';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:uuid/uuid.dart';

/// Lightweight chat message model used across the app.
class ChatMessage {
  final String id;
  final String author;
  final String text;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.author,
    required this.text,
    required this.timestamp,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: j['id'] as String? ?? '',
        author: j['author'] as String? ?? 'Anonymous',
        text: j['text'] as String? ?? '',
        timestamp: DateTime.tryParse(j['timestamp'] as String? ?? '') ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'author': author,
        'text': text,
        'timestamp': timestamp.toIso8601String(),
      };
}

/// Service that connects to broker.emqx.io and publishes/subscribes to a
/// single public topic. The service attempts reconnects and exposes an
/// event stream of `ChatMessage` objects.
class MqttService {
  final String broker;
  final int port;
  final String topic;

  late final String clientId;
  late final MqttServerClient _client;

  final StreamController<ChatMessage> _messagesController = StreamController.broadcast();
  Stream<ChatMessage> get messages => _messagesController.stream;

  bool _connecting = false;
  bool get isConnected => _client.connectionStatus?.state == MqttConnectionState.connected;

  MqttService({
    this.broker = 'broker.emqx.io',
    this.port = 1883,
    this.topic = 'flutter/public/chat',
  }) {
    clientId = 'flutter-${const Uuid().v4().substring(0, 8)}';
    _client = MqttServerClient(broker, clientId);
    _client.port = port;
    _client.logging(on: false);
    _client.keepAlivePeriod = 20;
    _client.onDisconnected = _onDisconnected;
    _client.onConnected = _onConnected;
    _client.onSubscribed = _onSubscribed;
    // Accept unsecured. The public broker supports anonymous connections.
    _client.secure = false;
    _client.pongCallback = _onPong;
  }

  Future<void> connect({Duration retryDelay = const Duration(seconds: 3)}) async {
    if (_connecting || isConnected) return;
    _connecting = true;
    while (!isConnected) {
      try {
        final connMess = MqttConnectMessage()
            .withClientIdentifier(clientId)
            .startClean();
        _client.connectionMessage = connMess;

        await _client.connect();
        // Wait a tiny bit so our subscriptions take effect
        if (isConnected) {
          _client.subscribe(topic, MqttQos.atLeastOnce);
        }
      } catch (e) {
        // ignore and try again after a delay
        await Future.delayed(retryDelay);
      }

      if (!isConnected) {
        await Future.delayed(retryDelay);
      }
    }
    _connecting = false;

    // listen for incoming messages
    _client.updates?.listen(_onMessageReceived);
  }

  void _onMessageReceived(List<MqttReceivedMessage<MqttMessage>>? event) {
    if (event == null || event.isEmpty) return;
    try {
      final rec = event[0];
      final payload = rec.payload as MqttPublishMessage;
      final messageString = MqttPublishPayload.bytesToStringAsString(payload.payload.message);
      // messages will be sent as JSON {id,author,text,timestamp}
      final decoded = json.decode(messageString);
      final msg = ChatMessage.fromJson(decoded as Map<String, dynamic>);
      _messagesController.add(msg);
    } catch (_) {
      // If the incoming message isn't JSON (fallback), add as plain text
      try {
        final rec = event[0];
        final payload = rec.payload as MqttPublishMessage;
        final messageString = MqttPublishPayload.bytesToStringAsString(payload.payload.message);
        _messagesController.add(ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          author: 'Anonymous',
          text: messageString,
          timestamp: DateTime.now(),
        ));
      } catch (_) {
        // ignore completely malformed payload
      }
    }
  }

  void _onConnected() {
    // No-op: UI reads connection status from client
  }

  void _onDisconnected() {
    // make sure we try to reconnect
    // reconnect logic is handled by calling connect again from outside or schedule here
    Future.delayed(const Duration(seconds: 2), () => connect());
  }

  void _onSubscribed(String topic) {
    // Subscribed
  }

  void _onPong() {}

  /// Publish a text chat message anonymously (with supplied author id)
  Future<void> sendMessage(String author, String text) async {
    if (!isConnected) await connect();

    final message = ChatMessage(
      id: const Uuid().v4(),
      author: author,
      text: text,
      timestamp: DateTime.now(),
    );
    final payload = json.encode(message.toJson());
    final builder = MqttClientPayloadBuilder();
    builder.addString(payload);
    _client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
  }

  Future<void> disconnect() async {
    try {
      // mqtt_client's disconnect() is synchronous (returns void), so do not await it.
      _client.disconnect();
    } catch (_) {}
  }

  void dispose() {
    disconnect();
    _messagesController.close();
  }
}
