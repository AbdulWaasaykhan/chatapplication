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
        return menuItems.map((PopupMenuEntry<String> item) {
          // check if the item is a PopupMenuItem to access its child
          if (item is PopupMenuItem<String>) {
            return PopupMenuItem<String>(
              value: item.value,
              child: Padding(
                // adjust the padding to your liking
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                child: item.child,
              ),
            );
          }
          // return other menu entry types as is (e.g., PopupMenuDivider)
          return item;
        }).toList();
      },
    );
  }
}