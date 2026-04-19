import 'dart:async';
import 'package:flutter/foundation.dart';
import '../data/models/schedule.dart';
import '../data/services/schedule_repository.dart';
import '../data/services/system_usage_provider.dart';
import '../data/services/context_aware_monitor.dart';
import 'agent_tools.dart';

/// 用户意图覆盖系统
///
/// 确保用户对Agent有最高控制权：
/// 1. 临时调课/改时间
/// 2. 创建临时自律规则
/// 3. 暂停/恢复监控
/// 4. 紧急情况跳过
class UserOverrideManager {
  static final UserOverrideManager _instance = UserOverrideManager._internal();
  factory UserOverrideManager() => _instance;
  UserOverrideManager._internal();

  final ScheduleRepository _scheduleRepo = ScheduleRepository();
  final SystemUsageProvider _usageProvider = SystemUsageProvider();

  // 用户临时指令（优先级最高）
  final Map<String, TemporaryOverride> _activeOverrides = {};

  // 一次性自律规则
  final List<TemporaryDisciplineRule> _temporaryRules = [];

  // 暂停的原始日程ID
  final Set<String> _pausedEvents = {};

  // 流控制器（通知UI变更）
  final StreamController<UserOverrideEvent> _overrideController =
      StreamController<UserOverrideEvent>.broadcast();
  Stream<UserOverrideEvent> get overrideStream => _overrideController.stream;

  /// 初始化
  Future<void> initialize() async {
    await _scheduleRepo.load();
    debugPrint('👤 用户覆盖管理器已初始化');
  }

  // ==================== 临时调课功能 ====================

  /// 临时调课 - 用户最高权限
  ///
  /// 示例：
  /// - "今天高数课改到下午3点"
  /// - "明天的课取消了"
  /// - "这周都不用上英语课"
  Future<OverrideResult> rescheduleEvent({
    required String eventName,
    required DateTime originalDate,
    DateTime? newDate,
    TimeSlot? newTime,
    String? reason,
    bool isCancellation = false,
  }) async {
    try {
      // 1. 查找原日程
      final events = _scheduleRepo.getAllEvents();
      final event = events.firstWhere(
        (e) => e.name.contains(eventName) || eventName.contains(e.name),
        orElse: () => throw Exception('未找到课程: $eventName'),
      );

      // 2. 创建覆盖记录
      final override = TemporaryOverride(
        type: OverrideType.reschedule,
        eventId: event.id,
        originalDate: originalDate,
        newDate: newDate,
        newTime: newTime,
        reason: reason,
        createdAt: DateTime.now(),
        expiresAt: originalDate.add(const Duration(days: 1)),
      );

      _activeOverrides[event.id] = override;

      // 3. 如果是取消，添加到暂停列表
      if (isCancellation) {
        _pausedEvents.add(event.id);
      }

      // 4. 通知系统
      _overrideController.add(UserOverrideEvent(
        type: OverrideEventType.scheduleChanged,
        message: isCancellation
            ? '已取消$eventName（${originalDate.month}月${originalDate.day}日）'
            : '已调整$eventName时间',
        override: override,
      ));

      return OverrideResult.success(
        message: isCancellation
            ? '✅ 已取消${event.name}的监控（${originalDate.month}月${originalDate.day}日）'
            : '✅ 已将${event.name}调整到${newTime?.displayTime ?? "新时间"}',
        action: OverrideAction.noIntervention,
      );
    } catch (e) {
      return OverrideResult.error('调整失败: $e');
    }
  }

  /// 快速暂停今日某课程监控
  Future<OverrideResult> pauseTodayEvent(String eventName) async {
    final now = DateTime.now();
    return rescheduleEvent(
      eventName: eventName,
      originalDate: now,
      isCancellation: true,
      reason: '用户临时取消',
    );
  }

  // ==================== 临时自律规则 ====================

