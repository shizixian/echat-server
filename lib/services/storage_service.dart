import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Auth tokens
  Future<void> saveToken(String token) async {
    await _prefs?.setString('auth_token', token);
  }

  String? getToken() => _prefs?.getString('auth_token');

  Future<void> clearToken() async {
    await _prefs?.remove('auth_token');
  }

  // User info
  Future<void> saveUserId(String userId) async {
    await _prefs?.setString('user_id', userId);
  }

  String? getUserId() => _prefs?.getString('user_id');

  Future<void> saveUsername(String username) async {
    await _prefs?.setString('username', username);
  }

  String? getUsername() => _prefs?.getString('username');

  Future<void> saveDisplayName(String name) async {
    await _prefs?.setString('display_name', name);
  }

  String? getDisplayName() => _prefs?.getString('display_name');

  // Encryption keys
  Future<void> savePrivateKey(String key) async {
    await _prefs?.setString('private_key', key);
  }

  String? getPrivateKey() => _prefs?.getString('private_key');

  Future<void> savePublicKey(String key) async {
    await _prefs?.setString('public_key', key);
  }

  String? getPublicKey() => _prefs?.getString('public_key');

  // Peers' public keys cache
  Future<void> savePeerPublicKey(String userId, String publicKey) async {
    final keys = _prefs?.getString('peer_keys');
    final map = keys != null ? Map<String, dynamic>.from(jsonDecode(keys)) : <String, dynamic>{};
    map[userId] = publicKey;
    await _prefs?.setString('peer_keys', jsonEncode(map));
  }

  String? getPeerPublicKey(String userId) {
    final keys = _prefs?.getString('peer_keys');
    if (keys == null) return null;
    final map = Map<String, dynamic>.from(jsonDecode(keys));
    return map[userId] as String?;
  }

  // Server URL
  Future<void> saveServerUrl(String url) async {
    await _prefs?.setString('server_url', url);
  }

  String? getServerUrl() => _prefs?.getString('server_url');

  // Clear all
  Future<void> clearAll() async {
    await _prefs?.clear();
  }
}
