// filename: chat_page.dart

import 'dart:io';
import 'dart:convert';
import 'package:chatapplication/components/chat_bubble.dart';
import 'package:chatapplication/components/my_textfield.dart'; // Ensure this component exists
import 'package:chatapplication/services/auth/auth_service.dart';
import 'package:chatapplication/services/auth/chat/chat_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // For media sharing

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
  final ImagePicker _picker = ImagePicker(); 

  final ValueNotifier<bool> _isComposing = ValueNotifier<bool>(false); 

  // Self-Destruct State 
  Duration? _selectedDestructionDuration;
  
  // VITAL: Flag for Time-Independent Deletion
  static const Duration deleteAfterViewingFlag = Duration(days: 9999); 

  final Map<String, Duration?> _destructionOptions = {
    'Normal': null,
    'Delete After Viewing': deleteAfterViewingFlag, // Flag: delete only when read and closed
    '1 Day': const Duration(days: 1),
    '3 Days': const Duration(days: 3),
    '7 Days': const Duration(days: 7),
  };
  String _selectedDurationText = 'Normal';

  @override
  void initState() {
    super.initState();
    _markAllMessagesAsRead();
    
    _messageController.addListener(() {
      _isComposing.value = _messageController.text.isNotEmpty;
    });
  }
  
  // Client-Side Deletion Logic (Runs when chat closes - NOW TIME-INDEPENDENT)
  void _deleteExpiredMessagesOnExit() async {
    final senderID = _authService.getCurrentUser()!.uid;
    final chatroomID = _chatService.getChatroomID(senderID, widget.receiverID);
    final now = Timestamp.now();
    
    // --- Step 1: Query all messages that are eligible for deletion ---
    // This query is broad because we check two different types of expiration
    final potentialDocs = await FirebaseFirestore.instance
        .collection('chat_rooms')
        .doc(chatroomID)
        .collection('messages')
        .where('destructionTime', isGreaterThan: Timestamp.fromMillisecondsSinceEpoch(1)) // Must have a destruction time set
        .get();

    Set<String> docsToDeleteIDs = {};

    for (var doc in potentialDocs.docs) {
      final data = doc.data();
      final destructionTime = data['destructionTime'] as Timestamp;
      final isRead = data['read'] as bool? ?? false;
      
      // Check 1: Time-Based Expiration (1 day, 3 days, 7 days)
      if (destructionTime.compareTo(now) <= 0) {
        docsToDeleteIDs.add(doc.id);
      } 
      
      // Check 2: View-Based Expiration ("Delete After Viewing" Flag)
      // If the destruction time is our very distant flag (meaning it was set to delete-after-view)
      // AND the message has been read (isRead: true), delete it.
      else if (destructionTime.toDate().difference(now.toDate()).inDays > 1000 && isRead) {
        docsToDeleteIDs.add(doc.id);
      }
    }


    // --- Step 2: Perform Batch Deletion ---
    if (docsToDeleteIDs.isNotEmpty) {
      WriteBatch batch = FirebaseFirestore.instance.batch();
      for (var docId in docsToDeleteIDs) {
        batch.delete(FirebaseFirestore.instance.collection('chat_rooms').doc(chatroomID).collection('messages').doc(docId));
      }
      await batch.commit();
    }
  }

  // ✅ Mark unread messages as read
  Future<void> _markAllMessagesAsRead() async {
    final currentUser = _authService.getCurrentUser()!;
    final chatroomID =
    _chatService.getChatroomID(currentUser.uid, widget.receiverID);
    await _chatService.markMessagesAsRead(chatroomID, currentUser.uid);
  }

  // Send Text Message (Updated to include Duration)
  void sendMessage({Duration? destructionDuration}) async {
    final senderID = _authService.getCurrentUser()!.uid;
    final text = _messageController.text.trim();
    
    if (text.isNotEmpty) {
      _messageController.clear();
      
      try {
        await _chatService.sendMessage(
          senderID, 
          widget.receiverID, 
          text,
          destructionDuration: destructionDuration, 
        );
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } catch (e) {
         // Handle error if necessary
      }
    }
  }

  // Send Media Message (Restored)
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
      }
    }
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
          // Banner for self-destruct mode
          if (_selectedDestructionDuration != null) 
             _buildSelfDestructingBanner(context),
             
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
                // Auto scroll to bottom
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
                });
                
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

    // Use FutureBuilder to decrypt message content for display
    return FutureBuilder<String>(
      future: _decryptMessageIfNeeded(data['message'], data['type'] == 'text'),
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

  // Adjusted decryption helper to skip non-text types
  Future<String> _decryptMessageIfNeeded(String msg, bool isText) async {
    if (!isText) return msg; // Skip decryption for media URLs or empty strings
    
    try {
      final decoded = jsonDecode(msg);
      if (decoded is Map && decoded.containsKey('encrypted_payload')) {
        return await _chatService.decryptMessagePayload(msg);
      } else {
        return msg; // Already plaintext or failed earlier
      }
    } catch (e) {
      return msg; // Failed to decode JSON
    }
  }
  
  // Banner for self-destruct mode 
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

  Widget _buildMessageInput(String senderID) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(8),
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        children: [
          // Attachment/Duration Button (Restored)
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
                          // Set self-destruct duration
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
                        // Media options
                        const PopupMenuItem<String>(
                          value: 'photo',
                          child: Row(children: [Icon(Icons.photo), SizedBox(width: 8), Text('Photo')]),
                        ),
                        const PopupMenuItem<String>(
                          value: 'video',
                          child: Row(children: [Icon(Icons.videocam), SizedBox(width: 8), Text('Video')]),
                        ),
                      ],
                    );
            },
          ),

          // textfield
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: const InputDecoration(hintText: "Type a message..."),
            ),
          ),

          // Send Button (Updated to use sendMessage with duration)
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
                        onPressed: () {
                          // Call sendMessage with the stored duration
                          sendMessage(
                            destructionDuration: _selectedDestructionDuration,
                          );
                        },
                        icon: Icon(Icons.send, color: colorScheme.onPrimary),
                      ),
                    )
                  : const SizedBox.shrink();
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
    _isComposing.dispose(); 
    _deleteExpiredMessagesOnExit(); // RUN DELETION ON EXIT (LAST CUSTOM CALL)
    super.dispose(); // FRAMEWORK CLEANUP (MUST BE LAST)
  }
}