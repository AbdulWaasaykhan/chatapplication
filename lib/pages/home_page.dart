import 'package:chatapplication/models/user_model.dart';
import 'package:chatapplication/services/auth/chat/chat_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../components/user_tile.dart';
import '../pages/settings_page.dart';
import '../services/auth/auth_service.dart';
import 'chat_page.dart';
import 'profile_page.dart';
import 'package:timeago/timeago.dart' as timeago;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // services
  final ChatService _chatService = ChatService();
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();

  // state
  List<UserModel> _searchResults = [];
  bool _isLoading = false;
  int _selectedIndex = 0;
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  List<Widget> get _pages => [
    _buildChatsPage(),
    const SettingsPage(),
    const ProfilePage(),
  ];

  void _searchUsers(String query) async {
    if (query.trim().isNotEmpty) {
      setState(() => _isLoading = true);
      final results = await _chatService.searchUsers(query);
      setState(() {
        _searchResults = results
            .where((user) => user.uid != _authService.getCurrentUser()!.uid)
            .toList();
        _isLoading = false;
      });
    } else {
      setState(() => _searchResults = []);
    }
  }

  void _startSearch() => setState(() => _isSearching = true);

  void _stopSearch() {
    setState(() {
      _isSearching = false;
      _searchController.clear();
      _searchResults = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_isSearching) {
          _stopSearch();
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: _buildAppBar(),
        body: _isSearching
            ? _buildSearchPage()
            : IndexedStack(
          index: _selectedIndex,
          children: _pages,
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline),
              label: 'Chats',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outlined),
              label: 'Profile',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar() {
    if (_selectedIndex == 1) return AppBar(title: const Text("Profile"));
    if (_selectedIndex == 2) return AppBar(title: const Text("Settings"));

    if (_isSearching) {
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _stopSearch,
        ),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search for users by username...',
            border: InputBorder.none,
          ),
          onChanged: _searchUsers,
        ),
      );
    } else {
      return AppBar(
        title: const Text("Chats"),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: _startSearch),
        ],
      );
    }
  }

  Widget _buildSearchPage() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_searchResults.isEmpty && _searchController.text.isNotEmpty) {
      return const Center(child: Text("No users found."));
    }
    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        return _buildUserListItem(_searchResults[index], context);
      },
    );
  }

  Widget _buildChatsPage() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _chatService.getChatRoomsStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text("Something went wrong."));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data == null || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(25.0),
              child: Text(
                "No chats yet. Tap the search icon to start a conversation.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            ),
          );
        }

        final chatDocs = snapshot.data!.docs;

        return ListView.builder(
          itemCount: chatDocs.length,
          itemBuilder: (context, index) {
            return _buildChatListItem(chatDocs[index]);
          },
        );
      },
    );
  }

  Widget _buildChatListItem(DocumentSnapshot<Map<String, dynamic>> chatDoc) {
    final chatData = chatDoc.data()!;
    final participants = chatData['participants'] as List<dynamic>;
    final otherUserID = participants
        .firstWhere((id) => id != _authService.getCurrentUser()!.uid);
    final lastMessage = chatData['last_message'] ?? '';
    final timestamp = (chatData['last_message_timestamp'] as Timestamp?)?.toDate();

    return FutureBuilder<UserModel?>(
      future: _chatService.getUserData(otherUserID),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) {
          return const ListTile(title: Text("Loading chat..."));
        }

        final otherUser = userSnapshot.data!;

        return Dismissible(
          key: Key(chatDoc.id),
          direction: DismissDirection.endToStart,
          onDismissed: (direction) {
            _chatService.softDeleteChat(chatDoc.id);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("${otherUser.username} chat deleted")),
            );
          },
          background: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          child: ListTile(
            leading: CircleAvatar(
              radius: 24,
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              child: const Icon(Icons.person, size: 28),
            ),
            title: Text(
              otherUser.username,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              lastMessage,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Text(
              timestamp != null ? timeago.format(timestamp) : '',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatPage(
                    receiverEmail: otherUser.email,
                    receiverID: otherUser.uid,
                    receiverUsername: otherUser.username,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildUserListItem(UserModel userData, BuildContext context) {
    return UserTile(
      text: userData.username,
      onTap: () {
        _stopSearch();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatPage(
              receiverEmail: userData.email,
              receiverID: userData.uid,
              receiverUsername: userData.username,
            ),
          ),
        );
      },
    );
  }
}