import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageKeys {
  const StorageKeys._();

  static const String token = 'auth_token';
  static const String user = 'user_profile';
  static const String rememberMe = 'remember_me';
}

class StorageService {
  StorageService({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _secureStorage;

  Future<void> persistSession({
    required String token,
    required Map<String, dynamic> user,
    bool rememberUser = false,
  }) async {
    await _secureStorage.write(key: StorageKeys.token, value: token);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(StorageKeys.user, jsonEncode(user));
    await prefs.setBool(StorageKeys.rememberMe, rememberUser);
  }

  Future<void> clearSession() async {
    await _secureStorage.delete(key: StorageKeys.token);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(StorageKeys.user);
    await prefs.remove(StorageKeys.rememberMe);
  }

  Future<String?> readToken() async {
    return _secureStorage.read(key: StorageKeys.token);
  }

  Future<Map<String, dynamic>?> readUser() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(StorageKeys.user);
    if (data == null) {
      return null;
    }
    try {
      return jsonDecode(data) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<bool> readRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(StorageKeys.rememberMe) ?? false;
  }
}
