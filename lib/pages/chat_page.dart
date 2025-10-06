import 'dart:convert';
import 'package:chatapplication/components/chat_bubble.dart';
import 'package:chatapplication/services/auth/auth_service.dart';
import 'package:chatapplication/services/auth/chat/chat_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ChatPage extends StatefulWidget {
  final String receiverEmail;
  final String receiverID;
  final String receiverUsername;

  const ChatPage({
    super.key,
    required this.receiverEmail,
    required this.receiverID,
    required this.receiverUsername,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ChatService _chatService = ChatService();
  final AuthService _authService = AuthService();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _markAllMessagesAsRead();
  }

  // ✅ Mark unread messages as read
  Future<void> _markAllMessagesAsRead() async {
    final currentUser = _authService.getCurrentUser()!;
    final chatroomID =
    _chatService.getChatroomID(currentUser.uid, widget.receiverID);
    await _chatService.markMessagesAsRead(chatroomID, currentUser.uid);
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _authService.getCurrentUser()!;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.receiverUsername),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream:
              _chatService.getMessages(currentUser.uid, widget.receiverID),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text("Error loading messages"));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;
                return ListView.builder(
                  controller: _scrollController,
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    return _buildMessageItem(docs[index]);
                  },
                );
              },
            ),
          ),
          _buildMessageInput(currentUser.uid),
        ],
      ),
    );
  }

  Widget _buildMessageItem(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    bool isCurrentUser = data['senderID'] == _authService.getCurrentUser()!.uid;

    return FutureBuilder<String>(
      future: _decryptMessageIfNeeded(data['message']),
      builder: (context, snapshot) {
        final decryptedText = snapshot.data ?? '[...]';
        final newData = Map<String, dynamic>.from(data);
        newData['message'] = decryptedText;

        return Align(
          alignment:
          isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
          child: ChatBubble(
            message: newData,
            isCurrentUser: isCurrentUser,
            isRead: data['read'] ?? false,
          ),
        );
      },
    );
  }

  Future<String> _decryptMessageIfNeeded(String msg) async {
    try {
      final decoded = jsonDecode(msg);
      if (decoded is Map && decoded.containsKey('encrypted_payload')) {
        return await _chatService.decryptMessagePayload(msg);
      } else {
        return msg;
      }
    } catch (e) {
      return msg;
    }
  }

  Widget _buildMessageInput(String senderID) {
    return Container(
      padding: const EdgeInsets.all(8),
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration:
              const InputDecoration(hintText: "Type a message..."),
            ),
          ),
          IconButton(
            style: IconButton.styleFrom(
              // The background color of the button
              backgroundColor: Theme.of(context).colorScheme.primary,
              // The color of the icon, text, and ripple effect
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              // Disables the splash effect
              highlightColor: Colors.transparent,
              // Sets a fixed size
              fixedSize: const Size(48, 48),
            ),
            icon: const Icon(Icons.send),
            onPressed: () async {
              final text = _messageController.text.trim();
              if (text.isNotEmpty) {
                await _chatService.sendMessage(
                    senderID, widget.receiverID, text);
                _messageController.clear();
                _scrollController.animateTo(
                  _scrollController.position.maxScrollExtent + 80,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
