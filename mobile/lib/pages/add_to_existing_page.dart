import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pinyin/pinyin.dart';

import '../models/models.dart';
import '../services/api.dart';
import '../utils/customer_search.dart';
import '../widgets/image_preview.dart';
import 'customer_detail_page.dart';

/// 添加到老客户页
///
/// P3 阶段：将草稿记录落库到已有客户
/// - 接收 DraftRecord
/// - 搜索并选择客户
/// - 落库记录
class AddToExistingPage extends StatefulWidget {
  const AddToExistingPage({super.key});

  @override
  State<AddToExistingPage> createState() => _AddToExistingPageState();
}

class _AddToExistingPageState extends State<AddToExistingPage> {
  /// 从首页传来的草稿数据
  DraftRecord? _draft;

  /// 草稿内容编辑器
  final TextEditingController _contentController = TextEditingController();

  /// 搜索
  final _searchController = TextEditingController();
  Timer? _debounceTimer;

  /// 客户列表
  List<Customer> _customers = [];
  bool _isLoading = false;
  String? _error;

  /// 提交状态
  bool _isSubmitting = false;
  final List<XFile> _selectedImages = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_draft == null) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      _draft = args?['draft'] as DraftRecord?;
      _contentController.text = _draft?.transcriptText ?? '';
      _selectedImages.addAll(
        (_draft?.imagePaths ?? const []).map((path) => XFile(path)),
      );
      _searchCustomers('');
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  /// 搜索客户（带防抖）
  void _onSearchChanged(String keyword) {
    setState(() {});
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _searchCustomers(keyword);
    });
  }

  /// 执行搜索
  Future<void> _searchCustomers(String keyword) async {
    final normalizedKeyword = keyword.trim();
    final useLocalPinyinSearch = isPinyinLikeKeyword(normalizedKeyword);

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await apiService.searchCustomers(
        keyword: normalizedKeyword.isEmpty || useLocalPinyinSearch
            ? null
            : normalizedKeyword,
        pageSize: 100,
        sortBy: 'name',
        sortOrder: 'asc',
      );

      if (response.success && response.data != null) {
        setState(() {
          final items = response.data!.items;
          _customers =
              (useLocalPinyinSearch
                    ? items
                          .where(
                            (customer) => customerMatchesKeyword(
                              customer,
                              normalizedKeyword,
                            ),
                          )
                          .toList()
                    : items)
                ..sort(_compareByPinyin);
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _error = response.error?.message ?? '搜索失败';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = '搜索失败: $e';
      });
    }
  }

  int _compareByPinyin(Customer a, Customer b) {
    final pinyinA = PinyinHelper.getPinyinE(a.name);
    final pinyinB = PinyinHelper.getPinyinE(b.name);
    return pinyinA.compareTo(pinyinB);
  }

  String _groupLetter(Customer customer) {
    if (customer.name.trim().isEmpty) return '#';
    final pinyin = PinyinHelper.getPinyinE(customer.name).trim();
    if (pinyin.isEmpty) return '#';
    final letter = pinyin[0].toUpperCase();
    final code = letter.codeUnitAt(0);
    return code >= 65 && code <= 90 ? letter : '#';
  }

  /// 提交记录到选中客户
  Future<void> _submitRecord(Customer customer) async {
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      setState(() {
        _error = '请输入记录内容';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final customerId = customer.id;
      final transcriptionId = _draft?.transcriptionId;

      ApiResponse<Map<String, dynamic>> recordResponse;
      String? recordId;

      if (transcriptionId != null && transcriptionId.isNotEmpty) {
        recordResponse = await apiService.confirmTranscription(
          transcriptionId: transcriptionId,
          content: content,
          customerId: customerId,
        );
        recordId = recordResponse.data?['record_id'] as String?;
        if (recordResponse.success &&
            recordId != null &&
            _selectedImages.isNotEmpty) {
          recordResponse = await apiService.updateRecordWithImages(
            recordId: recordId,
            content: content,
            imagePaths: _selectedImages.map((item) => item.path).toList(),
          );
        }
      } else {
        recordResponse = _selectedImages.isEmpty
            ? await apiService.createRecordDirect(
                customerId: customerId,
                content: content,
              )
            : await apiService.createRecordWithImages(
                customerId: customerId,
                content: content,
                imagePaths: _selectedImages.map((item) => item.path).toList(),
              );
      }

      setState(() {
        _isSubmitting = false;
      });

      if (recordResponse.success) {
        try {
          await apiService.generateSummary(customerId);
          await apiService.generateAdvice(customerId);
        } catch (_) {}
        _navigateToCustomerDetail(customerId);
      } else {
        setState(() {
          _error = recordResponse.error?.message ?? '添加记录失败';
        });
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
        _error = '请求失败: $e';
      });
    }
  }

  /// 跳转到客户详情页
  void _navigateToCustomerDetail(String customerId) {
    // 返回 true 通知首页成功
    Navigator.of(context).pop(true);

    // 延迟跳转，确保 pop 完成
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerDetailPage(), settings: RouteSettings(arguments: customerId)));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('选择客户'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: _isSubmitting
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    _selectedImages.isEmpty ? '正在保存记录...' : '正在上传图片并保存...',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ],
              ),
            )
          : Column(children: [Expanded(child: _buildSearchSection())]),
    );
  }

  /// 搜索区域
  Widget _buildSearchSection() {
    return Container(
      color: Colors.grey.shade50,
      child: Column(
        children: [
          if (_selectedImages.isNotEmpty)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: SelectedImagesPreview(
                images: _selectedImages,
                onRemove: (image) {
                  setState(() => _selectedImages.remove(image));
                },
              ),
            ),

          // 搜索框
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索姓名、电话、标签...',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _searchCustomers('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              onChanged: _onSearchChanged,
            ),
          ),

          // 错误提示
          if (_error != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Colors.red.shade400,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // 客户列表
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _customers.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 48,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _searchController.text.isEmpty ? '暂无客户' : '未找到匹配的客户',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  )
                : _buildGroupedCustomerList(),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedCustomerList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      itemCount: _customers.length,
      itemBuilder: (context, index) {
        final customer = _customers[index];
        final letter = _groupLetter(customer);
        final showHeader =
            index == 0 || _groupLetter(_customers[index - 1]) != letter;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showHeader)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
                child: Text(
                  letter,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            _buildCustomerItem(customer),
          ],
        );
      },
    );
  }

  /// 客户列表项
  Widget _buildCustomerItem(Customer customer) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFE7F5F2),
          child: Text(
            customer.name.isNotEmpty ? customer.name[0] : '?',
            style: const TextStyle(color: Color(0xFF0F766E)),
          ),
        ),
        title: Text(
          customer.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: customer.summary != null && customer.summary!.isNotEmpty
            ? Text(
                customer.summary!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              )
            : null,
        trailing: const Text(
          '添加',
          style: TextStyle(
            color: Color(0xFF0F766E),
            fontWeight: FontWeight.w700,
          ),
        ),
        onTap: () => _submitRecord(customer),
      ),
    );
  }
}
