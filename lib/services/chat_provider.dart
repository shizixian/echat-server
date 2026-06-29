import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/message.dart';
import '../models/conversation.dart';
import '../models/user.dart';
import 'api_service.dart';
import 'crypto_service.dart';
import 'storage_service.dart';

class ChatProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  final CryptoService _crypto = CryptoService();
  final StorageService _storage = StorageService();

  List<Conversation> _conversations = [];
  Map<String, List<Message>> _conversationMessages = {};
  Map<String, bool> _typingUsers = {};
  List<User> _searchResults = [];
  List<Map<String, dynamic>> _onlineUsers = [];
  bool _isLoading = false;
  String? _error;
  bool _isAuthenticated = false;
  bool _isConnected = false;
  String _currentUserId = '';
  String _currentUsername = '';
  String _currentDisplayName = '';
  String _currentPublicKey = '';

  List<Conversation> get conversations => _conversations;
  List<Message> get messages => [];
  List<Message> getConversationMessages(String convId) => _conversationMessages[convId] ?? [];
  Map<String, bool> get typingUsers => _typingUsers;
  List<User> get searchResults => _searchResults;
  set searchResults(List<User> v) { _searchResults = v; notifyListeners(); }
  List<Map<String, dynamic>> get onlineUsers => _onlineUsers;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _isAuthenticated;
  bool get isConnected => _isConnected;
  String get currentUserId => _currentUserId;
  String get currentUsername => _currentUsername;
  String get currentDisplayName => _currentDisplayName;
  String get currentPublicKey => _currentPublicKey;
  String get serverUrl => _api.serverUrl;

  StreamSubscription? _messageSub;
  StreamSubscription? _typingSub;
  StreamSubscription? _onlineSub;
  StreamSubscription? _connectionSub;

  Future<void> init() async {
    final token = _storage.getToken();
    final userId = _storage.getUserId();
    final username = _storage.getUsername();
    final displayName = _storage.getDisplayName();
    final serverUrl = _storage.getServerUrl();
    final savedPublicKey = _storage.getPublicKey();
    final savedPrivateKey = _storage.getPrivateKey();

    if (serverUrl != null) {
      _api.setServerUrl(serverUrl);
    }

    if (token != null && userId != null) {
      _currentUserId = userId;
      _currentUsername = username ?? '';
      _currentDisplayName = displayName ?? username ?? '';
      _currentPublicKey = savedPublicKey ?? '';

      // Restore key pair from saved private key
      if (savedPrivateKey != null && savedPrivateKey.isNotEmpty) {
        await _crypto.initFromPrivateKey(savedPrivateKey);
      } else {
        // No saved key - generate new one and update server
        await _crypto.init();
        _currentPublicKey = await _crypto.getPublicKeyBase64();
        final newPrivateKey = await _crypto.extractPrivateKeyBase64();
        await _storage.savePrivateKey(newPrivateKey);
        await _storage.savePublicKey(_currentPublicKey);
        if (token != null) {
          try {
            await _api.updatePublicKey(_currentPublicKey);
          } catch (_) {}
        }
      }
      _setupListeners();
      _api.connect();
      _isAuthenticated = true;
    }
  }

  void _setupListeners() {
    _messageSub = _api.messageStream.listen((msg) {
      final message = Message.fromJson(msg);
      if (!_conversationMessages.containsKey(message.conversationId)) {
        _conversationMessages[message.conversationId] = [];
      }
      _conversationMessages[message.conversationId]!.add(message);
      _updateConversationList();
      notifyListeners();
    });

    _typingSub = _api.typingStream.listen((data) {
      if (data['conversationId'] != null) {
        _typingUsers[data['conversationId']] = data['isTyping'] as bool;
        notifyListeners();
      }
    });

    _onlineSub = _api.onlineUsersStream.listen((users) {
      _onlineUsers = users;
      notifyListeners();
    });

    _connectionSub = _api.connectionStream.listen((connected) {
      _isConnected = connected;
      notifyListeners();
    });
  }

  Future<void> register(String username, String password, String displayName, String serverUrl) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _api.setServerUrl(serverUrl);
      await _crypto.init();
      final publicKey = await _crypto.getPublicKeyBase64();
      final privateKey = await _crypto.extractPrivateKeyBase64();
      final result = await _api.register(username, password, displayName, publicKey);

      _currentUserId = result['userId'];
      _currentUsername = result['username'];
      _currentDisplayName = result['displayName'] ?? username;
      _currentPublicKey = publicKey;

      // Save everything including private key for persistence
      await _storage.saveToken(result['token']);
      await _storage.saveUserId(_currentUserId);
      await _storage.saveUsername(_currentUsername);
      await _storage.saveDisplayName(_currentDisplayName);
      await _storage.savePublicKey(publicKey);
      await _storage.savePrivateKey(privateKey);
      await _storage.saveServerUrl(serverUrl);

      _setupListeners();
      _api.connect();
      _isAuthenticated = true;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> login(String username, String password, String serverUrl) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _api.setServerUrl(serverUrl);
      final result = await _api.login(username, password);

      _currentUserId = result['userId'];
      _currentUsername = result['username'];
      _currentDisplayName = result['displayName'] ?? username;

      // Try to restore key pair from saved private key
      final savedPrivateKey = _storage.getPrivateKey();
      if (savedPrivateKey != null && savedPrivateKey.isNotEmpty) {
        await _crypto.initFromPrivateKey(savedPrivateKey);
      } else {
        // First login after reinstall - generate new key and save
        await _crypto.init();
      }
      _currentPublicKey = await _crypto.getPublicKeyBase64();
      final currentPrivateKey = await _crypto.extractPrivateKeyBase64();

      await _storage.saveToken(result['token']);
      await _storage.saveUserId(_currentUserId);
      await _storage.saveUsername(_currentUsername);
      await _storage.saveDisplayName(_currentDisplayName);
      await _storage.savePublicKey(_currentPublicKey);
      await _storage.savePrivateKey(currentPrivateKey);
      await _storage.saveServerUrl(serverUrl);

      _setupListeners();
      _api.connect();
      _isAuthenticated = true;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> searchUsers(String query) async {
    try {
      _searchResults = await _api.searchUsers(query);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> startConversation(String userId) async {
    try {
      await _api.startConversation(userId);
      await loadConversations();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> loadConversations() async {
    try {
      _conversations = await _api.getConversations();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> loadMessages(String conversationId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final msgs = await _api.getMessages(conversationId);
      _conversationMessages[conversationId] = msgs;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> sendMessage(String conversationId, String plainText, String peerUserId) async {
    try {
      String peerPublicKey = _storage.getPeerPublicKey(peerUserId) ?? '';
      if (peerPublicKey.isEmpty) {
        peerPublicKey = await _api.getUserPublicKey(peerUserId);
        await _storage.savePeerPublicKey(peerUserId, peerPublicKey);
      }
      final encrypted = await _crypto.encryptMessage(plainText, peerPublicKey);
      _api.sendMessage(conversationId, encrypted, _currentDisplayName);
    } catch (e) {
      _error = 'Failed to send: $e';
      notifyListeners();
    }
  }

  Future<String> decryptMessage(Message message, String senderId) async {
    try {
      String peerPublicKey = _storage.getPeerPublicKey(senderId) ?? '';
      if (peerPublicKey.isEmpty) {
        peerPublicKey = await _api.getUserPublicKey(senderId);
        await _storage.savePeerPublicKey(senderId, peerPublicKey);
      }
      return await _crypto.decryptMessage(message.encryptedContent!, peerPublicKey);
    } catch (e) {
      return '[Encrypted message]';
    }
  }

  void sendTyping(String conversationId, bool isTyping) {
    _api.sendTyping(conversationId, isTyping);
  }

  void _updateConversationList() {
    loadConversations();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> logout() async {
    _api.disconnect();
    _messageSub?.cancel();
    _typingSub?.cancel();
    _onlineSub?.cancel();
    _connectionSub?.cancel();
    _crypto.clearSecrets();
    await _storage.clearAll();
    _conversations = [];
    _conversationMessages = {};
    _typingUsers = {};
    _searchResults = [];
    _onlineUsers = [];
    _isAuthenticated = false;
    _isConnected = false;
    _currentUserId = '';
    _currentUsername = '';
    _currentDisplayName = '';
    notifyListeners();
  }

  @override
  void dispose() {
    _messageSub?.cancel();
    _typingSub?.cancel();
    _onlineSub?.cancel();
    _connectionSub?.cancel();
    _api.dispose();
    super.dispose();
  }
}
