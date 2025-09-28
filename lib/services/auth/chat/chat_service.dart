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
  final Logger _logger = Logger();

  // get the chatroom id by sorting user ids to ensure consistency
  String getChatroomID(String user1, String user2) {
    List<String> ids = [user1, user2];
    ids.sort();
    return ids.join('_');
  }

  // helper to ensure the chat room document exists
  Future<void> ensureChatRoomExists(String senderID, String receiverID) async {
    String chatroomID = getChatroomID(senderID, receiverID);
    final chatRoomDocRef = _firestore.collection("chat_rooms").doc(chatroomID);
    final docSnapshot = await chatRoomDocRef.get();

    if (!docSnapshot.exists) {
      await chatRoomDocRef.set({
        'participants': [senderID, receiverID],
        'last_message_timestamp': Timestamp.now(),
      });
    }
  }

  // search users
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    if (query.isEmpty) {
      return [];
    }
    final result = await _firestore
        .collection('Users')
        .where('email', isEqualTo: query)
        .get();

    return result.docs.map((doc) => doc.data()).toList();
  }

  // --- READ RECEIPTS ---

  // mark a single message as read
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

  // mark all unread messages from the other user as read
  Future<void> markMessagesAsRead(String receiverID) async {
    String senderID = _auth.currentUser!.uid;
    String chatroomID = getChatroomID(senderID, receiverID);

    final messages = await _firestore
        .collection('chat_rooms')
        .doc(chatroomID)
        .collection('messages')
        .where('senderID', isEqualTo: receiverID)
        .where('read', isEqualTo: false)
        .get();

    WriteBatch batch = _firestore.batch();
    for (var doc in messages.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  // --- MESSAGES ---

  // send a text message
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

    // ensure chat room exists with participants before sending a message
    await ensureChatRoomExists(senderID, receiverID);

    await _firestore
        .collection("chat_rooms")
        .doc(chatroomID)
        .collection("messages")
        .add(newMessage.toMap());
  }

  // send a media message (image or video)
  Future<void> sendMediaMessage(
      String senderID,
      String receiverID,
      File file,
      String type,
      ) async {
    final String currentUserEmail = _auth.currentUser!.email!;
    final Timestamp timestamp = Timestamp.now();

    try {
      final fileExt = file.path.split('.').last;
      final fileName = "${DateTime.now().millisecondsSinceEpoch}.$fileExt";
      String chatroomID = getChatroomID(senderID, receiverID);

      // ensure chat room exists with participants before sending media
      await ensureChatRoomExists(senderID, receiverID);

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
        message: "", // message is empty for media
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
      _logger.e('sendMediaMessage failed: $e', error: e, stackTrace: st);
      rethrow;
    }
  }

  // get a stream of messages for a given chat room
  Stream<QuerySnapshot> getMessages(String userID, String otherUserID) {
    String chatRoomID = getChatroomID(userID, otherUserID);

    return _firestore
        .collection("chat_rooms")
        .doc(chatRoomID)
        .collection("messages")
        .orderBy("timestamp", descending: false)
        .snapshots();
  }

  // get a stream of all users
  Stream<List<Map<String, dynamic>>> getUserStream() {
    return _firestore.collection("Users").snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final user = doc.data();
        return user;
      }).toList();
    });
  }
}