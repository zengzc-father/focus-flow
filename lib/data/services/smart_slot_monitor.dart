import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/schedule.dart';
import '../models/app_usage.dart';
import 'system_usage_provider.dart';
import 'schedule_repository.dart';
import 'time_slot_analyzer.dart';

/// 应用分类与阈值配置
class AppCategoryConfig {
  // 娱乐类 - 严格监控，低阈值
  static const int entertainmentThresholdMinutes = 3;  // 3分钟即提醒
  static const int entertainmentWarningMinutes = 5;    // 5分钟强烈警告

  // 通讯类 - 较宽松，但连续使用也需关注
  static const int communicationThresholdMinutes = 10; // 10分钟提醒
  static const int communicationWarningMinutes = 20;   // 20分钟警告

  // 工具类 - 宽松，合理使用
  static const int toolThresholdMinutes = 15;          // 15分钟提醒
  static const int toolWarningMinutes = 30;            // 30分钟警告

  // 学习类 - 鼓励使用
  static const int studyThresholdMinutes = 60;         // 很少提醒

  // 音乐类 - 健身时几乎不限制
  static const int musicThresholdMinutes = 60;
}

/// 干预级别
enum InterventionLevel {
  none,      // 不干预
  gentle,    // 温和提醒（首次超过阈值）
  moderate,  // 中度提醒（持续使用）
  strong,    // 强烈提醒（严重超标）
}

/// 分类阈值管理器
class CategoryThresholdManager {
  /// 获取某类应用的提醒阈值（分钟）
  static int getThreshold(UsageIntent intent, {bool isFirstWarning = true}) {
    switch (intent) {
      case UsageIntent.entertainment:
        return isFirstWarning
            ? AppCategoryConfig.entertainmentThresholdMinutes
            : AppCategoryConfig.entertainmentWarningMinutes;
      case UsageIntent.communication:
        return isFirstWarning
            ? AppCategoryConfig.communicationThresholdMinutes
            : AppCategoryConfig.communicationWarningMinutes;
      case UsageIntent.tool:
        return isFirstWarning
            ? AppCategoryConfig.toolThresholdMinutes
            : AppCategoryConfig.toolWarningMinutes;
      case UsageIntent.study:
        return AppCategoryConfig.studyThresholdMinutes;
      case UsageIntent.music:
        return AppCategoryConfig.musicThresholdMinutes;
      case UsageIntent.unknown:
        return AppCategoryConfig.toolThresholdMinutes;
    }
  }

  /// 获取干预消息（根据级别和意图）
  static String getInterventionMessage(
    UsageIntent intent,
    int currentMinutes,
    InterventionLevel level,
    String? currentActivity,
  ) {
    final activity = currentActivity ?? '当前活动';

    switch (intent) {
      case UsageIntent.entertainment:
        return _getEntertainmentMessage(currentMinutes, level, activity);
      case UsageIntent.communication:
        return _getCommunicationMessage(currentMinutes, level, activity);
      case UsageIntent.tool:
        return _getToolMessage(currentMinutes, level, activity);
      default:
        return _getDefaultMessage(currentMinutes, level, activity);
    }
  }

  static String _getEntertainmentMessage(int minutes, InterventionLevel level, String activity) {
    switch (level) {
      case InterventionLevel.gentle:
        return '已经刷${minutes}分钟了，$activity还顺利吗？适度放松就好~';
      case InterventionLevel.moderate:
        return '已经${minutes}分钟了，$activity可能需要更多专注，先停一会儿吧~';
      case InterventionLevel.strong:
        return '$activity时间已用${minutes}分钟，娱乐有点久了，现在放下，等结束再玩吧！';
      default:
        return '';
    }
  }

  static String _getCommunicationMessage(int minutes, InterventionLevel level, String activity) {
    switch (level) {
      case InterventionLevel.gentle:
        return '回消息用了${minutes}分钟，$activity别落下太多哦~';
      case InterventionLevel.moderate:
        return '聊了${minutes}分钟了，$activity还在进行吗？';
      case InterventionLevel.strong:
        return '通讯已经${minutes}分钟，$activity可能需要专注一下了';
      default:
        return '';
    }
  }

