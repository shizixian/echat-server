import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/app_config.dart';
import '../models/user.dart';
import '../models/message.dart';
import '../models/conversation.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  String _serverUrl = AppConfig.defaultServerUrl;
  String? _token;
  String? _userId;
  
  WebSocketChannel? _channel;
  bool _connected = false;
  int _reconnectAttempts = 0;

  // Streams for real-time events
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _typingController = StreamController<Map<String, dynamic>>.broadcast();
  final _onlineUsersController = StreamController<List<Map<String, dynamic>>>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();

  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  Stream<Map<String, dynamic>> get typingStream => _typingController.stream;
  Stream<List<Map<String, dynamic>>> get onlineUsersStream => _onlineUsersController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;

  bool get isConnected => _connected;
  String? get userId => _userId;
  String get serverUrl => _serverUrl;

  void setServerUrl(String url) {
    _serverUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  Future<Map<String, dynamic>> register(String username, String password, String displayName, String publicKey) async {
    final response = await http.post(
      Uri.parse('$_serverUrl/api/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'password': password,
        'displayName': displayName,
        'publicKey': publicKey,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Registration failed');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    _token = data['token'];
    _userId = data['userId'];
    return data;
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    final response = await http.post(
      Uri.parse('$_serverUrl/api/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Login failed');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    _token = data['token'];
    _userId = data['userId'];
    return data;
  }

  Future<List<User>> searchUsers(String query) async {
    final response = await http.get(
      Uri.parse('$_serverUrl/api/users?search=$query'),
      headers: _authHeaders,
    );
    if (response.statusCode != 200) throw Exception('Failed to search users');
    final data = jsonDecode(response.body) as List;
    return data.map((u) => User.fromJson(u)).toList();
  }

  Future<String> startConversation(String userId) async {
    final response = await http.post(
      Uri.parse('$_serverUrl/api/conversations'),
      headers: {..._authHeaders, 'Content-Type': 'application/json'},
      body: jsonEncode({'userId': userId}),
    );
    if (response.statusCode != 200) throw Exception('Failed to start conversation');
    return jsonDecode(response.body)['conversationId'] as String;
  }

  Future<List<Conversation>> getConversations() async {
    final response = await http.get(
      Uri.parse('$_serverUrl/api/conversations'),
      headers: _authHeaders,
    );
    if (response.statusCode != 200) throw Exception('Failed to get conversations');
    final data = jsonDecode(response.body) as List;
    return data.map((c) => Conversation.fromJson(c)).toList();
  }

  Future<List<Message>> getMessages(String conversationId) async {
    final response = await http.get(
      Uri.parse('$_serverUrl/api/conversations/$conversationId/messages'),
      headers: _authHeaders,
    );
    if (response.statusCode != 200) throw Exception('Failed to get messages');
    final data = jsonDecode(response.body) as List;
    return data.map((m) => Message.fromJson(m)).toList();
  }

  Future<String> getUserPublicKey(String userId) async {
    final response = await http.get(
      Uri.parse('$_serverUrl/api/users/$userId/public-key'),
      headers: _authHeaders,
    );
    if (response.statusCode != 200) throw Exception('Failed to get public key');
    return jsonDecode(response.body)['publicKey'] as String;
  }


  Map<String, String> get _authHeaders => {
    'Authorization': 'Bearer $_token',
  };

  void connect() {
    try {
      final wsUrl = _serverUrl.replaceFirst('http', 'ws');
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _connected = true;
      _connectionController.add(true);

      _channel!.stream.listen(
        (data) {
          final msg = jsonDecode(data as String) as Map<String, dynamic>;
          switch (msg['type']) {
            case 'auth_ok':
              _reconnectAttempts = 0;
              _connectionController.add(true);
              break;
            case 'new_message':
              _messageController.add(msg['message']);
              break;
            case 'message_sent':
              _messageController.add(msg['message']);
              break;
            case 'typing':
              _typingController.add(msg);
              break;
            case 'online_users':
              _onlineUsersController.add(List<Map<String, dynamic>>.from(msg['users']));
              break;
          }
        },
        onError: (error) {
          _connected = false;
          _connectionController.add(false);
          _reconnect();
        },
        onDone: () {
          _connected = false;
          _connectionController.add(false);
          _reconnect();
        },
      );

      if (_token != null) {
        _channel!.sink.add(jsonEncode({'type': 'auth', 'token': _token}));
      }
    } catch (e) {
      _connected = false;
      _connectionController.add(false);
      _reconnect();
    }
  }

  void _reconnect() {
    if (_reconnectAttempts >= AppConfig.wsMaxReconnectAttempts) return;
    _reconnectAttempts++;
    Future.delayed(Duration(milliseconds: AppConfig.wsReconnectDelayMs), () {
      connect();
    });
  }

  void sendMessage(String conversationId, String encryptedContent, String senderName) {
    if (_channel == null || !_connected) return;
    _channel!.sink.add(jsonEncode({
      'type': 'send_message',
      'conversationId': conversationId,
      'encryptedContent': encryptedContent,
      'senderName': senderName,
    }));
  }

  void sendTyping(String conversationId, bool isTyping) {
    if (_channel == null || !_connected) return;
    _channel!.sink.add(jsonEncode({
      'type': 'typing',
      'conversationId': conversationId,
      'isTyping': isTyping,
    }));
  }

  void disconnect() {
    _channel?.sink.close();
    _connected = false;
    _connectionController.add(false);
  }

  void dispose() {
    disconnect();
    _messageController.close();
    _typingController.close();
    _onlineUsersController.close();
    _connectionController.close();
  }

  Future<void> updatePublicKey(String publicKey) async {
    final response = await http.put(
      Uri.parse('$_serverUrl/api/users/public-key'),
      headers: _authHeaders,
      body: jsonEncode({'publicKey': publicKey}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update public key');
    }
  }
}

