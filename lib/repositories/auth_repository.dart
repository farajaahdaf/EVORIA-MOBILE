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
