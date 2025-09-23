import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:logger/logger.dart';

final Logger logger = Logger();

class AppLock extends StatefulWidget {
  final Widget child;
  const AppLock({required this.child, super.key});

  @override
  State<AppLock> createState() => _AppLockState();
}

class _AppLockState extends State<AppLock> {
  bool _unlocked = false;

  @override
  void initState() {
    super.initState();
    _authenticate();
  }

  Future<void> _authenticate() async {
    final auth = LocalAuthentication();
    bool didAuthenticate = false;
    try {
      bool canCheck = await auth.canCheckBiometrics || await auth.isDeviceSupported();
      if (canCheck) {
        didAuthenticate = await auth.authenticate(
          localizedReason: 'Please authenticate to access your chats',
          options: const AuthenticationOptions(biometricOnly: false),
        );
      } else {
        didAuthenticate = true;
      }
    } catch (e) {
      logger.d('Authentication error: $e');
      didAuthenticate = true;
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
    return const Scaffold(
      body: Center(child: Text('Locked. Please authenticate.')),
    );
  }
}