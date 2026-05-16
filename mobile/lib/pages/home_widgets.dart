import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/api.dart';
import '../services/industry_settings.dart';
import '../theme/brand_colors.dart';
import '../widgets/customer_avatar.dart';
import 'customer_detail_page.dart';

class HomeColors {
  static const Color background = BrandColors.background;
  static const Color ink = BrandColors.ink;
  static const Color muted = BrandColors.muted;
  static const Color border = BrandColors.border;
  static const Color teal = BrandColors.primary;
  static const Color navy = BrandColors.navy;
  static const Color amber = BrandColors.amber;
}

class WorkspaceTitle extends StatelessWidget {
  final IndustryOption industry;

  const WorkspaceTitle({super.key, required this.industry});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          industry.workspaceLabel,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE7F5F2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                industry.label,
                style: const TextStyle(
                  color: HomeColors.teal,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class NewUserHome extends StatelessWidget {
  final VoidCallback onStartRecord;
  final VoidCallback onCreateCustomer;
  final VoidCallback onOpenAI;

  const NewUserHome({
    super.key,
    required this.onStartRecord,
    required this.onCreateCustomer,
    required this.onOpenAI,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        ValueListenableBuilder<IndustryOption>(
          valueListenable: IndustrySettings.selected,
          builder: (context, industry, _) => Column(
            children: [
              IndustryGuideBanner(industry: industry),
              const SizedBox(height: 14),
              const OnboardingFlowSteps(),
              const SizedBox(height: 14),
              RecordFirstCard(
                onTap: onStartRecord,
                onCreateCustomer: onCreateCustomer,
              ),
              const SizedBox(height: 14),
              IndustryQuickTip(tip: industry.quickTip),
              const SizedBox(height: 14),
              AiStarterCard(text: '问 AI：如何整理第一个客户？', onTap: onOpenAI),
            ],
          ),
        ),
      ],
    );
  }
}

class ExistingUserHome extends StatelessWidget {
  final List<Customer> recentCustomers;
  final int customerTotal;
  final int staleContactCount;
  final VoidCallback onStartRecord;
  final VoidCallback onQuickCreateCustomer;
  final VoidCallback onOpenCustomers;
  final VoidCallback onTapCustomers;
  final VoidCallback onTapStaleContact;
  final Widget reminderCard;

  const ExistingUserHome({
    super.key,
    required this.recentCustomers,
    required this.customerTotal,
    required this.staleContactCount,
    required this.onStartRecord,
    required this.onQuickCreateCustomer,
    required this.onOpenCustomers,
    required this.onTapCustomers,
    required this.onTapStaleContact,
    required this.reminderCard,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        SummaryStatsBar(
          customerTotal: customerTotal,
          staleContactCount: staleContactCount,
          onTapCustomers: onTapCustomers,
          onTapStaleContact: onTapStaleContact,
        ),
        const SizedBox(height: 14),
        reminderCard,
        const SizedBox(height: 14),
        QuickActionsRow(
          onRecord: onStartRecord,
          onCreateCustomer: onQuickCreateCustomer,
        ),
        const SizedBox(height: 14),
        SectionHeader(
          title: '最近客户',
          subtitle: '共 $customerTotal 位客户',
          actionLabel: '全部',
          onAction: onOpenCustomers,
        ),
        const SizedBox(height: 10),
        RecentCustomerList(
          customers: recentCustomers,
          onOpenCustomers: onOpenCustomers,
        ),
      ],
    );
  }
}

// ---- 老用户：快捷入口一行 ----

class QuickActionsRow extends StatelessWidget {
  final VoidCallback onRecord;
  final VoidCallback onCreateCustomer;

