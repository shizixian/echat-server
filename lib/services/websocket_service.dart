import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';


typedef MessageHandler = void Function(Map<String, dynamic> data);
typedef OnlineHandler = void Function(List<String> userIds);
typedef ConnectionHandler = void Function(bool connected);

class WebSocketService {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  bool _connected = false;

  MessageHandler? onMessage;
  OnlineHandler? onOnlineUsers;
  ConnectionHandler? onConnectionChange;

  bool get isConnected => _connected;

  void connect(String token, {String? serverUrl}) {
    disconnect();

    try {
      _channel = WebSocketChannel.connect(
        Uri.parse('${serverUrl ?? 'http://localhost:8730'}/ws?token=$token'),
      );

      _connected = true;
      onConnectionChange?.call(true);

      _subscription = _channel!.stream.listen(
        (data) {
          try {
            final msg = jsonDecode(data as String) as Map<String, dynamic>;
            switch (msg['type'] as String) {
              case 'message':
                onMessage?.call(msg);
                break;
              case 'online':
                final users = (msg['users'] as List).cast<String>();
                onOnlineUsers?.call(users);
                break;
              case 'ack':
                break;
              case 'pong':
                break;
              case 'error':
                print('WS error: ${msg['message']}');
                break;
            }
          } catch (e) {
            print('WS parse error: $e');
          }
        },
        onError: (error) {
          _connected = false;
          onConnectionChange?.call(false);
        },
        onDone: () {
          _connected = false;
          onConnectionChange?.call(false);
        },
      );
    } catch (e) {
      _connected = false;
      onConnectionChange?.call(false);
    }
  }

  void disconnect() {
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
    if (_connected) {
      _connected = false;
      onConnectionChange?.call(false);
    }
  }

  void sendMessage({
    required String recipientId,
    required String ciphertext,
    required String nonce,
    String? iv,
    String? ephemeralKey,
    String? mac,
  }) {
    if (_channel == null) return;
    final payload = {
      'type': 'send',
      'recipientId': recipientId,
      'ciphertext': ciphertext,
      'nonce': nonce,
      if (iv != null) 'iv': iv,
      if (ephemeralKey != null) 'ephemeralKey': ephemeralKey,
      if (mac != null) 'mac': mac,
    };
    _channel!.sink.add(jsonEncode(payload));
  }

  void sendPing() {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode({'type': 'ping'}));
    }
  }

  void dispose() {
    disconnect();
  }
}
