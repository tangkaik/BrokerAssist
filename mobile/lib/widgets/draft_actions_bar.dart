import 'package:flutter/material.dart';

import '../theme/brand_colors.dart';

/// 底部操作按钮区
class DraftActionsBar extends StatelessWidget {
  final bool hasContent;
  final VoidCallback onCreateCustomer;
  final VoidCallback onAddToExisting;

  const DraftActionsBar({
    super.key,
    required this.hasContent,
    required this.onCreateCustomer,
    required this.onAddToExisting,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: hasContent ? onCreateCustomer : null,
                    icon: const Icon(Icons.person_add, size: 20),
                    label: const Text('创建新客户'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BrandColors.primary,
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
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: hasContent ? onAddToExisting : null,
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
            if (!hasContent)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '请先输入内容或录音后继续',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
