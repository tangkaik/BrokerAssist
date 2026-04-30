import 'package:flutter/material.dart';

import '../services/industry_settings.dart';

const Color _ink = Color(0xFF111827);
const Color _muted = Color(0xFF6B7280);
const Color _border = Color(0xFFE5E7EB);
const Color _teal = Color(0xFF0F766E);
const Color _navy = Color(0xFF1E3A5F);

Future<IndustryOption?> showIndustryPicker(
  BuildContext context, {
  required IndustryOption current,
  String title = '选择行业',
  String subtitle = '先选一个工作区方向，后续客户画像和跟进建议会按行业调整。',
  bool requireSelection = false,
}) {
  return showModalBottomSheet<IndustryOption>(
    context: context,
    isDismissible: !requireSelection,
    enableDrag: !requireSelection,
    showDragHandle: !requireSelection,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => _IndustryPickerSheet(
      current: current,
      title: title,
      subtitle: subtitle,
    ),
  );
}

class _IndustryPickerSheet extends StatelessWidget {
  final IndustryOption current;
  final String title;
  final String subtitle;

  const _IndustryPickerSheet({
    required this.current,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: _ink,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(color: _muted, fontSize: 13, height: 1.45),
            ),
            const SizedBox(height: 14),
            for (final option in IndustryOption.options)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _IndustryOptionTile(
                  option: option,
                  selected: option.key == current.key,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _IndustryOptionTile extends StatelessWidget {
  final IndustryOption option;
  final bool selected;

  const _IndustryOptionTile({required this.option, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFE7F5F2) : const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () => Navigator.pop(context, option),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: selected ? _teal : _border),
          ),
          child: Row(
            children: [
              Icon(option.icon, color: selected ? _teal : _navy),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.label,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      option.workspaceLabel,
                      style: const TextStyle(color: _muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle_rounded, color: _teal),
            ],
          ),
        ),
      ),
    );
  }
}
