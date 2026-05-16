import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ChatHistoryService {
  static const int _maxHistoryCount = 50;
  static const int _maxSearchHistoryCount = 10;

  final SharedPreferences _prefs;
  final String _userScope;

  ChatHistoryService(this._prefs, {required String userScope})
    : _userScope = userScope.isNotEmpty ? userScope : 'anonymous';

  static Future<ChatHistoryService> create({String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    return ChatHistoryService(prefs, userScope: userId ?? 'anonymous');
  }

  String get _historyKey => 'chat_history_$_userScope';
  String get _searchHistoryKey => 'chat_search_history_$_userScope';

  /// 保存完整对话历史
  Future<void> saveChatHistory(List<Map<String, dynamic>> messages) async {
    final trimmedMessages = messages.length > _maxHistoryCount
        ? messages.sublist(messages.length - _maxHistoryCount)
        : messages;
    final jsonList = trimmedMessages
        .map(
          (m) => {
            'content': m['content'],
            'isUser': m['isUser'],
            'time': (m['time'] as DateTime).toIso8601String(),
          },
        )
        .toList();
    await _prefs.setString(_historyKey, jsonEncode(jsonList));
  }

  /// 加载对话历史
  List<Map<String, dynamic>> loadChatHistory() {
    final jsonStr = _prefs.getString(_historyKey);
    if (jsonStr == null || jsonStr.isEmpty) return [];

    try {
      final jsonList = jsonDecode(jsonStr) as List;
      return jsonList.map((item) {
        final map = item as Map<String, dynamic>;
        return {
          'content': map['content'] as String,
          'isUser': map['isUser'] as bool,
          'time': DateTime.parse(map['time'] as String),
        };
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// 清空对话历史
  Future<void> clearChatHistory() async {
    await _prefs.remove(_historyKey);
  }

  /// 保存用户搜索历史（仅用户提问）
  Future<void> addSearchQuery(String query) async {
    if (query.trim().isEmpty) return;

    final history = loadSearchHistory();
    history.remove(query);
    history.insert(0, query);

    if (history.length > _maxSearchHistoryCount) {
      history.removeRange(_maxSearchHistoryCount, history.length);
    }

    await _prefs.setStringList(_searchHistoryKey, history);
  }

  /// 加载搜索历史
  List<String> loadSearchHistory() {
    return _prefs.getStringList(_searchHistoryKey) ?? [];
  }

  /// 清空搜索历史
  Future<void> clearSearchHistory() async {
    await _prefs.remove(_searchHistoryKey);
  }
}
