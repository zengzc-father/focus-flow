import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_flow/core/theme/app_theme.dart';
import 'package:focus_flow/data/services/rule_engine.dart';

/// 规则管理页面
/// 展示和管理Agent生成的智能规则
class RulesScreen extends ConsumerStatefulWidget {
  const RulesScreen({super.key});

  @override
  ConsumerState<RulesScreen> createState() => _RulesScreenState();
}

class _RulesScreenState extends ConsumerState<RulesScreen> {
  final List<SmartRule> _rules = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRules();
  }

  Future<void> _loadRules() async {
    // 模拟加载规则
    await Future.delayed(const Duration(milliseconds: 500));

    setState(() {
      _rules.addAll([
        SmartRule(
          id: '1',
          name: '晚间使用限制',
          condition: RuleCondition(timeAfter: '20:00', dailyUsageOver: 240),
          action: RuleAction(
            type: RuleActionType.notify,
            title: '晚间提醒',
            message: '今天使用已达标，建议休息',
          ),
          createdAt: DateTime.now().subtract(const Duration(days: 3)),
        ),
        SmartRule(
          id: '2',
          name: '抖音超时提醒',
          condition: RuleCondition(consecutiveUseOver: 30, apps: ['douyin']),
          action: RuleAction(
            type: RuleActionType.suggestActivity,
          ),
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
        SmartRule(
          id: '3',
          name: '学习时段保护',
          condition: RuleCondition(timeAfter: '08:00', timeBefore: '12:00'),
          action: RuleAction(
            type: RuleActionType.notify,
            title: '学习提醒',
            message: '现在是高效学习时段，保持专注',
          ),
          isEnabled: false,
          createdAt: DateTime.now().subtract(const Duration(days: 5)),
        ),
      ]);
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('智能规则'),
        actions: [
          TextButton.icon(
            onPressed: _createNewRule,
            icon: const Icon(Icons.add),
            label: const Text('新建'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _rules.isEmpty
              ? _buildEmptyState()
              : _buildRulesList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.rule_folder_outlined,
            size: 80,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(height: 24),
          const Text(
            '暂无智能规则',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Agent会自动根据你的使用习惯创建规则\n你也可以手动添加',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _createNewRule,
            icon: const Icon(Icons.add),
            label: const Text('创建第一条规则'),
          ),
        ],
      ),
    );
  }

  Widget _buildRulesList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _rules.length,
      itemBuilder: (context, index) {
        final rule = _rules[index];
        return _buildRuleCard(rule);
      },
    );
  }

  Widget _buildRuleCard(SmartRule rule) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: rule.isEnabled
                    ? AppTheme.primaryColor.withOpacity(0.1)
                    : Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getRuleIcon(rule.action.type),
                color: rule.isEnabled ? AppTheme.primaryColor : Colors.grey,
              ),
            ),
            title: Text(
              rule.name,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: rule.isEnabled ? AppTheme.textPrimary : Colors.grey,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _buildConditionText(rule.condition),
                style: TextStyle(
                  fontSize: 13,
                  color: rule.isEnabled
                      ? AppTheme.textSecondary
                      : Colors.grey[400],
                ),
              ),
            ),
            trailing: Switch(
              value: rule.isEnabled,
              onChanged: (value) => _toggleRule(rule, value),
              activeColor: AppTheme.primaryColor,
            ),
          ),
          const Divider(height: 1, indent: 20, endIndent: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                _buildActionBadge(rule.action),
                const Spacer(),
                Text(
                  '${_daysSince(rule.createdAt)}天前创建',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[400],
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  onSelected: (value) => _handleMenuAction(value, rule),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 18),
                          SizedBox(width: 8),
                          Text('编辑'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'test',
                      child: Row(
                        children: [
                          Icon(Icons.play_arrow, size: 18),
                          SizedBox(width: 8),
                          Text('测试'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red, size: 18),
                          SizedBox(width: 8),
                          Text('删除', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getRuleIcon(RuleActionType type) {
    switch (type) {
      case RuleActionType.notify:
        return Icons.notifications_active_outlined;
      case RuleActionType.suggestActivity:
        return Icons.lightbulb_outline;
      case RuleActionType.lockApp:
        return Icons.lock_outline;
    }
  }

  String _buildConditionText(RuleCondition condition) {
    final parts = <String>[];

    if (condition.timeAfter != null) {
      parts.add('${_formatTime(condition.timeAfter!)}后');
    }
    if (condition.timeBefore != null) {
      parts.add('${_formatTime(condition.timeBefore!)}前');
    }
    if (condition.dailyUsageOver != null) {
      parts.add('使用超${condition.dailyUsageOver}分钟');
    }
    if (condition.consecutiveUseOver != null) {
      parts.add('连续使用${condition.consecutiveUseOver}分钟');
    }
    if (condition.apps != null && condition.apps!.isNotEmpty) {
      parts.add('使用${condition.apps!.first}等应用');
    }

    return parts.join(' + ');
  }

  String _formatTime(String time) {
    final parts = time.split(':');
    if (parts.length == 2) {
      return '${parts[0]}:${parts[1]}';
    }
    return time;
  }

  Widget _buildActionBadge(RuleAction action) {
    IconData icon;
    String label;
    Color color;

    switch (action.type) {
      case RuleActionType.notify:
        icon = Icons.notifications;
        label = '通知提醒';
        color = AppTheme.primaryColor;
        break;
      case RuleActionType.suggestActivity:
        icon = Icons.lightbulb;
        label = '推荐活动';
        color = AppTheme.successColor;
        break;
      case RuleActionType.lockApp:
        icon = Icons.lock;
        label = '限制应用';
        color = AppTheme.warningColor;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  int _daysSince(DateTime date) {
    return DateTime.now().difference(date).inDays;
  }

  void _toggleRule(SmartRule rule, bool value) {
    setState(() {
      final index = _rules.indexWhere((r) => r.id == rule.id);
      if (index != -1) {
        _rules[index] = SmartRule(
          id: rule.id,
          name: rule.name,
          condition: rule.condition,
          action: rule.action,
          isEnabled: value,
          createdAt: rule.createdAt,
        );
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(value ? '规则已启用' : '规则已禁用'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _handleMenuAction(String action, SmartRule rule) {
    switch (action) {
      case 'edit':
        _editRule(rule);
        break;
      case 'test':
        _testRule(rule);
        break;
      case 'delete':
        _deleteRule(rule);
        break;
    }
  }

  void _editRule(SmartRule rule) {
    // 跳转到编辑页面
  }

  void _testRule(SmartRule rule) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('测试规则'),
        content: Text('模拟触发规则"${rule.name}"？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // 触发测试通知
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('测试通知已发送')),
              );
            },
            child: const Text('测试'),
          ),
        ],
      ),
    );
  }

  void _deleteRule(SmartRule rule) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除规则'),
        content: Text('确定删除规则"${rule.name}"吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              setState(() => _rules.removeWhere((r) => r.id == rule.id));
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _createNewRule() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // 拖动指示器
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // 标题
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Text(
                    '创建新规则',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      // 使用AI创建
                      _showAICreateDialog();
                    },
                    icon: const Icon(Icons.auto_fix_high),
                    label: const Text('AI创建'),
                  ),
                ],
              ),
            ),
            // 创建表单（简化版）
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        labelText: '规则名称',
                        hintText: '例如：晚间使用限制',
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('触发条件'),
                    // 更多表单字段...
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAICreateDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.psychology, color: AppTheme.primaryColor),
            SizedBox(width: 8),
            Text('让AI创建规则'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('用自然语言描述你想要的规则'),
            const SizedBox(height: 16),
            TextField(
              maxLines: 3,
              decoration: InputDecoration(
                hintText: '例如：晚上8点后如果我刷抖音超过30分钟就提醒我',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // 调用Agent创建规则
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Agent正在分析并创建规则...')),
              );
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }
}
