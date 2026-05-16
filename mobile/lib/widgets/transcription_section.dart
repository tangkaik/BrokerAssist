import 'package:flutter/material.dart';

import '../theme/brand_colors.dart';

/// 转写结果区域
class TranscriptionSection extends StatelessWidget {
  final String? error;
  final bool isTranscribing;

  const TranscriptionSection({
    super.key,
    this.error,
    this.isTranscribing = false,
  });

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade400, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                error!,
                style: TextStyle(color: Colors.red.shade700, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    if (isTranscribing) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: BrandColors.primarySoft,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 8),
            Text(
              '转写中...',
              style: TextStyle(color: BrandColors.primary, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
