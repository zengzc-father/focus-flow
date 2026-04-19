import 'package:flutter/material.dart';
import 'package:focus_flow/core/theme/app_theme.dart';

class AppUsageList extends StatelessWidget {
  const AppUsageList({super.key});

  final List<Map<String, dynamic>> _mockApps = const [
    {'name': '微信', 'category': '社交', 'time': '1小时12分', 'percent': 35, 'color': 0xFF07C160},
    {'name': '抖音', 'category': '娱乐', 'time': '48分钟', 'percent': 24, 'color': 0xFF000000},
    {'name': '哔哩哔哩', 'category': '娱乐', 'time': '32分钟', 'percent': 16, 'color': 0xFFFB7299},
    {'name': '学习通', 'category': '学习', 'time': '25分钟', 'percent': 12, 'color': 0xFF2196F3},
    {'name': '其他应用', 'category': '其他', 'time': '35分钟', 'percent': 13, 'color': 0xFF9E9E9E},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: _mockApps.map((app) => _buildAppItem(app)).toList(),
      ),
    );
  }

  Widget _buildAppItem(Map<String, dynamic> app) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          // 应用图标占位
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Color(app['color'] as int).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                app['name'].toString().substring(0, 1),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(app['color'] as int),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      app['name'],
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      app['time'],
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (app['percent'] as int) / 100,
                          backgroundColor: AppTheme.dividerColor,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(app['color'] as int),
                          ),
                          minHeight: 6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${app['percent']}%',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(app['color'] as int),
                        fontWeight: FontWeight.w600,
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
}
