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
  final String recieverID;

  const ChatPage({
    super.key,
    required this.receiverEmail,
    required this.recieverID,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  // text controller
  final TextEditingController _messageController = TextEditingController();

  // chat & auth services
  final ChatService _chatService = ChatService();
  final AuthService _authService = AuthService();

  // for textfied focus
  FocusNode myFocusNode = FocusNode();

  // scroll controller
  final ScrollController _scrollController = ScrollController();

  // image picker
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();

    myFocusNode.addListener(() {
      if (myFocusNode.hasFocus) {
        Future.delayed(
          const Duration(milliseconds: 300),
              () => scrollDown(),
        );
      }
    });

    Future.delayed(
      const Duration(milliseconds: 500),
          () => scrollDown(),
    );
  }

  @override
  void dispose() {
    myFocusNode.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void scrollDown() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0, // since reverse:true
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  // ---------------- TEXT MESSAGE ----------------
  void sendMessage() async {
    if (_messageController.text.isNotEmpty) {
      await _chatService.sendMessage(
        _authService.getCurrentUser()!.uid,
        widget.recieverID,
        _messageController.text,
      );
      _messageController.clear();
      scrollDown();
    }
  }

  // ---------------- MEDIA MESSAGE ----------------
  Future<void> sendMedia(bool isVideo) async {
    final pickedFile = await (isVideo
        ? _picker.pickVideo(source: ImageSource.gallery)
        : _picker.pickImage(source: ImageSource.gallery));

    if (pickedFile != null) {
      // show loading while uploading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      await _chatService.sendMediaMessage(
        _authService.getCurrentUser()!.uid,
        widget.recieverID,
        File(pickedFile.path),
        isVideo ? "video" : "image",
      );

      Navigator.of(context).pop(); // close loading dialog
      scrollDown();
    }
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: Text(widget.receiverEmail),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.grey,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessageList()),
          _buildUserInput(),
        ],
      ),
    );
  }

  // build message list
  Widget _buildMessageList() {
    String senderID = _authService.getCurrentUser()!.uid;
    return StreamBuilder<QuerySnapshot>(
      stream: _chatService.getMessages(senderID, widget.recieverID),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text("Error loading messages"));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No messages yet."));
        }

        final docs = snapshot.data!.docs;

        return ListView.builder(
          controller: _scrollController,
          reverse: true, // newest at bottom
          itemCount: docs.length,
          itemBuilder: (context, index) {
            return _buildMessageItem(docs[index]);
          },
        );
      },
    );
  }

  // build message item
  Widget _buildMessageItem(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    bool isCurrentUser = data['senderID'] == _authService.getCurrentUser()!.uid;
    var alignment =
    isCurrentUser ? Alignment.centerRight : Alignment.centerLeft;

    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ChatBubble(
        message: data,
        isCurrentUser: isCurrentUser,
      ),
    );
  }

  // build user input
  Widget _buildUserInput() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
        child: Row(
          children: [
            // gallery (image)
            IconButton(
              icon: const Icon(Icons.photo, color: Colors.blue),
              onPressed: () => sendMedia(false),
            ),
            // video
            IconButton(
              icon: const Icon(Icons.videocam, color: Colors.red),
              onPressed: () => sendMedia(true),
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

            // send button
            Container(
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
              margin: const EdgeInsets.only(right: 8),
              child: IconButton(
                onPressed: sendMessage,
                icon: const Icon(Icons.arrow_upward, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
