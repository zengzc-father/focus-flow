import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/schedule.dart';
import '../models/app_usage.dart';
import 'system_usage_provider.dart';
import 'schedule_repository.dart';
import 'time_slot_analyzer.dart';
import 'chinese_app_database.dart';

/// 场景化应用策略配置
///
/// 根据活动类型 + 应用类型 组合决定策略
/// 基于中国用户实际应用使用习惯设计
class ContextualAppPolicy {

  /// 获取某活动类型的完整策略
  static Map<UsageIntent, int> getPolicy(EventType eventType) {
    switch (eventType) {
      case EventType.course:
      case EventType.study:
        return _studyPolicy();
      case EventType.exercise:
        return _exercisePolicy();
      case EventType.meeting:
        return _meetingPolicy();
      case EventType.custom:
        return _relaxedPolicy();
    }
  }

  /// 上课/自习策略
  static Map<UsageIntent, int> _studyPolicy() => {
    UsageIntent.entertainment: 3,   // 抖音/快手 3分钟提醒（高成瘾）
    UsageIntent.communication: 10,  // 微信/QQ 10分钟
    UsageIntent.tool: 20,           // WPS/相机 20分钟
    UsageIntent.study: 60,          // 学习通/知乎 60分钟（鼓励）
    UsageIntent.music: 0,           // 上课不适合音乐
    UsageIntent.unknown: 10,
  };

  /// 健身策略
  static Map<UsageIntent, int> _exercisePolicy() => {
    UsageIntent.entertainment: 10,  // 组间休息可刷
    UsageIntent.communication: 20,  // 休息回消息
    UsageIntent.tool: 15,           // 记录训练
    UsageIntent.study: 60,          // 不相关
    UsageIntent.music: 180,         // 音乐鼓励！180分钟
    UsageIntent.unknown: 20,
  };

  /// 会议策略
  static Map<UsageIntent, int> _meetingPolicy() => {
    UsageIntent.entertainment: 2,   // 严格
    UsageIntent.communication: 25,  // 工作消息
    UsageIntent.tool: 35,           // 记录
    UsageIntent.study: 60,
    UsageIntent.music: 0,           // 会议不适合
    UsageIntent.unknown: 10,
  };

  /// 自定义/休息策略
  static Map<UsageIntent, int> _relaxedPolicy() => {
    UsageIntent.entertainment: 30,
    UsageIntent.communication: 30,
    UsageIntent.tool: 30,
    UsageIntent.study: 60,
    UsageIntent.music: 60,
    UsageIntent.unknown: 30,
  };

  /// 获取特定组合的阈值
  static int getThreshold(EventType eventType, UsageIntent intent) {
    final policy = getPolicy(eventType);
    return policy[intent] ?? 10;
  }

  /// 判断是否完全禁止某类应用
  static bool isProhibited(EventType eventType, UsageIntent intent) {
    final threshold = getThreshold(eventType, intent);
    return threshold == 0;
  }

  /// 获取策略说明（用于Agent回复）
  static String getPolicyDescription(EventType eventType) {
    switch (eventType) {
      case EventType.course:
        return '上课期间：抖音/快手3分钟提醒，微信10分钟，学习应用鼓励使用';
      case EventType.study:
        return '自习期间：专注学习，短视频应用会提醒';
      case EventType.exercise:
        return '健身时间：可以听网易云/QQ音乐，短视频适度';
      case EventType.meeting:
        return '会议期间：请保持专注';
      case EventType.custom:
        return '自定义时段：相对宽松';
    }
  }

  /// 获取特定应用的个性化阈值
  ///
  /// 根据应用特性进一步细化
  static int getAppSpecificThreshold(EventType eventType, String packageName) {
    final appInfo = ChineseAppDatabase.getAppInfo(packageName);
    final intent = appInfo?.intent ?? UsageIntent.unknown;
    final baseThreshold = getThreshold(eventType, intent);

    // 高成瘾应用降低阈值
    if (appInfo?.highAddictive == true && eventType == EventType.course) {
      return (baseThreshold * 0.8).round().clamp(1, baseThreshold);
    }

    return baseThreshold;
  }
}

/// 场景感知监控器（增强版）
///
/// 特点：
/// 1. 区分活动类型（上课/健身/会议）
/// 2. 区分应用类型（娱乐/通讯/音乐等）
/// 3. 下课时间不干预
/// 4. 各时段独立统计
class ContextAwareMonitor {
  final SystemUsageProvider _usageProvider = SystemUsageProvider();
  final ScheduleRepository _scheduleRepo = ScheduleRepository();

  Timer? _monitorTimer;

  // 当前时段的使用记录（时段结束时清零）
  final Map<String, TimeSlotUsageRecord> _currentSlotUsage = {};

