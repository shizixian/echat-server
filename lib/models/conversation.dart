class Conversation {
  final String id;
  final List<String> participantIds;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final int unreadCount;
  final String? otherUserName;
  final bool otherUserOnline;

  Conversation({
    required this.id,
    required this.participantIds,
    this.lastMessage,
    this.lastMessageTime,
    this.unreadCount = 0,
    this.otherUserName,
    this.otherUserOnline = false,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] as String,
      participantIds: (json['participantIds'] as List).cast<String>(),
      lastMessage: json['lastMessage'] as String?,
      lastMessageTime: json['lastMessageTime'] != null
          ? DateTime.parse(json['lastMessageTime'] as String)
          : null,
      unreadCount: json['unreadCount'] as int? ?? 0,
      otherUserName: json['otherUserName'] as String?,
      otherUserOnline: json['otherUserOnline'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'participantIds': participantIds,
    'lastMessage': lastMessage,
    'lastMessageTime': lastMessageTime?.toIso8601String(),
    'unreadCount': unreadCount,
    'otherUserName': otherUserName,
    'otherUserOnline': otherUserOnline,
  };
}
