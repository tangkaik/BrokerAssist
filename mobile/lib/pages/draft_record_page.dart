import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../models/models.dart';
import '../services/api.dart';
import 'create_customer_page.dart';
import 'add_to_existing_page.dart';
import 'api_settings_page.dart';

/// 拜访记录录入页
///
/// 产品定位：文本框是核心，录音只是输入来源之一
class DraftRecordPage extends StatefulWidget {
  final String? customerId;
  final String? customerName;

  const DraftRecordPage({super.key, this.customerId, this.customerName});

  @override
  State<DraftRecordPage> createState() => _DraftRecordPageState();
}

class _DraftRecordPageState extends State<DraftRecordPage> {
  static const bool _showToolbarLabels = false;
  static const Color _background = Color(0xFFF6F7F9);
  static const Color _ink = Color(0xFF111827);
  static const Color _muted = Color(0xFF6B7280);
  static const Color _border = Color(0xFFE5E7EB);
  static const Color _teal = Color(0xFF0F766E);
  static const Color _navy = Color(0xFF1E3A5F);

  final ImagePicker _imagePicker = ImagePicker();

  /// 核心状态：草稿记录
  DraftRecord _draft = DraftRecord(createdAt: DateTime.now());

  /// 文本编辑器
  final TextEditingController _textController = TextEditingController();

  /// 录音相关
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isRecording = false;
  String? _recordedPath;
  bool _isPlaying = false;
  StateSetter? _audioSheetSetState;
  Duration _audioDuration = Duration.zero;
  Duration _audioPosition = Duration.zero;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;
  StreamSubscription<RecordState>? _recordStateSubscription;

  /// 转写相关
  bool _isTranscribing = false;
  String? _transcriptionId;
  Timer? _pollTimer;
  String? _transcriptionError;
  final List<XFile> _selectedImages = [];
  _ArchiveTarget _archiveTarget = _ArchiveTarget.existingCustomer;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _initAudioPlayer();
    _textController.addListener(_onTextChanged);

