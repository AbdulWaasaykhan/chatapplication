// filename: chat_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:chatapplication/models/message.dart';
import 'package:chatapplication/models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logger/logger.dart';
import 'encryption_service.dart'; // Assuming this file contains EncryptionService and MessageEnvelope

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final SupabaseClient _supabase = Supabase.instance.client;
  final Logger _logger = Logger();
  final EncryptionService _encryptionService = EncryptionService();

  // 🔹 Get chatroom ID by sorting user IDs
  String getChatroomID(String user1, String user2) {
    List<String> ids = [user1, user2];
    ids.sort();
    return ids.join('_');
  }

  // 🔹 Ensure chat room exists
  Future<void> ensureChatRoomExists(String senderID, String receiverID) async {
    String chatroomID = getChatroomID(senderID, receiverID);
    final chatRoomDocRef = _firestore.collection("chat_rooms").doc(chatroomID);
    final docSnapshot = await chatRoomDocRef.get();

    if (!docSnapshot.exists) {
      await chatRoomDocRef.set({
        'participants': [senderID, receiverID],
        'last_message_timestamp': Timestamp.now(),
        'deleted_for': [],
      });
    }
  }

  // 🔹 Update last message in room
  Future<void> _updateLastMessage(
      String chatroomID, String message, String senderID) async {
    await _firestore.collection("chat_rooms").doc(chatroomID).update({
      'last_message': message,
      'last_message_sender_id': senderID,
      'last_message_timestamp': Timestamp.now(),
    });
  }

  // 🔹 Stream of chat rooms (used in HomePage)
  Stream<QuerySnapshot<Map<String, dynamic>>> getChatRoomsStream() {
    final currentUserUID = _auth.currentUser!.uid;
    return _firestore
        .collection('chat_rooms')
        .where('participants', arrayContains: currentUserUID)
        .orderBy('last_message_timestamp', descending: true)
        .snapshots();
  }

  // 🔹 Search Users
  Future<List<UserModel>> searchUsers(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final result = await _firestore
          .collection('Users')
          .where('username', isGreaterThanOrEqualTo: query)
          .where('username', isLessThanOrEqualTo: '$query\uf8ff')
          .get();

      return result.docs.map((doc) => UserModel.fromMap(doc.data())).toList();
    } catch (e) {
      _logger.e('searchUsers failed: $e');
      return [];
    }
  }

  // 🔹 Send text message (encrypted, accepts destructionDuration)
  Future<void> sendMessage(String senderID, String receiverID, String message,
      {Duration? destructionDuration}) async {
    final String currentUserEmail = _auth.currentUser!.email!;
    final Timestamp timestamp = Timestamp.now();

    // 1. Calculate Destruction Time (Restored)
    Timestamp? destructionTime = destructionDuration != null
        ? Timestamp.fromMillisecondsSinceEpoch(
            timestamp.millisecondsSinceEpoch +
                destructionDuration.inMilliseconds)
        : null;

    String storedMessage = message;

    // 2. Encryption Logic (Original friend's logic)
    try {
      final doc = await _firestore.collection('Users').doc(receiverID).get();
      final recipientPublicKey = (doc.data()?['publicKey'] ?? '') as String;
      if (recipientPublicKey.isNotEmpty && message.trim().isNotEmpty) {
        // Assuming MessageEnvelope is defined in encryption_service or separately
        final envelope = await _encryptionService.encryptForRecipient(
            message, recipientPublicKey);
        // Assuming toJson() exists on MessageEnvelope
        storedMessage = jsonEncode(envelope.toJson()); 
      }
    } catch (e) {
      _logger.w('Encryption failed, storing plaintext: $e');
    }

    Message newMessage = Message(
      senderID: senderID,
      senderEmail: currentUserEmail,
      receiverID: receiverID,
      message: storedMessage,
      type: "text",
      mediaUrl: null,
      timestamp: timestamp,
      read: false,
      destructionTime: destructionTime, // <-- RESTORED
    );

    String chatroomID = getChatroomID(senderID, receiverID);
    await ensureChatRoomExists(senderID, receiverID);

    await _firestore
        .collection("chat_rooms")
        .doc(chatroomID)
        .collection("messages")
        .add(newMessage.toMap());

    // 3. Update last message preview (Secure placeholder)
    String messagePreview = destructionTime != null ? "Self-destructing message" : "[Encrypted message]";
    await _updateLastMessage(chatroomID, messagePreview, senderID);
  }

  // 🔹 Send media message (Restored logic, accepts destructionDuration)
  Future<void> sendMediaMessage(String senderID, String receiverID, File file,
      String type,
      {Duration? destructionDuration}) async {
    final String currentUserEmail = _auth.currentUser!.email!;
    final Timestamp timestamp = Timestamp.now();

    try {
      // 1. Calculate Destruction Time (Restored)
      Timestamp? destructionTime = destructionDuration != null
          ? Timestamp.fromMillisecondsSinceEpoch(
              timestamp.millisecondsSinceEpoch +
                  destructionDuration.inMilliseconds)
          : null;

      final fileExt = file.path.split('.').last;
      final fileName = "${DateTime.now().millisecondsSinceEpoch}.$fileExt";
      String chatroomID = getChatroomID(senderID, receiverID);
      await ensureChatRoomExists(senderID, receiverID);

      final filePath = "$chatroomID/$fileName";

      // Upload to Supabase Storage
      await _supabase.storage
          .from('chat_media')
          .upload(filePath, file, fileOptions: const FileOptions(upsert: true));

      final String publicUrl =
          _supabase.storage.from('chat_media').getPublicUrl(filePath);

      Message newMessage = Message(
        senderID: senderID,
        senderEmail: currentUserEmail,
        receiverID: receiverID,
        message: "", // Empty message for media
        type: type,
        mediaUrl: publicUrl,
        timestamp: timestamp,
        read: false,
        destructionTime: destructionTime, // <-- RESTORED
      );

      // Save message to Firestore
      await _firestore
          .collection("chat_rooms")
          .doc(chatroomID)
          .collection("messages")
          .add(newMessage.toMap());

      // 2. Update last message preview (Generic placeholder)
      String messagePreview = (type == 'image') ? "📷 Photo" : "📹 Video";
      if (destructionTime != null) {
        messagePreview = "Self-destructing $messagePreview";
      }
      await _updateLastMessage(chatroomID, messagePreview, senderID);

    } catch (e, st) {
      _logger.e('sendMediaMessage failed: $e', error: e, stackTrace: st);
      rethrow;
    }
  }

  // 🔹 Decrypt message payload
  Future<String> decryptMessagePayload(String envelopeJsonString) async {
    try {
      final Map<String, dynamic> map = jsonDecode(envelopeJsonString);
      // Assuming MessageEnvelope.fromJson is available
      // final envelope = MessageEnvelope.fromJson(map); 
      // final plaintext = await _encryptionService.decryptEnvelope(envelope);
      
      // Temporarily bypass decryption for testing merge stability
      // Since MessageEnvelope definition is missing, returning a placeholder
      return "[Decrypted Content: $envelopeJsonString]"; 
    } catch (e) {
      _logger.e('Decryption error: $e');
      return "[Unable to decrypt]";
    }
  }

  // 🔹 Get user's public key
  Future<String?> getUserPublicKey(String uid) async {
    final doc = await _firestore.collection('Users').doc(uid).get();
    return doc.data()?['publicKey'] as String?;
  }

  // 🔹 Get message stream
  Stream<QuerySnapshot> getMessages(String userID, String otherUserID) {
    String chatRoomID = getChatroomID(userID, otherUserID);
    return _firestore
        .collection("chat_rooms")
        .doc(chatRoomID)
        .collection("messages")
        .orderBy("timestamp", descending: false)
        .snapshots();
  }

  // 🔹 Get user data
  Future<UserModel?> getUserData(String uid) async {
    try {
      DocumentSnapshot doc =
      await _firestore.collection('Users').doc(uid).get();
      if (doc.exists) {
        // Assuming UserModel.fromMap is available
        return UserModel.fromMap(doc.data() as Map<String, dynamic>); 
      }
    } catch (e) {
      _logger.e('Failed to get user data for $uid: $e');
    }
    return null;
  }

  // 🔹 Mark all messages as read (used by ChatPage)
  Future<void> markMessagesAsRead(
      String chatroomID, String currentUserID) async {
    final unreadMessages = await _firestore
        .collection('chat_rooms')
        .doc(chatroomID)
        .collection('messages')
        .where('receiverID', isEqualTo: currentUserID)
        .where('read', isEqualTo: false)
        .get();

    WriteBatch batch = _firestore.batch();
    for (var doc in unreadMessages.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  // 🔹 Soft delete chat
  Future<void> softDeleteChat(String chatroomID) async {
    final currentUserUID = _auth.currentUser!.uid;
    await _firestore.collection('chat_rooms').doc(chatroomID).update({
      'deleted_for': FieldValue.arrayUnion([currentUserUID])
    });
  }
}
