import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/focus_session.dart';
import '../models/schedule.dart';
import 'system_usage_provider.dart';
import 'chinese_app_database.dart';
import 'notification_service.dart';
import 'schedule_repository.dart';
import '../models/app_usage.dart' show UsageIntent;
import 'context_aware_monitor.dart' show ContextualAppPolicy;

/// 专注模式使用检测服务
///
/// 功能：
/// 1. 在专注模式期间监控用户手机使用情况
/// 2. 检测是否离开专注页面使用其他应用
/// 3. 根据专注类型（课程/自习/健身）设定不同阈值
/// 4. 违规使用时发送提醒通知
class FocusSessionMonitor {
  static final FocusSessionMonitor _instance = FocusSessionMonitor._internal();
  factory FocusSessionMonitor() => _instance;
  FocusSessionMonitor._internal();

  final SystemUsageProvider _usageProvider = SystemUsageProvider();
  final NotificationService _notificationService = NotificationService();
  final ScheduleRepository _scheduleRepo = ScheduleRepository();

  Timer? _monitorTimer;
  FocusSession? _currentSession;
  ScheduleEvent? _boundEvent;

  // 专注期间的应用使用记录
  final Map<String, AppUsageDuringFocus> _usageRecords = {};

  // 当前前台应用
  String? _currentForegroundApp;

  // 上次检查时间
  DateTime? _lastCheckTime;

  // 已发送的提醒记录（避免重复提醒）
  final Set<String> _sentReminders = {};

  /// 是否正在监控
  bool get isMonitoring => _monitorTimer != null && _monitorTimer!.isActive;

