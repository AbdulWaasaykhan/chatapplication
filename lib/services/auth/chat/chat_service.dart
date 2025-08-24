import 'package:chatapplication/models/message.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatService {
  // get instance of firestore & auth
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // get user stream
 
  Stream<List<Map<String, dynamic>>> getUserStream(){
    return _firestore.collection("Users").snapshots().map((snapshot){
      return snapshot.docs.map((doc){
        // go through each indidual user
        final user = doc.data();

        // return user
        return user;
      }).toList();
    });
  }

  // send message
 Future<void> sendMessage(String senderID, String recieverID, String message) async {
  final String currentUserEmail = _auth.currentUser!.email!;
  final Timestamp timestamp = Timestamp.now();

  //create a new message
  Message newMessage = Message(
    senderID: senderID,
    senderEmail: currentUserEmail,
    recieverID: recieverID,
    message: message,
    timestamp: timestamp,
  );

  //construct chat room ID for the two users (sort to ensure uniqueness)
  List<String> ids = [senderID, recieverID];
  ids.sort();
  String chatroomID = ids.join('_');

  //add new message to database
  await _firestore
      .collection("chat_rooms")
      .doc(chatroomID)
      .collection("messages")
      .add(newMessage.toMap());
}

  // get message
  Stream<QuerySnapshot> getMessages(String userID, otherUserID) {
    // construct a chatroom ID for the two users
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