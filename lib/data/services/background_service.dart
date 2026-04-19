import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
import 'usage_stats_service.dart';
import 'notification_service.dart';
import 'alternative_activities_service.dart';
import 'rule_engine.dart';
import '../models/app_usage.dart';

// 后台任务名称
const String _checkUsageTask = 'checkUsageTask';
const String _bedtimeReminderTask = 'bedtimeReminderTask';
const String _dailyReportTask = 'dailyReportTask';
const String _ruleEngineTask = 'ruleEngineTask';

// 后台任务回调
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    debugPrint('后台任务执行: $task');

    switch (task) {
      case _checkUsageTask:
        await _handleUsageCheck();
        break;
      case _bedtimeReminderTask:
        await _handleBedtimeReminder();
        break;
      case _dailyReportTask:
        await _handleDailyReport();
        break;
      case _ruleEngineTask:
        await _handleRuleEngine();
        break;
    }

    return Future.value(true);
  });
}

// 处理使用检查
Future<void> _handleUsageCheck() async {
  final usageService = UsageStatsService();
  final notificationService = NotificationService();

  await notificationService.initialize();

  final usage = await usageService.getTodayUsage();
  final totalMinutes = usage.totalScreenTime ~/ 60;

  // 检查连续使用时间（简化逻辑）
  if (totalMinutes > 0 && totalMinutes % 30 == 0) {
    // 每30分钟提醒一次
    await notificationService.showContinuousUseReminder(totalMinutes);

    // 发送替代活动建议
    final activitiesService = AlternativeActivitiesService();
    final suggestions = activitiesService.getSuggestionsByUsageTime(totalMinutes);

    if (suggestions.isNotEmpty) {
      await notificationService.showAlternativeActivitySuggestion(suggestions.first);
    }
  }
}

// 处理睡前提醒
Future<void> _handleBedtimeReminder() async {
  final notificationService = NotificationService();
  await notificationService.initialize();
  await notificationService.showBedtimeReminder();
}

// 处理每日报告
Future<void> _handleDailyReport() async {
  final usageService = UsageStatsService();
  final notificationService = NotificationService();

  await notificationService.initialize();

  final usage = await usageService.getTodayUsage();
  await notificationService.showDailyReport(usage);
}

// 处理规则引擎检查
Future<void> _handleRuleEngine() async {
  final ruleEngine = RuleEngine();
  await ruleEngine.initialize();
  await ruleEngine.evaluateRules();
}

class BackgroundService {
  static final BackgroundService _instance = BackgroundService._internal();
  factory BackgroundService() => _instance;
  BackgroundService._internal();

  bool _isInitialized = false;

  // 初始化后台服务
  Future<void> initialize() async {
    if (_isInitialized) return;

    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: kDebugMode,
    );

    _isInitialized = true;
    debugPrint('后台服务已初始化');
  }

  // 启动使用监控
  Future<void> startUsageMonitoring() async {
    if (!_isInitialized) await initialize();

    // 每15分钟检查一次使用情况
    await Workmanager().registerPeriodicTask(
      'usage_monitor',
      _checkUsageTask,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.not_required,
        requiresBatteryNotLow: false,
      ),
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );

    debugPrint('使用监控已启动');
  }

  // 启动规则引擎后台检查
  Future<void> startRuleEngineMonitoring() async {
    if (!_isInitialized) await initialize();

    // 每分钟检查一次规则（使用更频繁的定时任务）
    await Workmanager().registerPeriodicTask(
      'rule_engine',
      _ruleEngineTask,
      frequency: const Duration(minutes: 15), // WorkManager最小15分钟
      constraints: Constraints(
        networkType: NetworkType.not_required,
        requiresBatteryNotLow: false,
      ),
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );

    // 同时启动前台规则引擎（在应用运行时使用）
    final ruleEngine = RuleEngine();
    await ruleEngine.initialize();
    ruleEngine.start();

    debugPrint('规则引擎监控已启动');
  }

  // 停止规则引擎监控
  Future<void> stopRuleEngineMonitoring() async {
    await Workmanager().cancelByUniqueName('rule_engine');
    RuleEngine().stop();
    debugPrint('规则引擎监控已停止');
  }

  // 设置睡前提醒
  Future<void> scheduleBedtimeReminder(int hour, int minute) async {
    if (!_isInitialized) await initialize();

    final now = DateTime.now();
    var scheduledTime = DateTime(now.year, now.month, now.day, hour, minute);

    if (scheduledTime.isBefore(now)) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }

    // 使用OneOff任务，在指定时间触发
    await Workmanager().registerOneOffTask(
      'bedtime_reminder',
      _bedtimeReminderTask,
      initialDelay: scheduledTime.difference(now),
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );

    debugPrint('睡前提醒已设置: $hour:$minute');
  }

  // 设置每日报告
  Future<void> scheduleDailyReport() async {
    if (!_isInitialized) await initialize();

    final now = DateTime.now();
    // 每天晚上10点发送报告
    var scheduledTime = DateTime(now.year, now.month, now.day, 22, 0);

    if (scheduledTime.isBefore(now)) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }

    await Workmanager().registerOneOffTask(
      'daily_report',
      _dailyReportTask,
      initialDelay: scheduledTime.difference(now),
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );

    debugPrint('每日报告已设置');
  }

  // 停止所有后台任务
  Future<void> stopAllTasks() async {
    await Workmanager().cancelAll();
    RuleEngine().stop();
    debugPrint('所有后台任务已停止');
  }

  // 停止特定任务
  Future<void> stopTask(String taskId) async {
    await Workmanager().cancelByUniqueName(taskId);
  }

  // 立即执行一次检查（用于测试）
  Future<void> triggerImmediateCheck() async {
    if (!_isInitialized) await initialize();

    await Workmanager().registerOneOffTask(
      'immediate_check',
      _checkUsageTask,
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );
  }

  // 立即执行规则引擎检查（用于测试）
  Future<void> triggerImmediateRuleCheck() async {
    if (!_isInitialized) await initialize();

    await Workmanager().registerOneOffTask(
      'immediate_rule_check',
      _ruleEngineTask,
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );
  }
}
