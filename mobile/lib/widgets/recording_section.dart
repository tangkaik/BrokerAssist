import 'dart:async';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

/// 录音区域组件
class RecordingSection extends StatefulWidget {
  final void Function(String path) onRecordingComplete;

  const RecordingSection({super.key, required this.onRecordingComplete});

  @override
  State<RecordingSection> createState() => _RecordingSectionState();
}

class _RecordingSectionState extends State<RecordingSection> {
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  String? _recordedPath;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;
  StreamSubscription<RecordState>? _recordStateSubscription;

  @override
  void initState() {
    super.initState();
    _recordStateSubscription = _recorder.onStateChanged().listen((state) {
      debugPrint('🎤 录音状态变化: $state');
    });
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _recordStateSubscription?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        _showError('请授权录音权限');
        return;
      }

      final dir = await getApplicationDocumentsDirectory();
      final path =
          '${dir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 16000,
          bitRate: 64000,
          numChannels: 1,
        ),
        path: path,
      );

      setState(() {
        _isRecording = true;
        _recordedPath = path;
        _recordingDuration = Duration.zero;
      });

      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _recordingDuration += const Duration(seconds: 1);
        });
      });
    } catch (e) {
      _showError('录音失败: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      await _recorder.stop();
      _recordingTimer?.cancel();
      setState(() => _isRecording = false);
      if (_recordedPath != null) {
        widget.onRecordingComplete(_recordedPath!);
      }
    } catch (e) {
      _showError('停止录音失败: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: _isRecording
          ? Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '录音中 ${_formatDuration(_recordingDuration)}',
                  style: TextStyle(
                    color: Colors.red.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _stopRecording,
                  icon: const Icon(Icons.stop_circle, size: 20),
                  label: const Text('停止'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade500,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            )
          : OutlinedButton.icon(
              onPressed: _startRecording,
              icon: Icon(Icons.mic, color: Colors.red.shade500),
              label: const Text('开始录音'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey.shade700,
                side: BorderSide(color: Colors.grey.shade300),
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 20,
                ),
              ),
            ),
    );
  }
}
