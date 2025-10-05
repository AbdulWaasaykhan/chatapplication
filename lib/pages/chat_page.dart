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
  final FocusNode myFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();

  // notifier to efficiently update ui without rebuilding the whole screen
  final ValueNotifier<bool> _isComposing = ValueNotifier<bool>(false);
  
  // STATE: For self-destructing duration
  Duration? _selectedDestructionDuration;

  // Map of display names to actual Durations
  final Map<String, Duration?> _destructionOptions = {
    'Normal': null,
    // Special flag duration: Used to signal "Delete on Close" logic later
    'Delete After Viewing': const Duration(seconds: 5), 
    '1 Day': const Duration(days: 1),
    '3 Days': const Duration(days: 3),
    '7 Days': const Duration(days: 7),
  };

  String _selectedDurationText = 'Normal';


  @override
  void initState() {
    super.initState();

    _initializeChat();

    myFocusNode.addListener(() {
      if (myFocusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 300), () => scrollDown());
      }
    });

    _messageController.addListener(() {
      _isComposing.value = _messageController.text.isNotEmpty;
    });
  }

  void _initializeChat() async {
    await _chatService.ensureChatRoomExists(
      _authService.getCurrentUser()!.uid,
      widget.receiverID,
    );

    if (mounted) {
      _chatService.markMessagesAsRead(widget.receiverID);
    }
  }

  @override
  void dispose() {
    // VITAL: Trigger deletion of "Delete After Viewing" messages when exiting the chat!
    _cleanupMessagesOnDispose();

    myFocusNode.dispose();
    _messageController.dispose();
    _isComposing.dispose();
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
      _messageController.clear();

      try {
        await _chatService.sendMessage(
          _authService.getCurrentUser()!.uid,
          widget.receiverID,
          messageText,
          destructionDuration: _selectedDestructionDuration,
        );
        scrollDown();
      } catch (e) {
        if (mounted) {
          _messageController.text = messageText;
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
          destructionDuration: _selectedDestructionDuration,
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

  // ====================================================================
  // CLIENT-SIDE DELETION LOGIC (Only for timed messages > 5 seconds)
  // ====================================================================
  void _deleteExpiredMessages(QuerySnapshot snapshot) {
    final now = Timestamp.now();
    
    // Filter out messages that are set for immediate deletion (5 seconds)
    final timedExpiredDocs = snapshot.docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final destructionTime = data['destructionTime'] as Timestamp?;
      
      // We only clean up long-term timers here (1, 3, 7 days).
      // The 5-second duration is reserved for 'Delete on Close' logic.
      final isTimedDeletion = destructionTime != null && 
                              (destructionTime.millisecondsSinceEpoch - data['timestamp'].millisecondsSinceEpoch) > 6000; // > 6 seconds

      return isTimedDeletion && destructionTime.compareTo(now) <= 0;
    }).toList();

    if (timedExpiredDocs.isNotEmpty) {
      WriteBatch batch = FirebaseFirestore.instance.batch();
      
      for (var doc in timedExpiredDocs) {
        batch.delete(doc.reference);
      }
      
      batch.commit().catchError((e) => print("Failed to clean up expired messages: $e"));
      print('Deleted ${timedExpiredDocs.length} timed messages on chat load.');
    }
  }

  // ====================================================================
  // NEW FUNCTION: DELETION ON CHAT EXIT (Dispose)
  // ====================================================================
  void _cleanupMessagesOnDispose() async {
    final currentUserUID = _authService.getCurrentUser()!.uid;
    final otherUserID = widget.receiverID;
    String chatRoomID = _chatService.getChatroomID(currentUserUID, otherUserID);
    
    // The special duration flag is 5 seconds
    final deleteOnCloseDurationMs = const Duration(seconds: 5).inMilliseconds;

    try {
      // 1. Find messages sent by the OTHER user to the CURRENT user
      // 2. Which are marked as 'read'
      // 3. AND have the special 5-second duration (our flag) set.
      final messagesToCleanup = await FirebaseFirestore.instance
          .collection('chat_rooms')
          .doc(chatRoomID)
          .collection('messages')
          .where('receiverID', isEqualTo: currentUserUID)
          .where('read', isEqualTo: true)
          // Since Firestore doesn't allow checking the difference,
          // we filter by destructionTime close to creationTime, or rely on a new flag.
          // For simplicity here, we assume the 5-second window is the flag.

          // Note: In a real app, chat_service.dart should save a 'deleteOnClose: true' flag.
          // Since we can't change the service file easily here, we query ALL messages
          // and filter the 5-second duration in memory.
          .get(); 

      WriteBatch batch = FirebaseFirestore.instance.batch();
      int deletedCount = 0;

      for (var doc in messagesToCleanup.docs) {
        final data = doc.data();
        final timestampMs = data['timestamp']?.millisecondsSinceEpoch ?? 0;
        final destructionTimeMs = data['destructionTime']?.millisecondsSinceEpoch ?? 0;
        
        final duration = destructionTimeMs - timestampMs;

        // Check if the duration matches our special "Delete on Close" flag (5 seconds)
        if (duration > 0 && duration <= deleteOnCloseDurationMs) {
          batch.delete(doc.reference);
          deletedCount++;
        }
      }

      if (deletedCount > 0) {
        await batch.commit();
        print('Cleanup: Deleted $deletedCount "Delete After Viewing" messages on chat exit.');
      }
    } catch (e) {
      print('Failed to cleanup messages on dispose: $e');
    }
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
          // Show the red banner if a self-destruct duration is set
          if (_selectedDestructionDuration != null) 
             _buildSelfDestructingBanner(context),
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
        
        // VITAL: Call the cleanup function for LONG-TERM timers
        if (snapshot.hasData && snapshot.data != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _deleteExpiredMessages(snapshot.data!);
          });
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
      _chatService.markMessagesAsRead(widget.receiverID); // Mark all messages as read
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

  Widget _buildSelfDestructingBanner(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      color: colorScheme.errorContainer,
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 16.0),
      child: Row(
        children: [
          Icon(Icons.timer_off_outlined, color: colorScheme.onErrorContainer, size: 16),
          const SizedBox(width: 8),
          Text(
            'Self-Destructing: $_selectedDurationText',
            style: TextStyle(color: colorScheme.onErrorContainer, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.close, color: colorScheme.onErrorContainer, size: 16),
            onPressed: () {
              setState(() {
                _selectedDestructionDuration = null;
                _selectedDurationText = 'Normal';
              });
            },
          ),
        ],
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
            ValueListenableBuilder<bool>(
              valueListenable: _isComposing,
              builder: (context, isComposingValue, child) {
                return isComposingValue
                    ? const SizedBox.shrink()
                    : PopupMenuButton<String>(
                        icon: Icon(Icons.add, color: colorScheme.primary),
                        onSelected: (value) {
                          if (value == 'photo') {
                            sendMedia(false);
                          } else if (value == 'video') {
                            sendMedia(true);
                          } else if (_destructionOptions.containsKey(value)) {
                            setState(() {
                              _selectedDurationText = value;
                              _selectedDestructionDuration = _destructionOptions[value];
                            });
                          }
                        },
                        itemBuilder: (BuildContext context) =>
                            <PopupMenuEntry<String>>[
                          // Self-Destruct options
                          ..._destructionOptions.keys.map((String key) {
                            return PopupMenuItem<String>(
                              value: key,
                              child: Row(
                                children: [
                                  Icon(key == 'Normal' ? Icons.chat_bubble_outline : Icons.alarm_on),
                                  const SizedBox(width: 8),
                                  Text(key),
                                ],
                              ),
                            );
                          }).toList(),
                          const PopupMenuDivider(),
                          // Existing media options
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

            Expanded(
              child: MyTextfield(
                controller: _messageController,
                hintText: "Type a message",
                obscureText: false,
                focusNode: myFocusNode,
              ),
            ),

            ValueListenableBuilder<bool>(
              valueListenable: _isComposing,
              builder: (context, isComposingValue, child) {
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
                    : const SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
    );
  }
}
