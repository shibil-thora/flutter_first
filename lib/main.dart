import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'services/mqtt_service.dart';

void main() {
  runApp(const MyApp());
}

/// A compact bubbly chat app that connects to the public EMQX broker
/// `broker.emqx.io` and sends/receives messages on topic `flutter/public/chat`.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Bubbly Chat',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.purple),
        useMaterial3: true,
      ),
      home: const ChatPage(),
    );
  }
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with SingleTickerProviderStateMixin {
  final MqttService _mqtt = MqttService();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  late final String _anonymousName;
  StreamSubscription<ChatMessage>? _sub;
  bool _connecting = false;

  @override
  void initState() {
    super.initState();
    _anonymousName = 'Anon-${const Uuid().v4().substring(0, 5)}';
    _connect();
  }

  Future<void> _connect() async {
    setState(() => _connecting = true);
    await _mqtt.connect();
    setState(() => _connecting = false);

    _sub = _mqtt.messages.listen((m) {
      setState(() => _messages.add(m));
      // scroll to bottom on new message
      Future.delayed(const Duration(milliseconds: 50), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent + 80,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
          );
        }
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _mqtt.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    try {
      await _mqtt.sendMessage(_anonymousName, text);
      _controller.clear();
    } catch (_) {
      // best-effort — if not connected try to reconnect
      await _mqtt.connect();
    }
  }

  Widget _messageBubble(ChatMessage msg) {
    final bool mine = msg.author == _anonymousName;
    final bubbleColor = mine ? Colors.pink.shade200 : Colors.teal.shade50;
    final align = mine ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 14),
      child: Column(
        crossAxisAlignment: align,
        children: [
          Text(
            msg.author,
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
          const SizedBox(height: 6),
          Container(
            constraints: const BoxConstraints(maxWidth: 280),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: Radius.circular(mine ? 20 : 4),
                bottomRight: Radius.circular(mine ? 4 : 20),
              ),
                boxShadow: [
                BoxShadow(
                  color: const Color.fromRGBO(0, 0, 0, 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
            child: Text(
              msg.text,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gradient = LinearGradient(
      colors: [Colors.purple.shade800, Colors.pink.shade400],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Container(
          decoration: BoxDecoration(gradient: gradient),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.transparent,
                      child: Icon(Icons.chat_bubble, size: 28, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Public Shibil Chat', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(_mqtt.isConnected ? Icons.wifi : Icons.wifi_off, color: Colors.white70, size: 14),
                              const SizedBox(width: 6),
                              Text(_mqtt.isConnected ? 'Connected' : (_connecting ? 'Connecting…' : 'Offline'), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(_anonymousName, style: const TextStyle(color: Colors.white, fontSize: 12)),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          controller: _scrollController,
                          itemCount: _messages.length,
                          padding: const EdgeInsets.only(top: 16, bottom: 8),
                          itemBuilder: (context, index) {
                            final msg = _messages[index];
                            return _messageBubble(msg);
                          },
                        ),
                      ),

                      // composer
                      SafeArea(
                        top: false,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.emoji_emotions_outlined, color: Colors.pink),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: TextField(
                                          controller: _controller,
                                          textCapitalization: TextCapitalization.sentences,
                                          decoration: const InputDecoration(
                                            hintText: 'Say something silly — everyone hears it!',
                                            border: InputBorder.none,
                                          ),
                                          onSubmitted: (_) => _sendMessage(),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      GestureDetector(
                                        onTap: () {
                                          // playful shake animation could go here
                                          _controller.text = '🎉';
                                        },
                                        child: const Icon(Icons.auto_awesome, color: Colors.orange),
                                      ),
                                      const SizedBox(width: 8)
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              FloatingActionButton(
                                onPressed: _sendMessage,
                                mini: true,
                                backgroundColor: Colors.pink,
                                child: const Icon(Icons.send),
                              )
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}