  /// 创建临时自律规则 - 用户主动自律
  ///
  /// 示例：
  /// - "接下来2小时别让我打开抖音"
  /// - "今晚我要专注写论文，防止刷手机"
  /// - "从现在到下午5点，游戏超过10分钟强烈提醒"
  Future<OverrideResult> createTemporaryDisciplineRule({
    required String description,
    List<String>? targetApps,
    int? durationMinutes,
    DateTime? until,
    String? specificApp,
    int? usageThreshold,
    ReminderIntensity intensity = ReminderIntensity.strong,
  }) async {
    try {
      // 确定结束时间
      final endTime = until ?? DateTime.now().add(
        Duration(minutes: durationMinutes ?? 120),
      );

      // 解析目标应用
      final apps = targetApps ??
          (specificApp != null ? [specificApp] : ['所有娱乐应用']);

      // 创建临时规则
      final rule = TemporaryDisciplineRule(
        id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
        description: description,
        targetApps: apps,
        usageThresholdMinutes: usageThreshold ?? 10,
        startTime: DateTime.now(),
        endTime: endTime,
        intensity: intensity,
        createdReason: description,
      );

      _temporaryRules.add(rule);

      // 启动监控
      _monitorTemporaryRule(rule);

      // 计算剩余时间
      final remainingMinutes = endTime.difference(DateTime.now()).inMinutes;
      final hours = remainingMinutes ~/ 60;
      final mins = remainingMinutes % 60;

      String timeText;
      if (hours > 0) {
        timeText = '$hours小时${mins > 0 ? '$mins分钟' : ''}';
      } else {
        timeText = '$mins分钟';
      }

      return OverrideResult.success(
        message: '💪 自律模式已启动！\n'
                '⏱️ 持续时长: $timeText\n'
                '📱 监控应用: ${apps.join('、')}\n'
                '⏰ 使用阈值: ${usageThreshold ?? 10}分钟\n'
                '💪 提醒强度: ${_intensityToText(intensity)}\n\n'
                '我会帮你盯着，加油！',
        action: OverrideAction.activeMonitoring,
        data: {'rule': rule},
      );
    } catch (e) {
      return OverrideResult.error('创建规则失败: $e');
    }
  }

  /// 快速自律 - 接下来X分钟不使用某应用
  Future<OverrideResult> quickDiscipline({
    required String appName,
    required int durationMinutes,
    String? goal,
  }) async {
    return createTemporaryDisciplineRule(
      description: goal ?? '专注时间，不使用$appName',
      specificApp: appName,
      durationMinutes: durationMinutes,
      usageThreshold: 1, // 一使用就提醒
      intensity: ReminderIntensity.strong,
    );
  }

  /// 监控临时规则
  void _monitorTemporaryRule(TemporaryDisciplineRule rule) {
    Timer.periodic(const Duration(minutes: 1), (timer) async {
      // 检查规则是否过期
      if (DateTime.now().isAfter(rule.endTime)) {
        timer.cancel();
        _temporaryRules.removeWhere((r) => r.id == rule.id);
        _overrideController.add(UserOverrideEvent(
          type: OverrideEventType.ruleExpired,
          message: '自律时间结束！你做得很棒~',
        ));
        return;
      }

      // 检查应用使用
      for (final app in rule.targetApps) {
        if (app == '所有娱乐应用' || app == '所有应用') {
          // 检查当前应用是否娱乐类
          final currentApp = await _usageProvider.getCurrentApp();
          if (currentApp != null) {
            final intent = AppIntentClassifier.classify(currentApp);
            if (intent == UsageIntent.entertainment) {
              _triggerTemporaryRule(rule, app);
              return;
            }
          }
        } else {
          // 检查特定应用
          final usageSeconds = await _usageProvider.getAppUsageToday(
            _guessPackageName(app),
          );
          if (usageSeconds > 60) { // 使用超过1分钟
            _triggerTemporaryRule(rule, app);
            return;
          }
        }
      }
    });
  }

  /// 触发临时规则提醒
  void _triggerTemporaryRule(TemporaryDisciplineRule rule, String app) {
    final now = DateTime.now();
    if (rule.lastReminderTime != null &&
        now.difference(rule.lastReminderTime!).inMinutes < 5) {
      return; // 5分钟内不重复提醒
    }

    rule.lastReminderTime = now;
    rule.reminderCount++;

    final message = _generateDisciplineMessage(rule, app);

    _overrideController.add(UserOverrideEvent(
      type: OverrideEventType.disciplineReminder,
      message: message,
      ruleId: rule.id,
    ));
  }

