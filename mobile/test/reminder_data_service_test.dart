import 'package:flutter_test/flutter_test.dart';

import 'package:broker_assist/services/reminder_data_service.dart';

void main() {
  test('提醒扫描客户数量不超过后端单页上限', () {
    expect(ReminderDataService.customerScanLimit, lessThanOrEqualTo(100));
  });
}
