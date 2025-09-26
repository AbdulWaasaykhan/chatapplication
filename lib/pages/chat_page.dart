import 'dart:io';
import 'dart:async';  // <--- Added this import

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

  bool isReceiverTyping = false;
  bool isCurrentUserTyping = false;

  // Debounce typing status update fields
  Timer? _typingTimer;
  bool _lastTypingStatus = false;

  @override
  void initState() {
    super.initState();

    myFocusNode.addListener(() {
      if (myFocusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 300), () => scrollDown());
      }
    });

    // Listen for typing status from the receiver
    _chatService.getTypingStatus(widget.receiverID).listen((status) {
      setState(() {
        isReceiverTyping = status;
      });
    });

    _chatService.markMessagesAsRead(widget.receiverID);
  }

  @override
  void dispose() {
    myFocusNode.dispose();
    _messageController.dispose();
    _typingTimer?.cancel();  // Cancel timer on dispose
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
      await _chatService.sendMessage(
        _authService.getCurrentUser()!.uid,
        widget.receiverID,
        _messageController.text,
      );
      _messageController.clear();
      scrollDown();

      // Stop typing after sending
      await _chatService.setTypingStatus(widget.receiverID, false);

      setState(() {
        isCurrentUserTyping = false;
        _lastTypingStatus = false;  // reset last status
      });
    }
  }

  // Refined Debounced handleTyping method with print debug
  void handleTyping() {
    bool typingNow = _messageController.text.isNotEmpty;
    print("handleTyping: typingNow = $typingNow, last = $_lastTypingStatus");

    if (typingNow != _lastTypingStatus) {
      print(" ➝ send typing status to backend");
      _chatService.setTypingStatus(widget.receiverID, typingNow);
      _lastTypingStatus = typingNow;
    }

    _typingTimer?.cancel();

    if (typingNow) {
      _typingTimer = Timer(const Duration(milliseconds: 800), () {
        print(" ➝ timer expired, turning off typing");
        _chatService.setTypingStatus(widget.receiverID, false);
        _lastTypingStatus = false;
        if (isCurrentUserTyping) {
          print(" ➝ setState false typing");
          setState(() {
            isCurrentUserTyping = false;
          });
        }
      });
    }

    if (typingNow != isCurrentUserTyping) {
      print(" ➝ setState typing change: $typingNow");
      setState(() {
        isCurrentUserTyping = typingNow;
      });
    }
  }

  Future<void> sendMedia(bool isVideo) async {
    final pickedFile = await (isVideo
        ? _picker.pickVideo(source: ImageSource.gallery)
        : _picker.pickImage(source: ImageSource.gallery));

    if (pickedFile != null) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      try {
        await _chatService.sendMediaMessage(
          _authService.getCurrentUser()!.uid,
          widget.receiverID,
          File(pickedFile.path),
          isVideo ? "video" : "image",
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Upload failed: $e")),
        );
      } finally {
        Navigator.of(context).pop();
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(getUsernameFromEmail(widget.receiverEmail)),
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
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          // If no messages, still show typing indicator if typing
          return ListView(
            controller: _scrollController,
            children: _buildTypingIndicators(),
          );
        }

        final docs = snapshot.data!.docs;

        // Combine messages and typing indicators in one list
        List<Widget> items = docs.map((doc) => _buildMessageItem(doc)).toList();

        // Add typing indicators at the end of the list
        items.addAll(_buildTypingIndicators());

        WidgetsBinding.instance.addPostFrameCallback((_) => scrollDown());

        return ListView(
          controller: _scrollController,
          children: items,
        );
      },
    );
  }

  List<Widget> _buildTypingIndicators() {
    List<Widget> indicators = [];

    if (isReceiverTyping) {
      indicators.add(
        Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              TypingIndicator(),
              SizedBox(width: 8),
              Text(
                "Typing...",
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    if (isCurrentUserTyping) {
      indicators.add(
        Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text(
                "Typing...",
                style: TextStyle(color: Colors.grey),
              ),
              SizedBox(width: 8),
              TypingIndicator(),
            ],
          ),
        ),
      );
    }

    return indicators;
  }

  Widget _buildMessageItem(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    bool isCurrentUser = data['senderID'] == _authService.getCurrentUser()!.uid;
    var alignment = isCurrentUser ? Alignment.centerRight : Alignment.centerLeft;

    if (!data['read'] && !isCurrentUser) {
      _chatService.markMessageAsRead(doc.id, widget.receiverID);
    }

    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ChatBubble(
        message: data,
        isCurrentUser: isCurrentUser,
        isRead: data['read'] ?? false,
      ),
    );
  }

  Widget _buildUserInput() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.photo, color: Color.fromRGBO(7, 71, 190, 1)),
              onPressed: () => sendMedia(false),
            ),
            IconButton(
              icon: const Icon(Icons.videocam, color: Color.fromRGBO(7, 86, 233, 1)),
              onPressed: () => sendMedia(true),
            ),
            Expanded(
              child: MyTextfield(
                controller: _messageController,
                hintText: "Type a message",
                obscureText: false,
                focusNode: myFocusNode,
                onChanged: (_) => handleTyping(),
              ),
            ),
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              margin: const EdgeInsets.only(right: 8),
              child: IconButton(
                onPressed: sendMessage,
                icon: const Icon(Icons.arrow_upward, color: Color.fromARGB(255, 110, 110, 110)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Simple typing indicator widget (3 bouncing dots)
class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _dotOneAnimation;
  late Animation<double> _dotTwoAnimation;
  late Animation<double> _dotThreeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _dotOneAnimation = Tween<double>(begin: 0.2, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeInOut),
      ),
    );

    _dotTwoAnimation = Tween<double>(begin: 0.2, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.8, curve: Curves.easeInOut),
      ),
    );

    _dotThreeAnimation = Tween<double>(begin: 0.2, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 1.0, curve: Curves.easeInOut),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double dotSize = 8;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FadeTransition(
          opacity: _dotOneAnimation,
          child: _buildDot(dotSize),
        ),
        const SizedBox(width: 4),
        FadeTransition(
          opacity: _dotTwoAnimation,
          child: _buildDot(dotSize),
        ),
        const SizedBox(width: 4),
        FadeTransition(
          opacity: _dotThreeAnimation,
          child: _buildDot(dotSize),
        ),
      ],
    );
  }

  Widget _buildDot(double size) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color.fromARGB(255, 126, 125, 125),
        shape: BoxShape.circle,
      ),
    );
  }
}
