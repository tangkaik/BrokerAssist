import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../services/api.dart';
import '../services/auth_session.dart';
import '../services/chat_storage.dart';
import 'customer_detail_page.dart';

/// AI 全局业务问答页 (P5 阶段)
///
/// 布局逻辑：
/// - 初始：输入框在顶部，中间空状态
/// - 发送消息后：输入框移到底部（类微信布局）
class AIChatPage extends StatefulWidget {
  const AIChatPage({super.key});

  @override
  State<AIChatPage> createState() => _AIChatPageState();
}

/// 消息模型
class _ChatMessage {
  final String content;
  final bool isUser;
  final DateTime time;

  _ChatMessage({required this.content, required this.isUser, DateTime? time})
    : time = time ?? DateTime.now();
}

class _AIChatPageState extends State<AIChatPage> {
  /// 消息列表
  final List<_ChatMessage> _messages = [];

  /// 输入控制器
  final TextEditingController _inputController = TextEditingController();

  /// 图片选择器
  final ImagePicker _imagePicker = ImagePicker();

  /// 当前待发送图片
  XFile? _selectedImage;

  /// 是否正在发送
  bool _isSending = false;

  /// 滚动控制器
  final ScrollController _scrollController = ScrollController();

  /// 是否显示建议问题
  bool _showSuggestions = true;

  /// 建议问题列表（5个）
  final List<String> _suggestedQuestions = [
    '有多少住在海淀区的女客户',
    '列出55岁以上的女性客户',
    '徐汇区的客户有哪些',
    '哪些客户两个月没联系了',
    '列出高净值客户',
  ];

  /// 搜索历史
  List<String> _searchHistory = [];

  /// 聊天存储服务
  ChatHistoryService? _chatStorage;

  static const int _maxSearchHistoryCount = 10;

  /// 长答案分页相关
  String? _pendingAnswer; // 待显示的完整答案
  int _answerPartIndex = 0; // 当前显示到第几部分
  static const int _maxLinesPerMessage = 100; // 每条消息最大行数（超过则截断）
  static const int _maxContextMessages = 16; // 最近 8 轮，供后端多轮能力使用

  @override
  void initState() {
    super.initState();
    _initChatStorage();
  }

  Future<void> _initChatStorage() async {
    _chatStorage = await ChatHistoryService.create(
      userId: AuthSession.currentUser?.id,
    );
    _searchHistory = _chatStorage!.loadSearchHistory();
    final history = _chatStorage!.loadChatHistory();
    if (history.isNotEmpty) {
      setState(() {
        for (final msg in history) {
          _messages.add(
            _ChatMessage(
              content: msg['content'] as String,
              isUser: msg['isUser'] as bool,
              time: msg['time'] as DateTime,
            ),
          );
        }
        if (_messages.isNotEmpty) {
          _showSuggestions = false;
        }
      });
    }
    if (mounted) setState(() {});
  }

  Future<void> _saveChatHistory() async {
    if (_chatStorage == null) return;
    final data = _messages
        .map((m) => {'content': m.content, 'isUser': m.isUser, 'time': m.time})
        .toList();
    await _chatStorage!.saveChatHistory(data);
  }

