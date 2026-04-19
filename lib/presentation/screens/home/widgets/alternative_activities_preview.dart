import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:focus_flow/core/theme/app_theme.dart';
import 'package:focus_flow/data/services/alternative_activities_service.dart';
import 'package:focus_flow/data/models/app_usage.dart';

class AlternativeActivitiesPreview extends StatelessWidget {
  const AlternativeActivitiesPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final service = AlternativeActivitiesService();
    final activities = service.getSuggestionsByUsageTime(45, limit: 3);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '替代活动建议',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            TextButton(
              onPressed: () => context.push('/alternatives'),
              child: const Text('查看全部'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...activities.map((activity) => _buildActivityCard(context, activity)),
      ],
    );
  }

  Widget _buildActivityCard(BuildContext context, AlternativeActivity activity) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: _getCategoryColor(activity.category).withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                activity.icon,
                style: const TextStyle(fontSize: 28),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${activity.suggestedDuration}分钟 · ${_getCategoryName(activity.category)}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
                if (activity.benefit != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    activity.benefit!,
                    style: TextStyle(
                      fontSize: 12,
                      color: _getCategoryColor(activity.category),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right,
            color: AppTheme.textSecondary,
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(ActivityCategory category) {
    switch (category) {
      case ActivityCategory.study:
        return AppTheme.primaryColor;
      case ActivityCategory.exercise:
        return AppTheme.successColor;
      case ActivityCategory.relaxation:
        return AppTheme.accentColor;
      case ActivityCategory.creative:
        return const Color(0xFF9C27B0);
      case ActivityCategory.social:
        return AppTheme.warningColor;
    }
  }

  String _getCategoryName(ActivityCategory category) {
    switch (category) {
      case ActivityCategory.study:
        return '学习';
      case ActivityCategory.exercise:
        return '运动';
      case ActivityCategory.relaxation:
        return '放松';
      case ActivityCategory.creative:
        return '创意';
      case ActivityCategory.social:
        return '社交';
    }
  }
}
