import 'package:flutter/material.dart';

class Navbar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabTapped;

  const Navbar({
    super.key,
    required this.currentIndex,
    required this.onTabTapped,
  });

  @override
  Widget build(BuildContext context) {
    // get the color scheme from the current theme
    final colorScheme = Theme.of(context).colorScheme;

    return BottomNavigationBar(
      // set the background color from the theme's background
      backgroundColor: colorScheme.background,

      // set the active item color to the theme's primary color
      selectedItemColor: colorScheme.primary,

      // set the inactive item color to the theme's onSurface color with some opacity
      unselectedItemColor: colorScheme.onSurface.withOpacity(0.6),

      // set the type to fixed to ensure the background color is always shown
      type: BottomNavigationBarType.fixed,

      // this property receives the current index from the parent widget
      currentIndex: currentIndex,

      // this callback is invoked when a tap is detected
      onTap: onTabTapped,

      // defines the items in the navbar
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.chat_bubble_outline),
          activeIcon: Icon(Icons.chat_bubble),
          label: 'Chats',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.settings_outlined),
          activeIcon: Icon(Icons.settings),
          label: 'Settings',
        ),
      ],
    );
  }
}