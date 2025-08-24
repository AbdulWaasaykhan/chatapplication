import 'package:chatapplication/components/chat_bubble.dart';
import 'package:chatapplication/components/my_textfield.dart';
import 'package:chatapplication/services/auth/auth_service.dart';
import 'package:chatapplication/services/auth/chat/chat_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ChatPage extends StatefulWidget {
  final String receiverEmail;
  final String recieverID;

 ChatPage({
  super.key, 
  required this.receiverEmail,
  required this.recieverID,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  // text controller
  final TextEditingController _messageController = TextEditingController();

  // chat & auth services
  final ChatService _chatService = ChatService();
  final AuthService _authService = AuthService();

  // for textfied focus
  FocusNode myFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();

    // add listener to focus node
    myFocusNode.addListener(() {
      if (myFocusNode.hasFocus) {
        // cause a delay so that the keyboard has to show up
        // then the amount of remaning space will be calculated,
        // then scrool down
        Future.delayed(
          const Duration(milliseconds: 500),
          () => scrollDown()
        );
      }
    });

    // wait a bit for listview to be built, then scrool to bottom
    Future.delayed(
      const Duration(milliseconds: 500),
      () => scrollDown(),
    );
  }

  @override
  void dispose() {
    myFocusNode.dispose();
    _messageController.dispose();
    super.dispose();
  }

  // scroll controller
  final ScrollController _scrollController = ScrollController();
  void scrollDown() {
    _scrollController.animateTo(
    _scrollController.position.maxScrollExtent, 
    duration: const Duration(seconds: 1), 
    curve: Curves.fastOutSlowIn,
    );
  }

  // send message
  void sendMessage() async {
    // if there is someting inside the textfield
    if (_messageController.text.isNotEmpty) {
      // send the message
      await _chatService.sendMessage(
  _authService.getCurrentUser()!.uid, // senderID (current user)
  widget.recieverID,                  // receiverID
  _messageController.text,            // message
);

      // clear text controller
      _messageController.clear();
    }

    scrollDown();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: Text(widget.receiverEmail),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.grey,
        elevation: 0,
        ),
      body: Column(
        children: [
        // display all messages
        Expanded(
          child: _buildMessageList()
        ),

        //user input
        _buildUserInput(),
      ],
     ),
    );
  }

  // build message list
 Widget _buildMessageList() {
  String senderID = _authService.getCurrentUser()!.uid;
  return StreamBuilder(
    stream: _chatService.getMessages(senderID, widget.recieverID ),
    
    builder: (context, snapshot) {
  print('Snapshot hasData: ${snapshot.hasData}, docs: ${snapshot.data?.docs.length}');
  // ...rest of your code
      // errors
      if (snapshot.hasError) {
        return const Text("Error");
      }
      
      // loading
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Text("Loading..");
      }

      // ADD THIS CHECK:
      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
        return const Center(child: Text("No messages yet."));
      }

      // return list view
      return ListView(
        controller: _scrollController,
        children: 
          snapshot.data!.docs.map((doc) => _buildMessageItem(doc)).toList(),
      );
    },
  );
}

  //build message item
  Widget _buildMessageItem(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    // is cirrent user
    bool isCurrentUser = data['senderID'] == _authService.getCurrentUser()!.uid;

    // align message to the right if sender is the curent user, otherwise left
    var alignment = 
    isCurrentUser ? Alignment.centerRight : Alignment.centerLeft;

    return Container(
      alignment: alignment,
      child: Column(
        crossAxisAlignment: 
        isCurrentUser ? CrossAxisAlignment.end :CrossAxisAlignment.start,
        children: [
        ChatBubble(
          message: data["message"], 
          isCurrentUser: isCurrentUser
          )
        ],
      )
    );
  }

  // build message input
  Widget _buildUserInput() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 50.0),
      child: Row(
        children: [
          // textfield should take up most of the space
          Expanded(
            child: MyTextfield(
            controller: _messageController, 
            hintText: "Type a message", 
            obscureText: false,
            focusNode: myFocusNode,
            ),
            ),
      
            // send button
            Container(
              decoration: const BoxDecoration(
                color: Colors.green,
              shape: BoxShape.circle,
              ),
              margin:const EdgeInsets.only(right: 25),
              child: IconButton(
                onPressed: sendMessage, 
                icon: const Icon(
                  Icons.arrow_upward,
                  color: Colors.white,
                  ),
                        ),
            ),
        ],
      ),
    );
  }
}