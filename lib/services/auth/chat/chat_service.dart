import 'dart:io';
import 'package:chatapplication/models/message.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logger/logger.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final SupabaseClient _supabase = Supabase.instance.client;

  // ---------------------- TYPING STATUS ----------------------

  /// Get the chatroom ID by sorting user IDs
  String getChatroomID(String user1, String user2) {
    List<String> ids = [user1, user2];
    ids.sort();
    return ids.join('_');
  }

  /// Listen to typing status of the other user inside the chatroom
  Stream<bool> getTypingStatus(String otherUserID) {
    final String currentUserID = _auth.currentUser!.uid;
    final String chatroomID = getChatroomID(currentUserID, otherUserID);

    return _firestore.collection('typing_status').doc(chatroomID).snapshots().map((snapshot) {
      if (!snapshot.exists) return false;
      Map<String, dynamic> data = snapshot.data() ?? {};
      return data[otherUserID] ?? false;
    });
  }

  /// Set typing status of current user inside the chatroom
  Future<void> setTypingStatus(String otherUserID, bool isTyping) async {
    final String currentUserID = _auth.currentUser!.uid;
    final String chatroomID = getChatroomID(currentUserID, otherUserID);

    await _firestore.collection('typing_status').doc(chatroomID).set({
      currentUserID: isTyping,
      'timestamp': Timestamp.now(),
    }, SetOptions(merge: true));
  }

  // ---------------------- READ RECEIPTS ----------------------

  Future<void> markMessageAsRead(String messageID, String receiverID) async {
    String senderID = _auth.currentUser!.uid;
    String chatroomID = getChatroomID(senderID, receiverID);

    await _firestore
        .collection('chat_rooms')
        .doc(chatroomID)
        .collection('messages')
        .doc(messageID)
        .update({'read': true});
  }

  Future<void> markMessagesAsRead(String receiverID) async {
    String senderID = _auth.currentUser!.uid;
    String chatroomID = getChatroomID(senderID, receiverID);

    final messages = await _firestore
        .collection('chat_rooms')
        .doc(chatroomID)
        .collection('messages')
        .where('senderID', isNotEqualTo: senderID)
        .where('read', isEqualTo: false)
        .get();

    for (var doc in messages.docs) {
      await doc.reference.update({'read': true});
    }
  }

  // ---------------------- MESSAGES ----------------------

  Future<void> sendMessage(
    String senderID,
    String receiverID,
    String message,
  ) async {
    final String currentUserEmail = _auth.currentUser!.email!;
    final Timestamp timestamp = Timestamp.now();

    Message newMessage = Message(
      senderID: senderID,
      senderEmail: currentUserEmail,
      receiverID: receiverID,
      message: message,
      type: "text",
      mediaUrl: null,
      timestamp: timestamp,
      read: false,
    );

    String chatroomID = getChatroomID(senderID, receiverID);

    await _firestore
        .collection("chat_rooms")
        .doc(chatroomID)
        .collection("messages")
        .add(newMessage.toMap());
  }

  Future<void> sendMediaMessage(
    String senderID,
    String receiverID,
    File file,
    String type,
  ) async {
    final String currentUserEmail = _auth.currentUser!.email!;
    final Timestamp timestamp = Timestamp.now();
    final Logger logger = Logger();

    try {
      final fileExt = file.path.split('.').last;
      final fileName = "${DateTime.now().millisecondsSinceEpoch}.$fileExt";

      String chatroomID = getChatroomID(senderID, receiverID);
      final String filePath = "$chatroomID/$fileName";

      await _supabase.storage.from('chat_media').upload(
        filePath,
        file,
        fileOptions: const FileOptions(upsert: true),
      );

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
      );

      await _firestore
          .collection("chat_rooms")
          .doc(chatroomID)
          .collection("messages")
          .add(newMessage.toMap());
    } catch (e, st) {
      logger.e('sendMediaMessage failed: $e', error: e, stackTrace: st);
      rethrow;
    }
  }

  Stream<QuerySnapshot> getMessages(String userID, String otherUserID) {
    String chatRoomID = getChatroomID(userID, otherUserID);

    return _firestore
        .collection("chat_rooms")
        .doc(chatRoomID)
        .collection("messages")
        .orderBy("timestamp", descending: false)
        .snapshots();
  }

  Stream<List<Map<String, dynamic>>> getUserStream() {
    return _firestore.collection("Users").snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => doc.data()).toList();
    });
  }
}
