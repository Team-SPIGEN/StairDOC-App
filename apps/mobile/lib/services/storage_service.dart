import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keys used for local storage operations.
class StorageKeys {
  const StorageKeys._();

  /// Key for storing the JWT authentication token (secure storage).
  static const String token = 'auth_token';

  /// Key for storing the user profile JSON (shared preferences).
  static const String user = 'user_profile';

  /// Key for storing the "remember me" preference.
  static const String rememberMe = 'remember_me';
}

/// Service for managing local data persistence.
///
/// Uses [FlutterSecureStorage] for sensitive data (tokens) and
/// [SharedPreferences] for non-sensitive user data.
class StorageService {
  StorageService({FlutterSecureStorage? secureStorage})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _secureStorage;

  /// Persists an authenticated session to local storage.
  ///
  /// Stores the token securely and caches user data for offline access.
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

  /// Clears all session data from local storage.
  ///
  /// Called during logout to remove tokens and cached user data.
  Future<void> clearSession() async {
    await _secureStorage.delete(key: StorageKeys.token);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(StorageKeys.user);
    await prefs.remove(StorageKeys.rememberMe);
  }

  /// Retrieves the stored authentication token.
  ///
  /// Returns `null` if no token is stored.
  Future<String?> readToken() async {
    return _secureStorage.read(key: StorageKeys.token);
  }

  /// Retrieves the cached user profile data.
  ///
  /// Returns `null` if no user data is stored or if parsing fails.
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

  /// Retrieves the "remember me" preference.
  Future<bool> readRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(StorageKeys.rememberMe) ?? false;
  }
}
