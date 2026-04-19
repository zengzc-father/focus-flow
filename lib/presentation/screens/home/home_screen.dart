import 'package:flutter/material.dart';
import 'package:focus_flow/core/theme/app_theme.dart';
import 'package:focus_flow/data/services/usage_tracker.dart';
import 'package:focus_flow/data/services/notification_service.dart';
import 'package:focus_flow/presentation/screens/settings/settings_screen.dart';

/// 极简首页 - 只显示今日使用时间和简单设置
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final UsageTracker _tracker = UsageTracker();

  // 设置值
  int _continuousLimit = 45; // 分钟
  int _dailyLimit = 3; // 小时
  String _bedtime = '22:30';

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    // 初始化通知
    await NotificationService().initialize();
    // 启动使用追踪
    await _tracker.initialize();
    // 加载设置
    await _loadSettings();
    // 监听数据变化刷新UI
    _tracker.addListener(_onUsageChanged);
  }

  Future<void> _loadSettings() async {
    final settings = await _tracker.getSettings();
    setState(() {
      _continuousLimit = settings.continuousLimitMinutes;
      _dailyLimit = settings.dailyLimitHours;
      _bedtime = settings.bedtime;
    });
  }

  void _onUsageChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final todayMinutes = _tracker.todayTotalMinutes;
    final todayHours = todayMinutes ~/ 60;
    final remainingMinutes = todayMinutes % 60;
    final currentSession = _tracker.currentSessionMinutes;
    final lastBreak = _tracker.minutesSinceLastBreak;

    // 计算进度
    final dailyLimitMinutes = _dailyLimit * 60;
    final progress = (todayMinutes / dailyLimitMinutes).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '今日使用',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined),
                    onPressed: () => _openSettings(),
                  ),
                ],
              ),
              const SizedBox(height: 40),

              // 大数字显示
              Center(
                child: Column(
                  children: [
                    Text(
                      '$todayHours',
                      style: const TextStyle(
                        fontSize: 80,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    Text(
                      '小时 ${remainingMinutes}分',
                      style: const TextStyle(
                        fontSize: 20,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '/ $_dailyLimit小时',
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // 进度条
              Container(
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: FractionallySizedBox(
                  widthFactor: progress,
                  alignment: Alignment.centerLeft,
                  child: Container(
                    decoration: BoxDecoration(
                      color: progress > 1.0 ? AppTheme.warningColor : AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  '${(progress * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),

              const SizedBox(height: 60),

              // 简单信息卡片
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildInfoRow('连续使用', '$currentSession 分钟'),
                    const Divider(height: 16),
                    _buildInfoRow('上次休息', '$lastBreak 分钟前'),
                    const Divider(height: 16),
                    _buildInfoRow('睡觉提醒', _bedtime),
                  ],
                ),
              ),

              const Spacer(),

              // 底部提示
              Center(
                child: Text(
                  '超过${_continuousLimit}分钟或${_dailyLimit}小时会收到提醒',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            color: AppTheme.textSecondary,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    ).then((_) => _loadSettings());
  }

  @override
  void dispose() {
    _tracker.removeListener(_onUsageChanged);
    super.dispose();
  }
}
