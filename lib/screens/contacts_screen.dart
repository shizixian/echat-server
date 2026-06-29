import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/chat_provider.dart';
import '../models/user.dart';
import 'chat_screen.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().loadContacts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatProvider>();
    final currentUser = provider.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1117),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('联系人', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: provider.contacts.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A2E),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(Icons.people_outline_rounded, size: 32, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 16),
                  Text('暂无其他用户', style: TextStyle(color: Colors.grey[500], fontSize: 16, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 6),
                  Text('分享你的用户 ID 给朋友', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  if (currentUser != null) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A2E),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'ID: ${currentUser.id.substring(0, 12)}...',
                        style: TextStyle(color: Colors.grey[500], fontSize: 11),
                      ),
                    ),
                  ],
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: provider.contacts.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFF1A1A2E), indent: 72),
              itemBuilder: (context, index) {
                final user = provider.contacts[index];
                final isOnline = provider.isUserOnline(user.id);
                return _ContactTile(user: user, isOnline: isOnline);
              },
            ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  final ChatUser user;
  final bool isOnline;

  const _ContactTile({required this.user, required this.isOnline});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(contact: user))),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: const Color(0xFF1A73E8).withOpacity(0.15),
                    child: Text(
                      user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?',
                      style: const TextStyle(color: Color(0xFF1A73E8), fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                  if (isOnline)
                    Positioned(
                      bottom: 0, right: 0,
                      child: Container(
                        width: 14, height: 14,
                        decoration: BoxDecoration(
                          color: Colors.green, shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF0D1117), width: 2.5),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.displayName,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          width: 6, height: 6,
                          decoration: BoxDecoration(
                            color: isOnline ? Colors.green : Colors.grey[700],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(isOnline ? '在线' : '离线',
                            style: TextStyle(color: isOnline ? Colors.green : Colors.grey[600], fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
