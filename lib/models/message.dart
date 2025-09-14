import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String senderID;
  final String senderEmail;
  final String recieverID;

  /// message text (only if type is text)
  final String message;

  /// text/image/video(for now only, may add file sharing later)
  final String type;

  /// url id image/video
  final String? mediaUrl;

  final Timestamp timestamp;

  Message({
    required this.senderID,
    required this.senderEmail,
    required this.recieverID,
    required this.message,
    required this.type,
    this.mediaUrl,
    required this.timestamp,
  });

  // convert to map
  Map<String, dynamic> toMap() {
    return {
      'senderID': senderID,
      'senderEmail': senderEmail,
      'recieverID': recieverID,
      'message': message,
      'type': type,
      'mediaUrl': mediaUrl,
      'timestamp': timestamp,
    };
  }

  // create message object from firestore map
  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      senderID: map['senderID'],
      senderEmail: map['senderEmail'],
      recieverID: map['recieverID'],
      message: map['message'] ?? '',
      type: map['type'] ?? 'text',
      mediaUrl: map['mediaUrl'],
      timestamp: map['timestamp'],
    );
  }
}
