import 'dart:io';
import 'package:chatapplication/models/message.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logger/logger.dart';

class ChatService {
  // instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final SupabaseClient _supabase = Supabase.instance.client;

  // user stream
  Stream<List<Map<String, dynamic>>> getUserStream() {
    return _firestore.collection("Users").snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return doc.data();
      }).toList();
    });
  }

  // text message
  Future<void> sendMessage(
      String senderID,
      String recieverID,
      String message,
      ) async {
    final String currentUserEmail = _auth.currentUser!.email!;
    final Timestamp timestamp = Timestamp.now();

    // create text message
    Message newMessage = Message(
      senderID: senderID,
      senderEmail: currentUserEmail,
      recieverID: recieverID,
      message: message,
      type: "text",
      mediaUrl: null,
      timestamp: timestamp,
    );

    // construct unique chatroom ID
    List<String> ids = [senderID, recieverID];
    ids.sort();
    String chatroomID = ids.join('_');

    // save message to firestore
    await _firestore
        .collection("chat_rooms")
        .doc(chatroomID)
        .collection("messages")
        .add(newMessage.toMap());
  }

  // media message
  Future<void> sendMediaMessage(
      String senderID,
      String recieverID,
      File file,
      String type, // "image" or "video"
      ) async {
    final String currentUserEmail = _auth.currentUser!.email!;
    final Timestamp timestamp = Timestamp.now();

    final fileExt = file.path.split('.').last;
    final fileName = "${DateTime.now().millisecondsSinceEpoch}.$fileExt";

    // Use chatroomID folder structure so files are grouped
    List<String> ids = [senderID, recieverID];
    ids.sort();
    final String chatroomID = ids.join('_');
    final String filePath = "$chatroomID/$fileName";
    final Logger logger = Logger();

    try {
      // Upload file to Supabase (overwrite allowed if same name)
      await _supabase.storage.from('chat_media').upload(
        filePath,
        file,
        fileOptions: const FileOptions(upsert: true),
      );

      // Get permanent public URL (since bucket is public)
      final String publicUrl =
      _supabase.storage.from('chat_media').getPublicUrl(filePath);

      // Create media message object
      Message newMessage = Message(
        senderID: senderID,
        senderEmail: currentUserEmail,
        recieverID: recieverID,
        message: "",
        type: type,
        mediaUrl: publicUrl,
        timestamp: timestamp,
      );

      // Save message to Firestore
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

  // get messages
  Stream<QuerySnapshot> getMessages(String userID, String otherUserID) {
    List<String> ids = [userID, otherUserID];
    ids.sort();
    String chatRoomID = ids.join('_');

    return _firestore
        .collection("chat_rooms")
        .doc(chatRoomID)
        .collection("messages")
        .orderBy("timestamp", descending: false)
        .snapshots();
  }
}
