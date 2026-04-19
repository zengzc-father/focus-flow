import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/schedule.dart';
import 'system_usage_provider.dart';
import 'schedule_repository.dart';
import 'time_slot_analyzer.dart';
import 'chinese_app_database.dart';

/// 统一监控配置
class MonitorConfig {
  // 基础监控间隔（分钟）
  static int baseMonitorInterval = 1;

  // 电量优化阈值
  static int lowBatteryThreshold = 20; // 低于20%为低电量
  static int criticalBatteryThreshold = 10;

  // 内存管理
  static int maxMessageHistory = 50; // 最多保留50条消息
  static int maxSlotHistory = 7; // 最多保留7个时段记录

  // 是否启用电量优化
  static bool enableBatteryOptimization = true;

  // 夜间模式（23:00-7:00降低监控频率）
  static bool enableNightMode = true;
  static int nightModeInterval = 5; // 夜间5分钟检查一次
}

/// 电量状态
enum BatteryLevel {
  normal,    // 正常
  low,       // 低电量
  critical,  // 极低电量
}

/// 统一监控管理器（优化版）
///
/// 解决原设计问题：
/// 1. 合并重复监控逻辑（SmartSlotMonitor + ContextAwareMonitor）
/// 2. 电量优化（低电量降低监控频率）
/// 3. 内存管理（自动清理历史记录）
/// 4. 夜间模式（减少夜间打扰）
class UnifiedMonitor {
  static final UnifiedMonitor _instance = UnifiedMonitor._internal();
  factory UnifiedMonitor() => _instance;
  UnifiedMonitor._internal();

  final SystemUsageProvider _usageProvider = SystemUsageProvider();
  final ScheduleRepository _scheduleRepo = ScheduleRepository();

  Timer? _monitorTimer;
  bool _isRunning = false;
  BatteryLevel _currentBatteryLevel = BatteryLevel.normal;

  // 当前时段记录
  TimeSlotUsageRecord? _currentRecord;
  String? _lastEventId;

  // 历史记录（自动清理）
  final List<TimeSlotUsageRecord> _slotHistory = [];

  // 流控制器（用于向UI发送干预建议）
  final StreamController<InterventionSuggestion> _interventionController =
      StreamController<InterventionSuggestion>.broadcast();
  Stream<InterventionSuggestion> get interventionStream => _interventionController.stream;

  /// 启动监控（智能频率）
  void startMonitoring() {
    if (_isRunning) return;
    _isRunning = true;

    _adjustMonitorFrequency();
    debugPrint('🔋 统一监控已启动（电量优化: ${MonitorConfig.enableBatteryOptimization}）');
  }

  /// 停止监控
  void stopMonitoring() {
    _monitorTimer?.cancel();
    _monitorTimer = null;
    _isRunning = false;
    debugPrint('⏹️ 统一监控已停止');
  }

  /// 根据电量和时段调整监控频率
  void _adjustMonitorFrequency() {
    _monitorTimer?.cancel();

    int intervalMinutes = MonitorConfig.baseMonitorInterval;

    // 电量优化
    if (MonitorConfig.enableBatteryOptimization) {
      switch (_currentBatteryLevel) {
        case BatteryLevel.low:
          intervalMinutes = 3; // 低电量3分钟检查一次
          break;
        case BatteryLevel.critical:
          intervalMinutes = 5; // 极低电量5分钟检查一次
          break;
        default:
          break;
      }
    }

    // 夜间模式
    if (MonitorConfig.enableNightMode && _isNightTime()) {
      intervalMinutes = MonitorConfig.nightModeInterval;
    }

    _monitorTimer = Timer.periodic(Duration(minutes: intervalMinutes), (_) {
      _monitorCycle();
    });

    // 立即执行一次
    _monitorCycle();
  }

  /// 检查是否是夜间（23:00-7:00）
  bool _isNightTime() {
    final hour = DateTime.now().hour;
    return hour >= 23 || hour < 7;
  }

  /// 更新电量状态（外部调用）
  void updateBatteryLevel(int percentage) {
    BatteryLevel newLevel;
    if (percentage <= MonitorConfig.criticalBatteryThreshold) {
      newLevel = BatteryLevel.critical;
    } else if (percentage <= MonitorConfig.lowBatteryThreshold) {
      newLevel = BatteryLevel.low;
    } else {
      newLevel = BatteryLevel.normal;
    }

    if (newLevel != _currentBatteryLevel) {
      _currentBatteryLevel = newLevel;
      _adjustMonitorFrequency(); // 重新调整频率
      debugPrint('🔋 电量状态变化: $newLevel, 监控间隔已调整');
    }
  }

  /// 监控周期
  Future<void> _monitorCycle() async {
    if (!_isRunning) return;

    try {
      final now = DateTime.now();
      final context = _scheduleRepo.getCurrentContext(now);

      // 1. 检查时段切换
      _checkSlotTransition(context);

      // 2. 如果不在日程中，不监控（下课自由时间）
      if (!context.isInScheduledTime || context.activeEvent == null) {
        _currentRecord = null;
        return;
      }

      // 3. 在活动中，执行监控
      final event = context.activeEvent!;
      await _monitorActiveEvent(event, now);
    } catch (e) {
      debugPrint('监控周期错误: $e');
    }
  }

  /// 检查时段切换
  void _checkSlotTransition(CurrentContext context) {
    final currentEventId = context.activeEvent?.id;

    // 如果之前有活动，现在没有了 = 下课了
    if (_lastEventId != null && currentEventId != _lastEventId) {
      _endCurrentSlot();
    }

    _lastEventId = currentEventId;
  }

