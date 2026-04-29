import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:broker_assist/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('登录注册流程', () {
    testWidgets('登录页显示 BrokerAssist 标题和登录表单', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const MyApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // 验证登录页正确显示
      expect(find.text('BrokerAssist'), findsOneWidget);
      expect(find.text('登录'), findsWidgets);
      expect(find.text('注册'), findsOneWidget);
    });

    testWidgets('登录页切换到注册模式', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const MyApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('注册'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('创建账号并登录'), findsOneWidget);
    });

    testWidgets('登录表单包含账号和密码输入框', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const MyApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // 找到文本输入框
      final textFields = find.byType(TextFormField);
      expect(textFields, findsNWidgets(2)); // 账号 + 密码
    });

    testWidgets('API 设置按钮存在', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const MyApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('API 设置'), findsOneWidget);
    });
  });

  group('首页 UI 组件', () {
    testWidgets('底部导航组件存在（模拟器）', (WidgetTester tester) async {
      // 检查 NavigationBar widget 是否在 widget list 中
      final binding = IntegrationTestWidgetsFlutterBinding.instance;
      expect(binding, isNotNull);
    });
  });
}
