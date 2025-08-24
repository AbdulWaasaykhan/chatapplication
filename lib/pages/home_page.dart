import 'package:chatapplication/services/auth/chat/chat_service.dart';
import 'package:flutter/material.dart';
import '../components/user_tile.dart';
import '../services/auth/auth_service.dart';
import '../components/my_drawer.dart';
import 'chat_page.dart';

class HomePage extends StatelessWidget {
  HomePage({super.key});

  // chat & auth service
  final ChatService _chatService = ChatService();
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: const Text("Home"),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.grey,
        elevation: 0,
        ),
        drawer: const MyDrawer(),
        body: _buildUserList(),
    );
  }

  // bulid a list of users except for the current logged in user
  Widget _buildUserList(){
    return StreamBuilder(
      stream: _chatService.getUserStream(),
       builder: (context, snapshot){
        //error
        if (snapshot.hasError) {
          return const Text("Error");
        }

        // loading..
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Text("Loading..");
        }

        // return list view 
        return ListView(
          children: snapshot.data!
          .map<Widget>((userData) => _buildUserListItem(userData, context))
          .toList(),
        );
       },
        );
       } 

       // build individual list title for user
       Widget _buildUserListItem(
        Map<String, dynamic> userData, BuildContext context){
        // display all users except current user
       if (userData["email"] != _authService.getCurrentUser()!.email) {
         return UserTile(
          text: userData["email"],
          onTap: () {
            // tapped on the user -> go check to chat page
            Navigator.push(
            context, 
            MaterialPageRoute(
              builder: (context) => ChatPage(
                receiverEmail: userData["email"],
                recieverID: userData["uid"],
              ),
            ),
          );
        },
      );
       } else {
        return Container();
       }
    }
  }
