import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/dio_client.dart';
import '../core/storage/secure_storage.dart';
import '../models/user_model.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(dioClientProvider),
    ref.watch(secureStorageProvider),
  );
});

class AuthRepository {
  final DioClient _client;
  final SecureStorage _storage;

  AuthRepository(this._client, this._storage);

  Future<UserModel> login(String email, String password) async {
    try {
      final res = await _client.dio.post('/auth/login', data: {
        'email': email,
        'password': password,
      });
      final token = res.data['access_token'] as String;
      final user = UserModel.fromJson(res.data['user'] as Map<String, dynamic>);
      await _storage.saveToken(token);
      await _storage.saveUser(jsonEncode(user.toJson()));
      return user;
    } on Exception catch (e) {
      throw _wrap(e);
    }
  }

  Future<UserModel> register(String name, String email, String password) async {
    try {
      final res = await _client.dio.post('/auth/register', data: {
        'name': name,
        'email': email,
        'password': password,
      });
      final token = res.data['access_token'] as String;
      final user = UserModel.fromJson(res.data['user'] as Map<String, dynamic>);
      await _storage.saveToken(token);
      await _storage.saveUser(jsonEncode(user.toJson()));
      return user;
    } on Exception catch (e) {
      throw _wrap(e);
    }
  }

  Future<void> logout() async {
    try {
      await _client.dio.post('/auth/logout');
    } catch (_) {}
    await _storage.clearAll();
  }

  Future<UserModel?> getProfile() async {
    try {
      final res = await _client.dio.get('/profile');
      return UserModel.fromJson(res.data['user'] as Map<String, dynamic>);
    } on Exception catch (e) {
      throw _wrap(e);
    }
  }

  /// Update profile info (name, email) + optional photo upload/removal.
  /// Sent as multipart/form-data so the optional photo file rides along.
  Future<UserModel> updateProfile({
    required String name,
    required String email,
    String? photoPath,
    bool removePhoto = false,
  }) async {
    try {
      final form = FormData.fromMap({
        'name': name,
        'email': email.toLowerCase(),
        if (removePhoto) 'remove_profile_photo': '1',
        if (photoPath != null)
          'profile_photo': await MultipartFile.fromFile(photoPath),
      });

      // DioClient sets a default `Content-Type: application/json`; override it
      // here (with the FormData boundary) so the multipart body is parsed.
      final res = await _client.dio.post(
        '/profile',
        data: form,
        options: Options(
          contentType: 'multipart/form-data; boundary=${form.boundary}',
        ),
      );
      final user = UserModel.fromJson(res.data['user'] as Map<String, dynamic>);
      await _storage.saveUser(jsonEncode(user.toJson()));
      return user;
    } on Exception catch (e) {
      throw _wrap(e);
    }
  }

  /// Change the account password.
  Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    try {
      await _client.dio.put('/profile/password', data: {
        'current_password': currentPassword,
        'password': newPassword,
        'password_confirmation': confirmPassword,
      });
    } on Exception catch (e) {
      throw _wrap(e);
    }
  }

  /// Permanently delete the account (requires password confirmation).
  /// Clears local auth only after the server confirms deletion.
  Future<void> deleteAccount({required String password}) async {
    try {
      await _client.dio.delete('/profile', data: {'password': password});
      await _storage.clearAll();
    } on Exception catch (e) {
      throw _wrap(e);
    }
  }

  Future<UserModel?> getCachedUser() async {
    final json = await _storage.getUser();
    if (json == null) return null;
    return UserModel.fromJson(jsonDecode(json) as Map<String, dynamic>);
  }

  Future<bool> isLoggedIn() async {
    final token = await _storage.getToken();
    return token != null;
  }

  Exception _wrap(Object e) {
    if (e is DioException) return ApiException.fromDioError(e);
    if (e is Exception) return e;
    return Exception(e.toString());
  }
}
