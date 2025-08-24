import 'package:chatapplication/services/auth/auth_gate.dart';
import 'package:chatapplication/firebase_options.dart';
import 'package:chatapplication/themes/theme_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import 'package:chatapplication/components/app_lock.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(
    ChangeNotifierProvider(
      create: (context) => ThemeProvider(),
      child: const Myapp(),
    ),
  );
}

  
// ...other imports...

class BlurOnInactive extends StatefulWidget {
  final Widget child;
  const BlurOnInactive({required this.child, super.key});

  @override
  State<BlurOnInactive> createState() => _BlurOnInactiveState();
}

class _BlurOnInactiveState extends State<BlurOnInactive> with WidgetsBindingObserver {
  bool _blur = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

 @override
void didChangeAppLifecycleState(AppLifecycleState state) {
  print("Lifecycle changed: $state");
  setState(() {
    _blur = state != AppLifecycleState.resumed;
  });
}


  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_blur)
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(color: Colors.black.withOpacity(0.2)),
            ),
          ),
      ],
    );
  }
}



// ...other imports...

class Myapp extends StatelessWidget {
  const Myapp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: Provider.of<ThemeProvider>(context).themeData,
      builder: (context, child) {
        return BlurOnInactive(child: child!); // <- wraps the whole widget tree
      },
      home: AppLock(
        child: const AuthGate(),
      ),
    );
  }
}