  /// 开始专注监控
  ///
  /// [session] 当前专注会话
  /// [boundEvent] 绑定的日程事件（可选，用于课表联动）
  Future<void> startMonitoring(FocusSession session, {ScheduleEvent? boundEvent}) async {
    if (isMonitoring) {
      stopMonitoring();
    }

    _currentSession = session;
    _boundEvent = boundEvent;
    _usageRecords.clear();
    _sentReminders.clear();
    _lastCheckTime = DateTime.now();

    // 初始化通知服务
    await _notificationService.initialize();

    // 立即检查一次当前应用
    _currentForegroundApp = await _usageProvider.getCurrentForegroundApp();

    // 每30秒检查一次使用情况
    _monitorTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkUsage();
    });

    debugPrint('🔍 专注监控已启动: ${session.taskName}');
    if (boundEvent != null) {
      debugPrint('   绑定日程: ${boundEvent.name} (${boundEvent.type.displayName})');
    }
  }

  /// 停止专注监控
  Future<void> stopMonitoring() async {
    _monitorTimer?.cancel();
    _monitorTimer = null;

    // 生成专注报告
    if (_currentSession != null) {
      await _generateFocusReport();
    }

    _currentSession = null;
    _boundEvent = null;
    _usageRecords.clear();
    _sentReminders.clear();

    debugPrint('🔍 专注监控已停止');
  }

  /// 检查使用情况
  Future<void> _checkUsage() async {
    if (_currentSession == null) return;

    final now = DateTime.now();
    final currentApp = await _usageProvider.getCurrentForegroundApp();

    if (currentApp == null) return;

    // 计算时间间隔
    final intervalMinutes = _lastCheckTime != null
        ? now.difference(_lastCheckTime!).inMinutes
        : 0;
    _lastCheckTime = now;

    // 更新应用使用记录
    await _updateUsageRecord(currentApp, intervalMinutes);

    // 检查是否需要干预
    await _checkIntervention(currentApp);

    _currentForegroundApp = currentApp;
  }

  /// 更新使用记录
  Future<void> _updateUsageRecord(String packageName, int minutes) async {
    final appInfo = ChineseAppDatabase.getAppInfo(packageName);
    final intent = appInfo?.intent ?? UsageIntent.unknown;

    if (!_usageRecords.containsKey(packageName)) {
      _usageRecords[packageName] = AppUsageDuringFocus(
        packageName: packageName,
        appName: appInfo?.name ?? packageName.split('.').last,
        intent: intent,
        firstSeen: DateTime.now(),
        totalMinutes: 0,
        lastSeen: DateTime.now(),
      );
    }

    final record = _usageRecords[packageName]!;
    record.totalMinutes += minutes;
    record.lastSeen = DateTime.now();

    debugPrint('📱 使用记录: ${record.appName} - ${record.totalMinutes}分钟');
  }

  /// 检查是否需要干预
  Future<void> _checkIntervention(String currentApp) async {
    if (_currentSession == null) return;

    final eventType = _boundEvent?.type;
    final policy = _boundEvent?.policy ?? _getDefaultPolicy();

    // 获取当前应用的使用记录
    final record = _usageRecords[currentApp];
    if (record == null) return;

    // 根据应用意图和事件类型获取阈值
    final threshold = _getThreshold(record.intent, eventType, policy);

    // 检查是否超过阈值
    if (threshold > 0 && record.totalMinutes >= threshold) {
      await _sendIntervention(record, threshold, eventType);
    }

    // 检查是否为高成瘾应用（额外提醒）
    final appInfo = ChineseAppDatabase.getAppInfo(currentApp);
    if (appInfo?.highAddictive == true && record.totalMinutes >= (threshold * 0.8).round()) {
      await _sendAddictiveAppWarning(record, eventType);
    }
  }

  /// 发送干预提醒
  Future<void> _sendIntervention(
    AppUsageDuringFocus record,
    int threshold,
    EventType? eventType,
  ) async {
    final reminderKey = '${record.packageName}_${record.totalMinutes ~/ threshold}';

    // 避免重复发送同一层级的提醒
    if (_sentReminders.contains(reminderKey)) return;
    _sentReminders.add(reminderKey);

    final ratio = record.totalMinutes / threshold;
    String title;
    String message;

    if (ratio >= 2.0) {
      // 超过2倍阈值 - 强力提醒
      title = '${record.appName}使用超标！';
      message = _getStrongMessage(record, eventType);
    } else if (ratio >= 1.5) {
      // 超过1.5倍阈值 - 中等提醒
      title = '专注提醒';
      message = _getModerateMessage(record, eventType);
    } else {
      // 首次超过 - 温和提醒
      title = '专注时间';
      message = _getGentleMessage(record, eventType);
    }

    await _notificationService.showInterventionNotification(
      title: title,
      message: message,
      importance: ratio >= 2.0 ? NotificationImportance.high : NotificationImportance.normal,
    );

    debugPrint('🔔 发送干预: $title - $message');
  }

  /// 发送高成瘾应用警告
  Future<void> _sendAddictiveAppWarning(AppUsageDuringFocus record, EventType? eventType) async {
    final reminderKey = 'addictive_${record.packageName}';
    if (_sentReminders.contains(reminderKey)) return;
    _sentReminders.add(reminderKey);

    final context = _currentSession?.taskName ?? '专注';

    await _notificationService.showInterventionNotification(
      title: '小心沉迷~',
      message: '${record.appName}容易让人停不下来，${context}时间要适度使用哦',
      importance: NotificationImportance.normal,
    );
  }

  /// 获取温和提醒消息
  String _getGentleMessage(AppUsageDuringFocus record, EventType? eventType) {
    final taskName = _currentSession?.taskName ?? '当前任务';

    switch (eventType) {
      case EventType.course:
        return '已经用${record.appName}${record.totalMinutes}分钟了，${taskName}还顺利吗？适度放松就好~';
      case EventType.study:
        return '${record.appName}${record.totalMinutes}分钟了，${taskName}进展如何？';
      case EventType.exercise:
        if (record.intent == UsageIntent.music) {
          return '继续加油！音乐伴你运动💪';
        }
        return '健身时${record.appName}${record.totalMinutes}分钟了，组间休息也别太久哦~';
      case EventType.meeting:
        return '${taskName}进行中，${record.appName}${record.totalMinutes}分钟了';
      default:
        return '${record.appName}用了${record.totalMinutes}分钟了，${taskName}还在进行吗？';
    }
  }

  /// 获取中等强度提醒消息
  String _getModerateMessage(AppUsageDuringFocus record, EventType? eventType) {
    final taskName = _currentSession?.taskName ?? '当前任务';

    switch (eventType) {
      case EventType.course:
        return '${taskName}时间已用${record.totalMinutes}分钟${record.appName}，该回到课堂了~';
      case EventType.study:
        return '${record.appName}${record.totalMinutes}分钟了，先完成${taskName}再放松吧';
      default:
        return '${record.appName}用了挺久了，${taskName}需要继续吗？';
    }
  }

  /// 获取强力提醒消息
  String _getStrongMessage(AppUsageDuringFocus record, EventType? eventType) {
    final taskName = _currentSession?.taskName ?? '当前任务';

    switch (eventType) {
      case EventType.course:
        return '${taskName}时间已用${record.totalMinutes}分钟${record.appName}，有点久了，现在放下，等下课再玩吧！';
      case EventType.study:
        return '${record.appName}${record.totalMinutes}分钟了，${taskName}时间快结束了，现在专注还来得及！';
      default:
        return '${record.appName}用了${record.totalMinutes}分钟了，该回到${taskName}了！';
    }
  }

  /// 获取阈值
  int _getThreshold(UsageIntent intent, EventType? eventType, DeviceUsagePolicy policy) {
    // 优先使用绑定日程的策略
    if (eventType != null) {
      return ContextualAppPolicy.getThreshold(eventType, intent);
    }

    // 使用默认策略
    switch (intent) {
      case UsageIntent.entertainment:
        return policy.entertainmentLimitMinutes;
      case UsageIntent.communication:
        return 10; // 通讯类10分钟
      case UsageIntent.study:
        return 60; // 学习类60分钟
      case UsageIntent.tool:
        return policy.allowToolUsage ? 20 : 0;
      case UsageIntent.music:
        return 30; // 音乐30分钟
      default:
        return 10;
    }
  }

  /// 获取默认策略
  DeviceUsagePolicy _getDefaultPolicy() {
    return DeviceUsagePolicy.focusMode();
  }

  /// 生成专注报告
  Future<FocusSessionReport> _generateFocusReport() async {
    if (_currentSession == null) {
      return FocusSessionReport.empty();
    }

    final session = _currentSession!;
    final now = DateTime.now();
    final actualMinutes = now.difference(session.startTime).inMinutes;

    // 统计各类应用使用时间
    int entertainmentMinutes = 0;
    int communicationMinutes = 0;
    int studyMinutes = 0;
    int toolMinutes = 0;

    for (var record in _usageRecords.values) {
      switch (record.intent) {
        case UsageIntent.entertainment:
          entertainmentMinutes += record.totalMinutes;
          break;
        case UsageIntent.communication:
          communicationMinutes += record.totalMinutes;
          break;
        case UsageIntent.study:
          studyMinutes += record.totalMinutes;
          break;
        case UsageIntent.tool:
          toolMinutes += record.totalMinutes;
          break;
        default:
          break;
      }
    }

    // 计算专注度分数
    final totalPhoneMinutes = entertainmentMinutes + communicationMinutes + toolMinutes;
    final focusScore = actualMinutes > 0
        ? ((actualMinutes - totalPhoneMinutes) / actualMinutes * 100).clamp(0, 100).round()
        : 100;

    final report = FocusSessionReport(
      sessionId: session.id,
      taskName: session.taskName,
      plannedMinutes: session.durationMinutes,
      actualMinutes: actualMinutes,
      entertainmentMinutes: entertainmentMinutes,
      communicationMinutes: communicationMinutes,
      studyMinutes: studyMinutes,
      toolMinutes: toolMinutes,
      focusScore: focusScore,
      topDistractions: _usageRecords.values
          .where((r) => r.intent == UsageIntent.entertainment)
          .toList()
          ..sort((a, b) => b.totalMinutes.compareTo(a.totalMinutes)),
    );

    debugPrint('📊 专注报告: ${report.taskName}, 专注度: ${report.focusScore}%');
    return report;
  }

  /// 获取当前专注状态
  FocusSessionStatus getCurrentStatus() {
    if (_currentSession == null) return FocusSessionStatus.idle;

    if (isMonitoring) {
      return FocusSessionStatus.monitoring;
    }
    return FocusSessionStatus.paused;
  }

  /// 获取实时使用统计
  Map<String, dynamic> getRealTimeStats() {
    if (_currentSession == null) {
      return {'error': '没有进行中的专注会话'};
    }

    final now = DateTime.now();
    final elapsedMinutes = now.difference(_currentSession!.startTime).inMinutes;

    return {
      'task_name': _currentSession!.taskName,
      'elapsed_minutes': elapsedMinutes,
      'planned_minutes': _currentSession!.durationMinutes,
      'remaining_minutes': (_currentSession!.durationMinutes - elapsedMinutes).clamp(0, 999),
      'apps_used': _usageRecords.length,
      'usage_breakdown': _getUsageBreakdown(),
    };
  }

  /// 获取使用分类统计
  Map<String, int> _getUsageBreakdown() {
    final breakdown = <String, int>{};

    for (var record in _usageRecords.values) {
      final intentName = _getIntentName(record.intent);
      breakdown[intentName] = (breakdown[intentName] ?? 0) + record.totalMinutes;
    }

    return breakdown;
  }

  String _getIntentName(UsageIntent intent) {
    switch (intent) {
      case UsageIntent.entertainment:
        return '娱乐';
      case UsageIntent.communication:
        return '通讯';
      case UsageIntent.study:
        return '学习';
      case UsageIntent.tool:
        return '工具';
      case UsageIntent.music:
        return '音乐';
      default:
        return '其他';
    }
  }
}

