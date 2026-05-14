import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:image_picker/image_picker.dart';
import '../models/models.dart';
import '../services/api.dart';
import '../services/auth_session.dart';
import '../services/chat_storage.dart';
import '../widgets/image_preview.dart';
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

class _SuggestionGroup {
  final String key;
  final String title;
  final IconData icon;
  final List<List<String>> variants;

  const _SuggestionGroup({
    required this.key,
    required this.title,
    required this.icon,
    required this.variants,
  });
}

const List<_SuggestionGroup> _realEstateSuggestionGroups = [
  _SuggestionGroup(
    key: 'query',
    title: '查客户数据',
    icon: Icons.manage_search,
    variants: [
      ['哪些客户两个月没联系了？', '列出预算敏感的客户', '住在海淀区、预算充足的客户有哪些？'],
      ['最近提到学区的客户有哪些？', '列出看房意向强的客户', '预算在500万以内的客户有哪些？'],
      ['哪些客户关注通勤和地铁？', '列出近期沟通过首付压力的客户', '有哪些客户适合本周优先跟进？'],
    ],
  ),
  _SuggestionGroup(
    key: 'assist',
    title: '客户跟进助手',
    icon: Icons.edit_note,
    variants: [
      ['给蔡凤霞写一段约看房微信', '总结张建国上次拜访，并给出这次建议', '明天见王女士，帮我准备会谈简报'],
      ['给蔡凤霞写一段跟进首付顾虑的微信', '整理张建国的预算和区域偏好', '见王女士前要确认哪些问题？'],
      ['给蔡凤霞写一段看房后的温和跟进微信', '张建国现在情况怎样，下一步怎么跟？', '王女士犹豫不决时怎么推进？'],
    ],
  ),
  _SuggestionGroup(
    key: 'help',
    title: '问产品用法',
    icon: Icons.help_outline,
    variants: [
      ['客户画像怎么生成？', '下一步建议在哪里看？', '怎样添加一次客户沟通记录？'],
      ['怎么给客户添加标签？', '语音记录怎么确认到客户？', 'AI助手能查哪些客户条件？'],
      ['行业选择后还能修改吗？', '客户列表怎么搜索拼音？', '图片记录可以识别什么？'],
    ],
  ),
];

const List<_SuggestionGroup> _insuranceSuggestionGroups = [
  _SuggestionGroup(
    key: 'query',
    title: '查客户数据',
    icon: Icons.manage_search,
    variants: [
      ['哪些客户两个月没联系了？', '列出关注重疾险的客户', '有健康告知顾虑的客户有哪些？'],
      ['列出预算敏感的客户', '哪些客户提到孩子保障？', '最近适合跟进保单配置的客户有哪些？'],
      ['列出关注养老规划的客户', '哪些客户还没有明确预算？', '有哪些客户适合本周优先跟进？'],
    ],
  ),
  _SuggestionGroup(
    key: 'assist',
    title: '客户跟进助手',
    icon: Icons.edit_note,
    variants: [
      ['给蔡凤霞写一段聊保障缺口的微信', '总结张建国上次拜访，并给出这次建议', '明天见王女士，帮我准备会谈简报'],
      ['给蔡凤霞写一段解释重疾险必要性的微信', '整理张建国的家庭责任和保障缺口', '见王女士前要确认哪些健康告知问题？'],
      ['给蔡凤霞写一段保费压力异议处理话术', '张建国现在情况怎样，下一步怎么跟？', '王女士一直拖延决策怎么推进？'],
    ],
  ),
  _SuggestionGroup(
    key: 'help',
    title: '问产品用法',
    icon: Icons.help_outline,
    variants: [
      ['客户画像怎么生成？', '下一步建议在哪里看？', '怎样添加一次客户沟通记录？'],
      ['怎么给客户添加标签？', '语音记录怎么确认到客户？', 'AI助手能查哪些客户条件？'],
      ['行业选择后还能修改吗？', '客户列表怎么搜索拼音？', '图片记录可以识别什么？'],
    ],
  ),
];

