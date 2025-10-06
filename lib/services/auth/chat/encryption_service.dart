import 'dart:convert';
import 'dart:typed_data';
import 'package:fast_rsa/fast_rsa.dart';
import '../../storage_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../utils/crypto_utils.dart';

class MessageEnvelope {
  final String encryptedPayload;
  final String encryptedKey;
  final String iv;
  final String algorithm;
  final String? signature;

  MessageEnvelope({
    required this.encryptedPayload,
    required this.encryptedKey,
    required this.iv,
    required this.algorithm,
    this.signature,
  });

  Map<String, dynamic> toJson() => {
        'encrypted_payload': encryptedPayload,
        'encrypted_key': encryptedKey,
        'iv': iv,
        'algo': algorithm,
        if (signature != null) 'signature': signature,
      };

  factory MessageEnvelope.fromJson(Map<String, dynamic> json) {
    return MessageEnvelope(
      encryptedPayload: json['encrypted_payload'],
      encryptedKey: json['encrypted_key'],
      iv: json['iv'],
      algorithm: json['algo'],
      signature: json['signature'],
    );
  }
}

class EncryptionService {
  final StorageService _storage = StorageService();

  static const _privateKeyKey = 'private_key';
  static const _publicKeyKey = 'public_key';

  Future<void> generateKeyPairIfNeededAndUpload({required String uid, String? email}) async {
    final existing = await _storage.getKey(_privateKeyKey);
    if (existing != null) return;

    final keyPair = await RSA.generate(2048);
    await _storage.saveKey(_privateKeyKey, keyPair.privateKey);
    await _storage.saveKey(_publicKeyKey, keyPair.publicKey);

    await FirebaseFirestore.instance.collection('Users').doc(uid).set({
      'publicKey': keyPair.publicKey,
      if (email != null) 'email': email,
    }, SetOptions(merge: true));
  }

  Future<String?> getPublicKey() async => await _storage.getKey(_publicKeyKey);
  Future<String?> getPrivateKey() async => await _storage.getKey(_privateKeyKey);

  Future<void> deleteKeys() async {
    await _storage.deleteKey(_privateKeyKey);
    await _storage.deleteKey(_publicKeyKey);
  }

  // Delete keys locally and remove all chat rooms/messages for this user from Firestore
  Future<void> deleteKeysAndChats(String uid) async {
    // delete local keys
    await _storage.deleteKey(_privateKeyKey);
    await _storage.deleteKey(_publicKeyKey);

    // find all chat_rooms where user participates
    final rooms = await FirebaseFirestore.instance
        .collection('chat_rooms')
        .where('participants', arrayContains: uid)
        .get();

    for (var doc in rooms.docs) {
      // delete messages in subcollection
      final msgs = await FirebaseFirestore.instance
          .collection('chat_rooms')
          .doc(doc.id)
          .collection('messages')
          .get();
      for (var m in msgs.docs) {
        await m.reference.delete();
      }
      // delete the chat room doc
      await FirebaseFirestore.instance.collection('chat_rooms').doc(doc.id).delete();
    }
  }

  Future<MessageEnvelope> encryptForRecipient(String plaintext, String recipientPublicPem) async {
    final aesKey = CryptoUtils.generateAESKey();
    final iv = CryptoUtils.generateIV();
    final plaintextBytes = Uint8List.fromList(utf8.encode(plaintext));
    final cipherText = CryptoUtils.aesGcmEncrypt(aesKey, iv, plaintextBytes);
    final aesKeyBase64 = base64Encode(aesKey);

    final rsa = RSA;
    final encryptedSymKey = await (rsa as dynamic).encrypt(aesKeyBase64, recipientPublicPem);

    return MessageEnvelope(
      encryptedPayload: base64Encode(cipherText),
      encryptedKey: encryptedSymKey,
      iv: base64Encode(iv),
      algorithm: 'AES-GCM+RSA-2048',
    );
  }

  Future<String> decryptEnvelope(MessageEnvelope envelope) async {
    final priv = await getPrivateKey();
    if (priv == null) throw Exception('Private key missing');

    final rsa = RSA;
    final decryptedBase64 = await (rsa as dynamic).decrypt(envelope.encryptedKey, priv);
    final aesKeyBytes = base64Decode(decryptedBase64);

    final iv = base64Decode(envelope.iv);
    final ciphertext = base64Decode(envelope.encryptedPayload);

    final plaintextBytes = CryptoUtils.aesGcmDecrypt(aesKeyBytes, iv, ciphertext);
    return utf8.decode(plaintextBytes);
  }
}
