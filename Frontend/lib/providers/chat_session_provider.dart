import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_message.dart';

class ChatSessionProvider extends ChangeNotifier {
  static const _SESSION_TIMEOUT = Duration(hours: 1);
  static const _prefKeyStartTime = 'chat_session_start_ms';
  static const _prefKeyMessages = 'chat_session_messages';
  static const _prefKeySessionId = 'chat_session_id';

  final List<ChatMessageVM> _messages = [];
  String _sessionId = '';
  DateTime _sessionStartTime = DateTime.now();
  Timer? _sessionTimer;
  bool _initialized = false;

  List<ChatMessageVM> get messages => List.unmodifiable(_messages);
  String get sessionId => _sessionId;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    final prefs = await SharedPreferences.getInstance();
    final savedStartMs = prefs.getInt(_prefKeyStartTime);

    if (savedStartMs != null) {
      _sessionStartTime = DateTime.fromMillisecondsSinceEpoch(savedStartMs);
      final elapsed = DateTime.now().difference(_sessionStartTime);

      if (elapsed < _SESSION_TIMEOUT) {
        _sessionId = prefs.getString(_prefKeySessionId) ??
            DateTime.now().millisecondsSinceEpoch.toString();

        final savedMessages = prefs.getString(_prefKeyMessages);
        if (savedMessages != null && savedMessages.isNotEmpty) {
          try {
            final decoded = jsonDecode(savedMessages) as List<dynamic>;
            _messages.clear();
            for (final m in decoded) {
              final map = m as Map<String, dynamic>;
              _messages.add(ChatMessageVM(
                role: map['role'] as String,
                text: map['text'] as String,
                decisionAction: map['decisionAction'] as String?,
              ));
            }
          } catch (_) {
            _messages.clear();
          }
        }
        if (_messages.isEmpty) {
          _messages.add(_welcomeMsg());
        }

        // Restart timer with remaining duration
        final remaining = _SESSION_TIMEOUT - elapsed;
        _sessionTimer = Timer(remaining, _onExpired);
      } else {
        // Session expired
        await _clearSessionData(prefs);
        _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
        _messages.add(_welcomeMsg());
        _sessionStartTime = DateTime.now();
        await _saveSessionData(prefs);
        _sessionTimer = Timer(_SESSION_TIMEOUT, _onExpired);
      }
    } else {
      _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
      _messages.add(_welcomeMsg());
      _sessionStartTime = DateTime.now();
      await _saveSessionData(prefs);
      _sessionTimer = Timer(_SESSION_TIMEOUT, _onExpired);
    }

    notifyListeners();
  }

  ChatMessageVM _welcomeMsg() => ChatMessageVM(
        role: 'assistant',
        text:
            'Xin chào! Mình là trợ lý ảo của TechShop. Bạn cần mình tư vấn sản phẩm công nghệ gì không?',
      );

  void addUserMessage(String text) {
    _messages.add(ChatMessageVM(role: 'user', text: text));
    _saveMessagesLater();
    notifyListeners();
  }

  void addAssistantMessage(ChatMessageVM msg) {
    _messages.add(msg);
    _saveMessagesLater();
    notifyListeners();
  }

  void updateSessionId(String newSessionId) {
    _sessionId = newSessionId;
  }

  Future<void> resetSession() async {
    _sessionTimer?.cancel();
    _sessionTimer = null;
    _messages.clear();
    _sessionStartTime = DateTime.now();
    _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    _messages.add(_welcomeMsg());
    final prefs = await SharedPreferences.getInstance();
    await _clearSessionData(prefs);
    _sessionTimer = Timer(_SESSION_TIMEOUT, _onExpired);
    notifyListeners();
  }

  Future<void> clearOnLogout() async {
    _sessionTimer?.cancel();
    _sessionTimer = null;
    final prefs = await SharedPreferences.getInstance();
    await _clearSessionData(prefs);
    _messages.clear();
    notifyListeners();
  }

  void _onExpired() async {
    _sessionTimer = null;
    final prefs = await SharedPreferences.getInstance();
    await _clearSessionData(prefs);
    _messages.clear();
    _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    _messages.add(_welcomeMsg());
    _sessionStartTime = DateTime.now();
    await _saveSessionData(prefs);
    _sessionTimer = Timer(_SESSION_TIMEOUT, _onExpired);
    notifyListeners();
  }

  Future<void> _saveMessagesLater() async {
    final prefs = await SharedPreferences.getInstance();
    await _saveSessionData(prefs);
  }

  Future<void> _saveSessionData(SharedPreferences prefs) async {
    await prefs.setInt(_prefKeyStartTime, _sessionStartTime.millisecondsSinceEpoch);
    await prefs.setString(_prefKeySessionId, _sessionId);
    final msgs = _messages.map((m) {
      return {
        'role': m.role,
        'text': m.text,
        'decisionAction': m.decisionAction,
      };
    }).toList();
    await prefs.setString(_prefKeyMessages, jsonEncode(msgs));
  }

  Future<void> _clearSessionData(SharedPreferences prefs) async {
    await prefs.remove(_prefKeyStartTime);
    await prefs.remove(_prefKeySessionId);
    await prefs.remove(_prefKeyMessages);
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    super.dispose();
  }
}

