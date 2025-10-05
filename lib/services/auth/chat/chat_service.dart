import 'dart:io';
import 'package:chatapplication/models/message.dart';
import 'package:chatapplication/models/user_model.dart';
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
        'deleted_for': [], // for soft delete
      });
    }
  }

  // helper to update the last message in the chat room document
  Future<void> _updateLastMessage(
      String chatroomID, String message, String senderID) async {
    await _firestore.collection("chat_rooms").doc(chatroomID).update({
      'last_message': message,
      'last_message_sender_id': senderID,
      'last_message_timestamp': Timestamp.now(),
    });
  }

  // --- SEARCH USERS ---
  Future<List<UserModel>> searchUsers(String query) async {
    // ... (no changes in this method)
    if (query.trim().isEmpty) {
      return [];
    }
    try {
      final result = await _firestore
          .collection('Users')
          .where('username', isGreaterThanOrEqualTo: query)
          .where('username', isLessThanOrEqualTo: '$query\uf8ff')
          .get();

      return result.docs.map((doc) => UserModel.fromMap(doc.data())).toList();
    } catch (e) {
      _logger.e('searchUsers failed: $e', error: e);
      return [];
    }
  }

  // mark a single message as read
  Future<void> markMessageAsRead(String messageID, String receiverID) async {
    // ... (no changes in this method)
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
    // ... (no changes in this method)
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
    // update the last message
    await _updateLastMessage(chatroomID, message, senderID);
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

      // update last message for media
      String messageText = (type == 'image') ? "📷 Photo" : "📹 Video";
      await _updateLastMessage(chatroomID, messageText, senderID);
    } catch (e, st) {
      _logger.e('sendMediaMessage failed: $e', error: e, stackTrace: st);
      rethrow;
    }
  }

  // get a stream of messages for a given chat room
  Stream<QuerySnapshot> getMessages(String userID, String otherUserID) {
    // ... (no changes in this method)
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
    // ... (no changes in this method)
    return _firestore.collection("Users").snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final user = doc.data();
        return user;
      }).toList();
    });
  }

  // --- NEW METHODS FOR RECENT CHATS ---

  // get a stream of chat rooms for the current user
  Stream<QuerySnapshot<Map<String, dynamic>>> getChatRoomsStream() {
    final currentUserUID = _auth.currentUser!.uid;
    return _firestore
        .collection('chat_rooms')
        .where('participants', arrayContains: currentUserUID)
        .orderBy('last_message_timestamp', descending: true)
        .snapshots();
  }

  // get user data from firestore
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

  // soft delete a chat
  Future<void> softDeleteChat(String chatroomID) async {
    final currentUserUID = _auth.currentUser!.uid;
    await _firestore.collection('chat_rooms').doc(chatroomID).update({
      'deleted_for': FieldValue.arrayUnion([currentUserUID])
    });
  }
}