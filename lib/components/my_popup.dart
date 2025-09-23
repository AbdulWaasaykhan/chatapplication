import 'package:flutter/material.dart';

class CustomPopupMenu extends StatelessWidget {
  final List<PopupMenuEntry<String>> menuItems;
  final ValueChanged<String> onSelected;

  const CustomPopupMenu({
    super.key,
    required this.menuItems,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: onSelected,
      itemBuilder: (BuildContext context) {
        return menuItems;
      },
    );
  }
}
