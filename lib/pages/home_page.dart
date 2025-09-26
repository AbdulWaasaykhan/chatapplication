import 'package:chatapplication/services/auth/chat/chat_service.dart';
import 'package:flutter/material.dart';
import '../components/user_tile.dart';
import '../services/auth/auth_service.dart';
import 'chat_page.dart';
import '../pages/settings_page.dart';
import '../components/my_popup.dart'; // Import the custom popup menu

class HomePage extends StatelessWidget {
  HomePage({super.key});

  final ChatService _chatService = ChatService();
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(56.0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: AppBar(
            title: const Text("Chats"),
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.grey,
            elevation: 0,
            actions: [
              CustomPopupMenu(
                menuItems: [
                  const PopupMenuItem<String>(
                    value: 'settings',
                    child: Text('Settings'),
                  ),
                  const PopupMenuItem<String>(
                    value: 'logout',
                    child: Text('Logout'),
                  ),
                ],
                onSelected: (value) {
                  if (value == 'settings') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SettingsPage(),
                      ),
                    );
                  } else if (value == 'logout') {
                    _authService.signOut();
                  }
                },
              ),
            ],
          ),
        ),
      ),
      body: _buildUserList(),
    );
  }

  Widget _buildUserList() {
    return StreamBuilder(
      stream: _chatService.getUserStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text("Error");
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Text("Loading..");
        }

        return ListView(
          children: snapshot.data!
              .map<Widget>((userData) => _buildUserListItem(userData, context))
              .toList(),
        );
      },
    );
  }

  Widget _buildUserListItem(Map<String, dynamic> userData, BuildContext context) {
  if (userData["email"] != _authService.getCurrentUser()!.email) {
    return UserTile(
      text: userData["username"] ?? userData["email"], // 🔥 show username if exists
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatPage(
              receiverEmail: userData["email"],
              receiverID: userData["uid"],  // <-- FIXED here
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
