import 'package:flutter/material.dart';
import '../components/my_popup.dart';
import '../components/navbar.dart';
import '../components/user_tile.dart';
import '../pages/settings_page.dart';
import '../services/auth/auth_service.dart';
import '../services/auth/chat/chat_service.dart';
import 'chat_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // services
  final ChatService _chatService = ChatService();
  final AuthService _authService = AuthService();

  // index for the navbar
  int _selectedIndex = 0;

  // function to handle navbar tap
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // list of pages to show
  List<Widget> get _pages => [
    // chats page (index 0)
    _buildUserList(),
    // settings page (index 1)
    const SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectedIndex == 0 ? "Chats" : "Settings",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: _selectedIndex == 0
            ? [
          CustomPopupMenu(
            menuItems: const [
              PopupMenuItem<String>(
                value: 'logout',
                child: Text('Logout'),
              ),
            ],
            onSelected: (value) {
              if (value == 'logout') {
                _authService.signOut();
              }
            },
          ),
        ]
            : null,
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: Navbar(
        currentIndex: _selectedIndex,
        onTabTapped: _onItemTapped,
      ),
    );
  }

  // user list method with improved empty state
  Widget _buildUserList() {
    return StreamBuilder(
      stream: _chatService.getUserStream(),
      builder: (context, snapshot) {
        // error state
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  color: Theme.of(context).colorScheme.error,
                  size: 48,
                ),
                const SizedBox(height: 8),
                const Text("Something went wrong."),
              ],
            ),
          );
        }

        // loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        // filter out the current user from the list
        final currentUser = _authService.getCurrentUser();
        final users = snapshot.data!
            .where((userData) => userData['email'] != currentUser!.email)
            .toList();

        // improved empty state
        if (users.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.people_outline,
                  size: 60,
                  color: Colors.grey.shade500,
                ),
                const SizedBox(height: 16),
                Text(
                  "No one to chat with yet",
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                ),
              ],
            ),
          );
        }

        // use listview.separated to show a divider between items
        return ListView.separated(
          itemCount: users.length,
          itemBuilder: (context, index) {
            return _buildUserListItem(users[index], context);
          },
          // this builds a theme-aware separator
          separatorBuilder: (context, index) => Divider(
            color: Theme.of(context).dividerColor,
            thickness: 0.3,
          ),
        );
      },
    );
  }

  // this widget now only builds the tile
  Widget _buildUserListItem(
      Map<String, dynamic> userData, BuildContext context) {
    return UserTile(
      text: userData["username"] ?? userData["email"],
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatPage(
              receiverEmail: userData["email"],
              receiverID: userData["uid"],
            ),
          ),
        );
      },
    );
  }
}