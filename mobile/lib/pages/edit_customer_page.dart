import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/api.dart';
import '../services/reminder_data_service.dart';
import '../theme/brand_colors.dart';

/// 编辑客户页
class EditCustomerPage extends StatefulWidget {
  const EditCustomerPage({super.key});

  @override
  State<EditCustomerPage> createState() => _EditCustomerPageState();
}

class _EditCustomerPageState extends State<EditCustomerPage> {
  String? _customerId;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _ageController = TextEditingController();
  final _birthdayController = TextEditingController();
  final _locationController = TextEditingController();
  String? _selectedGender;
  final List<String> _tags = [];
  final _tagController = TextEditingController();

  Customer? _customer;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_customerId == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is String) {
        _customerId = args;
        _loadCustomer();
      } else {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _ageController.dispose();
    _birthdayController.dispose();
    _locationController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomer() async {
    final response = await apiService.getCustomerDetail(_customerId!);
    if (response.success && response.data != null) {
      final customer = Customer.fromJson(response.data!);
      setState(() {
        _customer = customer;
        _nameController.text = customer.name;
        _phoneController.text = customer.phone ?? '';
        _ageController.text = customer.age?.toString() ?? '';
        _birthdayController.text = customer.birthday ?? '';
        _locationController.text = customer.locationRaw ?? '';
        _selectedGender = _normalizeGender(customer.gender);
        _tags.addAll(customer.tags);
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
        _error = response.error?.message ?? '加载客户失败';
      });
    }
  }

  String? _normalizeGender(String? gender) {
    final value = gender?.trim().toLowerCase();
    if (value == null || value.isEmpty) return null;
    if (value == 'male' || value == 'm' || value == '男') return 'male';
    if (value == 'female' || value == 'f' || value == '女') return 'female';
    return null;
  }

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _tagController.clear();
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }

  Future<void> _saveCustomer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _error = null;
    });

    final response = await apiService.updateCustomer(
      customerId: _customerId!,
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim().isNotEmpty
          ? _phoneController.text.trim()
          : null,
      gender: _selectedGender,
      age: int.tryParse(_ageController.text.trim()),
      birthday: _birthdayController.text.trim().isNotEmpty
          ? _birthdayController.text.trim()
          : null,
      location: _locationController.text.trim().isNotEmpty
          ? _locationController.text.trim()
          : null,
      tags: _tags.isNotEmpty ? _tags : null,
    );

    setState(() {
      _isSaving = false;
    });

    if (response.success) {
      await ReminderDataService.refreshLocalNotificationSchedule();
      if (mounted) Navigator.of(context).pop(true);
    } else {
      setState(() {
        _error = response.error?.message ?? '保存失败';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('编辑客户'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveCustomer,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('保存'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _customer == null
          ? Center(
              child: Text(
                _error!,
                style: TextStyle(color: Colors.red.shade600),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
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
                          TextFormField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              labelText: '姓名 *',
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
                          TextFormField(
                            controller: _birthdayController,
                            keyboardType: TextInputType.datetime,
                            decoration: InputDecoration(
                              labelText: '生日',
                              hintText: 'YYYY-MM-DD',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              labelText: '手机',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: _selectedGender,
                                  decoration: InputDecoration(
                                    labelText: '性别',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: null,
                                      child: Text('未选择'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'male',
                                      child: Text('男'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'female',
                                      child: Text('女'),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    setState(() => _selectedGender = value);
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextFormField(
                                  controller: _ageController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: '年龄',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _locationController,
                            decoration: InputDecoration(
                              labelText: '客户主地址',
                              hintText: '如：望京SOHO',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '标签',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
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
                                  onFieldSubmitted: (_) => _addTag(),
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
                                  backgroundColor: BrandColors.primarySoft,
                                  side: BorderSide.none,
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
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
                ],
              ),
            ),
    );
  }
}
