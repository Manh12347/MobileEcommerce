import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/login_response.dart';

class AuthStorage {
  static const _keySession = 'auth_session';

  static Future<void> saveSession(LoginResponse response) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _keySession,
      jsonEncode({
        'accountId': response.accountId,
        'email': response.email,
        'role': response.role,
        'accessToken': response.accessToken,
        'refreshToken': response.refreshToken,
      }),
    );
  }

  static Future<LoginResponse?> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keySession);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final map = jsonDecode(raw);
      if (map is! Map<String, dynamic>) {
        return null;
      }
      return LoginResponse.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySession);
  }
}
