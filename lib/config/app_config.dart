class AppConfig {
  // Default server URL - users can change this in settings
  // For production, deploy the server to Render/Railway and update this URL
  static const String defaultServerUrl = 'http://localhost:8730';
  static const String appName = 'EChat';
  static const String appVersion = '1.0.0';

  // WebSocket reconnect settings
  static const int wsReconnectDelayMs = 3000;
  static const int wsMaxReconnectAttempts = 10;

  // Encryption
  static const String encryptionAlgorithm = 'aes-256-gcm';
  static const int keyExchangeCurve = 25519;
}
