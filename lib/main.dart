import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:chatapplication/services/auth/auth_gate.dart';
import 'package:chatapplication/firebase_options.dart';
import 'package:chatapplication/components/app_lock.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:chatapplication/themes/theme_provider.dart';
import 'package:logger/logger.dart';

final Logger logger = Logger();


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    logger.d('[DEBUG] Firebase initialized.');
  } catch (e) {
    if (e.toString().contains('duplicate-app')) {
      logger.d('[DEBUG] Firebase already initialized.');
    } else {
      logger.d('[DEBUG] Firebase init failed.');
      rethrow;
    }
  }

  // Supabase init
  await Supabase.initialize(
    url: 'https://fmlkenusgqlfzodnxyqf.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZtbGtlbnVzZ3FsZnpvZG54eXFmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTgzMTk1MzMsImV4cCI6MjA3Mzg5NTUzM30.uxh9YaMC0N2oms0H8hqXTx3rQfyCRtHU-Q3JnGo9Ya8',
  );
  logger.d('[DEBUG] Supabase initialized.');

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),

      ],
      child: const MyApp(),
    ),
  );

}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chat Application',
      debugShowCheckedModeBanner: false,
      theme: Provider.of<ThemeProvider>(context).themeData,
      builder: (context, child) {
        return BlurOnInactive(child: child!);
      },
      home: AppLock(
        child: const AuthGate(),
      ),
    );
  }
}

// ----------- Blur Wrapper -----------
class BlurOnInactive extends StatefulWidget {
  final Widget child;
  const BlurOnInactive({required this.child, super.key});

  @override
  State<BlurOnInactive> createState() => _BlurOnInactiveState();
}

class _BlurOnInactiveState extends State<BlurOnInactive>
    with WidgetsBindingObserver {
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
              child: Container(color: Colors.black.withValues(alpha: 0.2)),
            ),
          ),
      ],
    );
  }
}
