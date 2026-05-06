import 'package:flutter/material.dart';

import '../services/api.dart';

class CustomerAIPage extends StatefulWidget {
  final String customerId;
  final String customerName;
  final String? summary;

  const CustomerAIPage({
    super.key,
    required this.customerId,
    required this.customerName,
    this.summary,
  });

  @override
  State<CustomerAIPage> createState() => _CustomerAIPageState();
}

class _CustomerAIPageState extends State<CustomerAIPage> {
  static const Color _background = Color(0xFFF6F7F9);
  static const Color _ink = Color(0xFF111827);
  static const Color _muted = Color(0xFF6B7280);
  static const Color _border = Color(0xFFE5E7EB);
  static const Color _teal = Color(0xFF0F766E);

  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_CustomerAiMessage> _messages = [];
  bool _isAsking = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _ask([String? presetQuestion]) async {
    final question = (presetQuestion ?? _controller.text).trim();
    if (question.isEmpty || _isAsking) return;

    setState(() {
      _messages.add(_CustomerAiMessage(text: question, isUser: true));
      _isAsking = true;
      _controller.clear();
    });
    _scrollToBottom();

    try {
      final response = await apiService.chatWithCustomer(
        customerId: widget.customerId,
        question: question,
      );
      if (!mounted) return;
      final answer = response.success && response.data != null
          ? (response.data!['answer'] ?? response.data!['reply'] ?? '暂无回答')
                as String
          : response.error?.message ?? '客户 AI 问答失败';
      setState(() {
        _messages.add(_CustomerAiMessage(text: answer, isUser: false));
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          _CustomerAiMessage(text: '客户 AI 问答失败: $error', isUser: false),
        );
      });
    } finally {
      if (mounted) {
        setState(() => _isAsking = false);
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        title: Text(
          '${widget.customerName}—向AI问该客户的情况',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        backgroundColor: _background,
        foregroundColor: _ink,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  _buildContextCard(),
                  const SizedBox(height: 12),
                  _buildQuickQuestions(),
                  const SizedBox(height: 16),
                  for (final message in _messages) _MessageBubble(message),
                  if (_isAsking)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: _ThinkingBubble(),
                    ),
                ],
              ),
            ),
            _buildComposer(),
          ],
        ),
      ),
    );
  }

  Widget _buildContextCard() {
    final summary = widget.summary?.trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '当前客户画像',
            style: TextStyle(
              color: _ink,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            summary?.isNotEmpty == true ? summary! : '暂无客户画像，可先询问 AI 总结客户情况。',
            style: const TextStyle(color: _muted, fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickQuestions() {
    const questions = ['总结客户画像', '下一步怎么跟进', '客户主要顾虑', '生成跟进话术'];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: questions
          .map(
            (question) => ActionChip(
              label: Text(question),
              avatar: const Icon(Icons.auto_awesome_outlined, size: 16),
              onPressed: _isAsking ? null : () => _ask(question),
              side: const BorderSide(color: _border),
              backgroundColor: Colors.white,
              labelStyle: const TextStyle(
                color: _ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildComposer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: _isAsking ? null : (_) => _ask(),
              decoration: InputDecoration(
                hintText: '问这个客户相关问题...',
                filled: true,
                fillColor: _background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          IconButton.filled(
            onPressed: _isAsking ? null : () => _ask(),
            icon: const Icon(Icons.send_rounded),
            style: IconButton.styleFrom(backgroundColor: _teal),
          ),
        ],
      ),
    );
  }
}

class _CustomerAiMessage {
  final String text;
  final bool isUser;

  const _CustomerAiMessage({required this.text, required this.isUser});
}

class _MessageBubble extends StatelessWidget {
  final _CustomerAiMessage message;

  const _MessageBubble(this.message);

  @override
  Widget build(BuildContext context) {
    final color = message.isUser ? const Color(0xFF0F766E) : Colors.white;
    final textColor = message.isUser ? Colors.white : const Color(0xFF111827);
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
          border: message.isUser
              ? null
              : Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Text(
          message.text,
          style: TextStyle(color: textColor, fontSize: 14, height: 1.55),
        ),
      ),
    );
  }
}

class _ThinkingBubble extends StatelessWidget {
  const _ThinkingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 8),
            Text('思考中...'),
          ],
        ),
      ),
    );
  }
}
