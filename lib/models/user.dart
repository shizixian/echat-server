class User {
  final String id;
  final String username;
  final String displayName;
  final String publicKey;
  final bool isOnline;
  final DateTime? lastSeen;

  User({
    required this.id,
    required this.username,
    required this.displayName,
    required this.publicKey,
    this.isOnline = false,
    this.lastSeen,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      username: json['username'] as String,
      displayName: json['displayName'] as String? ?? json['username'] as String,
      publicKey: json['publicKey'] as String,
      isOnline: json['isOnline'] as bool? ?? false,
      lastSeen: json['lastSeen'] != null ? DateTime.parse(json['lastSeen'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'displayName': displayName,
    'publicKey': publicKey,
    'isOnline': isOnline,
    'lastSeen': lastSeen?.toIso8601String(),
  };
}
