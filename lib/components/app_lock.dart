import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

final Logger logger = Logger();

class AppLock extends StatefulWidget {
  final Widget child;
  const AppLock({required this.child, super.key});

  @override
  State<AppLock> createState() => _AppLockState();
}

class _AppLockState extends State<AppLock> {
  bool _unlocked = false;
  bool _appLockEnabled = false;

  @override
  void initState() {
    super.initState();
    _checkAppLockStatus();
  }

  Future<void> _checkAppLockStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _appLockEnabled = prefs.getBool('appLockEnabled') ?? false;
    });

    if (_appLockEnabled) {
      _authenticate();
    } else {
      setState(() {
        _unlocked = true;
      });
    }
  }

  Future<void> _authenticate() async {
    final auth = LocalAuthentication();
    bool didAuthenticate = false;
    try {
      bool canCheck =
          await auth.canCheckBiometrics || await auth.isDeviceSupported();
      if (canCheck) {
        didAuthenticate = await auth.authenticate(
          localizedReason: 'Please authenticate to access your chats',
          options: const AuthenticationOptions(biometricOnly: false),
        );
      } else {
        // if no biometrics, we can't lock the app
        didAuthenticate = true;
      }
    } catch (e) {
      logger.d('Authentication error: $e');
      // if there's an error, we should not unlock the app
      didAuthenticate = false;
    }
    setState(() {
      _unlocked = didAuthenticate;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_unlocked) {
      return widget.child;
    }
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Locked. Please authenticate.'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _authenticate,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}