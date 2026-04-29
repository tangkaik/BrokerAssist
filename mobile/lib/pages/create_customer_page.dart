import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/models.dart';
import '../services/api.dart';

/// 创建新客户页
///
/// P3 阶段：将草稿记录落库到新客户
/// - 接收 DraftRecord
/// - 创建客户 + 创建记录
class CreateCustomerPage extends StatefulWidget {
  const CreateCustomerPage({super.key});

  @override
  State<CreateCustomerPage> createState() => _CreateCustomerPageState();
}

class _CreateCustomerPageState extends State<CreateCustomerPage> {
  final ImagePicker _imagePicker = ImagePicker();

  /// 从首页传来的草稿数据
  DraftRecord? _draft;

  /// 草稿内容编辑器
  final TextEditingController _contentController = TextEditingController();

  /// 客户表单字段
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String? _selectedGender;
  final _ageController = TextEditingController();
  final List<String> _tags = [];
  final _tagController = TextEditingController();

  /// 状态
  bool _isLoading = false;
  String? _error;
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
    _nameController.dispose();
    _ageController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  /// 添加标签
  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _tagController.clear();
      });
    }
  }

  /// 删除标签
  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }

  /// 创建客户并落库记录
  Future<void> _createCustomer() async {
    if (!_formKey.currentState!.validate()) {
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
      _isLoading = true;
      _error = null;
    });

    try {
      // 1. 创建客户
      final age = int.tryParse(_ageController.text.trim());
      final customerResponse = await apiService.createCustomer(
        name: _nameController.text.trim(),
        gender: _selectedGender,
        age: age,
        tags: _tags.isNotEmpty ? _tags : null,
      );

      if (!customerResponse.success || customerResponse.data == null) {
        setState(() {
          _isLoading = false;
          _error = customerResponse.error?.message ?? '创建客户失败';
        });
        return;
      }

      // 后端返回的字段名可能是 'customer_id' 或 'id'
      final customerId =
          customerResponse.data!['customer_id'] as String? ??
          customerResponse.data!['id'] as String?;

      // 调试：打印响应数据
      debugPrint('创建客户响应: ${customerResponse.data}');
      debugPrint('customerId: $customerId');

      if (customerId == null || customerId.isEmpty) {
        setState(() {
          _isLoading = false;
          _error = '创建客户成功但返回数据异常，缺少 customer_id';
        });
        return;
      }

      // 2. 根据路径落库记录
      final transcriptionId = _draft?.transcriptionId;
      ApiResponse<Map<String, dynamic>> recordResponse;
      String? recordId;

      // 调试信息
      debugPrint('══════ 开始落库记录 ══════');
      debugPrint('customerId: [$customerId]');
      debugPrint('content: [$content]');
      debugPrint('content length: ${content.length}');
      debugPrint('transcriptionId: $transcriptionId');

      try {
        if (transcriptionId != null && transcriptionId.isNotEmpty) {
          debugPrint('走 confirm 路径');
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
          debugPrint('走 direct record 路径');
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

        debugPrint('落库记录响应 success: ${recordResponse.success}');
        debugPrint('落库记录响应 data: ${recordResponse.data}');
        debugPrint('落库记录错误: ${recordResponse.error?.message}');

        setState(() {
          _isLoading = false;
        });

        if (recordResponse.success) {
          // 成功，跳转到客户详情页
          debugPrint('跳转到客户详情页: $customerId');
          _navigateToCustomerDetail(customerId);
        } else {
          setState(() {
            _error = recordResponse.error?.message ?? '创建记录失败';
          });
        }
      } catch (e, stackTrace) {
        debugPrint('落库记录异常: $e');
        debugPrint('堆栈: $stackTrace');
        setState(() {
          _isLoading = false;
          _error = '创建记录异常: $e';
        });
        return;
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
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
        title: const Text('创建新客户'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    _selectedImages.isEmpty ? '正在保存客户和记录...' : '正在上传图片并保存...',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 草稿内容区域
                  _buildDraftSection(),

                  const SizedBox(height: 16),

                  _buildImageSection(),

                  const SizedBox(height: 16),

                  // 客户表单
                  _buildCustomerForm(),

                  // 错误提示
                  if (_error != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(top: 16),
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

                  const SizedBox(height: 24),

                  // 创建按钮
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _createCustomer,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'OK，创建',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  /// 草稿内容区域
  Widget _buildDraftSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Icon(Icons.edit_note, size: 18, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Text(
                  '待录入内容（可编辑）',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
          TextField(
            controller: _contentController,
            maxLines: 4,
            minLines: 2,
            decoration: InputDecoration(
              hintText: '请输入记录内容...',
              hintStyle: TextStyle(color: Colors.grey.shade400),
              contentPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              border: InputBorder.none,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.photo_library_outlined, color: Colors.grey.shade700),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '附加图片',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: _pickImages,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('选择图片'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _selectedImages.isEmpty
                ? '可为这次新建记录一并上传拜访照片、聊天截图或保单图片。'
                : '已选择 ${_selectedImages.length} 张图片',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          if (_selectedImages.isNotEmpty) ...[
            const SizedBox(height: 12),
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
                        width: 88,
                        height: 88,
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

  /// 客户表单
  Widget _buildCustomerForm() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 姓名
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: '姓名 *',
                hintText: '请输入客户姓名',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '请输入姓名';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // 性别和年龄
            Row(
              children: [
                // 性别
                Expanded(
                  flex: 1,
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedGender,
                    decoration: InputDecoration(
                      labelText: '性别',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('未选择')),
                      DropdownMenuItem(value: 'male', child: Text('男')),
                      DropdownMenuItem(value: 'female', child: Text('女')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedGender = value;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                // 年龄
                Expanded(
                  flex: 1,
                  child: TextFormField(
                    controller: _ageController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: '年龄',
                      hintText: '诸位数字',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 标签
            Text(
              '标签',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),

            // 标签输入
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _tagController,
                    decoration: InputDecoration(
                      hintText: '输入标签后按回车添加',
                      hintStyle: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 13,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onSubmitted: (_) => _addTag(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addTag,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade200,
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('添加'),
                ),
              ],
            ),

            // 标签列表
            if (_tags.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _tags.map((tag) {
                  return Chip(
                    label: Text(tag),
                    deleteIcon: const Icon(Icons.close, size: 18),
                    onDeleted: () => _removeTag(tag),
                    backgroundColor: Colors.blue.shade50,
                    side: BorderSide.none,
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
