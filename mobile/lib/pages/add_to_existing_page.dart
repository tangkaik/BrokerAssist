import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/models.dart';
import '../services/api.dart';

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
  final ImagePicker _imagePicker = ImagePicker();

  /// 从首页传来的草稿数据
  DraftRecord? _draft;

  /// 草稿内容编辑器
  final TextEditingController _contentController = TextEditingController();

  /// 搜索
  final _searchController = TextEditingController();
  Timer? _debounceTimer;

  /// 客户列表
  List<Customer> _customers = [];
  Customer? _selectedCustomer;
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
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _searchCustomers(keyword);
    });
  }

  /// 执行搜索
  Future<void> _searchCustomers(String keyword) async {
    setState(() {
      _isLoading = true;
      _error = null;
      _selectedCustomer = null;
    });

    try {
      final response = await apiService.searchCustomers(
        keyword: keyword.isEmpty ? null : keyword,
        pageSize: 20,
      );

      if (response.success && response.data != null) {
        setState(() {
          _customers = response.data!.items;
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

  /// 选择客户
  void _selectCustomer(Customer customer) {
    setState(() {
      _selectedCustomer = customer;
    });
  }

  /// 提交记录到选中客户
  Future<void> _submitRecord() async {
    if (_selectedCustomer == null) {
      setState(() {
        _error = '请先选择客户';
      });
      return;
    }

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
      final customerId = _selectedCustomer!.id;
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

  Future<void> _pickImages() async {
    final images = await _imagePicker.pickMultiImage(imageQuality: 85);
    if (images.isEmpty) return;
    setState(() {
      _selectedImages.addAll(images);
    });
  }

  void _removeImage(XFile image) {
    setState(() {
      _selectedImages.remove(image);
    });
  }

  /// 跳转到客户详情页
  void _navigateToCustomerDetail(String customerId) {
    // 返回 true 通知首页成功
    Navigator.of(context).pop(true);

    // 延迟跳转，确保 pop 完成
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        Navigator.pushNamed(context, '/customer-detail', arguments: customerId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('添加到老客户'),
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
          : Column(
              children: [
                // 上半部分 - 草稿内容
                _buildDraftSection(),

                _buildImageSection(),

                // 中间部分 - 搜索和列表
                Expanded(child: _buildSearchSection()),

                // 底部 - 提交按钮
                _buildBottomSubmit(),
              ],
            ),
    );
  }

  /// 草稿内容区域
  Widget _buildDraftSection() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.edit_note, size: 18, color: Colors.grey.shade600),
              const SizedBox(width: 8),
              Text(
                '待添加内容（可编辑）',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _contentController,
            maxLines: 3,
            minLines: 2,
            decoration: InputDecoration(
              hintText: '请输入记录内容...',
              hintStyle: TextStyle(color: Colors.grey.shade400),
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageSection() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.photo_library_outlined, color: Colors.grey.shade600),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '附加图片',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: _pickImages,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('选择图片'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _selectedImages.isEmpty
                ? '给这条新增记录一起上传图片。'
                : '已选择 ${_selectedImages.length} 张图片',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          if (_selectedImages.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _selectedImages.map((image) {
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(
                        File(image.path),
                        width: 84,
                        height: 84,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => _removeImage(image),
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(2),
                          child: const Icon(
                            Icons.close,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  /// 搜索区域
  Widget _buildSearchSection() {
    return Container(
      color: Colors.grey.shade50,
      child: Column(
        children: [
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
                          _searchController.text.isEmpty
                              ? '请输入关键词搜索客户'
                              : '未找到匹配的客户',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _customers.length,
                    itemBuilder: (context, index) {
                      final customer = _customers[index];
                      final isSelected = _selectedCustomer?.id == customer.id;
                      return _buildCustomerItem(customer, isSelected);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  /// 客户列表项
  Widget _buildCustomerItem(Customer customer, bool isSelected) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isSelected ? Colors.blue.shade300 : Colors.grey.shade200,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isSelected
              ? Colors.blue.shade100
              : Colors.grey.shade100,
          child: Text(
            customer.name.isNotEmpty ? customer.name[0] : '?',
            style: TextStyle(
              color: isSelected ? Colors.blue.shade700 : Colors.grey.shade700,
            ),
          ),
        ),
        title: Text(
          customer.name,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        subtitle: customer.summary != null && customer.summary!.isNotEmpty
            ? Text(
                customer.summary!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              )
            : null,
        trailing: isSelected
            ? Icon(Icons.check_circle, color: Colors.blue.shade600)
            : Icon(Icons.chevron_right, color: Colors.grey.shade400),
        onTap: () => _selectCustomer(customer),
      ),
    );
  }

  /// 底部提交区域
  Widget _buildBottomSubmit() {
    final canSubmit =
        _selectedCustomer != null && _contentController.text.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 选中客户提示
            if (_selectedCustomer != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Colors.green.shade500,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '已选择: ${_selectedCustomer!.name}',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedCustomer = null;
                        });
                      },
                      child: const Text('取消选择'),
                    ),
                  ],
                ),
              ),

            // 提交按钮
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: canSubmit ? _submitRecord : null,
                icon: const Icon(Icons.add, size: 20),
                label: const Text('加入到此客户'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  disabledBackgroundColor: Colors.grey.shade200,
                  disabledForegroundColor: Colors.grey.shade400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
