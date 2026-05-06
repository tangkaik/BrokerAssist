import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../models/models.dart';
import '../services/api.dart';
import '../services/api_config.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../widgets/customer_avatar.dart';
import '../widgets/skeleton.dart';
import 'draft_record_page.dart';
import 'edit_customer_page.dart';

class CustomerDetailPage extends StatefulWidget {
  const CustomerDetailPage({super.key});

  @override
  State<CustomerDetailPage> createState() => _CustomerDetailPageState();
}

class _CustomerDetailPageState extends State<CustomerDetailPage> {
  final ImagePicker _imagePicker = ImagePicker();
  final ScrollController _scrollController = ScrollController();

  String? _customerId;
  String? _loadedCustomerId;
  Customer? _customer;
  List<Record> _records = [];
  String _adviceText = '';
  String? _adviceUpdatedAt;

  bool _isLoading = true;
  bool _isRefreshingSummary = false;
  bool _isRefreshingAdvice = false;
  bool _summaryExpanded = false;
  bool _adviceExpanded = false;
  final Set<String> _analyzingImageUrls = <String>{};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String && args != _loadedCustomerId) {
      _customerId = args;
      _loadedCustomerId = args;
      _loadCustomerData();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomerData() async {
    if (_customerId == null) return;
    setState(() => _isLoading = true);

    try {
      final customerResponse = await apiService.getCustomerDetail(_customerId!);
      final recordsResponse = await apiService.getCustomerRecords(
        customerId: _customerId!,
      );
      if (!mounted) return;

      if (customerResponse.success && customerResponse.data != null) {
        _customer = Customer.fromJson(customerResponse.data!);
      }
      if (recordsResponse.success && recordsResponse.data != null) {
        _records = recordsResponse.data!.items;
      }
      final adviceResponse = await apiService.getSavedAdvice(_customerId!);
      if (adviceResponse.success && adviceResponse.data != null) {
        _adviceText = _extractAdviceText(adviceResponse.data!);
        _adviceUpdatedAt = adviceResponse.data!['updated_at'] as String?;
      } else {
        _adviceText = '';
        _adviceUpdatedAt = null;
      }
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('加载失败: $e')));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _navigateToEdit() async {
    if (_customerId == null) return;
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const EditCustomerPage(),
        settings: RouteSettings(arguments: _customerId),
      ),
    );
    if (result == true && mounted) {
      _loadCustomerData();
    }
  }

  Future<void> _refreshSummary() async {
    if (_customerId == null) return;
    setState(() => _isRefreshingSummary = true);

    try {
      final response = await apiService.generateSummary(_customerId!);
      if (!mounted) return;
      if (response.success) {
        await _loadCustomerData();
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('客户画像已更新')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('更新失败: ${response.error?.message ?? '未知错误'}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('更新失败: $e')));
    } finally {
      if (mounted) {
        setState(() => _isRefreshingSummary = false);
      }
    }
  }

  Future<void> _analyzeRecordImage({
    required String recordId,
    required String imageUrl,
  }) async {
    if (_analyzingImageUrls.contains(imageUrl)) return;
    setState(() => _analyzingImageUrls.add(imageUrl));
    try {
      final response = await apiService.analyzeRecordImage(
        recordId: recordId,
        imageUrl: imageUrl,
        analyzeModes: const ['extract_key_points', 'summarize_description'],
      );
      if (!mounted) return;
      if (response.success) {
        _showMessage('图片识别完成');
        await _loadCustomerData();
      } else {
        _showMessage(_friendlyImageAnalysisError(response.error?.message));
      }
    } catch (e) {
      if (mounted) {
        _showMessage(_friendlyImageAnalysisError(e.toString()));
      }
    } finally {
      if (mounted) {
        setState(() => _analyzingImageUrls.remove(imageUrl));
      }
    }
  }

  String _friendlyImageAnalysisError(String? rawMessage) {
    final message = rawMessage?.trim();
    if (message == null ||
        message.isEmpty ||
        message.contains('服务暂时不可用') ||
        message.contains('请求失败') ||
        message.contains('网络连接失败')) {
      return '图片识别暂时不可用。可以先把图片里的文字或关键信息记录下来，我会继续基于文本帮你分析。';
    }
    return '图片识别失败：$message';
  }

  String _extractAdviceText(Map<String, dynamic> data) {
    return (data['advice'] ?? data['advice_text'] ?? '').toString().trim();
  }

  Future<void> _refreshAdvice() async {
    if (_customerId == null) return;
    setState(() => _isRefreshingAdvice = true);

    try {
      final response = await apiService.generateAdvice(_customerId!);
      if (!mounted) return;

      if (response.success && response.data != null) {
        setState(() {
          _adviceText = _extractAdviceText(response.data!);
          _adviceUpdatedAt = response.data!['updated_at'] as String?;
        });
        _showMessage('下一步建议已更新');
      } else {
        _showMessage('更新失败: ${response.error?.message ?? '未知错误'}');
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage('更新失败: $e');
    } finally {
      if (mounted) {
        setState(() => _isRefreshingAdvice = false);
      }
    }
  }

  Future<void> _copyText(String label, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    _showMessage('$label 已复制');
  }

  Future<void> _shareText(String label, String text) async {
    await Share.share('$label\n\n$text');
  }

  String _recordShareText(Record record) {
    final typeLabel = (record.type == 'manual' || record.type == 'text')
        ? '手动记录'
        : '语音记录';
    final time =
        '${record.createdAt.year}-${_pad(record.createdAt.month)}-${_pad(record.createdAt.day)} '
        '${_pad(record.createdAt.hour)}:${_pad(record.createdAt.minute)}';
    return '$typeLabel\n时间：$time\n\n${record.content}';
  }

  String _resolveMediaUrl(String rawUrl) {
    if (rawUrl.startsWith('http://') || rawUrl.startsWith('https://')) {
      return rawUrl;
    }
    final origin = ApiConfig.baseUrl.replaceFirst(RegExp(r'/api/v1/?$'), '');
    if (rawUrl.startsWith('/')) {
      return '$origin$rawUrl';
    }
    return '$origin/$rawUrl';
  }

  Future<void> _showEditRecordSheet(Record record) async {
    final controller = TextEditingController(text: record.content);
    final List<RecordImage> keptImages = List<RecordImage>.from(record.images);
    final List<XFile> newImages = [];
    bool isSaving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> pickImages() async {
              final picked = await _imagePicker.pickMultiImage(
                imageQuality: 85,
              );
              if (picked.isEmpty) return;
              setSheetState(() {
                newImages.addAll(picked);
              });
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 20,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              '编辑拜访记录',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: controller,
                        maxLines: 12,
                        minLines: 8,
                        decoration: InputDecoration(
                          hintText: '请输入拜访记录内容',
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          contentPadding: const EdgeInsets.all(16),
                        ),
                        style: const TextStyle(fontSize: 15, height: 1.6),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: isSaving ? null : pickImages,
                            icon: const Icon(
                              Icons.add_photo_alternate_outlined,
                            ),
                            label: const Text('补充图片'),
                          ),
                          if (keptImages.isNotEmpty)
                            _buildCountChip('${keptImages.length} 张已保存图片'),
                          if (newImages.isNotEmpty)
                            _buildCountChip('${newImages.length} 张待上传图片'),
                        ],
                      ),
                      if (keptImages.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const Text(
                          '已保存图片',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        _buildEditableExistingImages(
                          keptImages: keptImages,
                          onRemove: (image) {
                            setSheetState(() => keptImages.remove(image));
                          },
                        ),
                      ],
                      if (newImages.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const Text(
                          '待上传图片',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        _buildEditableNewImages(
                          imageFiles: newImages,
                          onRemove: (image) {
                            setSheetState(() => newImages.remove(image));
                          },
                        ),
                      ],
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: isSaving
                              ? null
                              : () async {
                                  final content = controller.text.trim();
                                  if (content.isEmpty) {
                                    _showMessage('记录内容不能为空');
                                    return;
                                  }
                                  setSheetState(() => isSaving = true);
                                  final success = await _updateRecordWithImages(
                                    recordId: record.id,
                                    content: content,
                                    keepImageUrls: keptImages
                                        .map((item) => item.url)
                                        .toList(),
                                    imagePaths: newImages
                                        .map((item) => item.path)
                                        .toList(),
                                  );
                                  if (!mounted) return;
                                  setSheetState(() => isSaving = false);
                                  if (success && context.mounted) {
                                    Navigator.pop(context);
                                  }
                                },
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                          ),
                          child: isSaving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('保存修改'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<bool> _updateRecordWithImages({
    required String recordId,
    required String content,
    List<String> keepImageUrls = const [],
    List<String> imagePaths = const [],
  }) async {
    final response = await apiService.updateRecordWithImages(
      recordId: recordId,
      content: content,
      keepImageUrls: keepImageUrls,
      imagePaths: imagePaths,
    );

    if (!mounted) return false;

    if (response.success) {
      _showMessage('记录已保存');
      await _loadCustomerData();
      return true;
    }

    _showMessage('保存失败: ${response.error?.message ?? '未知错误'}');
    return false;
  }

  void _showDeleteRecordDialog(Record record) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这条记录吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteRecord(record.id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _showAddRecordSheet() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DraftRecordPage(
          customerId: _customerId,
          customerName: _customer?.name,
        ),
      ),
    ).then((_) {
      _loadCustomerData();
      // 新增记录后自动刷新画像和建议
      _autoRefreshSummaryAndAdvice();
    });
  }

  Future<void> _autoRefreshSummaryAndAdvice() async {
    if (_customerId == null) return;
    try {
      await apiService.generateSummary(_customerId!);
      await apiService.generateAdvice(_customerId!);
      _loadCustomerData();
    } catch (_) {
      // 静默失败，不影响用户体验
    }
  }

  Future<void> _deleteRecord(String recordId) async {
    final response = await apiService.deleteRecord(recordId);
    if (!mounted) return;
    if (response.success) {
      _showMessage('记录已删除');
      _loadCustomerData();
    } else {
      _showMessage('删除失败: ${response.error?.message ?? '未知错误'}');
    }
  }

  Future<void> _deleteCustomer() async {
    if (_customerId == null) return;
    setState(() => _isLoading = true);

    try {
      final response = await apiService.deleteCustomer(_customerId!);
      if (!mounted) return;
      if (response.success) {
        _showMessage('客户已删除');
        Navigator.pop(context);
      } else {
        setState(() => _isLoading = false);
        _showMessage('删除失败: ${response.error?.message ?? '未知错误'}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage('删除失败: $e');
    }
  }

  void _showDeleteConfirmDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text(
          '确定要删除客户 "${_customer?.name}" 吗？\n\n此操作不可恢复，该客户的所有记录也将被删除。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteCustomer();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _showImagePreview(String imageUrl, String title) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        backgroundColor: Colors.black87,
        child: Stack(
          children: [
            InteractiveViewer(
              child: AspectRatio(
                aspectRatio: 1,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Center(
                    child: Icon(
                      Icons.broken_image,
                      color: Colors.white70,
                      size: 40,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 12,
              child: Text(
                title,
                style: const TextStyle(color: Colors.white),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_customer?.name ?? '客户详情'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            onPressed: _isLoading ? null : () => _showAddRecordSheet(),
            tooltip: '新增沟通记录',
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _isLoading ? null : _navigateToEdit,
            tooltip: '编辑',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadCustomerData,
            tooltip: '刷新',
          ),
        ],
      ),
      body: _isLoading ? const CustomerDetailSkeleton() : _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_customer == null) {
      return const Center(child: Text('客户信息加载失败'));
    }

    return RefreshIndicator(
      onRefresh: _loadCustomerData,
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        children: [
          _buildInfoCard(),
          const SizedBox(height: 16),
          _buildSummarySection(),
          const SizedBox(height: 16),
          _buildNextStepSuggestionSection(),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.history, color: Color(0xFF2196F3)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '沟通记录 (${_records.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, color: Color(0xFF2196F3)),
                onPressed: () => _showAddRecordSheet(),
                tooltip: '新增沟通记录',
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildRecordsList(),
          const SizedBox(height: 32),
          _buildDeleteButton(),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CustomerAvatar(
                  avatarUrl: _customer!.avatar,
                  name: _customer!.name,
                  radius: 28,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _customer!.name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (_customer!.gender != null)
                  _buildTag(_displayGender(_customer!.gender!), Icons.person),
                if (_customer!.age != null)
                  _buildTag('${_customer!.age}岁', Icons.cake),
                if (_customer?.createdAt != null)
                  _buildTag(
                    '${_customer!.createdAt.month}/${_customer!.createdAt.day} 创建',
                    Icons.calendar_today,
                  ),
                if (_locationDisplay.isNotEmpty)
                  _buildTag(_locationDisplay, Icons.location_on),
              ],
            ),
            if (_customer!.phone != null && _customer!.phone!.isNotEmpty) ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => _copyText('电话', _customer!.phone!),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.phone, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Text(
                      _customer!.phone!,
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
            ],
            if (_customer!.tags.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _customer!.tags
                    .map(
                      (tag) => Chip(
                        label: Text(tag),
                        backgroundColor: const Color(0xFF2196F3).withAlpha(25),
                        labelStyle: const TextStyle(color: Color(0xFF2196F3)),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
        ],
      ),
    );
  }

  Widget _buildSummarySection() {
    final summary = _customer?.summary?.trim() ?? '';
    final hasSummary = summary.isNotEmpty;
    final isUpdating = _customer?.summaryStatus == 'updating';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.summarize, color: Color(0xFF2196F3)),
                      SizedBox(width: 8),
                      Text(
                        '客户画像摘要',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isUpdating)
                  const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                IconButton(
                  onPressed: _isRefreshingSummary || isUpdating
                      ? null
                      : _refreshSummary,
                  icon: _isRefreshingSummary
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  tooltip: '刷新',
                ),
                IconButton(
                  onPressed: hasSummary
                      ? () => _copyText('客户画像', summary)
                      : null,
                  icon: const Icon(Icons.copy_outlined),
                  tooltip: '复制',
                ),
                IconButton(
                  onPressed: hasSummary
                      ? () => _shareText('客户画像摘要', summary)
                      : null,
                  icon: const Icon(Icons.ios_share_outlined),
                  tooltip: '分享',
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (hasSummary)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: _buildExpandableText(summary, _summaryExpanded, () {
                  setState(() => _summaryExpanded = !_summaryExpanded);
                }),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.description_outlined,
                        size: 32,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '暂无客户画像摘要',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '点击右上角刷新图标生成',
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNextStepSuggestionSection() {
    final hasAdvice = _adviceText.isNotEmpty;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.lightbulb_outline, color: Color(0xFF0F766E)),
                      SizedBox(width: 8),
                      Text(
                        '下一步建议',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _isRefreshingAdvice ? null : _refreshAdvice,
                  icon: _isRefreshingAdvice
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  tooltip: '刷新',
                ),
                IconButton(
                  onPressed: hasAdvice
                      ? () => _copyText('下一步建议', _adviceText)
                      : null,
                  icon: const Icon(Icons.copy_outlined),
                  tooltip: '复制',
                ),
                IconButton(
                  onPressed: hasAdvice
                      ? () => _shareText('下一步建议', _adviceText)
                      : null,
                  icon: const Icon(Icons.ios_share_outlined),
                  tooltip: '分享',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF3FAF8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBFE4DD)),
              ),
              child: hasAdvice
                  ? _buildExpandableText(_adviceText, _adviceExpanded, () {
                      setState(() => _adviceExpanded = !_adviceExpanded);
                    })
                  : Text(
                      '根据客户画像和最近沟通记录，生成下一次拜访前最值得关注的问题、开场方式和跟进重点。',
                      style: TextStyle(fontSize: 14, height: 1.65, color: Colors.grey[700]),
                    ),
            ),
            if (_adviceUpdatedAt != null && _adviceUpdatedAt!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '上次生成：${_adviceUpdatedAt!.replaceFirst('T', ' ').split('.').first}',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ] else if (!hasAdvice) ...[
              const SizedBox(height: 8),
              Text(
                '点击右上角刷新图标生成',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRecordsList() {
    if (_records.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.chat_bubble_outline,
                size: 48,
                color: Colors.grey[300],
              ),
              const SizedBox(height: 12),
              Text('暂无沟通记录', style: TextStyle(color: Colors.grey[600])),
            ],
          ),
        ),
      );
    }

    return Column(children: _records.map(_buildRecordItem).toList());
  }

  Widget _buildRecordItem(Record record) {
    final shareText = _recordShareText(record);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        (record.type == 'manual' || record.type == 'text')
                            ? Icons.edit
                            : Icons.mic,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        (record.type == 'manual' || record.type == 'text')
                            ? '手动记录'
                            : '语音记录',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${record.createdAt.month}/${record.createdAt.day} '
                  '${_pad(record.createdAt.hour)}:${_pad(record.createdAt.minute)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              record.content,
              style: const TextStyle(fontSize: 15, height: 1.6),
            ),
            if (record.images.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildRecordImages(record),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                _buildPlainIconAction(
                  icon: Icons.copy_outlined,
                  tooltip: '复制',
                  onTap: () => _copyText('拜访记录', shareText),
                ),
                _buildPlainIconAction(
                  icon: Icons.ios_share_outlined,
                  tooltip: '分享',
                  onTap: () => _shareText('拜访记录', shareText),
                ),
                _buildPlainIconAction(
                  icon: Icons.edit_outlined,
                  tooltip: '编辑',
                  onTap: () => _showEditRecordSheet(record),
                ),
                _buildPlainIconAction(
                  icon: Icons.delete_outline,
                  color: Colors.red,
                  tooltip: '删除',
                  onTap: () => _showDeleteRecordDialog(record),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordImages(Record record) {
    return Column(
      children: record.images.map((image) {
        final imageUrl = _resolveMediaUrl(image.url);
        final isAnalyzing = _analyzingImageUrls.contains(image.url);
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => _showImagePreview(imageUrl, image.name),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      Image.network(
                        imageUrl,
                        width: 96,
                        height: 96,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 96,
                          height: 96,
                          color: Colors.grey[200],
                          alignment: Alignment.center,
                          child: const Icon(Icons.broken_image_outlined),
                        ),
                      ),
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Material(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(999),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(999),
                            onTap: isAnalyzing
                                ? null
                                : () => _analyzeRecordImage(
                                    recordId: record.id,
                                    imageUrl: image.url,
                                  ),
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: isAnalyzing
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.auto_awesome_outlined,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                            ),
                          ),
                        ),
                      ),
                      if (image.visionAnswer?.isNotEmpty == true)
                        Positioned(
                          right: 6,
                          bottom: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.68),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              '已识别',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            image.name.isNotEmpty ? image.name : '记录图片',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                        ),
                        if (isAnalyzing)
                          const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (image.visionAnswer?.isNotEmpty == true)
                      _buildVisionAnswerBox(image.visionAnswer!)
                    else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isAnalyzing ? '正在识别图片...' : '暂未识别，点图片右上角星标开始识别',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.5,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildVisionAnswerBox(String answer) {
    final looksLikeTable = _looksLikeTableText(answer);
    final textWidget = SelectableText(
      answer,
      style: TextStyle(
        fontSize: 12,
        height: 1.55,
        color: Colors.grey[800],
        fontFamily: looksLikeTable ? 'monospace' : null,
      ),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF8F6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD0EAE4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '识别结果',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0D6C63),
            ),
          ),
          const SizedBox(height: 6),
          if (looksLikeTable)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 320),
                child: textWidget,
              ),
            )
          else
            textWidget,
        ],
      ),
    );
  }

  static const int _expandThreshold = 150;

  Widget _buildExpandableText(String text, bool expanded, VoidCallback onToggle) {
    final needsToggle = text.length > _expandThreshold;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MarkdownBody(
          data: needsToggle && !expanded ? '${text.substring(0, _expandThreshold)}...' : text,
          selectable: true,
          styleSheet: MarkdownStyleSheet(
            p: const TextStyle(fontSize: 14, height: 1.7, color: Colors.black87),
            strong: const TextStyle(fontWeight: FontWeight.w700),
            h1: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            h2: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            h3: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ),
        if (needsToggle)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onToggle,
              child: Text(expanded ? '收起 ▲' : '展开全部 ▼',
                  style: const TextStyle(fontSize: 12)),
            ),
          ),
      ],
    );
  }

  bool _looksLikeTableText(String text) {
    final lines = text.split('\n');
    final pipeHeavyLines = lines.where((line) => line.contains('|')).length;
    return pipeHeavyLines >= 2 ||
        text.contains('---|') ||
        text.contains('|---');
  }

  Widget _buildPlainIconAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color? color,
  }) {
    return IconButton(
      onPressed: onTap,
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      icon: Icon(icon, size: 20, color: color),
    );
  }

  Widget _buildEditableExistingImages({
    required List<RecordImage> keptImages,
    required ValueChanged<RecordImage> onRemove,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: keptImages.map((image) {
        final imageUrl = _resolveMediaUrl(image.url);
        return _buildImageTile(
          child: Image.network(
            imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              color: Colors.grey[200],
              alignment: Alignment.center,
              child: const Icon(Icons.broken_image_outlined),
            ),
          ),
          onRemove: () => onRemove(image),
        );
      }).toList(),
    );
  }

  Widget _buildEditableNewImages({
    required List<XFile> imageFiles,
    required ValueChanged<XFile> onRemove,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: imageFiles.map((image) {
        return _buildImageTile(
          child: Image.file(File(image.path), fit: BoxFit.cover),
          onRemove: () => onRemove(image),
        );
      }).toList(),
    );
  }

  Widget _buildImageTile({
    required Widget child,
    required VoidCallback onRemove,
  }) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(width: 88, height: 88, child: child),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(2),
              child: const Icon(Icons.close, color: Colors.white, size: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCountChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F7FB),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFD4E1EF)),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildDeleteButton() {
    return OutlinedButton.icon(
      onPressed: _showDeleteConfirmDialog,
      icon: const Icon(Icons.delete_outline, color: Colors.red),
      label: const Text('删除客户', style: TextStyle(color: Colors.red)),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.red,
        side: const BorderSide(color: Colors.red),
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  String get _locationDisplay {
    final c = _customer;
    if (c == null) return '';
    final parts = <String>[
      if (c.locationRaw != null && c.locationRaw!.isNotEmpty) c.locationRaw!,
      if (c.locationDistrict != null && c.locationDistrict!.isNotEmpty)
        c.locationDistrict!,
      if (c.locationSubarea != null && c.locationSubarea!.isNotEmpty)
        c.locationSubarea!,
    ];
    // 去重：避免 location_raw 已经包含下级信息时重复显示
    final seen = <String>{};
    final unique = <String>[];
    for (final p in parts) {
      final trimmed = p.trim();
      if (trimmed.isNotEmpty && seen.add(trimmed)) {
        unique.add(trimmed);
      }
    }
    return unique.join(' · ');
  }

  String _displayGender(String raw) {
    switch (raw.trim()) {
      case 'male':
        return '男';
      case 'female':
        return '女';
      default:
        return raw;
    }
  }

  String _pad(int value) => value.toString().padLeft(2, '0');
}
