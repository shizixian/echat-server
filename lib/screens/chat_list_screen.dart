import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/chat_provider.dart';
import '../models/conversation.dart';
import 'chat_screen.dart';
import 'login_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().loadConversations();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _startNewChat(String userId) async {
    final provider = context.read<ChatProvider>();
    await provider.startConversation(userId);
    if (mounted) {
      setState(() => _isSearching = false);
      _searchController.clear();
      provider.searchResults = [];
    }
  }

  Future<void> _logout() async {
    await context.read<ChatProvider>().logout();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D2B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A3E),
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 10, height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.watch<ChatProvider>().isConnected
                    ? Colors.green.shade400
                    : Colors.red.shade400,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'EChat',
              style: TextStyle(
                color: Colors.cyan.shade300,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: Colors.cyan.shade300),
            onPressed: () => setState(() => _isSearching = !_isSearching),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: Colors.cyan.shade300),
            onSelected: (v) {
              if (v == 'settings') _showSettings();
              if (v == 'logout') _logout();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'settings', child: Text('Settings')),
              const PopupMenuItem(value: 'logout', child: Text('Logout')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isSearching) _buildSearchBar(),
          Expanded(child: _buildBody()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.cyan.shade600,
        onPressed: () => setState(() => _isSearching = !_isSearching),
        child: const Icon(Icons.edit_outlined, color: Colors.white),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: const Color(0xFF1A1A3E),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search users...',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
              prefixIcon: Icon(Icons.search, color: Colors.cyan.shade300),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white54),
                      onPressed: () {
                        _searchController.clear();
                        context.read<ChatProvider>().searchResults = [];
                        setState(() {});
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.08),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (value) {
              setState(() {});
              if (value.length >= 2) {
                context.read<ChatProvider>().searchUsers(value);
              }
            },
          ),
          const SizedBox(height: 8),
          Consumer<ChatProvider>(
            builder: (context, provider, _) {
              if (_searchController.text.length < 2) return const SizedBox.shrink();
              if (provider.searchResults.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('No users found', style: TextStyle(color: Colors.white54)),
                );
              }
              return SizedBox(
                height: 200,
                child: ListView.builder(
                  itemCount: provider.searchResults.length,
                  itemBuilder: (context, index) {
                    final user = provider.searchResults[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.cyan.shade800,
                        child: Text(
                          user.displayName[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(user.displayName, style: const TextStyle(color: Colors.white)),
                      subtitle: Text('@${user.username}', style: TextStyle(color: Colors.white54)),
                      onTap: () => _startNewChat(user.id),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return Consumer<ChatProvider>(
      builder: (context, provider, _) {
        if (provider.conversations.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline, size: 64, color: Colors.white.withValues(alpha: 0.2)),
                const SizedBox(height: 16),
                Text(
                  'No conversations yet',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap + to start a new chat',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => provider.loadConversations(),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: provider.conversations.length,
            itemBuilder: (context, index) {
              final conv = provider.conversations[index];
              return _buildConversationTile(conv, provider);
            },
          ),
        );
      },
    );
  }

  Widget _buildConversationTile(Conversation conv, ChatProvider provider) {
    final isOnline = provider.onlineUsers.any((u) => u['userId'] == conv.participantIds.firstWhere((id) => id != provider.currentUserId));
    final timeStr = conv.lastMessageTime != null
        ? DateFormat('HH:mm').format(conv.lastMessageTime!)
        : '';

    return Dismissible(
      key: Key(conv.id),
      background: Container(color: Colors.red.shade800, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.delete, color: Colors.white)),
      onDismissed: (_) {},
      child: ListTile(
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.cyan.shade800,
              child: Text(
                (conv.otherUserName ?? '?')[0].toUpperCase(),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            if (isOnline)
              Positioned(
                bottom: 0, right: 0,
                child: Container(
                  width: 12, height: 12,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.fromBorderSide(BorderSide(color: Color(0xFF0D0D2B), width: 2)),
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          conv.otherUserName ?? 'Unknown',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          conv.lastMessage ?? 'Start chatting...',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(timeStr, style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12)),
            if (conv.unreadCount > 0)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.cyan.shade600,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${conv.unreadCount}',
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
          ],
        ),
        onTap: () async {
          await provider.loadMessages(conv.id);
          if (mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ChatScreen(conversationId: conv.id, otherUserName: conv.otherUserName ?? 'User', otherUserId: conv.participantIds.firstWhere((id) => id != provider.currentUserId)),
              ),
            );
          }
        },
      ),
    );
  }

  void _showSettings() {
    final provider = context.read<ChatProvider>();
    final urlController = TextEditingController(text: provider.serverUrl);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A3E),
        title: const Text('Settings', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: urlController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Server URL',
                labelStyle: const TextStyle(color: Colors.white54),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.cyan)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              provider.logout();
              Navigator.pop(ctx);
            },
            child: const Text('Logout', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}
