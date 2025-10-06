// lib/services/auth/chat/chat_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:chatapplication/models/message.dart';
import 'package:chatapplication/models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logger/logger.dart';
import 'encryption_service.dart';

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

  // 🔹 Send text message (encrypted)
  Future<void> sendMessage(String senderID, String receiverID, String message,
      {Duration? destructionDuration}) async {
    final String currentUserEmail = _auth.currentUser!.email!;
    final Timestamp timestamp = Timestamp.now();

    Timestamp? destructionTime = destructionDuration != null
        ? Timestamp.fromMillisecondsSinceEpoch(
        timestamp.millisecondsSinceEpoch +
            destructionDuration.inMilliseconds)
        : null;

    String storedMessage = message;

    try {
      final doc = await _firestore.collection('Users').doc(receiverID).get();
      final recipientPublicKey = (doc.data()?['publicKey'] ?? '') as String;
      if (recipientPublicKey.isNotEmpty && message.trim().isNotEmpty) {
        final envelope = await _encryptionService.encryptForRecipient(
            message, recipientPublicKey);
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
      destructionTime: destructionTime,
    );

    String chatroomID = getChatroomID(senderID, receiverID);
    await ensureChatRoomExists(senderID, receiverID);

    await _firestore
        .collection("chat_rooms")
        .doc(chatroomID)
        .collection("messages")
        .add(newMessage.toMap());

    await _updateLastMessage(chatroomID, "[Encrypted message]", senderID);
  }

  // 🔹 Send media message (not encrypted)
  Future<void> sendMediaMessage(String senderID, String receiverID, File file,
      String type,
      {Duration? destructionDuration}) async {
    final String currentUserEmail = _auth.currentUser!.email!;
    final Timestamp timestamp = Timestamp.now();

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

    await _supabase.storage
        .from('chat_media')
        .upload(filePath, file, fileOptions: const FileOptions(upsert: true));

    final String publicUrl =
    _supabase.storage.from('chat_media').getPublicUrl(filePath);

    Message newMessage = Message(
      senderID: senderID,
      senderEmail: currentUserEmail,
      receiverID: receiverID,
      message: "",
      type: type,
      mediaUrl: publicUrl,
      timestamp: timestamp,
      read: false,
      destructionTime: destructionTime,
    );

    await _firestore
        .collection("chat_rooms")
        .doc(chatroomID)
        .collection("messages")
        .add(newMessage.toMap());

    String messagePreview = (type == 'image') ? "📷 Photo" : "📹 Video";
    await _updateLastMessage(chatroomID, messagePreview, senderID);
  }

  // 🔹 Decrypt message payload
  Future<String> decryptMessagePayload(String envelopeJsonString) async {
    try {
      final Map<String, dynamic> map = jsonDecode(envelopeJsonString);
      final envelope = MessageEnvelope.fromJson(map);
      final plaintext = await _encryptionService.decryptEnvelope(envelope);
      return plaintext;
    } catch (e) {
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

    for (var doc in unreadMessages.docs) {
      await doc.reference.update({'read': true});
    }
  }

  // 🔹 Soft delete chat
  Future<void> softDeleteChat(String chatroomID) async {
    final currentUserUID = _auth.currentUser!.uid;
    await _firestore.collection('chat_rooms').doc(chatroomID).update({
      'deleted_for': FieldValue.arrayUnion([currentUserUID])
    });
  }
}