    // 监听录音状态（调试）
    _recordStateSubscription = _audioRecorder.onStateChanged().listen((state) {
      debugPrint('🎤 录音状态变化: $state');
      if (state == RecordState.stop && _isRecording) {
        debugPrint('⚠️ 录音意外停止！时长: ${_recordingDuration.inSeconds}s');
      }
    });
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _pollTimer?.cancel();
    _recordingTimer?.cancel();
    _recordStateSubscription?.cancel();
    super.dispose();
  }

  void _initAudioPlayer() {
    _audioPlayer.onPlayerStateChanged.listen((state) {
      debugPrint('🎵 播放器状态: $state');
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
        _refreshAudioSheet();
      }
    });
    _audioPlayer.onDurationChanged.listen((duration) {
      debugPrint('🎵 音频时长: ${duration.inSeconds}s');
      if (mounted) {
        setState(() {
          _audioDuration = duration;
        });
        _refreshAudioSheet();
      }
    });
    _audioPlayer.onPositionChanged.listen((position) {
      if (mounted) {
        setState(() {
          _audioPosition = position;
        });
        _refreshAudioSheet();
      }
    });
  }

  void _refreshAudioSheet() {
    _audioSheetSetState?.call(() {});
  }

  /// 开始录音
  Future<void> _startRecording() async {
    try {
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        _showError('请授权录音权限');
        return;
      }

      final dir = await getApplicationDocumentsDirectory();
      final path =
          '${dir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';

      debugPrint('🎙️ 开始录音，路径: $path');

      // 使用 AAC 格式，但确保配置正确
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 16000, // 讯飞推荐 16kHz
          bitRate: 64000, // 64kbps 足够语音识别
          numChannels: 1, // 单声道
        ),
        path: path,
      );

      setState(() {
        _isRecording = true;
        _recordedPath = path;
        _recordingDuration = Duration.zero;
        _transcriptionError = null;
      });
      _refreshAudioSheet();

      // 开始计时
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        debugPrint('⏱️ 录音中... ${_recordingDuration.inSeconds}s');
        setState(() {
          _recordingDuration += const Duration(seconds: 1);
        });
        _refreshAudioSheet();
      });
    } catch (e) {
      debugPrint('❌ 录音失败: $e');
      _showError('录音失败: $e');
    }
  }

  /// 停止录音
  Future<void> _stopRecording() async {
    try {
      await _audioRecorder.stop();
      _recordingTimer?.cancel();

      setState(() {
        _isRecording = false;
      });
      _refreshAudioSheet();

      // 预加载音频以获取时长
      if (_recordedPath != null) {
        try {
          // 等待文件写入完成（500ms延迟）
          await Future.delayed(const Duration(milliseconds: 500));

          // 检查文件大小
          final file = File(_recordedPath!);
          if (await file.exists()) {
            final size = await file.length();
            debugPrint('📁 录音文件大小: ${size}bytes');
          }

          await _audioPlayer.setSource(DeviceFileSource(_recordedPath!));

          // 等待音频加载完成
          await Future.delayed(const Duration(milliseconds: 300));

          // 获取音频时长
          final duration = await _audioPlayer.getDuration();
          debugPrint('🎵 获取到时长: ${duration?.inSeconds}s');

          if (duration != null && mounted) {
            setState(() {
              _audioDuration = duration;
            });
            _refreshAudioSheet();
          }
        } catch (e) {
          debugPrint('❌ 获取音频时长失败: $e');
        }
      }
    } catch (e) {
      _showError('停止录音失败: $e');
    }
  }

  /// 播放/暂停录音
  Future<void> _togglePlayback() async {
    if (_recordedPath == null) return;

    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
        debugPrint('⏸️ 暂停');
      } else {
        debugPrint('▶️ 播放请求，位置: ${_audioPosition.inSeconds}s');

        // 每次都重新加载，避免缓存问题
        await _audioPlayer.stop();
        await Future.delayed(const Duration(milliseconds: 100));

        await _audioPlayer.setSource(DeviceFileSource(_recordedPath!));
        await Future.delayed(const Duration(milliseconds: 200));

        // 从头开始播放
        await _audioPlayer.seek(Duration.zero);
        await _audioPlayer.play(DeviceFileSource(_recordedPath!));

        debugPrint('▶️ 播放命令已发送（重新加载音频）');
      }
    } catch (e) {
      debugPrint('❌ 播放失败: $e');
      _showError('播放失败: $e');
    }
  }

  /// 删除录音
  Future<void> _deleteRecording() async {
    await _audioPlayer.stop();
    if (_recordedPath != null) {
      final file = File(_recordedPath!);
      if (await file.exists()) {
        await file.delete();
      }
    }
    setState(() {
      _recordedPath = null;
      _audioDuration = Duration.zero;
      _audioPosition = Duration.zero;
      _transcriptionId = null;
      _transcriptionError = null;
    });
    _refreshAudioSheet();
  }

  Future<void> _confirmRestartRecording() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('重新开始？'),
          content: const Text('这会清除刚才的录音，是否继续？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('继续'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _deleteRecording();
    }
  }

  /// 手动触发转写
  Future<void> _startTranscription() async {
    if (_recordedPath == null) {
      _showError('请先录音');
      return;
    }

    setState(() {
      _isTranscribing = true;
      _transcriptionError = null;
    });
    _refreshAudioSheet();

    try {
      final response = await apiService.uploadAndTranscribe(_recordedPath!);

      if (response.success && response.data != null) {
        final transcription = response.data!;
        // 后端返回的字段名是 transcription_id，而不是 id
        final id =
            transcription['transcription_id'] as String? ??
            transcription['id'] as String?;
        if (id == null || id.isEmpty) {
          setState(() {
            _isTranscribing = false;
            _transcriptionError = '上传成功但返回数据异常: 缺少 transcription_id';
          });
          _refreshAudioSheet();
          return;
        }
        setState(() {
          _transcriptionId = id;
        });
        _refreshAudioSheet();
        _startPolling();
      } else {
        setState(() {
          _isTranscribing = false;
          _transcriptionError = response.error?.message ?? '上传失败';
        });
        _refreshAudioSheet();
      }
    } catch (e) {
      setState(() {
        _isTranscribing = false;
        _transcriptionError = '转写请求失败: $e';
      });
      _refreshAudioSheet();
    }
  }

  /// 开始轮询转写状态
  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (_transcriptionId == null) {
        timer.cancel();
        return;
      }

      try {
        final response = await apiService.getTranscription(_transcriptionId!);

        if (!mounted) return;

        if (response.success && response.data != null) {
          final transcription = Transcription.fromJson(response.data!);

          if (transcription.status == 'transcribed') {
            timer.cancel();
            final text = transcription.transcriptText ?? '';
            setState(() {
              _isTranscribing = false;
            });
            _refreshAudioSheet();
            _textController.text = text;
            _textController.selection = TextSelection.fromPosition(
              TextPosition(offset: text.length),
            );
          } else if (transcription.status == 'failed') {
            timer.cancel();
            setState(() {
              _isTranscribing = false;
              _transcriptionError =
                  transcription.errorMessage?.isNotEmpty == true
                  ? transcription.errorMessage
                  : '转写失败';
            });
            _refreshAudioSheet();
          }
        } else {
          timer.cancel();
          setState(() {
            _isTranscribing = false;
            _transcriptionError = '查询状态失败';
          });
          _refreshAudioSheet();
        }
      } catch (e) {
        if (!mounted) return;
        debugPrint('轮询错误: $e');
      }
    });
  }

  /// 文本变化时更新 draft
  void _onTextChanged() {
    final text = _textController.text;
    setState(() {
      _draft = DraftRecord(
        transcriptionId: _transcriptionId,
        transcriptText: text,
        customerId: _draft.customerId,
        imagePaths: _selectedImages.map((item) => item.path).toList(),
        createdAt: _draft.createdAt,
      );
    });
  }

  Future<void> _pickImages() async {
    final picked = await _imagePicker.pickMultiImage(imageQuality: 85);
    if (picked.isEmpty) return;
    setState(() {
      _selectedImages.addAll(picked);
      _draft = DraftRecord(
        transcriptionId: _transcriptionId,
        transcriptText: _textController.text,
        customerId: _draft.customerId,
        imagePaths: _selectedImages.map((item) => item.path).toList(),
        createdAt: _draft.createdAt,
      );
    });
  }

  Future<void> _takePhoto() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (picked == null) return;
    setState(() {
      _selectedImages.add(picked);
      _draft = DraftRecord(
        transcriptionId: _transcriptionId,
        transcriptText: _textController.text,
        customerId: _draft.customerId,
        imagePaths: _selectedImages.map((item) => item.path).toList(),
        createdAt: _draft.createdAt,
      );
    });
  }

  void _removeImage(XFile image) {
    setState(() {
      _selectedImages.remove(image);
      _draft = DraftRecord(
        transcriptionId: _transcriptionId,
        transcriptText: _textController.text,
        customerId: _draft.customerId,
        imagePaths: _selectedImages.map((item) => item.path).toList(),
        createdAt: _draft.createdAt,
      );
    });
  }

  /// 跳转创建新客户
  Future<void> _navigateToCreateCustomer() async {
    // 必须有文本内容才能继续
    if (!_hasTextContent) {
      _showError('请先输入记录内容');
      return;
    }
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CreateCustomerPage(),
        settings: RouteSettings(arguments: {'draft': _draft}),
      ),
    );
    // 如果创建成功，清空首页状态
    if (result == true && mounted) {
      _clearAll();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已完成客户创建，草稿已清空')));
    }
  }

  /// 跳转添加到老客户
  Future<void> _navigateToAddToExisting() async {
    // 必须有文本内容才能继续
    if (!_hasTextContent) {
      _showError('请先输入记录内容');
      return;
    }
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddToExistingPage(),
        settings: RouteSettings(arguments: {'draft': _draft}),
      ),
    );
    // 如果添加成功，清空首页状态
    if (result == true && mounted) {
      _clearAll();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已完成记录添加，草稿已清空')));
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _autoRefreshSummaryAndAdvice() async {
    final cid = widget.customerId;
    if (cid == null || cid.isEmpty) return;
    try {
      await apiService.generateSummary(cid);
      await apiService.generateAdvice(cid);
    } catch (_) {
      // 静默失败
    }
  }

  /// 清空所有内容
  void _clearAll() {
    _deleteRecording();
    _textController.clear();
    _pollTimer?.cancel();
    setState(() {
      _selectedImages.clear();
      _draft = DraftRecord(createdAt: DateTime.now());
      _transcriptionId = null;
      _transcriptionError = null;
      _isTranscribing = false;
    });
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  /// 检查文本框是否有有效内容
  /// 绑定到文本框内容，不依赖录音状态
  bool get _hasTextContent => _textController.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        title: GestureDetector(
          onLongPress: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ApiSettingsPage()),
            );
          },
          child: const Text('记录沟通'),
        ),
        backgroundColor: _background,
        foregroundColor: _ink,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: '清空',
            onPressed: _clearAll,
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
            if (keyboardVisible) {
              return SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSelectedCustomerBanner(),
                      SizedBox(
                        height: 280,
                        child: _buildTextArea(expanded: false),
                      ),
                      const SizedBox(height: 12),
                      _buildBottomActions(),
                    ],
                  ),
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSelectedCustomerBanner(),
                  _buildIntroCard(),
                  const SizedBox(height: 14),
                  Expanded(child: _buildTextArea(expanded: true)),
                  const SizedBox(height: 12),
                  _buildBottomActions(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSelectedCustomerBanner() {
    if (!_hasPreSelectedCustomer) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE7F5F2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.person, color: _teal, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '记录给：${widget.customerName ?? "客户"}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _teal,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFE7F5F2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.route_outlined, color: _teal),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  '1. 写下或录音记录本次沟通\n2. 提交到新客户或已有客户\n3. AI 自动整理画像和跟进建议',
                  style: TextStyle(color: _ink, fontSize: 13, height: 1.45),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建文本输入区域
  Widget _buildTextArea({bool expanded = false}) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (expanded)
            Expanded(child: _buildRecordTextField(expanded: true))
          else
            _buildRecordTextField(),
          if (_selectedImages.isNotEmpty) _buildAttachmentPreview(),
          _buildComposerToolbar(),
          if (_transcriptionError != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.all(16),
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
                      _transcriptionError!,
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
    );
  }

  Widget _buildRecordTextField({bool expanded = false}) {
    final field = TextField(
      controller: _textController,
      maxLines: null,
      minLines: expanded ? null : 6,
      expands: expanded,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      textAlignVertical: TextAlignVertical.top,
      scrollPadding: const EdgeInsets.fromLTRB(16, 24, 16, 160),
      decoration: InputDecoration(
        hintText: '记录这次拜访聊了什么，客户有什么需求、顾虑、下一步动作...',
        hintStyle: TextStyle(color: Colors.grey.shade400, height: 1.5),
        contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        border: InputBorder.none,
      ),
      style: const TextStyle(fontSize: 15, height: 1.5),
    );

    if (expanded) {
      return ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 180),
        child: field,
      );
    }

    return TextField(
      controller: _textController,
      maxLines: 10,
      minLines: 6,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      textAlignVertical: TextAlignVertical.top,
      scrollPadding: const EdgeInsets.fromLTRB(16, 24, 16, 160),
      decoration: InputDecoration(
        hintText: '记录这次拜访聊了什么，客户有什么需求、顾虑、下一步动作...',
        hintStyle: TextStyle(color: Colors.grey.shade400, height: 1.5),
        contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        border: InputBorder.none,
      ),
      style: const TextStyle(fontSize: 15, height: 1.5),
    );
  }

  Widget _buildAttachmentPreview() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: SizedBox(
        height: 78,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _selectedImages.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final image = _selectedImages[index];
            return Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(image.path),
                    width: 78,
                    height: 78,
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
                        size: 15,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildComposerToolbar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _border)),
      ),
      child: Row(
        children: [
          _buildToolbarAction(
            label: '图片',
            tooltip: '从相册选择图片',
            icon: Icons.image_outlined,
            onPressed: _pickImages,
          ),
          _buildToolbarAction(
            label: '相机',
            tooltip: '拍照',
            icon: Icons.photo_camera_outlined,
            onPressed: _takePhoto,
          ),
          if (_selectedImages.isNotEmpty) const SizedBox(width: 6),
          if (_selectedImages.isNotEmpty)
            Text(
              '${_selectedImages.length} 张图片',
              style: const TextStyle(
                color: _muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          const Spacer(),
          if (_isTranscribing) ...[
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 8),
            const Text('转写中', style: TextStyle(color: _muted, fontSize: 12)),
            const SizedBox(width: 8),
          ],
          _buildToolbarAction(
            label: '语音',
            tooltip: '语音输入',
            icon: Icons.mic_none_rounded,
            onPressed: _openAudioInputSheet,
          ),
        ],
      ),
    );
  }

  Widget _buildToolbarAction({
    required String label,
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    if (_showToolbarLabels) {
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: TextButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 18),
          label: Text(label),
          style: TextButton.styleFrom(
            foregroundColor: _navy,
            minimumSize: const Size(0, 40),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      );
    }

    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
      color: _navy,
    );
  }

  Future<void> _openAudioInputSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            _audioSheetSetState = setSheetState;
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [_buildAudioSection()],
                ),
              ),
            );
          },
        );
      },
    );
    _audioSheetSetState = null;
  }

  /// 构建音频输入区域
  Widget _buildAudioSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAudioRecorderHeader(),
          const SizedBox(height: 16),
          _buildAudioControls(),
        ],
      ),
    );
  }

  Widget _buildAudioRecorderHeader() {
    final hasRecording = _recordedPath != null;
    final label = _isTranscribing
        ? '正在转写'
        : _isRecording
        ? '听写中'
        : hasRecording
        ? '录音完成'
        : '语音听写';
    final time = _isRecording ? _recordingDuration : _audioDuration;

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: _ink,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Text(
          _formatDuration(time),
          style: const TextStyle(
            color: _muted,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  /// 录音控件
  Widget _buildAudioControls() {
    // 录音中状态
    if (_isRecording) {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _stopRecording,
              icon: const Icon(Icons.stop_rounded, size: 22),
              label: const Text('结束'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade500,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      );
    }

    // 有录音文件状态 - 显示播放控件和转写按钮
    if (_recordedPath != null) {
      return Column(
        children: [
          // 播放控件
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _border),
            ),
            child: Column(
              children: [
                // 播放/暂停按钮和进度
                Row(
                  children: [
                    // 播放/暂停按钮
                    IconButton(
                      onPressed: _isTranscribing ? null : _togglePlayback,
                      icon: Icon(
                        _isPlaying
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_filled,
                        size: 40,
                        color: _teal,
                      ),
                    ),
                    const SizedBox(width: 8),

                    // 进度条
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Slider(
                            value: _audioDuration.inMilliseconds > 0
                                ? _audioPosition.inMilliseconds /
                                      _audioDuration.inMilliseconds
                                : 0,
                            onChanged: _isTranscribing
                                ? null
                                : (value) async {
                                    final position = Duration(
                                      milliseconds:
                                          (value *
                                                  _audioDuration.inMilliseconds)
                                              .round(),
                                    );
                                    await _audioPlayer.seek(position);
                                  },
                            activeColor: _teal,
                            inactiveColor: Colors.grey.shade300,
                          ),
                          // 时间显示
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _formatDuration(_audioPosition),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                Text(
                                  _formatDuration(_audioDuration),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 8),

                    // 重新开始
                    IconButton(
                      onPressed: _isTranscribing
                          ? null
                          : _confirmRestartRecording,
                      icon: const Icon(Icons.refresh_rounded, color: _muted),
                      tooltip: '重新开始',
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // 转成文字按钮 - 必须明确可见
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isTranscribing ? null : _startTranscription,
              icon: _isTranscribing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.translate, size: 20),
              label: Text(_isTranscribing ? '转写中...' : '转成文字'),
              style: FilledButton.styleFrom(
                backgroundColor: _teal,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                disabledBackgroundColor: _teal.withValues(alpha: 0.45),
              ),
            ),
          ),
        ],
      );
    }

    // 初始状态 - 开始录音按钮（不那么突出）
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _startRecording,
        icon: const Icon(Icons.mic_none_rounded),
        label: const Text('开始'),
        style: FilledButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: _teal,
          minimumSize: const Size.fromHeight(54),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  /// 底部操作按钮区域
  Widget _buildBottomActions() {
    if (_hasPreSelectedCustomer) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: _hasTextContent && !_isSubmitting
              ? _submitToPreSelectedCustomer
              : null,
          icon: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.check_rounded, size: 20),
          label: Text(
            _isSubmitting ? '保存中...' : '保存到${widget.customerName ?? "客户"}',
          ),
          style: FilledButton.styleFrom(
            backgroundColor: _teal,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(52),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            disabledBackgroundColor: Colors.grey.shade200,
            disabledForegroundColor: Colors.grey.shade500,
          ),
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _hasTextContent ? _openArchiveTargetSheet : null,
        icon: const Icon(Icons.check_rounded, size: 20),
        label: const Text('提交'),
        style: FilledButton.styleFrom(
          backgroundColor: _teal,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          disabledBackgroundColor: Colors.grey.shade200,
          disabledForegroundColor: Colors.grey.shade500,
        ),
      ),
    );
  }

  bool get _hasPreSelectedCustomer =>
      widget.customerId != null && widget.customerId!.isNotEmpty;

  Future<void> _submitToPreSelectedCustomer() async {
    if (!_hasTextContent) {
      _showError('请先输入记录内容');
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final response = _selectedImages.isEmpty
          ? await apiService.createRecordDirect(
              customerId: widget.customerId!,
              content: _textController.text.trim(),
            )
          : await apiService.createRecordWithImages(
              customerId: widget.customerId!,
              content: _textController.text.trim(),
              imagePaths: _selectedImages.map((item) => item.path).toList(),
            );
      if (!mounted) return;
      if (response.success) {
        _clearAll();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已保存到${widget.customerName ?? "客户"}')),
        );
        // 后台刷新画像和建议
        _autoRefreshSummaryAndAdvice();
      } else {
        _showError(response.error?.message ?? '保存失败');
      }
    } catch (e) {
      if (mounted) _showError('保存失败: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _openArchiveTargetSheet() async {
    if (!_hasTextContent) {
      _showError('请先输入记录内容');
      return;
    }

    final selected = await showModalBottomSheet<_ArchiveTarget>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _ArchiveTargetSheet(current: _archiveTarget),
    );

    if (selected == null || !mounted) return;
    setState(() => _archiveTarget = selected);
    _continueArchive();
  }

  void _continueArchive() {
    if (_archiveTarget == _ArchiveTarget.existingCustomer) {
      _navigateToAddToExisting();
    } else {
      _navigateToCreateCustomer();
    }
  }
}

