import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:broker_assist/main.dart';
import 'package:broker_assist/services/chat_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App 在未登录时显示登录页', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('BrokerAssist'), findsOneWidget);
    expect(find.text('登录'), findsWidgets);
  });

  testWidgets('聊天历史按用户隔离存储', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    final userA = await ChatHistoryService.create(userId: 'user-a');
    final userB = await ChatHistoryService.create(userId: 'user-b');

    await userA.saveChatHistory([
      {
        'content': 'A 的问题',
        'isUser': true,
        'time': DateTime.parse('2026-04-21T11:00:00Z'),
      },
    ]);
    await userA.addSearchQuery('A 历史提问');

    await userB.saveChatHistory([
      {
        'content': 'B 的问题',
        'isUser': true,
        'time': DateTime.parse('2026-04-21T11:05:00Z'),
      },
    ]);
    await userB.addSearchQuery('B 历史提问');

    final historyA = userA.loadChatHistory();
    final historyB = userB.loadChatHistory();
    final searchA = userA.loadSearchHistory();
    final searchB = userB.loadSearchHistory();

    expect(historyA, hasLength(1));
    expect(historyB, hasLength(1));
    expect(historyA.first['content'], 'A 的问题');
    expect(historyB.first['content'], 'B 的问题');
    expect(searchA, ['A 历史提问']);
    expect(searchB, ['B 历史提问']);
  });
}
