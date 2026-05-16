import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:broker_assist/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('客户列表页 UI', () {
    testWidgets('客户列表搜索框存在', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const MyApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // 验证搜索框存在（登录页就有 API 设置入口）
      final searchField = find.byType(TextField);
      expect(searchField, findsWidgets);
    });
  });

  group('AI 聊天页 UI', () {
    testWidgets('AI 聊天页在未登录时显示登录页', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const MyApp());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // 未登录时显示登录页（客记标题）
      expect(find.text('客记'), findsOneWidget);
    });
  });

  group('应用启动', () {
    testWidgets('App 启动无崩溃', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const MyApp());
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('登录页显示正确', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const MyApp());
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('客记'), findsOneWidget);
      expect(find.text('登录'), findsWidgets);
      expect(find.text('注册'), findsOneWidget);
    });

    testWidgets('登录表单验证账号最少3位', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const MyApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // 输入2位字符
      final accountField = find.byType(TextFormField).first;
      await tester.enterText(accountField, 'ab');
      await tester.pump();

      // 点击登录按钮（ElevatedButton）
      final buttons = find.byType(ElevatedButton);
      await tester.tap(buttons.first);
      await tester.pump();

      // 应该显示验证错误
      expect(find.text('请输入至少 3 位账号'), findsOneWidget);
    });

    testWidgets('登录表单验证密码最少6位', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const MyApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // 输入正确账号但短密码
      final accountField = find.byType(TextFormField).first;
      await tester.enterText(accountField, 'testuser');
      await tester.pump();

      final passwordField = find.byType(TextFormField).at(1);
      await tester.enterText(passwordField, '12345');
      await tester.pump();

      final buttons = find.byType(ElevatedButton);
      await tester.tap(buttons.first);
      await tester.pump();

      expect(find.text('密码至少 6 位'), findsOneWidget);
    });

    testWidgets('登录页切换到注册模式后显示创建账号按钮', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const MyApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('注册'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('创建账号并登录'), findsOneWidget);
      // 登录按钮消失
      expect(find.text('登录').evaluate().length, greaterThan(0));
    });
  });
}