  /// 生成自律提醒消息
  String _generateDisciplineMessage(TemporaryDisciplineRule rule, String app) {
    final messages = {
      ReminderIntensity.gentle: [
        '你在使用$app，还记得你的自律目标吗？',
        '自律时间还有${_getRemainingTime(rule)}，坚持住~',
      ],
      ReminderIntensity.normal: [
        '⚠️ 检测到$app使用，你的目标是：${rule.description}',
        '自律模式进行中，$app可能会影响你的目标哦~',
      ],
      ReminderIntensity.strong: [
        '🛑 停下！你在使用$app',
        '💪 自律时间！现在放下$app，坚持${_getRemainingTime(rule)}就赢了！',
        '你承诺过要${rule.description}，现在不是用$app的时候！',
      ],
    };

    final msgs = messages[rule.intensity] ?? messages[ReminderIntensity.normal]!;
    return msgs[rule.reminderCount % msgs.length];
  }

  String _getRemainingTime(TemporaryDisciplineRule rule) {
    final remaining = rule.endTime.difference(DateTime.now());
    final mins = remaining.inMinutes;
    if (mins < 60) return '$mins分钟';
    return '${mins ~/ 60}小时${mins % 60}分钟';
  }

  // ==================== 全局暂停功能 ====================

  /// 用户完全暂停所有监控
  ///
  /// 适用于：
  /// - 假期完全放松
  /// - 特殊情况需要自由使用
  /// - 测试/调试
  Future<OverrideResult> pauseAllMonitoring({
    required Duration duration,
    required String reason,
  }) async {
    final until = DateTime.now().add(duration);

    final override = TemporaryOverride(
      type: OverrideType.globalPause,
      eventId: 'global',
      reason: reason,
      createdAt: DateTime.now(),
      expiresAt: until,
    );

    _activeOverrides['global'] = override;

    // 设置自动恢复
    Timer(duration, () {
      _activeOverrides.remove('global');
      _overrideController.add(UserOverrideEvent(
        type: OverrideEventType.globalResumed,
        message: '监控已恢复，欢迎回来~',
      ));
    });

    return OverrideResult.success(
      message: '🌴 已进入自由模式\n'
              '⏱️ 持续时间: ${_formatDuration(duration)}\n'
              '📝 原因: $reason\n\n'
              '这段时间我不会干预你，但数据仍在记录。',
      action: OverrideAction.noIntervention,
    );
  }

  /// 检查是否全局暂停
  bool get isGloballyPaused => _activeOverrides.containsKey('global');

  // ==================== 紧急跳过功能 ====================

  /// 紧急跳过当前提醒
  ///
  /// 当用户有正当理由需要继续使用时
  Future<OverrideResult> emergencySkip({
    required String currentIntervention,
    required String reason,
    Duration skipDuration = const Duration(minutes: 15),
  }) async {
    final until = DateTime.now().add(skipDuration);

    final override = TemporaryOverride(
      type: OverrideType.emergencySkip,
      eventId: 'emergency_${DateTime.now().millisecondsSinceEpoch}',
      reason: reason,
      createdAt: DateTime.now(),
      expiresAt: until,
    );

    _activeOverrides[override.eventId] = override;

    return OverrideResult.success(
      message: '✅ 已跳过本次提醒\n'
              '⏱️ 暂停干预: ${_formatDuration(skipDuration)}\n'
              '请合理使用，注意眼睛休息~',
      action: OverrideAction.noIntervention,
    );
  }

  // ==================== 查询功能 ====================

  /// 获取当前活跃的覆盖
  List<TemporaryOverride> get activeOverrides => _activeOverrides.values.toList();

  /// 获取当前临时自律规则
  List<TemporaryDisciplineRule> get activeTemporaryRules =>
      _temporaryRules.where((r) => r.endTime.isAfter(DateTime.now())).toList();

  /// 检查某日程是否被覆盖
  bool isEventOverridden(String eventId, DateTime date) {
    final override = _activeOverrides[eventId];
    if (override == null) return false;

    // 检查是否匹配日期
    if (override.originalDate != null) {
      return _isSameDay(override.originalDate!, date);
    }

    return override.expiresAt.isAfter(DateTime.now());
  }

  /// 取消覆盖
  Future<void> cancelOverride(String eventId) async {
    _activeOverrides.remove(eventId);
    _pausedEvents.remove(eventId);

    _overrideController.add(UserOverrideEvent(
      type: OverrideEventType.overrideCancelled,
      message: '已恢复原有设置',
    ));
  }