  const QuickActionsRow({
    super.key,
    required this.onRecord,
    required this.onCreateCustomer,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: _ActionButton(
            icon: Icons.edit_note_rounded,
            label: '快速增加一条沟通记录',
            onTap: onRecord,
            filled: true,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: _ActionButton(
            icon: Icons.person_add_outlined,
            label: '快速新建客户',
            onTap: onCreateCustomer,
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = filled ? HomeColors.teal : const Color(0xFFE7F5F2);
    final fgColor = filled ? Colors.white : HomeColors.teal;

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: filled
                ? null
                : Border.all(color: HomeColors.teal.withValues(alpha: 0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: fgColor, size: 24),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: fgColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---- 新用户：两个平级入口卡片 ----

class QuickCreateCard extends StatelessWidget {
  final VoidCallback onTap;

  const QuickCreateCard({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF0F766E),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.person_add_outlined,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '快速创建客户',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '仅需姓名 + 电话',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white54),
            ],
          ),
        ),
      ),
    );
  }
}

class RecordFirstCard extends StatelessWidget {
  final VoidCallback onTap;
  final VoidCallback onCreateCustomer;

  const RecordFirstCard({
    super.key,
    required this.onTap,
    required this.onCreateCustomer,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: HomeColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '先记录一次沟通',
              style: TextStyle(
                color: HomeColors.ink,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '你可以用文字、语音或图片记录，保存后 AI 会自动生成客户画像和下一步建议。',
              style: TextStyle(
                color: HomeColors.muted,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            _NewUserActionButton(
              onTap: onTap,
              icon: Icons.mic_none_outlined,
              title: '开始记录',
              subtitle: '文字、语音或图片都可以',
              backgroundColor: HomeColors.teal,
              foregroundColor: Colors.white,
              iconBackgroundColor: Colors.white24,
              borderColor: HomeColors.teal,
              shadowColor: HomeColors.teal.withAlpha(45),
            ),
            const SizedBox(height: 10),
            _NewUserActionButton(
              onTap: onCreateCustomer,
              icon: Icons.person_add_alt_1_outlined,
              title: '直接新建客户',
              subtitle: '先填写客户姓名和基础资料',
              backgroundColor: Colors.white,
              foregroundColor: HomeColors.teal,
              iconBackgroundColor: const Color(0xFFE7F5F2),
              borderColor: const Color(0xFF9DD7CE),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewUserActionButton extends StatelessWidget {
  final VoidCallback onTap;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color iconBackgroundColor;
  final Color borderColor;
  final Color? shadowColor;

  const _NewUserActionButton({
    required this.onTap,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.iconBackgroundColor,
    required this.borderColor,
    this.shadowColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(8),
      elevation: shadowColor == null ? 0 : 2,
      shadowColor: shadowColor,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          constraints: const BoxConstraints(minHeight: 68),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBackgroundColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: foregroundColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: foregroundColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: foregroundColor.withAlpha(210),
                        fontSize: 12,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: foregroundColor.withAlpha(190),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---- 极简快速建客户弹窗 ----

class QuickCreateCustomerSheet extends StatefulWidget {
  const QuickCreateCustomerSheet({super.key});

  @override
  State<QuickCreateCustomerSheet> createState() =>
      _QuickCreateCustomerSheetState();
}

class _QuickCreateCustomerSheetState extends State<QuickCreateCustomerSheet> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _ageController = TextEditingController();
  final _birthdayController = TextEditingController();
  final _locationController = TextEditingController();
  String? _gender;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _ageController.dispose();
    _birthdayController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入客户姓名')));
      return;
    }
    setState(() => _isSaving = true);
    try {
      final ageText = _ageController.text.trim();
      final response = await apiService.createCustomer(
        name: name,
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        gender: _gender,
        age: ageText.isNotEmpty ? int.tryParse(ageText) : null,
        birthday: _birthdayController.text.trim().isEmpty
            ? null
            : _birthdayController.text.trim(),
        location: _locationController.text.trim().isEmpty
            ? null
            : _locationController.text.trim(),
      );
      if (!mounted) return;
      if (response.success) {
        final customerId = response.data?['customer_id'] as String?;
        Navigator.pop(context, customerId);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('创建失败: ${response.error?.message ?? '未知错误'}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('创建失败: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '快速创建客户',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '仅需姓名，其他信息会由 AI 自动补全',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: '客户姓名 *',
                hintText: '请输入姓名',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: '电话',
                hintText: '选填',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ageController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: '年龄',
                hintText: '选填',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _birthdayController,
              keyboardType: TextInputType.datetime,
              decoration: InputDecoration(
                labelText: '生日',
                hintText: 'YYYY-MM-DD，选填',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _locationController,
              decoration: InputDecoration(
                labelText: '地址/区域',
                hintText: '如：海淀五路居、国贸',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Text(
                  '性别：',
                  style: TextStyle(color: HomeColors.muted, fontSize: 14),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('男'),
                  selected: _gender == 'male',
                  onSelected: (_) => setState(() => _gender = 'male'),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('女'),
                  selected: _gender == 'female',
                  onSelected: (_) => setState(() => _gender = 'female'),
                ),
                const SizedBox(width: 8),
                if (_gender != null)
                  GestureDetector(
                    onTap: () => setState(() => _gender = null),
                    child: const Text(
                      '清除',
                      style: TextStyle(fontSize: 12, color: HomeColors.muted),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isSaving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: HomeColors.teal,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('创建', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AiStarterCard extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const AiStarterCard({super.key, required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF102A43),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.smart_toy_outlined, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white70),
            ],
          ),
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: HomeColors.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: const TextStyle(color: HomeColors.muted, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
        TextButton(onPressed: onAction, child: Text(actionLabel)),
      ],
    );
  }
}

class RecentCustomerList extends StatelessWidget {
  final List<Customer> customers;
  final VoidCallback onOpenCustomers;

  const RecentCustomerList({
    super.key,
    required this.customers,
    required this.onOpenCustomers,
  });

  @override
  Widget build(BuildContext context) {
    if (customers.isEmpty) {
      return const MutedPanel(text: '最近客户会在这里显示。');
    }

    return Column(
      children: [
        for (final customer in customers.take(4))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: CustomerRowShell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CustomerDetailPage(),
                  settings: RouteSettings(arguments: customer.id),
                ),
              ),
              leading: CustomerAvatar(
                avatarUrl: customer.avatar,
                name: customer.name,
                radius: 19,
              ),
              title: customer.name,
              subtitle: _formatLastContact(customer.updatedAt),
              trailing: StatusBadge(summaryStatus: customer.summaryStatus),
            ),
          ),
      ],
    );
  }

  String _formatLastContact(DateTime? updatedAt) {
    if (updatedAt == null) return '暂无记录';
    final now = DateTime.now();
    final diff = now.difference(updatedAt);
    if (diff.inMinutes < 60) return '刚刚';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    if (diff.inDays == 1) return '昨天';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}周前';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}个月前';
    return '${(diff.inDays / 365).floor()}年前';
  }
}

class CustomerRowShell extends StatelessWidget {
  final Widget leading;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback onTap;

  const CustomerRowShell({
    super.key,
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: HomeColors.border),
          ),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: HomeColors.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: HomeColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class MutedPanel extends StatelessWidget {
  final String text;

  const MutedPanel({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: HomeColors.border),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: HomeColors.muted,
          fontSize: 13,
          height: 1.5,
        ),
      ),
    );
  }
}

class IndustryGuideBanner extends StatelessWidget {
  final IndustryOption industry;

  const IndustryGuideBanner({super.key, required this.industry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9F6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFE7F5F2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.lightbulb_outline_rounded,
                  color: HomeColors.teal,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  industry == IndustryOption.generic
                      ? '开始建立你的客户工作台'
                      : '${industry.label}行业工作台',
                  style: const TextStyle(
                    color: HomeColors.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '先建一位客户，再记录拜访过程 — AI 会帮你整理画像和跟进建议。',
            style: const TextStyle(
              color: HomeColors.muted,
              fontSize: 13,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  final String? summaryStatus;

  const StatusBadge({super.key, this.summaryStatus});

  @override
  Widget build(BuildContext context) {
    final info = _statusInfo(summaryStatus);
    if (info == null) return const SizedBox.shrink();

    final (label, color) = info;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  (String, Color)? _statusInfo(String? status) {
    switch (status) {
      case 'updating':
        return ('生成中', HomeColors.navy);
      case 'failed':
        return ('需关注', const Color(0xFFDC2626));
      default:
        return null;
    }
  }
}

class SummaryStatsBar extends StatelessWidget {
  final int customerTotal;
  final int staleContactCount;
  final VoidCallback onTapCustomers;
  final VoidCallback onTapStaleContact;

  const SummaryStatsBar({
    super.key,
    required this.customerTotal,
    required this.staleContactCount,
    required this.onTapCustomers,
    required this.onTapStaleContact,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: HomeColors.border),
      ),
      child: Row(
        children: [
          _StatItem(
            label: '客户',
            value: '$customerTotal',
            color: HomeColors.navy,
            onTap: onTapCustomers,
          ),
          _divider(),
          _StatItem(
            label: '超期未联系',
            value: '$staleContactCount',
            color: staleContactCount > 0
                ? const Color(0xFFDC2626)
                : HomeColors.muted,
            onTap: onTapStaleContact,
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(width: 1, height: 28, color: HomeColors.border);
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final VoidCallback onTap;

  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(color: HomeColors.muted, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---- 新人首页：三步流程示意 ----

class OnboardingFlowSteps extends StatelessWidget {
  const OnboardingFlowSteps({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: HomeColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _step(Icons.mic_none_outlined, '记录', '语音/文字/图片', '记一次沟通'),
          ),
          _arrow(),
          Expanded(
            child: _step(Icons.person_add_outlined, '归档', '创建客户', '挂到客户名下'),
          ),
          _arrow(),
          Expanded(
            child: _step(
              Icons.auto_awesome_outlined,
              'AI 整理',
              '自动生成画像',
              '随时查看建议',
            ),
          ),
        ],
      ),
    );
  }

  Widget _step(IconData icon, String title, String desc1, String desc2) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFE7F5F2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(icon, color: HomeColors.teal, size: 22),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: HomeColors.ink,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          desc1,
          style: const TextStyle(fontSize: 11, color: HomeColors.muted),
        ),
        Text(
          desc2,
          style: const TextStyle(fontSize: 11, color: HomeColors.muted),
        ),
      ],
    );
  }

  Widget _arrow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Icon(
        Icons.chevron_right_rounded,
        color: HomeColors.border,
        size: 20,
      ),
    );
  }
}

// ---- 新人首页：一句话实操提示 ----

class IndustryQuickTip extends StatelessWidget {
  final String tip;

  const IndustryQuickTip({super.key, required this.tip});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F6FF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.lightbulb_outline_rounded,
            color: HomeColors.navy,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '试试看：$tip',
              style: const TextStyle(
                fontSize: 13,
                height: 1.55,
                color: HomeColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HomeLoadingView extends StatelessWidget {
  const HomeLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 80, 20, 28),
      children: const [
        Center(child: CircularProgressIndicator()),
        SizedBox(height: 16),
        Center(
          child: Text('正在整理首页...', style: TextStyle(color: HomeColors.muted)),
        ),
      ],
    );
  }
}

class HomeErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const HomeErrorView({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 80, 20, 28),
      children: [
        const Icon(Icons.cloud_off_outlined, color: HomeColors.muted, size: 40),
        const SizedBox(height: 14),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: HomeColors.muted),
        ),
        const SizedBox(height: 16),
        FilledButton(onPressed: onRetry, child: const Text('重试')),
      ],
    );
  }
}
