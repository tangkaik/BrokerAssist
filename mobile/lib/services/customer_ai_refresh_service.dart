import 'api.dart';

typedef CustomerAiRefreshTask = Future<void> Function(String customerId);

class CustomerAiRefreshService {
  CustomerAiRefreshService({
    CustomerAiRefreshTask? generateSummary,
    CustomerAiRefreshTask? generateAdvice,
  }) : _generateSummary =
           generateSummary ??
           ((customerId) async {
             await apiService.generateSummary(customerId);
           }),
       _generateAdvice =
           generateAdvice ??
           ((customerId) async {
             await apiService.generateAdvice(customerId);
           });

  final CustomerAiRefreshTask _generateSummary;
  final CustomerAiRefreshTask _generateAdvice;

  Future<void> refreshAfterRecordSaved(String customerId) async {
    if (customerId.trim().isEmpty) return;
    try {
      await _generateSummary(customerId);
      await _generateAdvice(customerId);
    } catch (_) {
      // AI 刷新失败不应阻断拜访记录保存。
    }
  }
}

final customerAiRefreshService = CustomerAiRefreshService();