  // 已结束时段的历史记录
  final List<TimeSlotUsageRecord> _slotHistory = [];

  /// 启动监控
  void startMonitoring() {
    _monitorTimer?.cancel();
    _monitorTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _monitorCycle();
    });
    debugPrint('🎯 场景感知监控已启动');
  }

  /// 停止监控
  void stopMonitoring() {
    _monitorTimer?.cancel();
    _monitorTimer = null;
  }

  /// 监控周期
  Future<void> _monitorCycle() async {
    final now = DateTime.now();
    final context = _scheduleRepo.getCurrentContext(now);

    // 1. 检查是否刚下课（时段切换）
    await _checkSlotTransition(now);

    // 2. 如果不在任何日程中，不干预（下课自由时间）
    if (!context.isInScheduledTime || context.activeEvent == null) {
      return;
    }

    // 3. 在活动中，进行监控
    final event = context.activeEvent!;
    await _monitorActiveEvent(event, now);
  }

  /// 检查时段切换（下课时处理）
  Future<void> _checkSlotTransition(DateTime now) async {
    // 检查之前是否在活动中，现在是否刚结束
    // 简化实现：通过历史记录判断
    // 实际应该记录上一个状态
  }

  /// 监控进行中的活动
  Future<InterventionDecision?> _monitorActiveEvent(
    ScheduleEvent event,
    DateTime now,
  ) async {
    // 获取当前应用
    final currentApp = await _usageProvider.getCurrentApp();
    if (currentApp == null) return null;

    // 识别应用意图
    final intent = AppIntentClassifier.classify(currentApp);

    // 获取该活动+应用的阈值
    final threshold = ContextualAppPolicy.getThreshold(event.type, intent);

    // 如果阈值为0，表示完全禁止
    if (threshold == 0) {
      return InterventionDecision(
        shouldIntervene: true,
        level: ContextInterventionLevel.strong,
        reason: '${event.name}期间不适合使用${AppIntentClassifier.getIntentName(intent)}',
        suggestion: '现在不是用${AppIntentClassifier.getIntentName(intent)}的时候哦~',
      );
    }

    // 更新当前时段使用记录
    final record = _updateSlotRecord(event, currentApp, intent, now);

    // 检查是否超过阈值
    final usageMinutes = record.getUsageMinutes(currentApp);

    if (usageMinutes >= threshold) {
      // 根据使用时长和类型生成干预决策
      return _makeInterventionDecision(
        event: event,
        appPackage: currentApp,
        intent: intent,
        usageMinutes: usageMinutes,
        threshold: threshold,
      );
    }

    return null;
  }

  /// 更新时段记录
  TimeSlotUsageRecord _updateSlotRecord(
    ScheduleEvent event,
    String packageName,
    UsageIntent intent,
    DateTime now,
  ) {
    final key = event.id;

    if (!_currentSlotUsage.containsKey(key)) {
      _currentSlotUsage[key] = TimeSlotUsageRecord(
        eventId: event.id,
        eventName: event.name,
        eventType: event.type,
        date: now,
        startTime: DateTime(
          now.year, now.month, now.day,
          event.timeSlot.hour, event.timeSlot.minute,
        ),
        appUsage: {},
      );
    }

    final record = _currentSlotUsage[key]!;
    record.addUsage(packageName, intent, 1); // 增加1分钟

    return record;
  }

  /// 生成干预决策
  InterventionDecision _makeInterventionDecision({
    required ScheduleEvent event,
    required String appPackage,
    required UsageIntent intent,
    required int usageMinutes,
    required int threshold,
  }) {
    final appName = appPackage.split('.').last;
    final intentName = AppIntentClassifier.getIntentName(intent);

    // 根据超标程度决定干预级别
    final ratio = usageMinutes / threshold;

    if (ratio >= 2.0) {
      // 超过2倍阈值
      return InterventionDecision(
        shouldIntervene: true,
        level: ContextInterventionLevel.strong,
        reason: '$intentName已使用$usageMinutes分钟，严重超标',
        suggestion: '${event.name}时间已用$usageMinutes分钟$intentName，'
                    '有点久了，现在放下，等${event.name}结束再玩吧！',
      );
    } else if (ratio >= 1.5) {
      // 超过1.5倍
      return InterventionDecision(
        shouldIntervene: true,
        level: ContextInterventionLevel.moderate,
        reason: '$intentName持续使用中',
        suggestion: '已经$intentName${usageMinutes}分钟了，${event.name}还在进行吗？',
      );
    } else {
      // 首次超过
      return InterventionDecision(
        shouldIntervene: true,
        level: ContextInterventionLevel.gentle,
        reason: '$intentName达到阈值',
        suggestion: _getGentleMessage(event.name, intentName, usageMinutes, event.type),
      );
    }
  }

  /// 获取温和提醒消息（根据场景个性化）
  String _getGentleMessage(String eventName, String intentName, int minutes, EventType type) {
    switch (type) {
      case EventType.course:
        return '已经$intentName$minutes分钟了，$eventName还顺利吗？适度放松就好~';
      case EventType.exercise:
        if (intentName == '听音乐') {
          return '继续加油！音乐伴你运动💪';
        }
        return '健身时$intentName$minutes分钟了，组间休息也别太久哦~';
      case EventType.study:
        return '$intentName$minutes分钟了，学习目标进展如何？';
      case EventType.meeting:
        return '$eventName进行中，$intentName$minutes分钟了，注意会议节奏~';
      case EventType.custom:
        return '$intentName$minutes分钟了，时间分配注意下~';
    }
  }

  /// 获取当前时段统计（用于Agent回复用户查询）
  Map<String, dynamic> getCurrentSlotStats(String eventId) {
    final record = _currentSlotUsage[eventId];
    if (record == null) {
      return {'error': '没有找到该时段记录'};
    }

    return {
      'event_name': record.eventName,
      'elapsed_minutes': record.elapsedMinutes,
      'total_phone_minutes': record.totalPhoneMinutes,
      'by_intent': record.getSummaryByIntent(),
      'focus_score': record.calculateFocusScore(),
    };
  }

  /// 结束时段（下课时调用）
  void endTimeSlot(String eventId) {
    if (_currentSlotUsage.containsKey(eventId)) {
      final record = _currentSlotUsage[eventId]!;
      record.endTime = DateTime.now();
      _slotHistory.add(record);
      _currentSlotUsage.remove(eventId);

      debugPrint('📊 时段结束: ${record.eventName}, 专注度: ${record.calculateFocusScore()}%');
    }
  }

  /// 获取历史时段分析
  List<Map<String, dynamic>> getSlotHistory(DateTime date) {
    return _slotHistory
        .where((r) => r.date.day == date.day)
        .map((r) => {
          'event_name': r.eventName,
          'focus_score': r.calculateFocusScore(),
          'total_phone_minutes': r.totalPhoneMinutes,
        })
        .toList();
  }
}

