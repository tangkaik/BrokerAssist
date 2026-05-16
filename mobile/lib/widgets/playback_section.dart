import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

import '../theme/brand_colors.dart';

/// 播放控制区域组件
class PlaybackSection extends StatefulWidget {
  final String recordedPath;
  final VoidCallback onDelete;

  const PlaybackSection({
    super.key,
    required this.recordedPath,
    required this.onDelete,
  });

  @override
  State<PlaybackSection> createState() => _PlaybackSectionState();
}

class _PlaybackSectionState extends State<PlaybackSection> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  Duration _audioDuration = Duration.zero;
  Duration _audioPosition = Duration.zero;

  @override
  void initState() {
    super.initState();
    _initPlayer();
    _loadAudio();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _initPlayer() async {
    _player.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() => _isPlaying = state == PlayerState.playing);
      }
    });
    _player.onDurationChanged.listen((duration) {
      if (mounted) setState(() => _audioDuration = duration);
    });
    _player.onPositionChanged.listen((position) {
      if (mounted) setState(() => _audioPosition = position);
    });
  }

  Future<void> _loadAudio() async {
    try {
      await Future.delayed(const Duration(milliseconds: 500));
      final file = File(widget.recordedPath);
      if (await file.exists()) {
        await _player.setSource(DeviceFileSource(widget.recordedPath));
      }
    } catch (e) {
      debugPrint('加载音频失败: $e');
    }
  }

  Future<void> _togglePlayback() async {
    try {
      if (_isPlaying) {
        await _player.pause();
      } else {
        await _player.stop();
        await Future.delayed(const Duration(milliseconds: 100));
        await _player.setSource(DeviceFileSource(widget.recordedPath));
        await Future.delayed(const Duration(milliseconds: 200));
        await _player.seek(Duration.zero);
        await _player.play(DeviceFileSource(widget.recordedPath));
      }
    } catch (e) {
      debugPrint('播放失败: $e');
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _togglePlayback,
            icon: Icon(
              _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
              size: 40,
              color: BrandColors.primary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Slider(
                  value: _audioDuration.inMilliseconds > 0
                      ? _audioPosition.inMilliseconds / _audioDuration.inMilliseconds
                      : 0,
                  onChanged: (value) async {
                    final position = Duration(
                      milliseconds: (value * _audioDuration.inMilliseconds).round(),
                    );
                    await _player.seek(position);
                  },
                  activeColor: BrandColors.primary,
                  inactiveColor: Colors.grey.shade300,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(_audioPosition),
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                      Text(
                        _formatDuration(_audioDuration),
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: widget.onDelete,
            icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
            tooltip: '删除录音',
          ),
        ],
      ),
    );
  }
}