  /// 结束当前时段
  void _endCurrentSlot() {
    if (_currentRecord != null) {
      _currentRecord!.endTime = DateTime.now();
      _slotHistory.add(_currentRecord!);

      // 自动清理历史记录
      _cleanupHistory();

      debugPrint('📊 时段结束: ${_currentRecord!.eventName}, '
                 '专注度: ${_currentRecord!.calculateFocusScore().toStringAsFixed(1)}%');

      _currentRecord = null;
    }
  }

  /// 清理历史记录
  void _cleanupHistory() {
    // 只保留最近N个时段
    while (_slotHistory.length > MonitorConfig.maxSlotHistory) {
      _slotHistory.removeAt(0);
    }
  }

  /// 监控进行中的活动
  Future<void> _monitorActiveEvent(ScheduleEvent event, DateTime now) async {
    // 获取或创建当前时段记录
    if (_currentRecord == null || _currentRecord!.eventId != event.id) {
      _currentRecord = TimeSlotUsageRecord(
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

    // 获取当前应用
    final currentApp = await _usageProvider.getCurrentApp();
    if (currentApp == null) return;

    // 识别应用意图
    final intent = AppIntentClassifier.classify(currentApp);

    // 更新使用记录
    _currentRecord!.addUsage(currentApp, intent, 1);

    // 检查是否需要干预
    final suggestion = _evaluateIntervention(
      event: event,
      appPackage: currentApp,
      intent: intent,
      record: _currentRecord!,
    );

    if (suggestion != null) {
      _interventionController.add(suggestion);
    }
  }

  /// 评估是否需要干预
  InterventionSuggestion? _evaluateIntervention({
    required ScheduleEvent event,
    required String appPackage,
    required UsageIntent intent,
    required TimeSlotUsageRecord record,
  }) {
    final appUsage = record.appUsage[appPackage];
    if (appUsage == null) return null;

    final currentMinutes = appUsage.minutes;

    // 获取阈值
    final threshold = ContextualAppPolicy.getThreshold(event.type, intent);

    // 如果阈值为0，表示完全禁止
    if (threshold == 0) {
      return InterventionSuggestion(
        level: InterventionLevel.strong,
        message: '现在不是用${AppIntentClassifier.getIntentName(intent)}的时候哦~',
        eventName: event.name,
        appName: ChineseAppDatabase.getAppName(appPackage),
        usageMinutes: currentMinutes,
      );
    }

    // 判断是否达到干预条件
    final ratio = currentMinutes / threshold;

    if (ratio >= 2.0) {
      return InterventionSuggestion(
        level: InterventionLevel.strong,
        message: '${event.name}时间已用${currentMinutes}分钟${_getIntentDisplay(intent)}，'
                  '有点久了，现在放下，等结束再玩吧！',
        eventName: event.name,
        appName: ChineseAppDatabase.getAppName(appPackage),
        usageMinutes: currentMinutes,
      );
    } else if (ratio >= 1.0) {
      return InterventionSuggestion(
        level: InterventionLevel.gentle,
        message: _getGentleMessage(event.name, intent, currentMinutes, event.type),
        eventName: event.name,
        appName: ChineseAppDatabase.getAppName(appPackage),
        usageMinutes: currentMinutes,
      );
    }

    return null;
  }

  String _getIntentDisplay(UsageIntent intent) {
    switch (intent) {
      case UsageIntent.entertainment:
        return '娱乐';
      case UsageIntent.communication:
        return '回消息';
      case UsageIntent.tool:
        return '使用工具';
      case UsageIntent.music:
        return '听音乐';
      default:
        return '';
    }
  }

  String _getGentleMessage(String eventName, UsageIntent intent, int minutes, EventType type) {
    switch (intent) {
      case UsageIntent.entertainment:
        return '已经刷${minutes}分钟了，$eventName还顺利吗？适度放松就好~';
      case UsageIntent.communication:
        return '回消息用了${minutes}分钟，$eventName别落下太多哦~';
      case UsageIntent.tool:
        return '查资料/用工具${minutes}分钟了，$eventName进展如何？';
      case UsageIntent.music:
        if (type == EventType.exercise) {
          return '继续加油！音乐伴你运动💪';
        }
        return '已经听音乐${minutes}分钟了~';
      default:
        return '已经${minutes}分钟了，注意时间分配~';
    }
  }

  /// 获取当前时段统计
  Map<String, dynamic>? getCurrentSlotStats() {
    if (_currentRecord == null) return null;

    return {
      'event_name': _currentRecord!.eventName,
      'elapsed_minutes': _currentRecord!.elapsedMinutes,
      'total_phone_minutes': _currentRecord!.totalPhoneMinutes,
      'by_intent': _currentRecord!.getSummaryByIntent(),
      'focus_score': _currentRecord!.calculateFocusScore(),
    };
  }

  /// 获取今日历史
  List<Map<String, dynamic>> getTodayHistory() {
    return _slotHistory.map((r) => {
      'event_name': r.eventName,
      'focus_score': r.calculateFocusScore(),
      'total_phone_minutes': r.totalPhoneMinutes,
    }).toList();
  }

  /// 释放资源
  void dispose() {
    stopMonitoring();
    _interventionController.close();
  }
}

/// 干预建议
class InterventionSuggestion {
  final InterventionLevel level;
  final String message;
  final String eventName;
  final String appName;
  final int usageMinutes;

  InterventionSuggestion({
    required this.level,
    required this.message,
    required this.eventName,
    required this.appName,
    required this.usageMinutes,
  });
}

/// 干预级别
enum InterventionLevel {
  gentle,
  strong,
}