/// 时段使用记录（单一时段内）
class TimeSlotUsageRecord {
  final String eventId;
  final String eventName;
  final EventType eventType;
  final DateTime date;
  final DateTime startTime;
  DateTime? endTime;

  final Map<String, AppUsageDetail> appUsage;

  TimeSlotUsageRecord({
    required this.eventId,
    required this.eventName,
    required this.eventType,
    required this.date,
    required this.startTime,
    this.endTime,
    required this.appUsage,
  });

  void addUsage(String packageName, UsageIntent intent, int minutes) {
    if (appUsage.containsKey(packageName)) {
      appUsage[packageName]!.minutes += minutes;
    } else {
      appUsage[packageName] = AppUsageDetail(
        packageName: packageName,
        intent: intent,
        minutes: minutes,
      );
    }
  }

  int getUsageMinutes(String packageName) {
    return appUsage[packageName]?.minutes ?? 0;
  }

  int get elapsedMinutes {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime).inMinutes;
  }

  int get totalPhoneMinutes {
    return appUsage.values.fold(0, (sum, u) => sum + u.minutes);
  }

  Map<String, int> getSummaryByIntent() {
    final summary = <String, int>{};
    for (var usage in appUsage.values) {
      final intentName = AppIntentClassifier.getIntentName(usage.intent);
      summary[intentName] = (summary[intentName] ?? 0) + usage.minutes;
    }
    return summary;
  }

  double calculateFocusScore() {
    if (elapsedMinutes == 0) return 100;

    final policy = ContextualAppPolicy.getPolicy(eventType);

    double score = 100;

    for (var usage in appUsage.values) {
      final threshold = policy[usage.intent] ?? 10;
      if (threshold > 0) {
        final ratio = usage.minutes / threshold;
        score -= ratio * 10;
      }
    }

    return score.clamp(0, 100);
  }
}

/// 应用使用详情
class AppUsageDetail {
  final String packageName;
  final UsageIntent intent;
  int minutes;

  AppUsageDetail({
    required this.packageName,
    required this.intent,
    required this.minutes,
  });
}

/// 干预决策
class InterventionDecision {
  final bool shouldIntervene;
  final ContextInterventionLevel level;
  final String reason;
  final String suggestion;

  InterventionDecision({
    required this.shouldIntervene,
    required this.level,
    required this.reason,
    required this.suggestion,
  });
}

/// 干预级别（context_aware_monitor 专用）
enum ContextInterventionLevel {
  none,
  gentle,
  moderate,
  strong,
}
