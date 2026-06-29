import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

class CryptoService {
  static final CryptoService _instance = CryptoService._internal();
  factory CryptoService() => _instance;
  CryptoService._internal();

  final _keyExchange = X25519();
  final _cipher = AesGcm.with256bits();

  SimpleKeyPair? _keyPair;

  Future<SimplePublicKey> get publicKey async {
    final pk = await _keyPair!.extractPublicKey();
    return pk;
  }

  Future<void> init() async {
    _keyPair = await _keyExchange.newKeyPair();
  }

  Future<void> initFromPrivateKey(String privateKeyBase64) async {
    final privateBytes = base64Decode(privateKeyBase64);
    _keyPair = await _keyExchange.newKeyPairFromSeed(privateBytes);
  }

  Future<String> getPublicKeyBase64() async {
    final pk = await _keyPair!.extractPublicKey();
    return base64Encode(pk.bytes);
  }

  Future<String> extractPrivateKeyBase64() async {
    final privateBytes = await _keyPair!.extractPrivateKeyBytes();
    return base64Encode(privateBytes);
  }

  final Map<String, SecretKey> _sharedSecrets = {};

  Future<SecretKey> _deriveSharedSecret(String peerPublicKeyBase64) async {
    _checkValidBase64(peerPublicKeyBase64);
    
    if (_sharedSecrets.containsKey(peerPublicKeyBase64)) {
      return _sharedSecrets[peerPublicKeyBase64]!;
    }

    final peerPublicKey = SimplePublicKey(
      base64Decode(peerPublicKeyBase64),
      type: KeyPairType.x25519,
    );

    final sharedSecret = await _keyExchange.sharedSecretKey(
      keyPair: _keyPair!,
      remotePublicKey: peerPublicKey,
    );

    _sharedSecrets[peerPublicKeyBase64] = sharedSecret;
    return sharedSecret;
  }

  void _checkValidBase64(String input) {
    if (input.isEmpty) {
      throw Exception('Empty public key');
    }
    try {
      base64Decode(input);
    } catch (e) {
      throw Exception('Invalid public key format (not valid Base64): $e');
    }
  }

  Future<String> encryptMessage(String plainText, String peerPublicKeyBase64) async {
    final sharedSecret = await _deriveSharedSecret(peerPublicKeyBase64);
    final plainBytes = utf8.encode(plainText);
    final secretBox = await _cipher.encrypt(
      plainBytes,
      secretKey: sharedSecret,
    );

    final combined = Uint8List.fromList([
      ...secretBox.nonce,
      ...secretBox.cipherText,
      ...secretBox.mac.bytes,
    ]);

    return base64Encode(combined);
  }

  Future<String> decryptMessage(String encryptedBase64, String peerPublicKeyBase64) async {
    final sharedSecret = await _deriveSharedSecret(peerPublicKeyBase64);
    final combined = base64Decode(encryptedBase64);

    const nonceLength = 12;
    const macLength = 16;

    if (combined.length < nonceLength + macLength) {
      throw Exception('Invalid encrypted message');
    }

    final nonce = combined.sublist(0, nonceLength);
    final cipherText = combined.sublist(nonceLength, combined.length - macLength);
    final mac = Mac(combined.sublist(combined.length - macLength));

    final secretBox = SecretBox(
      cipherText,
      nonce: nonce,
      mac: mac,
    );

    final plainBytes = await _cipher.decrypt(
      secretBox,
      secretKey: sharedSecret,
    );

    return utf8.decode(plainBytes);
  }

  void clearSecrets() {
    _sharedSecrets.clear();
  }
}
