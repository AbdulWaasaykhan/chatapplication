import 'package:chatapplication/themes/theme_provider.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text("Settings"),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.grey,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondary,
        ),
        margin: const EdgeInsets.all(0),
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            // Dark Mode
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Dark Mode"),
                CupertinoSwitch(
                  value: themeProvider.isDarkMode,
                  onChanged: (value) => themeProvider.toggleTheme(),
                ),
              ],
            ),
            const SizedBox(height: 20),

          ],
        ),
      ),
    );
  }
}
