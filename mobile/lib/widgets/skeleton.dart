import 'package:flutter/material.dart';

/// 骨架屏组件
class SkeletonBox extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 4,
  });

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _animation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(_animation.value, 0),
              end: Alignment(_animation.value + 1, 0),
              colors: [
                Colors.grey[300]!,
                Colors.grey[200]!,
                Colors.grey[300]!,
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 客户详情骨架屏
class CustomerDetailSkeleton extends StatelessWidget {
  const CustomerDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 基本信息卡片
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const SkeletonBox(width: 56, height: 56, borderRadius: 28),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    SkeletonBox(width: 120, height: 20, borderRadius: 4),
                    SizedBox(height: 8),
                    SkeletonBox(width: 80, height: 14, borderRadius: 4),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Summary 卡片
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SkeletonBox(width: 100, height: 16, borderRadius: 4),
                SizedBox(height: 12),
                SkeletonBox(width: double.infinity, height: 60, borderRadius: 8),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // 沟通记录标题
          const SkeletonBox(width: 100, height: 16, borderRadius: 4),
          const SizedBox(height: 12),
          // 记录卡片
          ...List.generate(3, (_) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: 80, height: 12, borderRadius: 4),
                  SizedBox(height: 8),
                  SkeletonBox(width: double.infinity, height: 14, borderRadius: 4),
                  SizedBox(height: 4),
                  SkeletonBox(width: 200, height: 14, borderRadius: 4),
                ],
              ),
            ),
          )),
        ],
      ),
    );
  }
}

/// AI 回答骨架屏
class AIAnswerSkeleton extends StatelessWidget {
  const AIAnswerSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          SkeletonBox(width: double.infinity, height: 14, borderRadius: 4),
          SizedBox(height: 8),
          SkeletonBox(width: 200, height: 14, borderRadius: 4),
          SizedBox(height: 8),
          SkeletonBox(width: 150, height: 14, borderRadius: 4),
        ],
      ),
    );
  }
}
