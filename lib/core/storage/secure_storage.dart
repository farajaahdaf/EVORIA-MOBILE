import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_constants.dart';

final secureStorageProvider = Provider<SecureStorage>((ref) => SecureStorage());

class SecureStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<void> saveToken(String token) =>
      _storage.write(key: AppConstants.tokenKey, value: token);

  Future<String?> getToken() =>
      _storage.read(key: AppConstants.tokenKey);

  Future<void> deleteToken() =>
      _storage.delete(key: AppConstants.tokenKey);

  Future<void> saveUser(String userJson) =>
      _storage.write(key: AppConstants.userKey, value: userJson);

  Future<String?> getUser() =>
      _storage.read(key: AppConstants.userKey);

  Future<void> deleteUser() =>
      _storage.delete(key: AppConstants.userKey);

  Future<void> clearAll() => _storage.deleteAll();
}