/// 专注期间应用使用记录
class AppUsageDuringFocus {
  final String packageName;
  final String appName;
  final UsageIntent intent;
  final DateTime firstSeen;
  DateTime lastSeen;
  int totalMinutes;

  AppUsageDuringFocus({
    required this.packageName,
    required this.appName,
    required this.intent,
    required this.firstSeen,
    required this.totalMinutes,
    required this.lastSeen,
  });
}

/// 专注会话报告
class FocusSessionReport {
  final String sessionId;
  final String taskName;
  final int plannedMinutes;
  final int actualMinutes;
  final int entertainmentMinutes;
  final int communicationMinutes;
  final int studyMinutes;
  final int toolMinutes;
  final int focusScore;
  final List<AppUsageDuringFocus> topDistractions;

  FocusSessionReport({
    required this.sessionId,
    required this.taskName,
    required this.plannedMinutes,
    required this.actualMinutes,
    required this.entertainmentMinutes,
    required this.communicationMinutes,
    required this.studyMinutes,
    required this.toolMinutes,
    required this.focusScore,
    required this.topDistractions,
  });

  factory FocusSessionReport.empty() => FocusSessionReport(
    sessionId: '',
    taskName: '',
    plannedMinutes: 0,
    actualMinutes: 0,
    entertainmentMinutes: 0,
    communicationMinutes: 0,
    studyMinutes: 0,
    toolMinutes: 0,
    focusScore: 0,
    topDistractions: [],
  );

  String get summary {
    if (focusScore >= 90) {
      return '非常专注！${taskName}完成得很棒';
    } else if (focusScore >= 70) {
      return '专注度不错，${taskName}进展顺利';
    } else if (focusScore >= 50) {
      return '专注度一般，${taskName}完成但有些分心';
    } else {
      return '专注度较低，下次可以更专注一些';
    }
  }
}

/// 专注会话状态扩展
enum FocusSessionStatus {
  idle,       // 空闲
  monitoring, // 监控中
  paused,     // 暂停
}
