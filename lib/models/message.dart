class Message {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String content;
  final String? encryptedContent;
  final DateTime timestamp;
  final bool isRead;

  Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.content,
    this.encryptedContent,
    required this.timestamp,
    this.isRead = false,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String,
      conversationId: json['conversationId'] as String,
      senderId: json['senderId'] as String,
      senderName: json['senderName'] as String? ?? '',
      content: json['content'] as String? ?? '',
      encryptedContent: json['encryptedContent'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      isRead: json['isRead'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'conversationId': conversationId,
    'senderId': senderId,
    'senderName': senderName,
    'content': content,
    'encryptedContent': encryptedContent,
    'timestamp': timestamp.toIso8601String(),
    'isRead': isRead,
  };
}
