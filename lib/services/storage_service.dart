import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<void> saveKey(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  Future<String?> getKey(String key) async {
    return await _storage.read(key: key);
  }

  Future<void> deleteKey(String key) async {
    await _storage.delete(key: key);
  }

  Future<void> deleteAll() async {
    await _storage.deleteAll();
  }
}
