import 'package:chatapplication/services/auth/auth_service.dart';
import 'package:chatapplication/themes/theme_provider.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _appLockEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadAppLockStatus();
  }

  Future<void> _loadAppLockStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _appLockEnabled = prefs.getBool('appLockEnabled') ?? false;
    });
  }

  Future<void> _toggleAppLock(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('appLockEnabled', value);
    setState(() {
      _appLockEnabled = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    // get access to the theme provider and color scheme
    final themeProvider = Provider.of<ThemeProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;

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
                  activeColor: colorScheme.secondary,
                ),
              ),
            ),
            const SizedBox(height: 10),

            // a styled container for the app lock setting
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
                  Icons.fingerprint,
                  // use the onsurface color from the theme for icons/text
                  color: colorScheme.onSurface,
                ),
                // title of the setting
                title: Text(
                  "App Lock",
                  style: TextStyle(
                    // use the onsurface color from the theme
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
                // the switch is the trailing widget
                trailing: CupertinoSwitch(
                  value: _appLockEnabled,
                  onChanged: _toggleAppLock,
                  // use the primary theme color for the active switch
                  activeColor: colorScheme.secondary,
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
                onTap: () {
                  // call sign out method from auth service
                  final authService = AuthService();
                  authService.signOut();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}