const List<_SuggestionGroup> _genericSuggestionGroups = [
  _SuggestionGroup(
    key: 'query',
    title: '查客户数据',
    icon: Icons.manage_search,
    variants: [
      ['哪些客户两个月没联系了？', '列出预算敏感的客户', '有哪些客户适合本周优先跟进？'],
      ['列出最近沟通频繁的客户', '哪些客户还没有明确需求？', '住在海淀区的客户有哪些？'],
      ['列出女性客户', '哪些客户提到价格顾虑？', '有多少客户超过两个月没联系？'],
    ],
  ),
  _SuggestionGroup(
    key: 'assist',
    title: '客户跟进助手',
    icon: Icons.edit_note,
    variants: [
      ['给蔡凤霞写一段跟进微信', '总结张建国上次沟通，并给出这次建议', '明天见王女士，帮我准备会谈简报'],
      ['给蔡凤霞写一段久未回复后的跟进微信', '整理张建国的需求和顾虑', '见王女士前要确认哪些问题？'],
      ['给蔡凤霞写一段温和确认时间的微信', '张建国现在情况怎样，下一步怎么跟？', '王女士犹豫时怎么推进？'],
    ],
  ),
  _SuggestionGroup(
    key: 'help',
    title: '问产品用法',
    icon: Icons.help_outline,
    variants: [
      ['客户画像怎么生成？', '下一步建议在哪里看？', '怎样添加一次客户沟通记录？'],
      ['怎么给客户添加标签？', '语音记录怎么确认到客户？', 'AI助手能查哪些客户条件？'],
      ['行业选择后还能修改吗？', '客户列表怎么搜索拼音？', '图片记录可以识别什么？'],
    ],
  ),
];

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

  /// 每个建议分组当前显示第几组问题
  final Map<String, int> _suggestionVariantIndex = {};

  /// 用于动态生成“客户跟进助手”建议的最近客户
  List<Customer> _suggestionCustomers = [];

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

  List<_SuggestionGroup> get _suggestionGroups {
    final industryKey = AuthSession.currentUser?.industryKey ?? 'generic';
    final baseGroups = switch (industryKey) {
      'insurance' => _insuranceSuggestionGroups,
      'real_estate' => _realEstateSuggestionGroups,
      _ => _genericSuggestionGroups,
    };
    if (_suggestionCustomers.isEmpty) {
      return baseGroups.map((group) {
        if (group.key != 'assist') return group;
        return _emptyCustomerAssistGroup(group);
      }).toList();
    }
    return baseGroups.map((group) {
      if (group.key != 'assist') return group;
      return _dynamicCustomerAssistGroup(group, industryKey);
    }).toList();
  }

  _SuggestionGroup _emptyCustomerAssistGroup(_SuggestionGroup baseGroup) {
    return _SuggestionGroup(
      key: baseGroup.key,
      title: baseGroup.title,
      icon: baseGroup.icon,
      variants: const [
        ['给某位客户写一段跟进微信', '总结某位客户上次沟通，并给出这次建议', '见客户前帮我准备会谈简报'],
        ['先添加客户和沟通记录，再让我写微信', '先选择一位客户，再让我总结上次拜访', '先保存客户记录，再让我准备问题清单'],
        ['给客户写微信时请带上客户姓名', '准备会谈简报时请带上客户姓名', '问下一步怎么跟时请带上客户姓名'],
      ],
    );
  }

  _SuggestionGroup _dynamicCustomerAssistGroup(
    _SuggestionGroup baseGroup,
    String industryKey,
  ) {
    final names = _suggestionCustomers
        .map((customer) => customer.name.trim())
        .where((name) => name.isNotEmpty)
        .toList();
    String nameAt(int index) => names[index % names.length];
    final first = nameAt(0);
    final second = nameAt(names.length > 1 ? 1 : 0);
    final third = nameAt(names.length > 2 ? 2 : names.length - 1);

    final variants = switch (industryKey) {
      'insurance' => [
          ['给$first写一段聊保障缺口的微信', '总结$second上次拜访，并给出这次建议', '明天见$third，帮我准备会谈简报'],
          ['给$first写一段解释重疾险必要性的微信', '整理$second的家庭责任和保障缺口', '见$third前要确认哪些健康告知问题？'],
          ['给$first写一段保费压力异议处理话术', '$second现在情况怎样，下一步怎么跟？', '$third一直拖延决策怎么推进？'],
        ],
      'real_estate' => [
          ['给$first写一段约看房微信', '总结$second上次拜访，并给出这次建议', '明天见$third，帮我准备会谈简报'],
          ['给$first写一段跟进首付顾虑的微信', '整理$second的预算和区域偏好', '见$third前要确认哪些问题？'],
          ['给$first写一段看房后的温和跟进微信', '$second现在情况怎样，下一步怎么跟？', '$third犹豫不决时怎么推进？'],
        ],
      _ => [
          ['给$first写一段跟进微信', '总结$second上次沟通，并给出这次建议', '明天见$third，帮我准备会谈简报'],
          ['给$first写一段久未回复后的跟进微信', '整理$second的需求和顾虑', '见$third前要确认哪些问题？'],
          ['给$first写一段温和确认时间的微信', '$second现在情况怎样，下一步怎么跟？', '$third犹豫时怎么推进？'],
        ],
    };

    return _SuggestionGroup(
      key: baseGroup.key,
      title: baseGroup.title,
      icon: baseGroup.icon,
      variants: variants,
    );
  }

  @override
  void initState() {
    super.initState();
    _initChatStorage();
    _loadSuggestionCustomers();
  }

  Future<void> _loadSuggestionCustomers() async {
    if (!AuthSession.isLoggedIn) return;
    try {
      final response = await apiService.getCustomers(page: 1, pageSize: 6);
      final customers = response.data?.items ?? <Customer>[];
      if (!mounted) return;
      setState(() {
        _suggestionCustomers = customers
            .where((customer) => customer.name.trim().isNotEmpty)
            .toList();
      });
    } catch (_) {
      // 建议问题加载失败不影响 AI 助手主流程。
    }
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

  void _rotateSuggestionGroup(_SuggestionGroup group) {
    final current = _suggestionVariantIndex[group.key] ?? 0;
    setState(() {
      _suggestionVariantIndex[group.key] =
          (current + 1) % group.variants.length;
    });
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

        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                // 建议问题
                if (_showSuggestions) _buildSuggestedQuestions(),

                const Divider(height: 1),

                // 空状态
                SizedBox(height: 260, child: _buildEmptyState()),
              ],
            ),
          ),
        ),
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
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => showLocalImagePreview(context, image),
              child: Image.file(
                File(image.path),
                width: previewSize,
                height: previewSize,
                fit: BoxFit.cover,
              ),
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
                    '查客户、客户跟进、问用法',
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
          ..._suggestionGroups.map(_buildSuggestionGroup),
        ],
      ),
    );
  }

  Widget _buildSuggestionGroup(_SuggestionGroup group) {
    final variantIndex =
        (_suggestionVariantIndex[group.key] ?? 0) % group.variants.length;
    final questions = group.variants[variantIndex];

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(group.icon, size: 16, color: const Color(0xFF4B5563)),
              const SizedBox(width: 6),
              Text(
                group.title,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF4B5563),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _isSending
                    ? null
                    : () => _rotateSuggestionGroup(group),
                icon: const Icon(Icons.refresh, size: 15),
                label: const Text('换一组'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF2196F3),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: questions.map((q) {
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

  /// 构建 Markdown 文本，并解析 [客户名|ID] 为可点击客户链接。
  Widget _buildClickableText(String text) {
    text = _cleanAssistantAnswer(text);
    final markdownText = _normalizeCustomerLinksForMarkdown(text);
    final baseStyle = const TextStyle(
      color: Colors.black87,
      fontSize: 15,
      height: 1.5,
    );

    return MarkdownBody(
      data: markdownText,
      selectable: true,
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        p: baseStyle,
        listBullet: baseStyle,
        strong: baseStyle.copyWith(fontWeight: FontWeight.w700),
        em: baseStyle.copyWith(fontStyle: FontStyle.italic),
        h1: baseStyle.copyWith(fontSize: 20, fontWeight: FontWeight.w700),
        h2: baseStyle.copyWith(fontSize: 18, fontWeight: FontWeight.w700),
        h3: baseStyle.copyWith(fontSize: 16, fontWeight: FontWeight.w700),
        blockquote: baseStyle.copyWith(color: Colors.black54),
        code: baseStyle.copyWith(
          fontFamily: 'monospace',
          backgroundColor: Colors.white.withAlpha(180),
        ),
        a: baseStyle.copyWith(
          color: const Color(0xFF2196F3),
          decoration: TextDecoration.underline,
          fontWeight: FontWeight.w600,
        ),
      ),
      onTapLink: (text, href, title) {
        final customerId = _extractCustomerIdFromHref(href);
        if (customerId != null) {
          _openCustomerDetail(customerId);
        }
      },
    );
  }

  String _normalizeCustomerLinksForMarkdown(String text) {
    final pipeRegex = RegExp(r'\[([^\]\n|]+)\|([0-9a-fA-F-]{36})\]');
    final barePipeRegex = RegExp(
      r'(?<!\[)([\u4e00-\u9fa5A-Za-z][\u4e00-\u9fa5A-Za-z·]{1,20})\|([0-9a-fA-F-]{36})',
    );
    return text
        .replaceAllMapped(pipeRegex, (match) {
          final name = match.group(1) ?? '';
          final id = match.group(2) ?? '';
          return '[$name](brokerassist://customer/$id)';
        })
        .replaceAllMapped(barePipeRegex, (match) {
          final name = match.group(1) ?? '';
          final id = match.group(2) ?? '';
          return '[$name](brokerassist://customer/$id)';
        });
  }

  String? _extractCustomerIdFromHref(String? href) {
    if (href == null || href.isEmpty) return null;
    final patterns = [
      RegExp(r'^brokerassist://customer/([0-9a-fA-F-]{36})$'),
      RegExp(r'^/customer-detail/([0-9a-fA-F-]{36})$'),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(href);
      if (match != null) {
        return match.group(1);
      }
    }
    return null;
  }

  /// 打开客户详情页
  void _openCustomerDetail(String customerId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerDetailPage(),
        settings: RouteSettings(arguments: customerId),
      ),
    );
  }
}
