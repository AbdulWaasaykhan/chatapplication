import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fast_rsa/fast_rsa.dart';
import '../services/storage_service.dart';
import '../services/auth/chat/encryption_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final StorageService _storage = StorageService();
  final EncryptionService _enc = EncryptionService();
  String publicKey = '';
  String privateKey = '';

  @override
  void initState() {
    super.initState();
    _loadKeys();
  }

  // ✅ Auto-generate keys if missing
  Future<void> _loadKeys() async {
    final pub = await _storage.getKey('public_key');
    final priv = await _storage.getKey('private_key');
    if (pub == null || priv == null || pub == 'Not Found' || priv == 'Not Found') {
      final user = FirebaseAuth.instance.currentUser!;
      await _enc.generateKeyPairIfNeededAndUpload(uid: user.uid, email: user.email);
    }

    final newPub = await _storage.getKey('public_key') ?? 'Not Found';
    final newPriv = await _storage.getKey('private_key') ?? 'Not Found';
    setState(() {
      publicKey = newPub;
      privateKey = newPriv;
    });
  }

  Future<void> _copyKey() async {
    await Clipboard.setData(ClipboardData(text: privateKey));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Private key copied to clipboard')),
    );
  }

  Future<void> _deleteKey() async {
    final user = FirebaseAuth.instance.currentUser!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Confirm delete'),
        content: const Text(
          'This will delete your private key locally and remove your chat rooms from the server. Are you sure?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) {
      await _enc.deleteKeysAndChats(user.uid);
      await _loadKeys();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Keys and chats deleted')),
      );
    }
  }

  Future<void> _pasteKey() async {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Paste your private key'),
        content: TextField(
          controller: controller,
          maxLines: 6,
          decoration: const InputDecoration(hintText: 'Paste private key PEM here'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final pasted = controller.text.trim();
              if (pasted.isEmpty) return;
              // validate pasted key
              final storedPub = await _storage.getKey('public_key');
              bool ok = true;
              if (storedPub != null && storedPub.isNotEmpty && storedPub != 'Not Found') {
                try {
                  final rsa = RSA;
                  final sig = await (rsa as dynamic).sign('test', pasted);
                  final verify = await (rsa as dynamic).verify('test', sig, storedPub);
                  ok = verify == true;
                } catch (e) {
                  ok = false;
                }
              }
              if (!ok) {
                showDialog(
                  context: context,
                  builder: (d) => AlertDialog(
                    title: const Text('Invalid key'),
                    content: const Text(
                      'The pasted key did not match your stored public key or is invalid.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(d),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
                return;
              }
              await _storage.saveKey('private_key', pasted);
              await _loadKeys();
              Navigator.pop(c);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Private key restored.')),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _generateNewKey() async {
    final user = FirebaseAuth.instance.currentUser!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Generate new key'),
        content: const Text('Generating a new key will delete your old chats. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Generate')),
        ],
      ),
    );
    if (confirmed == true) {
      await _enc.deleteKeysAndChats(user.uid);
      await _enc.generateKeyPairIfNeededAndUpload(uid: user.uid, email: user.email);
      await _loadKeys();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New key pair generated')),
      );
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    // Accessing theme for consistent styling
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: ListView(
        // Use slightly larger padding for a less cramped look
        padding: const EdgeInsets.all(16.0),
        children: [
          // --- Section 1: Public Key ---
          Text(
            'Encryption Keys',
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 2,
            clipBehavior: Clip.antiAlias, // Ensures content respects rounded corners
            child: ListTile(

              title: const Text('Public Key'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  const Text('This is your shareable key, visible to others.'),
                  const SizedBox(height: 8),
                  SelectableText(
                    publicKey,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ],
              ),
              trailing: IconButton(
                icon: const Icon(Icons.copy_outlined),
                tooltip: 'Copy Public Key',
                onPressed: _copyKey,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // --- Section 2: Private Key ---
          Card(
            elevation: 2,
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              title: const Text('Private Key'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  const Text('Keep this key safe and do not share it.'),
                  const SizedBox(height: 8),
                  SelectableText(
                    privateKey,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ],
              ),
              trailing: IconButton(
                icon: const Icon(Icons.copy_outlined),
                tooltip: 'Copy Private Key',
                onPressed: _copyKey,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // --- Section 3: Key Management Actions ---
          Text(
            'Key Management',
            style: textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          // A Row of modern, filled tonal buttons for primary actions
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: _generateNewKey,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Generate New'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: _pasteKey,
                  icon: const Icon(Icons.content_paste_go_outlined),
                  label: const Text('Restore'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // --- Section 4: Destructive & Account Actions ---
          // Using ListTiles in a Card for these actions is a common pattern in settings screens
          Card(
            color: Theme.of(context).colorScheme.error,
            child: ListTile(
              leading: Icon(Icons.delete_forever_outlined, color: colorScheme.onPrimary),
              title: Text(
                'Delete Keys',
                style: TextStyle(color: colorScheme.onErrorContainer, fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                'This action cannot be undone.',
                style: TextStyle(color: colorScheme.onErrorContainer),
              ),
              onTap: _deleteKey,
            ),
          ),
        ],
      ),
    );
  }
}

