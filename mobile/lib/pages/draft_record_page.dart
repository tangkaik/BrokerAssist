import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../models/models.dart';
import '../services/api.dart';

/// 拜访记录录入页
///
/// 产品定位：文本框是核心，录音只是输入来源之一
class DraftRecordPage extends StatefulWidget {
  const DraftRecordPage({super.key});

  @override
  State<DraftRecordPage> createState() => _DraftRecordPageState();
}

class _DraftRecordPageState extends State<DraftRecordPage> {
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
      }
    });
    _audioPlayer.onDurationChanged.listen((duration) {
      debugPrint('🎵 音频时长: ${duration.inSeconds}s');
      if (mounted) {
        setState(() {
          _audioDuration = duration;
        });
      }
    });
    _audioPlayer.onPositionChanged.listen((position) {
      if (mounted) {
        setState(() {
          _audioPosition = position;
        });
      }
    });
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

      // 开始计时
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        debugPrint('⏱️ 录音中... ${_recordingDuration.inSeconds}s');
        setState(() {
          _recordingDuration += const Duration(seconds: 1);
        });
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
          return;
        }
        setState(() {
          _transcriptionId = id;
        });
        _startPolling();
      } else {
        setState(() {
          _isTranscribing = false;
          _transcriptionError = response.error?.message ?? '上传失败';
        });
      }
    } catch (e) {
      setState(() {
        _isTranscribing = false;
        _transcriptionError = '转写请求失败: $e';
      });
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
          }
        } else {
          timer.cancel();
          setState(() {
            _isTranscribing = false;
            _transcriptionError = '查询状态失败';
          });
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
    final result = await Navigator.pushNamed(
      context,
      '/create-customer',
      arguments: {'draft': _draft},
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
    final result = await Navigator.pushNamed(
      context,
      '/add-to-existing',
      arguments: {'draft': _draft},
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
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: GestureDetector(
          onLongPress: () {
            Navigator.pushNamed(context, '/api-settings');
          },
          child: const Text('拜访记录'),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        actions: [
          TextButton.icon(
            onPressed: _clearAll,
            icon: const Icon(Icons.clear_all, size: 18),
            label: const Text('清空'),
            style: TextButton.styleFrom(foregroundColor: Colors.grey.shade600),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTextArea(),
                    const SizedBox(height: 16),
                    _buildImageSection(),
                    const SizedBox(height: 16),
                    _buildAudioSection(),
                  ],
                ),
              ),
            ),
            _buildBottomActions(),
          ],
        ),
      ),
    );
  }

  /// 构建文本输入区域
  Widget _buildTextArea() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题栏
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Icon(Icons.edit_note, size: 18, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Text(
                  '记录内容',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                ),
                if (_isTranscribing) ...[
                  const SizedBox(width: 8),
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '转写中...',
                    style: TextStyle(fontSize: 12, color: Colors.blue.shade600),
                  ),
                ],
              ],
            ),
          ),

          // 文本框
          TextField(
            controller: _textController,
            maxLines: 8,
            minLines: 4,
            decoration: InputDecoration(
              hintText: '请输入记录内容，或使用下方录音功能...',
              hintStyle: TextStyle(color: Colors.grey.shade400),
              contentPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              border: InputBorder.none,
            ),
          ),

          // 转写错误提示
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

  /// 构建音频输入区域
  Widget _buildAudioSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题栏
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                Icon(Icons.mic, size: 18, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Text(
                  '语音输入',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                ),
                const Spacer(),
                // 录音状态标签
                if (_isRecording)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '录音中 ${_formatDuration(_recordingDuration)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // 录音控件区域
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _buildAudioControls(),
          ),
        ],
      ),
    );
  }

  Widget _buildImageSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.photo_library_outlined,
                  size: 18,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 8),
                Text(
                  '图片附件',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _pickImages,
                  icon: const Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 18,
                  ),
                  label: const Text('添加图片'),
                ),
              ],
            ),
            Text(
              _selectedImages.isEmpty
                  ? '先把拜访照片、聊天截图或保单图片带上，后面新建客户或补到老客户时会一起上传。'
                  : '已选择 ${_selectedImages.length} 张图片',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
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
                          width: 92,
                          height: 92,
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
      ),
    );
  }

  /// 录音控件
  Widget _buildAudioControls() {
    // 录音中状态
    if (_isRecording) {
      return Row(
        children: [
          // 停止录音按钮
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _stopRecording,
              icon: const Icon(Icons.stop_circle, size: 24),
              label: const Text('停止录音'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade500,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
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
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                // 播放/暂停按钮和进度
                Row(
                  children: [
                    // 播放/暂停按钮
                    IconButton(
                      onPressed: _togglePlayback,
                      icon: Icon(
                        _isPlaying
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_filled,
                        size: 40,
                        color: Colors.blue.shade600,
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
                            onChanged: (value) async {
                              final position = Duration(
                                milliseconds:
                                    (value * _audioDuration.inMilliseconds)
                                        .round(),
                              );
                              await _audioPlayer.seek(position);
                            },
                            activeColor: Colors.blue.shade600,
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

                    // 删除按钮
                    IconButton(
                      onPressed: _deleteRecording,
                      icon: Icon(
                        Icons.delete_outline,
                        color: Colors.red.shade400,
                      ),
                      tooltip: '删除录音',
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // 转写成文字按钮 - 必须明确可见
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
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
              label: Text(_isTranscribing ? '转写中...' : '转写成文字'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                disabledBackgroundColor: Colors.blue.shade300,
              ),
            ),
          ),
        ],
      );
    }

    // 初始状态 - 开始录音按钮（不那么突出）
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _startRecording,
        icon: Icon(Icons.mic, color: Colors.red.shade500),
        label: const Text('开始录音'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.grey.shade700,
          side: BorderSide(color: Colors.grey.shade300),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  /// 底部操作按钮区域
  Widget _buildBottomActions() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      padding: const EdgeInsets.all(16),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 两个主操作按钮
            Row(
              children: [
                // 创建新客户
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _hasTextContent
                        ? _navigateToCreateCustomer
                        : null,
                    icon: const Icon(Icons.person_add, size: 20),
                    label: const Text('创建新客户'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      disabledBackgroundColor: Colors.grey.shade200,
                      disabledForegroundColor: Colors.grey.shade400,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // 添加到老客户
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _hasTextContent
                        ? _navigateToAddToExisting
                        : null,
                    icon: const Icon(Icons.person_add_alt_1, size: 20),
                    label: const Text('添加到老客户'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
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

            // 空状态提示
            if (!_hasTextContent)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '请先输入内容或录音后继续',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
