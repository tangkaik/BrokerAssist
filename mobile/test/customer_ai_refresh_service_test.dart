import 'package:flutter_test/flutter_test.dart';

import 'package:broker_assist/services/customer_ai_refresh_service.dart';

void main() {
  test('保存拜访记录后按顺序刷新客户画像和拜访建议', () async {
    final calls = <String>[];
    final service = CustomerAiRefreshService(
      generateSummary: (customerId) async {
        calls.add('summary:$customerId');
      },
      generateAdvice: (customerId) async {
        calls.add('advice:$customerId');
      },
    );

    await service.refreshAfterRecordSaved('customer-1');

    expect(calls, ['summary:customer-1', 'advice:customer-1']);
  });

  test('AI 刷新失败不阻断保存拜访记录流程', () async {
    final calls = <String>[];
    final service = CustomerAiRefreshService(
      generateSummary: (customerId) async {
        calls.add('summary:$customerId');
        throw Exception('summary failed');
      },
      generateAdvice: (customerId) async {
        calls.add('advice:$customerId');
      },
    );

    await service.refreshAfterRecordSaved('customer-1');

    expect(calls, ['summary:customer-1']);
  });
}