  static String _getToolMessage(int minutes, InterventionLevel level, String activity) {
    switch (level) {
      case InterventionLevel.gentle:
        return ''; // 工具类很少在3-15分钟内提醒
      case InterventionLevel.moderate:
        return '查资料/用工具${minutes}分钟了，$activity进展如何？';
      case InterventionLevel.strong:
        return '使用工具${minutes}分钟，$activity是否需要调整下节奏？';
      default:
        return '';
    }
  }

  static String _getDefaultMessage(int minutes, InterventionLevel level, String activity) {
    return '$activity已进行${minutes}分钟，注意时间分配~';
  }
}

/// 智能时段监控器
class SmartSlotMonitor {
  final SystemUsageProvider _usageProvider = SystemUsageProvider();
  final ScheduleRepository _scheduleRepo = ScheduleRepository();

  // 运行中的应用使用记录（内存中）
  final Map<String, AppUsageSession> _activeSessions = {};
  final Map<String, int> _warningCount = {}; // 记录每个应用的提醒次数

  Timer? _monitorTimer;

  /// 启动监控
  void startMonitoring() {
    _monitorTimer?.cancel();
    _monitorTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _checkCurrentUsage();
    });
    debugPrint('🔍 智能时段监控已启动');
  }

  /// 停止监控
  void stopMonitoring() {
    _monitorTimer?.cancel();
    _monitorTimer = null;
  }

  /// 检查当前使用
  Future<InterventionResult?> _checkCurrentUsage() async {
    final now = DateTime.now();
    final context = _scheduleRepo.getCurrentContext(now);

    // 如果不在任何日程中，不干预
    if (!context.isInScheduledTime || context.activeEvent == null) {
      _clearSessions();
      return null;
    }

    final event = context.activeEvent!;
    final policy = context.policy!;

    // 获取当前使用的应用
    final currentApp = await _usageProvider.getCurrentApp();
    if (currentApp == null) return null;

    // 识别应用意图
    final intent = AppIntentClassifier.classify(currentApp);

    // 更新或创建会话
    _updateSession(currentApp, intent);

    // 根据意图和时长判断是否干预
    return _evaluateIntervention(
      event: event,
      appPackage: currentApp,
      intent: intent,
      policy: policy,
      elapsedMinutes: context.minutesElapsed,
    );
  }

  /// 更新会话记录
  void _updateSession(String packageName, UsageIntent intent) {
    final now = DateTime.now();

    if (_activeSessions.containsKey(packageName)) {
      // 更新现有会话
      final session = _activeSessions[packageName]!;
      session.lastSeen = now;
      session.durationMinutes = now.difference(session.startTime).inMinutes;
    } else {
      // 新会话
      _activeSessions[packageName] = AppUsageSession(
        packageName: packageName,
        intent: intent,
        startTime: now,
        lastSeen: now,
        durationMinutes: 0,
      );
      _warningCount[packageName] = 0;
    }

    // 清理旧会话（超过10分钟未活动）
    _cleanupInactiveSessions(now);
  }

  /// 清理不活跃会话
  void _cleanupInactiveSessions(DateTime now) {
    final toRemove = <String>[];

    for (var entry in _activeSessions.entries) {
      final inactiveMinutes = now.difference(entry.value.lastSeen).inMinutes;
      if (inactiveMinutes > 10) {
        toRemove.add(entry.key);
      }
    }

    for (var key in toRemove) {
      _activeSessions.remove(key);
      _warningCount.remove(key);
    }
  }

  /// 评估是否需要干预
  InterventionResult? _evaluateIntervention({
    required ScheduleEvent event,
    required String appPackage,
    required UsageIntent intent,
    required DeviceUsagePolicy policy,
    required int elapsedMinutes,
  }) {
    final session = _activeSessions[appPackage];
    if (session == null) return null;

    final currentMinutes = session.durationMinutes;
    final warningCount = _warningCount[appPackage] ?? 0;

    // 获取该意图的阈值
    final threshold = CategoryThresholdManager.getThreshold(intent, isFirstWarning: warningCount == 0);

    // 判断是否达到干预条件
    InterventionLevel? level;

    if (currentMinutes >= threshold * 2 && warningCount >= 2) {
      // 超过2倍阈值且已提醒2次 → 强烈警告
      level = InterventionLevel.strong;
    } else if (currentMinutes >= threshold * 1.5 && warningCount >= 1) {
      // 超过1.5倍阈值且已提醒1次 → 中度提醒
      level = InterventionLevel.moderate;
    } else if (currentMinutes >= threshold && warningCount == 0) {
      // 首次超过阈值 → 温和提醒
      level = InterventionLevel.gentle;
    }

    // 如果不干预，返回null
    if (level == null || level == InterventionLevel.none) {
      return null;
    }

    // 增加提醒计数
    _warningCount[appPackage] = warningCount + 1;

    // 生成干预消息
    final message = CategoryThresholdManager.getInterventionMessage(
      intent,
      currentMinutes,
      level,
      event.name,
    );

    return InterventionResult(
      shouldIntervene: true,
      level: level,
      message: message,
      appName: appPackage.split('.').last,
      intent: intent,
      durationMinutes: currentMinutes,
      eventName: event.name,
    );
  }

  /// 获取当前使用状态报告
  Map<String, dynamic> getCurrentStatus() {
    final status = <String, dynamic>{};

    for (var entry in _activeSessions.entries) {
      final session = entry.value;
      status[entry.key] = {
        'intent': session.intent.toString(),
        'duration_minutes': session.durationMinutes,
        'warnings': _warningCount[entry.key] ?? 0,
      };
    }

    return status;
  }

  /// 清除所有会话（日程结束时）
  void _clearSessions() {
    _activeSessions.clear();
    _warningCount.clear();
  }
}

