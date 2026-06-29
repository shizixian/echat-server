import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/chat_provider.dart';
import '../models/message.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String otherUserName;
  final String otherUserId;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.otherUserName,
    required this.otherUserId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    context.read<ChatProvider>().loadMessages(widget.conversationId);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();
    final provider = context.read<ChatProvider>();
    await provider.sendMessage(widget.conversationId, text, widget.otherUserId);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D2B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A3E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.cyan.shade800,
              child: Text(
                widget.otherUserName[0].toUpperCase(),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.otherUserName,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                ),
                Consumer<ChatProvider>(
                  builder: (context, provider, _) {
                    final isOnline = provider.onlineUsers.any((u) => u['userId'] == widget.otherUserId);
                    return Text(
                      isOnline ? 'Online' : 'Offline',
                      style: TextStyle(
                        color: isOnline ? Colors.green.shade400 : Colors.white38,
                        fontSize: 12,
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.lock, color: Colors.cyan.shade300, size: 20),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessageList()),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return Consumer<ChatProvider>(
      builder: (context, provider, _) {
        final messages = provider.getConversationMessages(widget.conversationId);

        if (provider.isLoading && messages.isEmpty) {
          return const Center(child: CircularProgressIndicator(color: Colors.cyan));
        }

        if (messages.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline, size: 48, color: Colors.white.withValues(alpha: 0.2)),
                const SizedBox(height: 16),
                Text(
                  'End-to-End Encrypted',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  'Messages are secure and private',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 14),
                ),
              ],
            ),
          );
        }

        final isOnline = provider.onlineUsers.any((u) => u['userId'] == widget.otherUserId);

        return Column(
          children: [
            // Online indicator
            if (isOnline)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(width: 6, height: 6, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.green)),
                    const SizedBox(width: 6),
                    Text('Online', style: TextStyle(color: Colors.green.shade400, fontSize: 12)),
                  ],
                ),
              ),
            // Typing indicator
            if (provider.typingUsers[widget.conversationId] == true)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    Text(widget.otherUserName, style: TextStyle(color: Colors.cyan.shade300, fontSize: 12)),
                    Text(' is typing...', style: TextStyle(color: Colors.white38, fontSize: 12)),
                  ],
                ),
              ),
            // Messages list
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index];
                  final isMe = message.senderId == provider.currentUserId;
                  return _buildMessageBubble(message, isMe, provider);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMessageBubble(Message message, bool isMe, ChatProvider provider) {
    return FutureBuilder<String>(
      future: message.senderId == provider.currentUserId
          ? Future.value(message.content.isNotEmpty ? message.content : message.encryptedContent ?? '')
          : provider.decryptMessage(message, message.senderId),
      builder: (context, snapshot) {
        final decryptedContent = snapshot.data ?? '[Decrypting...]';
        final timeStr = DateFormat('HH:mm').format(message.timestamp);
        final showEncryptedIcon = message.content.isEmpty || message.content == '[Encrypted message]';

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Align(
            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  gradient: isMe
                      ? LinearGradient(
                          colors: [Colors.cyan.shade700, Colors.cyan.shade600],
                        )
                      : LinearGradient(
                          colors: [
                            const Color(0xFF2A2A4A),
                            const Color(0xFF252545),
                          ],
                        ),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: isMe ? const Radius.circular(18) : const Radius.circular(4),
                    bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(18),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isMe ? Colors.cyan.shade700 : const Color(0xFF2A2A4A)).withValues(alpha: 0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    if (!isMe)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          message.senderName.isEmpty ? widget.otherUserName : message.senderName,
                          style: TextStyle(color: Colors.cyan.shade300, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                    if (showEncryptedIcon && snapshot.connectionState == ConnectionState.done)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock, size: 12, color: Colors.white.withValues(alpha: 0.5)),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              decryptedContent,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      Text(
                        snapshot.connectionState == ConnectionState.waiting ? 'Decrypting...' : decryptedContent,
                        style: TextStyle(
                          color: snapshot.connectionState == ConnectionState.waiting
                              ? Colors.white.withValues(alpha: 0.5)
                              : Colors.white.withValues(alpha: 0.9),
                          fontSize: 15,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock, size: 10, color: Colors.white.withValues(alpha: 0.35)),
                        const SizedBox(width: 4),
                        Text(
                          timeStr,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 4),
                          Icon(
                            message.isRead ? Icons.done_all : Icons.done,
                            size: 14,
                            color: message.isRead ? Colors.blue.shade300 : Colors.white38,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A3E),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _messageController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 4,
                  minLines: 1,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  onChanged: (text) {
                    final provider = context.read<ChatProvider>();
                    final shouldType = text.isNotEmpty;
                    if (shouldType != _isTyping) {
                      _isTyping = shouldType;
                      provider.sendTyping(widget.conversationId, shouldType);
                    }
                  },
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Colors.cyan.shade600, Colors.cyan.shade500],
                ),
              ),
              child: IconButton(
                icon: const Icon(Icons.send_rounded, color: Colors.white),
                onPressed: _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