class _ArchiveTargetSheet extends StatefulWidget {
  const _ArchiveTargetSheet({required this.current});

  final _ArchiveTarget current;

  @override
  State<_ArchiveTargetSheet> createState() => _ArchiveTargetSheetState();
}

class _ArchiveTargetSheetState extends State<_ArchiveTargetSheet> {
  late _ArchiveTarget _selected = widget.current;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '这次记录属于谁？',
              style: TextStyle(
                color: _DraftRecordPageState._ink,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '选择这次记录要保存到哪里。',
              style: TextStyle(
                color: _DraftRecordPageState._muted,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 14),
            _buildArchiveChoice(
              value: _ArchiveTarget.existingCustomer,
              title: '已有客户',
              subtitle: '把拜访记录添加到已有客户',
              icon: Icons.people_alt_outlined,
            ),
            const SizedBox(height: 10),
            _buildArchiveChoice(
              value: _ArchiveTarget.newCustomer,
              title: '新客户',
              subtitle: '这是新客户拜访记录',
              icon: Icons.person_add_alt_1_rounded,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.pop(context, _selected),
                icon: const Icon(Icons.check_rounded, size: 20),
                label: const Text('提交'),
                style: FilledButton.styleFrom(
                  backgroundColor: _DraftRecordPageState._teal,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(50),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArchiveChoice({
    required _ArchiveTarget value,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final selected = _selected == value;

    return Material(
      color: selected ? const Color(0xFFE7F5F2) : Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () => setState(() => _selected = value),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? _DraftRecordPageState._teal
                  : _DraftRecordPageState._border,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected
                    ? _DraftRecordPageState._teal
                    : _DraftRecordPageState._muted,
              ),
              const SizedBox(width: 4),
              Icon(
                icon,
                color: selected
                    ? _DraftRecordPageState._teal
                    : _DraftRecordPageState._navy,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _DraftRecordPageState._ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: _DraftRecordPageState._muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _ArchiveTarget { existingCustomer, newCustomer }
