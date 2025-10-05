import 'package:chatapplication/services/auth/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SecuritySettingsPage extends StatefulWidget {
  const SecuritySettingsPage({super.key});

  @override
  State<SecuritySettingsPage> createState() => _SecuritySettingsPageState();
}

class _SecuritySettingsPageState extends State<SecuritySettingsPage> {
  String? _publicKey;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPublicKey();
  }

  // fix: load public key from firestore, not from the local private key.
  Future<void> _loadPublicKey() async {
    try {
      final authService = AuthService();
      final user = authService.getCurrentUser();
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('Users')
            .doc(user.uid)
            .get();
        if (userDoc.exists && userDoc.data()!.containsKey('publicKey')) {
          setState(() {
            _publicKey = userDoc.data()!['publicKey'];
          });
        } else {
          setState(() {
            _error = "Could not find public key in your user profile.";
          });
        }
      }
    } catch (e) {
      setState(() {
        _error = "Failed to load public key: $e";
      });
      print("Error loading public key: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "your public key",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "This key is shared with others so they can send you encrypted messages. your private key never leaves this device.",
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            _buildKeyDisplay(),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyDisplay() {
    if (_publicKey != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: SelectableText(
                _publicKey!,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _publicKey!));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Public key copied')),
                );
              },
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Text("error: $_error", style: const TextStyle(color: Colors.red));
    }

    return const Center(child: CircularProgressIndicator());
  }
}