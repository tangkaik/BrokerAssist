import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/api.dart';

class LoginPage extends StatefulWidget {
  final Future<void> Function(AuthSessionData session) onAuthenticated;

  const LoginPage({super.key, required this.onAuthenticated});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _loginFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();
  final _loginAccountController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  final _registerNameController = TextEditingController();
  final _registerAccountController = TextEditingController();
  final _registerPasswordController = TextEditingController();

  bool _isRegisterMode = false;
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _loginAccountController.dispose();
    _loginPasswordController.dispose();
    _registerNameController.dispose();
    _registerAccountController.dispose();
    _registerPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submitLogin() async {
    if (!_loginFormKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final response = await apiService.login(
        account: _loginAccountController.text.trim(),
        password: _loginPasswordController.text,
      );
      if (response.success && response.data != null) {
        await widget.onAuthenticated(response.data!);
      } else {
        setState(() => _error = response.error?.message ?? '登录失败');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _submitRegister() async {
    if (!_registerFormKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final response = await apiService.register(
        name: _registerNameController.text.trim().isEmpty
            ? null
            : _registerNameController.text.trim(),
        account: _registerAccountController.text.trim(),
        password: _registerPasswordController.text,
      );
      if (response.success && response.data != null) {
        await widget.onAuthenticated(response.data!);
      } else {
        setState(() => _error = response.error?.message ?? '注册失败');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  InputDecoration _inputDecoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      border: const OutlineInputBorder(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'BrokerAssist',
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isRegisterMode ? '先创建一个账号' : '先登录，再进入你的客户工作台',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('登录'),
                            selected: !_isRegisterMode,
                            onSelected: (_) => setState(() => _isRegisterMode = false),
                          ),
                          ChoiceChip(
                            label: const Text('注册'),
                            selected: _isRegisterMode,
                            onSelected: (_) => setState(() => _isRegisterMode = true),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      if (_error != null) ...[
                        Text(_error!, style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 12),
                      ],
                      if (_isRegisterMode)
                        Form(
                          key: _registerFormKey,
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _registerNameController,
                                decoration: _inputDecoration('昵称', hint: '可选'),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _registerAccountController,
                                decoration: _inputDecoration('账号', hint: '手机号或邮箱'),
                                validator: (value) => (value == null || value.trim().length < 3)
                                    ? '请输入至少 3 位账号'
                                    : null,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _registerPasswordController,
                                obscureText: true,
                                decoration: _inputDecoration('密码', hint: '至少 6 位'),
                                validator: (value) => (value == null || value.length < 6)
                                    ? '密码至少 6 位'
                                    : null,
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _isSubmitting ? null : _submitRegister,
                                  child: Text(_isSubmitting ? '正在创建...' : '创建账号并登录'),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Form(
                          key: _loginFormKey,
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _loginAccountController,
                                decoration: _inputDecoration('账号', hint: '手机号或邮箱'),
                                validator: (value) => (value == null || value.trim().length < 3)
                                    ? '请输入至少 3 位账号'
                                    : null,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _loginPasswordController,
                                obscureText: true,
                                decoration: _inputDecoration('密码', hint: '至少 6 位'),
                                validator: (value) => (value == null || value.length < 6)
                                    ? '密码至少 6 位'
                                    : null,
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _isSubmitting ? null : _submitLogin,
                                  child: Text(_isSubmitting ? '正在登录...' : '登录'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => Navigator.pushNamed(context, '/api-settings'),
                          child: const Text('API 设置'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
