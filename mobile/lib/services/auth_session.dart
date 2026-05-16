import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

class AuthSession {
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'auth_user';
  static final ValueNotifier<int> authVersion = ValueNotifier<int>(0);

  static String _token = '';
  static AuthUser? _currentUser;

  static String get token => _token;
  static AuthUser? get currentUser => _currentUser;
  static bool get isLoggedIn => _token.isNotEmpty && _currentUser != null;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey) ?? '';
    final rawUser = prefs.getString(_userKey);
    if (rawUser == null || rawUser.isEmpty) return;

    try {
      _currentUser = AuthUser.fromJson(
        jsonDecode(rawUser) as Map<String, dynamic>,
      );
    } catch (_) {
      _currentUser = null;
    }
  }

  static Future<void> save({
    required String token,
    required AuthUser user,
  }) async {
    _token = token;
    _currentUser = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
    authVersion.value++;
  }

  static Future<void> updateUser(AuthUser user) async {
    _currentUser = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
    authVersion.value++;
  }

  static Future<void> clear() async {
    _token = '';
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
    authVersion.value++;
  }
}
