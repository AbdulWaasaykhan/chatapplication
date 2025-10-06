import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:chatapplication/themes/theme_provider.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    // get access to the theme provider and color scheme
    final themeProvider = Provider.of<ThemeProvider>(context);
    final colorScheme = Theme
        .of(context)
        .colorScheme;

    return Scaffold(
      // scaffold background is now handled by the theme
      body: Padding(
        // add some padding around the main column
        padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 16),
        child: Column(
          children: [
            // a styled container for the dark mode setting
            Container(
              padding:
              const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
              decoration: BoxDecoration(
                // use the surface color from the theme
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                // remove the default padding of listtile
                contentPadding: EdgeInsets.zero,
                // leading icon for the setting
                leading: Icon(
                  Icons.dark_mode_outlined,
                  // use the onsurface color from the theme for icons/text
                  color: colorScheme.onSurface,
                ),
                // title of the setting
                title: Text(
                  "Dark Mode",
                  style: TextStyle(
                    // use the onsurface color from the theme
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
                // the switch is the trailing widget
                trailing: CupertinoSwitch(
                  value: themeProvider.isDarkMode,
                  onChanged: (value) => themeProvider.toggleTheme(),
                  // use the primary theme color for the active switch
                  activeColor: colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 10),

            // logout button
            Container(
              padding:
              const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.logout,
                  color: colorScheme.onSurface,
                ),
                title: Text(
                  "Logout",
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
                // *** FIX IS HERE: Call the new _logout function ***
                onTap: () => _logout(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