  Future<void> _addToSearchHistory(String query) async {
    if (_chatStorage == null) return;
    await _chatStorage!.addSearchQuery(query);
    _searchHistory = _chatStorage!.loadSearchHistory();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// 发送消息
  Future<void> _sendMessage(String question) async {
    final normalizedQuestion = question.trim();
    final attachedImage = _selectedImage;
    if (normalizedQuestion.isEmpty && attachedImage == null) return;

    // 处理"继续"命令
    if (normalizedQuestion == '继续' && _pendingAnswer != null) {
      _showNextPart();
      return;
    }

    final effectiveQuestion = normalizedQuestion.isNotEmpty
        ? normalizedQuestion
        : '请识别这张图片并提取重点信息';
    final recentMessages = _buildRecentMessagesForRequest();
    final userMessage = attachedImage == null
        ? effectiveQuestion
        : effectiveQuestion == normalizedQuestion
        ? '$effectiveQuestion\n\n[附图：${attachedImage.name}]'
        : '[附图：${attachedImage.name}]\n\n$effectiveQuestion';

    // 添加用户消息
    setState(() {
      _messages.add(_ChatMessage(content: userMessage, isUser: true));
      _isSending = true;
      _showSuggestions = false; // 隐藏建议问题
      _selectedImage = null;
    });

    _inputController.clear();
    _scrollToBottom();

    try {
      final response = attachedImage == null
          ? await apiService.aiChat(
              question: effectiveQuestion,
              recentMessages: recentMessages,
            )
          : await apiService.aiChatWithImage(
              question: effectiveQuestion,
              imagePath: attachedImage.path,
            );

      // 保存用户提问到搜索历史
      _addToSearchHistory(effectiveQuestion);

      if (response.success && response.data != null) {
        final fullAnswer = response.data!['answer'] as String? ?? '暂无回答';

        // 按行数判断是否截断
        final lines = fullAnswer.split('\n');
        if (lines.length > _maxLinesPerMessage) {
          _pendingAnswer = fullAnswer;
          _answerPartIndex = 0;
          _showNextPart();
        } else {
          setState(() {
            _messages.add(_ChatMessage(content: fullAnswer, isUser: false));
          });
        }
      } else {
        setState(() {
          _messages.add(
            _ChatMessage(
              content: _friendlyAiErrorMessage(
                response.error?.message,
                hasImage: attachedImage != null,
              ),
              isUser: false,
            ),
          );
        });
      }
    } catch (e) {
      setState(() {
        _messages.add(
          _ChatMessage(
            content: _friendlyAiErrorMessage(
              e.toString(),
              hasImage: attachedImage != null,
            ),
            isUser: false,
          ),
        );
      });
    } finally {
      setState(() => _isSending = false);
      _scrollToBottom();
      _saveChatHistory();
    }
  }

  List<Map<String, String>> _buildRecentMessagesForRequest() {
    return _messages
        .where((message) => message.content.trim().isNotEmpty)
        .toList()
        .reversed
        .take(_maxContextMessages)
        .toList()
        .reversed
        .map(
          (message) => {
            'role': message.isUser ? 'user' : 'assistant',
            'content': message.content.trim(),
          },
        )
        .toList();
  }

  String _friendlyAiErrorMessage(String? rawMessage, {required bool hasImage}) {
    final message = rawMessage?.trim();
    if (hasImage) {
      return '图片识别暂时不可用。可以先把图片里的文字或关键信息发给我，我会继续基于文本帮你分析。';
    }
    if (message == null || message.isEmpty || message == '未知错误') {
      return 'AI 助手暂时没有返回结果，请稍后再试。';
    }
    if (message.contains('服务暂时不可用') ||
        message.contains('请求失败') ||
        message.contains('网络连接失败')) {
      return 'AI 助手暂时连接不上服务，请稍后再试。';
    }
    return '请求失败：$message';
  }

  Future<void> _pickImage() async {
    if (_isSending) return;
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;
    setState(() => _selectedImage = picked);
  }

  void _clearSelectedImage() {
    if (_selectedImage == null) return;
    setState(() => _selectedImage = null);
  }

  /// 显示长答案的下一部分（按100行分割）
  void _showNextPart() {
    if (_pendingAnswer == null) return;

    final allLines = _pendingAnswer!.split('\n');
    final startLine = _answerPartIndex * _maxLinesPerMessage;
    final endLine = startLine + _maxLinesPerMessage;

    List<String> partLines;

    if (endLine >= allLines.length) {
      // 最后一部分
      partLines = allLines.sublist(startLine);
      _pendingAnswer = null;
      _answerPartIndex = 0;
    } else {
      // 还有后续
      partLines = allLines.sublist(startLine, endLine);
      partLines.add('');
      partLines.add('（内容较长，输入"继续"查看后续）');
      _answerPartIndex++;
    }

    setState(() {
      _messages.add(_ChatMessage(content: partLines.join('\n'), isUser: false));
    });
    _scrollToBottom();
  }

  /// 滚动到底部
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// 开始新对话（清空消息）
  void _startNewChat() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('开始新对话'),
        content: const Text('确定要清空当前对话吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _chatStorage?.clearChatHistory();
              setState(() {
                _messages.clear();
                _showSuggestions = true;
                _pendingAnswer = null;
                _answerPartIndex = 0;
              });
              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2196F3),
              foregroundColor: Colors.white,
            ),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 根据是否有消息决定布局
    final hasMessages = _messages.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 助手'),
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
        actions: [
          // 新对话按钮（有消息时才显示）
          if (hasMessages)
            TextButton.icon(
              onPressed: _startNewChat,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('新对话', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: hasMessages
          ? _buildChatLayout() // 有消息：输入框在底部
          : _buildInitialLayout(), // 无消息：输入框在顶部
    );
  }

  /// 初始布局：输入框在顶部
  Widget _buildInitialLayout() {
    return Column(
      children: [
        // 输入区（置顶）
        _buildTopInputArea(),

        // 建议问题
        if (_showSuggestions) _buildSuggestedQuestions(),

        const Divider(height: 1),

        // 空状态
        Expanded(child: _buildEmptyState()),
      ],
    );
  }

  /// 聊天布局：输入框在底部（类微信）
  Widget _buildChatLayout() {
    return Column(
      children: [
        // 消息列表
        Expanded(child: _buildMessageList()),

        const Divider(height: 1),

        // 输入区（置底）
        _buildBottomInputArea(),
      ],
    );
  }

  /// 顶部输入区（初始状态）
  Widget _buildTopInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_selectedImage != null) ...[
            _buildSelectedImagePreview(compact: false),
            const SizedBox(height: 12),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                onPressed: _isSending ? null : _pickImage,
                icon: const Icon(Icons.photo_outlined),
                color: const Color(0xFF2196F3),
                tooltip: '上传图片',
              ),
              Expanded(
                child: TextField(
                  controller: _inputController,
                  enabled: !_isSending,
                  minLines: 1,
                  maxLines: 3,
                  maxLength: 500,
                  decoration: InputDecoration(
                    hintText: _selectedImage == null
                        ? '输入您的问题...'
                        : '可补充说明，或直接发送图片',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    counterText: '',
                  ),
                  onSubmitted: (value) => _sendMessage(value),
                ),
              ),
              const SizedBox(width: 8),
              _isSending
                  ? const SizedBox(
                      width: 48,
                      height: 48,
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      onPressed: () => _sendMessage(_inputController.text),
                      icon: const Icon(Icons.send),
                      color: const Color(0xFF2196F3),
                      iconSize: 28,
                    ),
            ],
          ),
        ],
      ),
    );
  }

  /// 底部输入区（聊天状态）
  Widget _buildBottomInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_selectedImage != null) ...[
              _buildSelectedImagePreview(compact: true),
              const SizedBox(height: 10),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: _isSending ? null : _pickImage,
                  icon: const Icon(Icons.photo_outlined),
                  color: const Color(0xFF2196F3),
                  tooltip: '上传图片',
                ),
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    enabled: !_isSending,
                    minLines: 1,
                    maxLines: 3,
                    maxLength: 500,
                    decoration: InputDecoration(
                      hintText: _selectedImage == null
                          ? '输入消息...'
                          : '可补充说明，或直接发送图片',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      counterText: '',
                    ),
                    onSubmitted: (value) => _sendMessage(value),
                  ),
                ),
                const SizedBox(width: 8),
                _isSending
                    ? const SizedBox(
                        width: 44,
                        height: 44,
                        child: Padding(
                          padding: EdgeInsets.all(10),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        onPressed: () => _sendMessage(_inputController.text),
                        icon: const Icon(Icons.send),
                        color: const Color(0xFF2196F3),
                        iconSize: 24,
                      ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedImagePreview({required bool compact}) {
    final image = _selectedImage;
    if (image == null) return const SizedBox.shrink();

    final previewSize = compact ? 68.0 : 84.0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F9FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD7E8FF)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.file(
              File(image.path),
              width: previewSize,
              height: previewSize,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '已附加图片',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  image.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _isSending ? null : _clearSelectedImage,
            icon: const Icon(Icons.close),
            tooltip: '移除图片',
          ),
        ],
      ),
    );
  }

  /// 空状态展示
  Widget _buildEmptyState() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 180;
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.smart_toy,
                    size: compact ? 44 : 80,
                    color: Colors.grey[300],
                  ),
                  SizedBox(height: compact ? 8 : 20),
                  Text(
                    '有什么可以帮您的？',
                    style: TextStyle(
                      fontSize: compact ? 15 : 18,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '基于您的客户数据提供业务洞察',
                    style: TextStyle(fontSize: 13, color: Colors.grey[400]),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// 建议问题区
  Widget _buildSuggestedQuestions() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 搜索历史
          if (_searchHistory.isNotEmpty) ...[
            Row(
              children: [
                Text(
                  '最近提问：',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () async {
                    await _chatStorage?.clearSearchHistory();
                    _searchHistory = [];
                    if (mounted) setState(() {});
                  },
                  child: Text(
                    '清空',
                    style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _searchHistory.take(_maxSearchHistoryCount).map((q) {
                return ActionChip(
                  label: Text(q),
                  backgroundColor: Colors.grey[100],
                  labelStyle: TextStyle(color: Colors.grey[700], fontSize: 13),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  onPressed: _isSending ? null : () => _sendMessage(q),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
          Text(
            '试试问：',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _suggestedQuestions.map((q) {
              return ActionChip(
                label: Text(q),
                backgroundColor: const Color(0xFF2196F3).withAlpha(25),
                labelStyle: const TextStyle(
                  color: Color(0xFF2196F3),
                  fontSize: 14,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                onPressed: _isSending ? null : () => _sendMessage(q),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// 消息列表
  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        return _buildMessageBubble(msg);
      },
    );
  }

  /// 消息气泡（支持可点击客户链接）
  Widget _buildMessageBubble(_ChatMessage msg) {
    final isUser = msg.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF2196F3) : Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        child: isUser
            ? Text(
                msg.content,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.5,
                ),
              )
            : _buildClickableText(msg.content),
      ),
    );
  }

  String _cleanAssistantAnswer(String text) {
    final hasCustomerLink = RegExp(
      r'(?:\[?[^\]\n|]{1,24}\|[0-9a-fA-F-]{36}\]?)',
    ).hasMatch(text);
    if (!hasCustomerLink) return text;

    final lines = text.split('\n');
    while (lines.isNotEmpty && lines.last.trim().isEmpty) {
      lines.removeLast();
    }
    if (lines.isEmpty) return text;

    final lastParagraphStart = lines.lastIndexWhere((line) {
      final trimmed = line.trim();
      return trimmed.isEmpty;
    });
    final paragraphStart = lastParagraphStart == -1
        ? 0
        : lastParagraphStart + 1;
    final lastParagraph = lines.sublist(paragraphStart).join('\n').trim();

    if (lastParagraph.startsWith('当前记录中') &&
        (lastParagraph.contains('没有') || lastParagraph.contains('不足'))) {
      return lines.sublist(0, paragraphStart).join('\n').trimRight();
    }

    return text;
  }

  /// 构建可点击文本（解析 [客户名|ID] 格式）
  Widget _buildClickableText(String text) {
    text = _cleanAssistantAnswer(text);
    final pipeRegex = RegExp(r'\[([^\]]+)\|([0-9a-fA-F-]{36})\]');
    final barePipeRegex = RegExp(
      r'(?<!\[)([\u4e00-\u9fa5A-Za-z][\u4e00-\u9fa5A-Za-z·]{1,20})\|([0-9a-fA-F-]{36})',
    );
    final markdownRegex = RegExp(
      r'\[([^\]]+)\]\((?:/customer-detail/|brokerassist://customer/)([0-9a-fA-F-]{36})\)',
    );
    final matches = <_InlineCustomerLinkMatch>[
      ...pipeRegex
          .allMatches(text)
          .map(
            (match) => _InlineCustomerLinkMatch(
              start: match.start,
              end: match.end,
              name: match.group(1) ?? '',
              id: match.group(2) ?? '',
            ),
          ),
      ...barePipeRegex
          .allMatches(text)
          .map(
            (match) => _InlineCustomerLinkMatch(
              start: match.start,
              end: match.end,
              name: match.group(1) ?? '',
              id: match.group(2) ?? '',
            ),
          ),
      ...markdownRegex
          .allMatches(text)
          .map(
            (match) => _InlineCustomerLinkMatch(
              start: match.start,
              end: match.end,
              name: match.group(1) ?? '',
              id: match.group(2) ?? '',
            ),
          ),
    ]..sort((a, b) => a.start.compareTo(b.start));

    final filteredMatches = <_InlineCustomerLinkMatch>[];
    var previousEnd = -1;
    for (final match in matches) {
      if (match.start < previousEnd) continue;
      filteredMatches.add(match);
      previousEnd = match.end;
    }

    if (filteredMatches.isEmpty) {
      // 没有链接，普通文本
      return Text(
        text,
        style: TextStyle(color: Colors.black87, fontSize: 15, height: 1.5),
      );
    }

    // 构建 RichText
    final List<TextSpan> spans = [];
    int currentPos = 0;

    for (final match in filteredMatches) {
      // 添加链接前的普通文本
      if (match.start > currentPos) {
        spans.add(
          TextSpan(
            text: text.substring(currentPos, match.start),
            style: TextStyle(color: Colors.black87, fontSize: 15, height: 1.5),
          ),
        );
      }

      // 提取客户名和ID
      final name = match.name;
      final id = match.id;

      // 添加可点击的客户链接
      spans.add(
        TextSpan(
          text: name,
          style: const TextStyle(
            color: Color(0xFF2196F3),
            fontSize: 15,
            height: 1.5,
            decoration: TextDecoration.underline,
            fontWeight: FontWeight.w500,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () => _openCustomerDetail(id),
        ),
      );

      currentPos = match.end;
    }

    // 添加最后的普通文本
    if (currentPos < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(currentPos),
          style: TextStyle(color: Colors.black87, fontSize: 15, height: 1.5),
        ),
      );
    }

    return RichText(text: TextSpan(children: spans));
  }

  /// 打开客户详情页
  void _openCustomerDetail(String customerId) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerDetailPage(), settings: RouteSettings(arguments: customerId)));
  }
}

class _InlineCustomerLinkMatch {
  final int start;
  final int end;
  final String name;
  final String id;

  _InlineCustomerLinkMatch({
    required this.start,
    required this.end,
    required this.name,
    required this.id,
  });
}
