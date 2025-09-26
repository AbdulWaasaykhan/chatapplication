import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String senderID;
  final String senderEmail;
  final String receiverID; // ✅ Correct spelling
  final String message;
  final String type; // text, image, video
  final String? mediaUrl;
  final Timestamp timestamp;
  final bool read; // ✅ For read receipts

  Message({
    required this.senderID,
    required this.senderEmail,
    required this.receiverID, // ✅ Correct spelling here
    required this.message,
    required this.type,
    this.mediaUrl,
    required this.timestamp,
    this.read = false, // Default unread
  });

  Map<String, dynamic> toMap() {
    return {
      'senderID': senderID,
      'senderEmail': senderEmail,
      'receiverID': receiverID, // ✅ Match here too
      'message': message,
      'type': type,
      'mediaUrl': mediaUrl,
      'timestamp': timestamp,
      'read': read,
    };
  }

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      senderID: map['senderID'],
      senderEmail: map['senderEmail'],
      receiverID: map['receiverID'], // ✅ Match here
      message: map['message'] ?? '',
      type: map['type'] ?? 'text',
      mediaUrl: map['mediaUrl'],
      timestamp: map['timestamp'],
      read: map['read'] ?? false,
    );
  }
}