/// 应用使用会话
class AppUsageSession {
  final String packageName;
  final UsageIntent intent;
  final DateTime startTime;
  DateTime lastSeen;
  int durationMinutes;

  AppUsageSession({
    required this.packageName,
    required this.intent,
    required this.startTime,
    required this.lastSeen,
    required this.durationMinutes,
  });
}

/// 干预结果
class InterventionResult {
  final bool shouldIntervene;
  final InterventionLevel level;
  final String message;
  final String appName;
  final UsageIntent intent;
  final int durationMinutes;
  final String eventName;

  InterventionResult({
    required this.shouldIntervene,
    required this.level,
    required this.message,
    required this.appName,
    required this.intent,
    required this.durationMinutes,
    required this.eventName,
  });

  Map<String, dynamic> toJson() => {
    'should_intervene': shouldIntervene,
    'level': level.toString(),
    'message': message,
    'app_name': appName,
    'intent': intent.toString(),
    'duration_minutes': durationMinutes,
    'event_name': eventName,
  };
}

/// 时段专注度评分器
class FocusScoreCalculator {
  /// 计算某时段的专注度分数
  ///
  /// 基于：
  /// - 娱乐使用时长（惩罚重）
  /// - 通讯使用时长（适度惩罚）
  /// - 工具使用时长（轻度惩罚）
  /// - 未使用手机时长（加分）
  static double calculateScore({
    required int totalMinutes,
    required Map<UsageIntent, int> intentMinutes,
    required DeviceUsagePolicy policy,
  }) {
    if (totalMinutes == 0) return 100;

    double score = 100;

    // 娱乐使用 - 重罚
    final entertainment = intentMinutes[UsageIntent.entertainment] ?? 0;
    score -= (entertainment / totalMinutes) * 150; // 娱乐占比惩罚系数1.5

    // 通讯使用 - 适度罚
    final communication = intentMinutes[UsageIntent.communication] ?? 0;
    score -= (communication / totalMinutes) * 50; // 通讯占比惩罚系数0.5

    // 工具使用 - 轻罚
    final tool = intentMinutes[UsageIntent.tool] ?? 0;
    score -= (tool / totalMinutes) * 20; // 工具占比惩罚系数0.2

    // 根据策略调整
    if (!policy.allowToolUsage) {
      // 严格模式：任何手机使用都重罚
      final totalPhone = intentMinutes.values.fold(0, (a, b) => a + b);
      score -= (totalPhone / totalMinutes) * 100;
    }

    return score.clamp(0, 100);
  }

  /// 获取专注度等级评价
  static String getScoreLabel(double score) {
    if (score >= 90) return '非常专注 🌟';
    if (score >= 75) return '比较专注 👍';
    if (score >= 60) return '一般专注 😐';
    if (score >= 40) return '容易分心 😅';
    return '需要改进 💪';
  }
}
