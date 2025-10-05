// filename: message.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String senderID;
  final String senderEmail;
  final String receiverID;
  final String message;
  final String type; // text, image, video
  final String? mediaUrl;
  final Timestamp timestamp;
  final bool read;
  final Timestamp? destructionTime; // <-- NEW FIELD for self-destruct

  Message({
    required this.senderID,
    required this.senderEmail,
    required this.receiverID,
    required this.message,
    required this.type,
    this.mediaUrl,
    required this.timestamp,
    this.read = false,
    this.destructionTime, // <-- NEW FIELD
  });

  Map<String, dynamic> toMap() {
    return {
      'senderID': senderID,
      'senderEmail': senderEmail,
      'receiverID': receiverID,
      'message': message,
      'type': type,
      'mediaUrl': mediaUrl,
      'timestamp': timestamp,
      'read': read,
      'destructionTime': destructionTime, // <-- NEW FIELD
    };
  }

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      senderID: map['senderID'],
      senderEmail: map['senderEmail'],
      receiverID: map['receiverID'],
      message: map['message'] ?? '',
      type: map['type'] ?? 'text',
      mediaUrl: map['mediaUrl'],
      timestamp: map['timestamp'],
      read: map['read'] ?? false,
      // ADD NEW FIELD TO FACTORY CONSTRUCTOR
      destructionTime: map['destructionTime'] as Timestamp?,
    );
  }
}