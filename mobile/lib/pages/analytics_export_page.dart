import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api.dart';
import '../services/api_config.dart';
import '../theme/brand_colors.dart';

/// 埋点数据导出页面
///
/// 用于导出埋点数据为 CSV 文件
/// 支持选择日期范围、预览统计、直接下载
class AnalyticsExportPage extends StatefulWidget {
  const AnalyticsExportPage({super.key});

  @override
  State<AnalyticsExportPage> createState() => _AnalyticsExportPageState();
}

class _AnalyticsExportPageState extends State<AnalyticsExportPage> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();
  bool _isLoading = false;
  Map<String, dynamic>? _dashboardData;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await apiService.getAnalyticsDashboard(
        startDate: DateFormat('yyyy-MM-dd').format(_startDate),
        endDate: DateFormat('yyyy-MM-dd').format(_endDate),
      );

      if (response.success && mounted) {
        setState(() {
          _dashboardData = response.data;
        });
      } else if (mounted) {
        setState(() {
          _errorMessage = response.error?.message ?? '加载失败';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '加载失败: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2024),
      lastDate: _endDate,
    );
    if (picked != null && picked != _startDate) {
      setState(() {
        _startDate = picked;
      });
      _loadDashboard();
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _endDate) {
      setState(() {
        _endDate = picked;
      });
      _loadDashboard();
    }
  }

  Future<void> _exportCSV() async {
    final startStr = DateFormat('yyyy-MM-dd').format(_startDate);
    final endStr = DateFormat('yyyy-MM-dd').format(_endDate);

    final exportUrl = apiService.buildAnalyticsExportUrl(
      startDate: startStr,
      endDate: endStr,
    );

    // 使用完整URL
    final fullUrl = ApiConfig.baseUrl + exportUrl.replaceFirst('/api/v1', '');

    try {
      final uri = Uri.parse(fullUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('正在下载 CSV 文件...')));
        }
      } else {
        throw '无法打开链接';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('导出失败: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('数据统计与导出'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadDashboard,
          ),
        ],
      ),
      body: _isLoading && _dashboardData == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 日期选择
                  _buildDateSelector(),
                  const SizedBox(height: 24),

                  // 错误提示
                  if (_errorMessage != null) _buildErrorCard(),

                  // 统计概览
                  if (_dashboardData != null) ...[
                    _buildSummaryCard(),
                    const SizedBox(height: 16),
                    _buildConversionCard(),
                    const SizedBox(height: 16),
                    _buildEventTypesCard(),
                  ],

                  const SizedBox(height: 32),

                  // 导出按钮
                  _buildExportButton(),
                ],
              ),
            ),
    );
  }

  Widget _buildDateSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '选择日期范围',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildDateButton(
                    label: '开始日期',
                    date: _startDate,
                    onTap: _selectStartDate,
                  ),
                ),
                const SizedBox(width: 16),
                const Icon(Icons.arrow_forward, color: Colors.grey),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildDateButton(
                    label: '结束日期',
                    date: _endDate,
                    onTap: _selectEndDate,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateButton({
    required String label,
    required DateTime date,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('MM月dd日').format(date),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(color: Colors.red.shade700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final summary = _dashboardData!['summary'] as Map<String, dynamic>;
    final totalEvents = summary['total_events'] ?? 0;
    final uniqueUsers = summary['unique_users'] ?? 0;
    final uniqueSessions = summary['unique_sessions'] ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '数据概览',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildMetricItem(
                  '事件总数',
                  totalEvents.toString(),
                  Icons.analytics,
                ),
                _buildMetricItem('独立用户', uniqueUsers.toString(), Icons.person),
                _buildMetricItem(
                  '会话数',
                  uniqueSessions.toString(),
                  Icons.devices,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricItem(String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: BrandColors.primary, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildConversionCard() {
    final conversions = _dashboardData!['conversions'] as List<dynamic>? ?? [];

    if (conversions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '记录创建转化',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...conversions.map((c) => _buildConversionItem(c)),
          ],
        ),
      ),
    );
  }

  Widget _buildConversionItem(Map<String, dynamic> conversion) {
    final source = conversion['source'] == 'recording' ? '录音' : '手动';
    final action = conversion['action'] == 'create_new' ? '创建客户' : '添加记录';
    final attempts = conversion['attempts'] ?? 0;
    final success = conversion['success'] ?? 0;
    final rate = (conversion['success_rate'] ?? 0.0) * 100;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$source · $action',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              Text(
                '${rate.toStringAsFixed(1)}%',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: rate / 100,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation(
              rate >= 80 ? Colors.green : Colors.orange,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$success / $attempts 成功',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildEventTypesCard() {
    final eventTypes = _dashboardData!['event_types'] as List<dynamic>? ?? [];

    if (eventTypes.isEmpty) {
      return const SizedBox.shrink();
    }

    // 取前5个
    final topEvents = eventTypes.take(5).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '热门事件',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...topEvents.map((e) => _buildEventTypeItem(e)),
          ],
        ),
      ),
    );
  }

  Widget _buildEventTypeItem(Map<String, dynamic> event) {
    final name = event['event_name'] ?? 'unknown';
    final count = event['count'] ?? 0;
    final displayName = _getEventDisplayName(name);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(displayName, overflow: TextOverflow.ellipsis)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: BrandColors.primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                color: BrandColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getEventDisplayName(String eventName) {
    final names = {
      'page_view_home': '首页浏览',
      'action_start_recording': '开始录音',
      'action_stop_recording': '完成录音',
      'action_create_customer': '创建客户',
      'action_add_to_existing': '添加到客户',
      'result_transcription': '转写完成',
      'result_record_created': '记录创建',
      'result_summary_refresh': '刷新摘要',
      'result_advice_generated': '生成建议',
      'action_ai_chat': 'AI对话',
    };
    return names[eventName] ?? eventName;
  }

  Widget _buildExportButton() {
    final startStr = DateFormat('yyyy-MM-dd').format(_startDate);
    final endStr = DateFormat('yyyy-MM-dd').format(_endDate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _exportCSV,
          icon: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.download),
          label: Text(_isLoading ? '准备中...' : '导出 CSV 文件'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: const TextStyle(fontSize: 16),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '导出 $startStr 至 $endStr 的埋点数据',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '导出说明:',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '• CSV 文件包含所有原始埋点事件',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              Text(
                '• 可用 Excel 打开进行透视分析',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              Text(
                '• 最大支持导出 90 天数据',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