  /// 取消临时规则
  Future<void> cancelTemporaryRule(String ruleId) async {
    _temporaryRules.removeWhere((r) => r.id == ruleId);

    _overrideController.add(UserOverrideEvent(
      type: OverrideEventType.ruleCancelled,
      message: '已取消自律规则',
    ));
  }

  // ==================== 辅助方法 ====================

  String _intensityToText(ReminderIntensity intensity) {
    switch (intensity) {
      case ReminderIntensity.gentle:
        return '温和';
      case ReminderIntensity.normal:
        return '普通';
      case ReminderIntensity.strong:
        return '强烈';
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final mins = duration.inMinutes % 60;
    if (hours > 0) {
      return '$hours小时${mins > 0 ? '$mins分钟' : ''}';
    }
    return '$mins分钟';
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _guessPackageName(String appName) {
    final map = {
      '抖音': 'com.ss.android.ugc.aweme',
      '微信': 'com.tencent.mm',
      'qq': 'com.tencent.mobileqq',
      '微博': 'com.sina.weibo',
      'b站': 'tv.danmaku.bili',
      '小红书': 'com.xingin.xhs',
      '淘宝': 'com.taobao.taobao',
      '游戏': 'com.tencent.tmgp.sgame',
    };

    final lower = appName.toLowerCase();
    for (var entry in map.entries) {
      if (lower.contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }

    return appName;
  }
}

// ==================== 数据模型 ====================

/// 临时覆盖
class TemporaryOverride {
  final OverrideType type;
  final String eventId;
  final DateTime? originalDate;
  final DateTime? newDate;
  final TimeSlot? newTime;
  final String? reason;
  final DateTime createdAt;
  final DateTime expiresAt;

  TemporaryOverride({
    required this.type,
    required this.eventId,
    this.originalDate,
    this.newDate,
    this.newTime,
    this.reason,
    required this.createdAt,
    required this.expiresAt,
  });
}

/// 临时自律规则
class TemporaryDisciplineRule {
  final String id;
  final String description;
  final List<String> targetApps;
  final int usageThresholdMinutes;
  final DateTime startTime;
  final DateTime endTime;
  final ReminderIntensity intensity;
  final String createdReason;

  int reminderCount = 0;
  DateTime? lastReminderTime;

  TemporaryDisciplineRule({
    required this.id,
    required this.description,
    required this.targetApps,
    required this.usageThresholdMinutes,
    required this.startTime,
    required this.endTime,
    required this.intensity,
    required this.createdReason,
  });
}

/// 覆盖类型
enum OverrideType {
  reschedule,     // 改时间
  globalPause,    // 全局暂停
  emergencySkip,  // 紧急跳过
}

/// 覆盖结果
class OverrideResult {
  final bool success;
  final String message;
  final OverrideAction action;
  final Map<String, dynamic>? data;

  OverrideResult({
    required this.success,
    required this.message,
    required this.action,
    this.data,
  });

  factory OverrideResult.success({
    required String message,
    required OverrideAction action,
    Map<String, dynamic>? data,
  }) => OverrideResult(
    success: true,
    message: message,
    action: action,
    data: data,
  );

  factory OverrideResult.error(String message) => OverrideResult(
    success: false,
    message: message,
    action: OverrideAction.none,
  );
}

/// 覆盖行动
enum OverrideAction {
  none,
  noIntervention,    // 不干预
  activeMonitoring,  // 主动监控
  reschedule,        // 改时间
}

/// 覆盖事件类型
enum OverrideEventType {
  scheduleChanged,    // 日程变更
  ruleExpired,        // 规则过期
  ruleCancelled,      // 规则取消
  globalResumed,      // 全局恢复
  overrideCancelled,  // 覆盖取消
  disciplineReminder, // 自律提醒
}

/// 用户覆盖事件
class UserOverrideEvent {
  final OverrideEventType type;
  final String message;
  final TemporaryOverride? override;
  final String? ruleId;

  UserOverrideEvent({
    required this.type,
    required this.message,
    this.override,
    this.ruleId,
  });
}

/// 提醒强度
enum ReminderIntensity {
  gentle,   // 温和
  normal,   // 普通
  strong,   // 强烈
}
