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
import '../widgets/image_preview.dart';
import '../widgets/skeleton.dart';
import 'customer_ai_page.dart';
import 'draft_record_page.dart';
import 'edit_customer_page.dart';

part 'customer_detail/customer_detail_layout.dart';
part 'customer_detail/customer_detail_header.dart';
part 'customer_detail/customer_detail_overview.dart';
part 'customer_detail/customer_detail_shared_widgets.dart';
part 'customer_detail/customer_detail_suggestions.dart';
part 'customer_detail/customer_detail_records.dart';
part 'customer_detail/customer_detail_actions.dart';
part 'customer_detail/customer_detail_formatters.dart';

const _detailPrimary = Color(0xFF0F766E);
const _detailAccent = Color(0xFF1E3A5F);
const _detailBorder = Color(0xFFE2E8F0);

class CustomerDetailPage extends StatefulWidget {
  const CustomerDetailPage({super.key});

  @override
  State<CustomerDetailPage> createState() => _CustomerDetailPageState();
}

class _CustomerDetailPageState extends State<CustomerDetailPage> {
  final ImagePicker _imagePicker = ImagePicker();

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
  final Set<String> _expandedVisionImageUrls = <String>{};

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
        _showMessage('下次拜访建议已更新');
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
        Navigator.pop(context, true);
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

  void _toggleSummaryExpanded() {
    setState(() => _summaryExpanded = !_summaryExpanded);
  }

  void _toggleAdviceExpanded() {
    setState(() => _adviceExpanded = !_adviceExpanded);
  }

  void _toggleVisionImageExpanded(String imageUrl) {
    setState(() {
      if (_expandedVisionImageUrls.contains(imageUrl)) {
        _expandedVisionImageUrls.remove(imageUrl);
      } else {
        _expandedVisionImageUrls.add(imageUrl);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('客户详情'),
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
}
