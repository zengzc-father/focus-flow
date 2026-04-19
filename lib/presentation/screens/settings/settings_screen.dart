import 'package:flutter/material.dart';
import 'package:focus_flow/core/theme/app_theme.dart';
import 'package:focus_flow/data/services/usage_tracker.dart';
import 'package:focus_flow/data/services/rule_engine.dart';
import 'package:focus_flow/data/services/notification_service.dart';

/// 极简设置页面
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _continuousLimit = 45;
  int _dailyLimit = 3;
  String _bedtime = '22:30';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await UsageTracker().getSettings();
    setState(() {
      _continuousLimit = settings.continuousLimitMinutes;
      _dailyLimit = settings.dailyLimitHours;
      _bedtime = settings.bedtime;
    });
  }

  Future<void> _saveSettings() async {
    await UsageTracker().updateSettings(
      continuousLimit: _continuousLimit,
      dailyLimit: _dailyLimit,
      bedtime: _bedtime,
    );
    await RuleEngine().updateBasicSettings(
      continuousLimit: _continuousLimit,
      dailyLimit: _dailyLimit,
      bedtime: _bedtime,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('设置'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // 连续使用提醒
          _buildSettingCard(
            icon: Icons.timer,
            title: '连续使用提醒',
            subtitle: '超过设定时间后提醒休息',
            child: Row(
              children: [
                Text(
                  '$_continuousLimit 分钟',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
                Expanded(
                  child: Slider(
                    value: _continuousLimit.toDouble(),
                    min: 15,
                    max: 120,
                    divisions: 21,
                    onChanged: (v) => setState(() => _continuousLimit = v.round()),
                    onChangeEnd: (_) => _saveSettings(),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 每日上限
          _buildSettingCard(
            icon: Icons.today,
            title: '每日使用上限',
            subtitle: '超过后提醒注意休息',
            child: Row(
              children: [
                Text(
                  '$_dailyLimit 小时',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
                Expanded(
                  child: Slider(
                    value: _dailyLimit.toDouble(),
                    min: 1,
                    max: 12,
                    divisions: 11,
                    onChanged: (v) => setState(() => _dailyLimit = v.round()),
                    onChangeEnd: (_) => _saveSettings(),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 睡觉提醒
          _buildSettingCard(
            icon: Icons.bedtime,
            title: '睡觉提醒',
            subtitle: '提醒准备休息',
            child: ListTile(
              title: const Text('提醒时间'),
              trailing: Text(
                _bedtime,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryColor,
                ),
              ),
              onTap: () => _selectBedtime(),
            ),
          ),

          const SizedBox(height: 32),

          // 测试按钮
          Center(
            child: OutlinedButton(
              onPressed: () async {
                await NotificationService().showNotification(
                  title: '测试提醒',
                  body: '这是一条测试通知，你的设置正常工作！',
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('测试通知已发送')),
                );
              },
              child: const Text('测试提醒'),
            ),
          ),

          const SizedBox(height: 32),

          // 版本
          Center(
            child: Text(
              'Focus Flow Lite v1.0.0',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[400],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.primaryColor),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Future<void> _selectBedtime() async {
    final parts = _bedtime.split(':');
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      ),
    );
    if (time != null) {
      setState(() {
        _bedtime = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
      });
      await _saveSettings();
    }
  }
}
