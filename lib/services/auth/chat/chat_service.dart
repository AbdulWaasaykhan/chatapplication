import 'dart:io';
import 'package:chatapplication/models/message.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


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
    String type,
) async {
  final String currentUserEmail = _auth.currentUser!.email!;
  final Timestamp timestamp = Timestamp.now();

  final fileExt = file.path.split('.').last;
  final fileName = "${DateTime.now().millisecondsSinceEpoch}.$fileExt";
  final filePath = "$senderID-$recieverID/$fileName";

  try {
    // Upload file to supabase storage
    await _supabase.storage.from('chat_media').upload(filePath, file);

    // Create signed URL for the uploaded file (valid 7 days)
    final signedUrl = await _supabase.storage.from('chat_media').createSignedUrl(filePath, 60 * 60 * 24 * 7);
    if (signedUrl == null || signedUrl.isEmpty) {
      throw Exception('Failed to create signed URL');
    }

    // Create media message object
    Message newMessage = Message(
      senderID: senderID,
      senderEmail: currentUserEmail,
      recieverID: recieverID,
      message: "",
      type: type,
      mediaUrl: signedUrl,
      timestamp: timestamp,
    );

    List<String> ids = [senderID, recieverID];
    ids.sort();
    String chatroomID = ids.join('_');

    // Save message to Firestore
    await _firestore
        .collection("chat_rooms")
        .doc(chatroomID)
        .collection("messages")
        .add(newMessage.toMap());
  } catch (e) {
    print('[ERROR] sendMediaMessage failed: $e');
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
