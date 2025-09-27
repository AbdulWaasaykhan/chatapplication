// filename: chat_page.dart

import 'dart:io';
import 'package:chatapplication/components/chat_bubble.dart';
import 'package:chatapplication/components/my_textfield.dart';
import 'package:chatapplication/services/auth/auth_service.dart';
import 'package:chatapplication/services/auth/chat/chat_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ChatPage extends StatefulWidget {
  final String receiverEmail;
  final String receiverID;

  const ChatPage({
    super.key,
    required this.receiverEmail,
    required this.receiverID,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ChatService _chatService = ChatService();
  final AuthService _authService = AuthService();
  final FocusNode myFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();

  // notifier to efficiently update ui without rebuilding the whole screen
  final ValueNotifier<bool> _isComposing = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();

    // handle async initialization
    _initializeChat();

    // listener to scroll down when keyboard appears
    myFocusNode.addListener(() {
      if (myFocusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 300), () => scrollDown());
      }
    });

    // this listener updates the notifier's value when text changes
    _messageController.addListener(() {
      _isComposing.value = _messageController.text.isNotEmpty;
    });
  }

  void _initializeChat() async {
    // wait for the chat room to be created or confirmed
    await _chatService.ensureChatRoomExists(
      _authService.getCurrentUser()!.uid,
      widget.receiverID,
    );

    // now that the room exists, mark messages as read
    if (mounted) {
      _chatService.markMessagesAsRead(widget.receiverID);
    }
  }

  @override
  void dispose() {
    myFocusNode.dispose();
    _messageController.dispose();
    _isComposing.dispose(); // dispose the notifier
    super.dispose();
  }

  void scrollDown() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void sendMessage() async {
    if (_messageController.text.isNotEmpty) {
      String messageText = _messageController.text;
      _messageController.clear(); // clear the controller immediately for better ux

      try {
        await _chatService.sendMessage(
          _authService.getCurrentUser()!.uid,
          widget.receiverID,
          messageText, // use the stored message text
        );
        scrollDown();
      } catch (e) {
        // if sending fails, show an error message and restore the text
        if (mounted) {
          _messageController.text = messageText; // put the text back
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Couldn't send message. Please check your connection."),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> sendMedia(bool isVideo) async {
    final pickedFile = await (isVideo
        ? _picker.pickVideo(source: ImageSource.gallery)
        : _picker.pickImage(source: ImageSource.gallery));
    if (pickedFile != null) {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator()),
        );
      }
      try {
        await _chatService.sendMediaMessage(
          _authService.getCurrentUser()!.uid,
          widget.receiverID,
          File(pickedFile.path),
          isVideo ? "video" : "image",
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Upload failed: $e")),
          );
        }
      } finally {
        if (mounted) Navigator.of(context).pop();
        scrollDown();
      }
    }
  }

  String getUsernameFromEmail(String email) {
    return email.split('@').first;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(getUsernameFromEmail(widget.receiverEmail)),
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessageList()),
          _buildUserInput(),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    String senderID = _authService.getCurrentUser()!.uid;
    return StreamBuilder<QuerySnapshot>(
      stream: _chatService.getMessages(senderID, widget.receiverID),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text("Error loading messages"));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        WidgetsBinding.instance.addPostFrameCallback((_) => scrollDown());
        final docs = snapshot.data!.docs;
        return ListView.builder(
          controller: _scrollController,
          itemCount: docs.length,
          itemBuilder: (context, index) {
            return _buildMessageItem(docs[index]);
          },
        );
      },
    );
  }

  Widget _buildMessageItem(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    bool isCurrentUser = data['senderID'] == _authService.getCurrentUser()!.uid;
    var alignment =
    isCurrentUser ? Alignment.centerRight : Alignment.centerLeft;
    if (!data['read'] && !isCurrentUser) {
      _chatService.markMessageAsRead(doc.id, widget.receiverID);
    }
    return Container(
      alignment: alignment,
      child: ChatBubble(
        message: data,
        isCurrentUser: isCurrentUser,
        isRead: data['read'] ?? false,
      ),
    );
  }

  Widget _buildUserInput() {
    final colorScheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            // this builder hides the plus button when composing
            ValueListenableBuilder<bool>(
              valueListenable: _isComposing,
              builder: (context, isComposingValue, child) {
                // only show the plus button when not typing
                return isComposingValue
                    ? const SizedBox.shrink() // hide when typing
                    : PopupMenuButton<String>(
                  icon: Icon(Icons.add, color: colorScheme.primary),
                  onSelected: (value) {
                    if (value == 'photo') {
                      sendMedia(false);
                    } else if (value == 'video') {
                      sendMedia(true);
                    }
                  },
                  itemBuilder: (BuildContext context) =>
                  <PopupMenuEntry<String>>[
                    const PopupMenuItem<String>(
                      value: 'photo',
                      child: Row(
                        children: [
                          Icon(Icons.photo),
                          SizedBox(width: 8),
                          Text('Photo'),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'video',
                      child: Row(
                        children: [
                          Icon(Icons.videocam),
                          SizedBox(width: 8),
                          Text('Video'),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),

            // textfield
            Expanded(
              child: MyTextfield(
                controller: _messageController,
                hintText: "Type a message",
                obscureText: false,
                focusNode: myFocusNode,
              ),
            ),

            // send button builder
            ValueListenableBuilder<bool>(
              valueListenable: _isComposing,
              builder: (context, isComposingValue, child) {
                // only show the send button when typing
                return isComposingValue
                    ? Container(
                  margin: const EdgeInsets.only(left: 8),
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: sendMessage,
                    icon: Icon(Icons.arrow_upward,
                        color: colorScheme.onPrimary),
                  ),
                )
                    : const SizedBox.shrink(); // hide when not typing
              },
            ),
          ],
        ),
      ),
    );
  }
}