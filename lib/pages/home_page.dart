import 'package:flutter/material.dart';
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
  final TextEditingController _searchController = TextEditingController();

  // state
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;
  int _selectedIndex = 0; // index for the navbar
  bool _isSearching = false; // to toggle search bar in appbar

  // dispose controller
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // function to handle navbar tap
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // list of pages to show
  List<Widget> get _pages => [
    // chats page (index 0)
    _buildChatsPage(),
    // settings page (index 1)
    const SettingsPage(),
  ];

  void _searchUsers(String query) async {
    // only search if the query is not empty
    if (query.trim().isNotEmpty) {
      setState(() {
        _isLoading = true;
      });
      final results = await _chatService.searchUsers(query);
      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    } else {
      // clear results if query is empty
      setState(() {
        _searchResults = [];
      });
    }
  }

  void _startSearch() {
    setState(() {
      _isSearching = true;
    });
  }

  void _stopSearch() {
    setState(() {
      _isSearching = false;
      _searchController.clear();
      _searchResults = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    // use willpopscope to override the back button when searching
    return WillPopScope(
      onWillPop: () async {
        if (_isSearching) {
          _stopSearch();
          return false; // prevent app from closing
        }
        return true; // allow app to close
      },
      child: Scaffold(
        appBar: _buildAppBar(),
        body: _pages[_selectedIndex],
        bottomNavigationBar: Navbar(
          currentIndex: _selectedIndex,
          onTabTapped: _onItemTapped,
        ),
      ),
    );
  }

  // build the appbar based on the selected index and search state
  AppBar _buildAppBar() {
    // settings page appbar
    if (_selectedIndex == 1) {
      return AppBar(
        title: const Text(
          "Settings",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      );
    }

    // chats page appbar (with search logic)
    if (_isSearching) {
      // search appbar
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _stopSearch,
        ),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Search for users by email...',
            // updated border and padding
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            filled: true,
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          ),
          onSubmitted: _searchUsers,
        ),
      );
    } else {
      // normal appbar
      return AppBar(
        title: const Text(
          "Chats",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _startSearch,
          ),
        ],
      );
    }
  }

  // build the main content for the chats page
  Widget _buildChatsPage() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // prompt user to search if the search bar is not active
    if (_searchController.text.isEmpty && !_isSearching) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(25.0),
          child: Text(
            "Tap the search icon 🔎 to find and chat with other users.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
        ),
      );
    }

    // show message if no users are found
    if (_searchResults.isEmpty && _searchController.text.isNotEmpty) {
      return const Center(
        child: Text("No users found."),
      );
    }

    // display search results
    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        return _buildUserListItem(_searchResults[index], context);
      },
    );
  }

  // build a single user list item
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