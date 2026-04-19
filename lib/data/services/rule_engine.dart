import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/schedule.dart';
import 'schedule_repository.dart';
import 'system_usage_provider.dart';
import 'chinese_app_database.dart';
import 'notification_service.dart';
import 'usage_tracker.dart';

/// 智能规则引擎（增强版）
///
/// 功能：
/// 1. 后台定时检查任务（每分钟）
/// 2. 规则条件评估引擎（时间/应用/时长/日程）
/// 3. 触发器执行（通知/提醒/记录）
/// 4. 规则持久化和状态管理
/// 5. 自然语言规则创建
class RuleEngine {
  static final RuleEngine _instance = RuleEngine._internal();
  factory RuleEngine() => _instance;
  RuleEngine._internal();

  final SystemUsageProvider _usageProvider = SystemUsageProvider();
  final NotificationService _notificationService = NotificationService();
  final ScheduleRepository _scheduleRepo = ScheduleRepository();
  final UsageTracker _usageTracker = UsageTracker();

  Timer? _evaluationTimer;
  bool _isInitialized = false;

  // 规则列表（增强版）
  List<SmartRuleV2> _rules = [];

  // 规则触发记录（防止重复触发）
  final Map<String, DateTime> _lastTriggered = {};

  // 规则触发计数（用于统计）
  final Map<String, int> _triggerCount = {};

  // 提醒冷却（防止重复提醒）
  final Map<String, DateTime> _lastReminders = {};
  static const Duration _cooldown = Duration(minutes: 10);

  // 规则状态流
  final _ruleStateController = StreamController<RuleStateEvent>.broadcast();
  Stream<RuleStateEvent> get ruleStateStream => _ruleStateController.stream;

  /// 是否正在运行
  bool get isRunning => _evaluationTimer != null && _evaluationTimer!.isActive;

  /// 获取所有规则
  List<SmartRuleV2> get rules => List.unmodifiable(_rules);

  /// 获取启用规则数量
  int get enabledRuleCount => _rules.where((r) => r.enabled).length;

  /// 初始化引擎
  Future<void> initialize() async {
    if (_isInitialized) return;

    await _loadRules();
    await _notificationService.initialize();
    await _scheduleRepo.load();

    // 监听使用变化（批量检查）
    _usageTracker.addListener(_onUsageChanged);

    _isInitialized = true;
    debugPrint('⚙️ 规则引擎已初始化，共${_rules.length}条规则');
  }

  /// 启动规则引擎（后台定时检查）
  Future<void> start() async {
    if (!_isInitialized) await initialize();
    if (isRunning) return;

    // 立即执行一次检查
    await _evaluateRules();

    // 每分钟评估一次规则
    _evaluationTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _evaluateRules();
    });

    debugPrint('⚙️ 规则引擎后台检查已启动');
  }

  /// 停止规则引擎
  void stop() {
    _evaluationTimer?.cancel();
    _evaluationTimer = null;
    debugPrint('⚙️ 规则引擎已停止');
  }

  /// 使用数据变化时的回调
  Timer? _checkTimer;
  void _onUsageChanged() {
    // 防抖：500ms内多次变化只检查一次
    _checkTimer?.cancel();
    _checkTimer = Timer(const Duration(milliseconds: 500), () {
      _evaluateRules();
    });
  }

  /// 评估所有规则
  Future<void> _evaluateRules() async {
    final tracker = UsageTracker();
    final now = DateTime.now();

    // 检查内置规则（连续使用、每日上限）
    await _checkBuiltInRules(tracker, now);

    // 检查增强规则
    for (final rule in _rules) {
      if (!rule.enabled) continue;

      // 检查冷却时间
      if (_isInRuleCooldown(rule)) continue;

      // 检查规则条件
      if (await _shouldTriggerEnhanced(rule, now)) {
        await _executeRuleEnhanced(rule);
      }
    }
  }

  /// 公开的评估方法（供后台服务调用）
  Future<void> evaluateRules() async {
    await _evaluateRules();
  }

  /// 判断增强规则是否应该触发
  Future<bool> _shouldTriggerEnhanced(SmartRuleV2 rule, DateTime now) async {
    final cond = rule.conditions;

    // 检查时间范围
    if (cond.timeRange != null) {
      if (!_isInTimeRange(cond.timeRange!, now)) return false;
    }

    // 检查星期
    if (cond.weekdays != null && cond.weekdays!.isNotEmpty) {
      if (!cond.weekdays!.contains(now.weekday)) return false;
    }

    // 检查日程类型
    if (cond.scheduleEventType != null) {
      final context = _scheduleRepo.getCurrentContext(now);
      if (context.activeEvent?.type != cond.scheduleEventType) return false;
    }

    // 检查应用使用条件
    if (cond.targetApps != null && cond.targetApps!.isNotEmpty) {
      // 检查连续使用时长
      if (cond.consecutiveMinutes != null) {
        final maxConsecutive = await _getAppsMaxConsecutive(cond.targetApps!);
        if (maxConsecutive < cond.consecutiveMinutes!) return false;
      }

      // 检查总使用时长
      if (cond.totalMinutes != null) {
        final totalToday = await _getAppsTotalToday(cond.targetApps!);
        if (totalToday < cond.totalMinutes!) return false;
      }
    }

    // 检查今日总使用时长
    if (cond.dailyTotalMinutes != null) {
      final todayUsage = await _usageProvider.getTodayUsage(detailed: false);
      final todayMinutes = todayUsage.totalScreenTime ~/ 60;
      if (todayMinutes < cond.dailyTotalMinutes!) return false;
    }

    return true;
  }

  /// 检查规则冷却
  bool _isInRuleCooldown(SmartRuleV2 rule) {
    final last = _lastTriggered[rule.id];
    if (last == null) return false;
    final cooldownMinutes = rule.cooldownMinutes ?? 10;
    return DateTime.now().difference(last).inMinutes < cooldownMinutes;
  }

  /// 获取应用最大连续使用时长
  Future<int> _getAppsMaxConsecutive(List<String> apps) async {
    int maxMinutes = 0;
    final now = DateTime.now();

    for (var appName in apps) {
      final packageName = _guessPackageName(appName);
      final timeline = await _usageProvider.getAppTimeline(packageName, now);

      if (timeline.isNotEmpty) {
        final lastSession = timeline.last;
        final duration = lastSession.duration.inMinutes;
        if (duration > maxMinutes) maxMinutes = duration;
      }
    }

    return maxMinutes;
  }

  /// 获取应用今日总使用时长
  Future<int> _getAppsTotalToday(List<String> apps) async {
    int totalMinutes = 0;

    for (var appName in apps) {
      final packageName = _guessPackageName(appName);
      final seconds = await _usageProvider.getAppUsageToday(packageName);
      totalMinutes += seconds ~/ 60;
    }

    return totalMinutes;
  }

  /// 执行增强规则
  Future<void> _executeRuleEnhanced(SmartRuleV2 rule) async {
    final now = DateTime.now();
    _lastTriggered[rule.id] = now;
    _triggerCount[rule.id] = (_triggerCount[rule.id] ?? 0) + 1;

    switch (rule.action.type) {
      case RuleActionType.notification:
        await _sendNotificationAction(rule);
        break;
      case RuleActionType.reminder:
        await _sendReminderAction(rule);
        break;
      case RuleActionType.alarm:
        await _sendAlarmAction(rule);
        break;
      case RuleActionType.logOnly:
        debugPrint('📝 规则记录: ${rule.name}');
        break;
    }

    _ruleStateController.add(RuleStateEvent(
      type: RuleEventType.triggered,
      ruleName: rule.name,
      ruleId: rule.id,
      timestamp: now,
    ));

    debugPrint('🎯 规则触发: ${rule.name}');
  }

  /// 发送通知动作
  Future<void> _sendNotificationAction(SmartRuleV2 rule) async {
    await _notificationService.showRuleTriggeredNotification(
      title: rule.action.title ?? 'Focus 提醒',
      message: rule.action.message ?? '你设置的规则"${rule.name}"已触发',
      ruleId: rule.id,
    );
  }

  /// 发送提醒动作
  Future<void> _sendReminderAction(SmartRuleV2 rule) async {
    String message = rule.action.message ?? '该休息一下了';

    if (rule.action.suggestAlternative == true) {
      final suggestions = _getAlternativeSuggestions(rule);
      if (suggestions.isNotEmpty) {
        message += '\n\n建议: ${suggestions.first}';
      }
    }

    await _notificationService.showRuleTriggeredNotification(
      title: rule.action.title ?? 'Focus 提醒',
      message: message,
      ruleId: rule.id,
      actions: ['我知道了', '稍后提醒'],
    );
  }

  /// 发送强提醒动作
  Future<void> _sendAlarmAction(SmartRuleV2 rule) async {
    await _notificationService.showHighPriorityNotification(
      title: rule.action.title ?? '⏰ 重要提醒',
      message: rule.action.message ?? '你设置的规则"${rule.name}"已触发',
    );
  }

  /// 获取替代活动建议
  List<String> _getAlternativeSuggestions(SmartRuleV2 rule) {
    final suggestions = <String>[];

    if (rule.conditions.targetApps != null) {
      for (var app in rule.conditions.targetApps!) {
        final appInfo = ChineseAppDatabase.getAppByName(app);
        if (appInfo != null) {
          switch (appInfo.intent) {
            case UsageIntent.entertainment:
              suggestions.addAll([
                '起来走动一下，看看窗外',
                '做几个深呼吸放松',
                '喝杯水，休息一下眼睛',
              ]);
              break;
            case UsageIntent.communication:
              suggestions.addAll([
                '消息可以等会儿再回',
                '专注完成手头的事',
                '设置个时间段统一回复',
              ]);
              break;
            default:
              suggestions.add('起来活动活动，休息2分钟');
          }
        }
      }
    }

    if (suggestions.isEmpty) {
      suggestions.addAll(['起来走动一下', '闭目养神2分钟', '做几个深呼吸']);
    }

    return suggestions;
  }

  /// 猜测包名
  String _guessPackageName(String appName) {
    final appInfo = ChineseAppDatabase.getAppByName(appName);
    if (appInfo != null) return appInfo.packageName;

    final map = {
      '抖音': 'com.ss.android.ugc.aweme',
      '微信': 'com.tencent.mm',
      'qq': 'com.tencent.mobileqq',
      '微博': 'com.sina.weibo',
      'b站': 'tv.danmaku.bili',
      '小红书': 'com.xingin.xhs',
      '淘宝': 'com.taobao.taobao',
      '知乎': 'com.zhihu.android',
    };

    return map[appName] ?? appName;
  }

  /// 检查内置规则
  Future<void> _checkBuiltInRules(UsageTracker tracker, DateTime now) async {
    final settings = await tracker.getSettings();

    final decision = tracker.shouldRemind(
      continuousLimit: settings.continuousLimitMinutes,
      dailyLimitMinutes: settings.dailyLimitHours * 60,
    );

    if (decision.shouldRemind && decision.message != null) {
      final ruleName = tracker.currentSessionMinutes >= settings.continuousLimitMinutes
          ? 'continuous'
          : 'daily';

      if (!_isInCooldown(ruleName)) {
        await _sendReminder(
          rule: ruleName,
          message: decision.message!,
          level: decision.level ?? ReminderLevel.normal,
        );
      }
    }
  }

  /// 用户响应了提醒
  Future<void> onUserResponded(String rule) async {
    await UsageTracker().recordReminderResponse(true);
    _lastReminders.remove(rule);
    _lastTriggered.remove(rule);
  }

  /// 从自然语言创建规则
  SmartRuleV2? createRuleFromNL(String input) {
    try {
      // 提取应用名称
      final apps = <String>[];
      final appPatterns = ['抖音', '微信', '微博', 'B站', '小红书', '淘宝', '知乎', '快手'];
      for (var pattern in appPatterns) {
        if (input.contains(pattern)) apps.add(pattern);
      }

      // 提取时间范围
      String? timeRange;
      final timeReg = RegExp(r'(\d{1,2})[:点时](\d{0,2})?.*?到.*?(\d{1,2})[:点时](\d{0,2})?');
      final timeMatch = timeReg.firstMatch(input);
      if (timeMatch != null) {
        final startH = timeMatch.group(1)?.padLeft(2, '0');
        final startM = (timeMatch.group(2) ?? '00').padLeft(2, '0');
        final endH = timeMatch.group(3)?.padLeft(2, '0');
        final endM = (timeMatch.group(4) ?? '00').padLeft(2, '0');
        timeRange = '$startH:$startM-$endH:$endM';
      }

      // 提取时长
      int? duration;
      final durationReg = RegExp(r'(\d+)[\s]*分钟');
      final durationMatch = durationReg.firstMatch(input);
      if (durationMatch != null) duration = int.parse(durationMatch.group(1)!);

      // 提取星期
      List<int>? weekdays;
      if (input.contains('每天') || input.contains('每日')) {
        weekdays = [1, 2, 3, 4, 5, 6, 7];
      } else if (input.contains('工作日')) {
        weekdays = [1, 2, 3, 4, 5];
      } else if (input.contains('周末')) {
        weekdays = [6, 7];
      }

      // 生成规则名称
      final ruleName = apps.isNotEmpty
          ? '${apps.first}使用规则'
          : '智能规则${DateTime.now().millisecondsSinceEpoch % 1000}';

      return SmartRuleV2(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: ruleName,
        description: input,
        conditions: RuleConditionsV2(
          timeRange: timeRange,
          weekdays: weekdays,
          consecutiveMinutes: duration,
          targetApps: apps.isNotEmpty ? apps : null,
        ),
        action: RuleActionV2(
          type: RuleActionType.notification,
          title: 'Focus 提醒',
          message: '你已经使用${apps.join('、')}一段时间了，该休息一下了~',
        ),
        enabled: true,
      );
    } catch (e) {
      debugPrint('规则解析失败: $e');
      return null;
    }
  }

  /// 添加规则
  Future<void> addRule(SmartRuleV2 rule) async {
    _rules.add(rule);
    await _saveRules();

    _ruleStateController.add(RuleStateEvent(
      type: RuleEventType.added,
      ruleName: rule.name,
    ));

    debugPrint('➕ 添加规则: ${rule.name}');
  }

  /// 添加 Agent 解析的规则（V1 SmartRule → SmartRuleV2 转换）
  Future<void> addAgentRule(SmartRule rule) async {
    final ruleV2 = SmartRuleV2(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: rule.name,
      description: rule.description,
      conditions: RuleConditionsV2(
        timeRange: rule.conditions.timeRange,
        weekdays: rule.conditions.days,
        consecutiveMinutes: rule.conditions.consecutiveMinutes,
        totalMinutes: rule.conditions.totalMinutes,
      ),
      action: RuleActionV2(
        type: RuleActionType.notification,
        title: 'Focus 提醒',
        message: rule.action.message,
      ),
      enabled: rule.enabled,
    );
    await addRule(ruleV2);
  }

  /// 删除规则
  Future<void> removeRule(String ruleId) async {
    _rules.removeWhere((r) => r.id == ruleId);
    _lastTriggered.remove(ruleId);
    _triggerCount.remove(ruleId);
    await _saveRules();

    _ruleStateController.add(RuleStateEvent(
      type: RuleEventType.removed,
      ruleId: ruleId,
    ));

    debugPrint('➖ 删除规则: $ruleId');
  }

  /// 更新规则
  Future<void> updateRule(String ruleId, SmartRuleV2 newRule) async {
    final index = _rules.indexWhere((r) => r.id == ruleId);
    if (index != -1) {
      _rules[index] = newRule;
      await _saveRules();

      _ruleStateController.add(RuleStateEvent(
        type: RuleEventType.updated,
        ruleName: newRule.name,
      ));
    }
  }

  /// 启用/禁用规则
  Future<void> toggleRuleV2(String ruleId, bool enabled) async {
    final index = _rules.indexWhere((r) => r.id == ruleId);
    if (index != -1) {
      final updated = _rules[index].copyWith(enabled: enabled);
      _rules[index] = updated;
      await _saveRules();

      _ruleStateController.add(RuleStateEvent(
        type: enabled ? RuleEventType.enabled : RuleEventType.disabled,
        ruleName: updated.name,
      ));

      debugPrint('${enabled ? "✅" : "❌"} ${enabled ? "启用" : "禁用"}规则: ${updated.name}');
    }
  }

  /// 加载规则
  Future<void> _loadRules() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList('smart_rules_v2') ?? [];

    _rules = jsonList
        .map((json) => SmartRuleV2.fromJson(jsonDecode(json)))
        .toList();

    debugPrint('📋 已加载 ${_rules.length} 条规则');
  }

  /// 保存规则
  Future<void> _saveRules() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _rules.map((r) => jsonEncode(r.toJson())).toList();
    await prefs.setStringList('smart_rules_v2', jsonList);
  }

  /// 获取规则统计
  Map<String, dynamic> getStatistics() {
    return {
      'total_rules': _rules.length,
      'enabled_rules': enabledRuleCount,
      'trigger_counts': Map<String, int>.from(_triggerCount),
    };
  }

  /// 清空所有规则
  Future<void> clearAllRules() async {
    _rules.clear();
    _lastTriggered.clear();
    _triggerCount.clear();
    await _saveRules();
  }

  /// 检查是否在冷却期
  bool _isInCooldown(String ruleName) {
    final last = _lastReminders[ruleName];
    if (last == null) return false;
    return DateTime.now().difference(last) < _cooldown;
  }

  /// 发送提醒
  Future<void> _sendReminder({
    required String rule,
    required String message,
    required ReminderLevel level,
  }) async {
    final tracker = UsageTracker();

    switch (level) {
      case ReminderLevel.subtle:
        await NotificationService().showQuietNotification(
          title: 'Focus Flow',
          body: message,
        );
        break;
      case ReminderLevel.normal:
        await NotificationService().showNotification(
          title: '休息提醒',
          body: message,
        );
        break;
      case ReminderLevel.strong:
        await NotificationService().showAlert(
          title: '该休息了',
          body: message,
        );
        break;
      case ReminderLevel.intervention:
        await NotificationService().showFullScreenReminder(
          title: '强制休息',
          body: message,
        );
        break;
    }

    _lastReminders[rule] = DateTime.now();
    await tracker.recordReminderResponse(false);
  }

  /// 更新基础设置
  Future<void> updateBasicSettings({
    int? continuousLimit,
    int? dailyLimit,
    String? bedtime,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (continuousLimit != null) await prefs.setInt('continuous_limit', continuousLimit);
    if (dailyLimit != null) await prefs.setInt('daily_limit', dailyLimit);
    if (bedtime != null) await prefs.setString('bedtime', bedtime);
  }
}

/// 智能规则
class SmartRule {
  final String name;
  final String description;
  final RuleConditions conditions;
  final RuleAction action;
  final bool enabled;

  SmartRule({
    required this.name,
    required this.description,
    required this.conditions,
    required this.action,
    this.enabled = true,
  });

  factory SmartRule.fromJson(Map<String, dynamic> json) => SmartRule(
        name: json['name'] ?? '',
        description: json['description'] ?? '',
        conditions: RuleConditions.fromJson(json['conditions'] ?? {}),
        action: RuleAction.fromJson(json['action'] ?? {}),
        enabled: json['enabled'] ?? true,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'conditions': conditions.toJson(),
        'action': action.toJson(),
        'enabled': enabled,
      };
}

class RuleConditions {
  final String? timeRange;
  final List<int>? days;
  final int? consecutiveMinutes;
  final int? totalMinutes;

  RuleConditions({
    this.timeRange,
    this.days,
    this.consecutiveMinutes,
    this.totalMinutes,
  });

  factory RuleConditions.fromJson(Map<String, dynamic> json) => RuleConditions(
        timeRange: json['timeRange'],
        days: (json['days'] as List?)?.cast<int>(),
        consecutiveMinutes: json['consecutiveMinutes'],
        totalMinutes: json['totalMinutes'],
      );

  Map<String, dynamic> toJson() => {
        'timeRange': timeRange,
        'days': days,
        'consecutiveMinutes': consecutiveMinutes,
        'totalMinutes': totalMinutes,
      };
}

class RuleAction {
  final String type;
  final String? message;

  RuleAction({
    required this.type,
    this.message,
  });

  factory RuleAction.fromJson(Map<String, dynamic> json) => RuleAction(
        type: json['type'] ?? 'notify',
        message: json['message'],
      );

  Map<String, dynamic> toJson() => {
        'type': type,
        'message': message,
      };
}

/// 通知动作回调
class ActionCallback {
  final String title;
  final VoidCallback callback;

  ActionCallback({
    required this.title,
    required this.callback,
  });
}

/// 智能规则 V2（增强版）
class SmartRuleV2 {
  final String id;
  final String name;
  final String description;
  final RuleConditionsV2 conditions;
  final RuleActionV2 action;
  final bool enabled;
  final int? cooldownMinutes;
  final DateTime createdAt;

  SmartRuleV2({
    required this.id,
    required this.name,
    required this.description,
    required this.conditions,
    required this.action,
    this.enabled = true,
    this.cooldownMinutes = 10,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  SmartRuleV2 copyWith({bool? enabled}) => SmartRuleV2(
    id: id,
    name: name,
    description: description,
    conditions: conditions,
    action: action,
    enabled: enabled ?? this.enabled,
    cooldownMinutes: cooldownMinutes,
    createdAt: createdAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'conditions': conditions.toJson(),
    'action': action.toJson(),
    'enabled': enabled,
    'cooldown_minutes': cooldownMinutes,
    'created_at': createdAt.toIso8601String(),
  };

  factory SmartRuleV2.fromJson(Map<String, dynamic> json) => SmartRuleV2(
    id: json['id'] as String,
    name: json['name'] as String,
    description: json['description'] as String,
    conditions: RuleConditionsV2.fromJson(json['conditions'] as Map<String, dynamic>),
    action: RuleActionV2.fromJson(json['action'] as Map<String, dynamic>),
    enabled: json['enabled'] as bool? ?? true,
    cooldownMinutes: json['cooldown_minutes'] as int?,
    createdAt: json['created_at'] != null
        ? DateTime.parse(json['created_at'] as String)
        : DateTime.now(),
  );
}

/// 规则条件 V2（增强版）
class RuleConditionsV2 {
  final String? timeRange;
  final List<int>? weekdays;
  final EventType? scheduleEventType;
  final List<String>? targetApps;
  final int? consecutiveMinutes;
  final int? totalMinutes;
  final int? dailyTotalMinutes;

  RuleConditionsV2({
    this.timeRange,
    this.weekdays,
    this.scheduleEventType,
    this.targetApps,
    this.consecutiveMinutes,
    this.totalMinutes,
    this.dailyTotalMinutes,
  });

  Map<String, dynamic> toJson() => {
    'time_range': timeRange,
    'weekdays': weekdays,
    'schedule_event_type': scheduleEventType?.toString().split('.').last,
    'target_apps': targetApps,
    'consecutive_minutes': consecutiveMinutes,
    'total_minutes': totalMinutes,
    'daily_total_minutes': dailyTotalMinutes,
  };

  factory RuleConditionsV2.fromJson(Map<String, dynamic> json) => RuleConditionsV2(
    timeRange: json['time_range'] as String?,
    weekdays: (json['weekdays'] as List?)?.cast<int>(),
    scheduleEventType: json['schedule_event_type'] != null
        ? EventType.values.firstWhere(
            (e) => e.toString().split('.').last == json['schedule_event_type'],
            orElse: () => EventType.custom,
          )
        : null,
    targetApps: (json['target_apps'] as List?)?.cast<String>(),
    consecutiveMinutes: json['consecutive_minutes'] as int?,
    totalMinutes: json['total_minutes'] as int?,
    dailyTotalMinutes: json['daily_total_minutes'] as int?,
  );
}

/// 规则动作类型
enum RuleActionType {
  notification,
  reminder,
  alarm,
  logOnly,
}

/// 规则动作 V2（增强版）
class RuleActionV2 {
  final RuleActionType type;
  final String? title;
  final String? message;
  final bool? suggestAlternative;

  RuleActionV2({
    required this.type,
    this.title,
    this.message,
    this.suggestAlternative,
  });

  Map<String, dynamic> toJson() => {
    'type': type.toString().split('.').last,
    'title': title,
    'message': message,
    'suggest_alternative': suggestAlternative,
  };

  factory RuleActionV2.fromJson(Map<String, dynamic> json) => RuleActionV2(
    type: RuleActionType.values.firstWhere(
      (e) => e.toString().split('.').last == json['type'],
      orElse: () => RuleActionType.notification,
    ),
    title: json['title'] as String?,
    message: json['message'] as String?,
    suggestAlternative: json['suggest_alternative'] as bool?,
  );
}

/// 规则状态事件
class RuleStateEvent {
  final RuleEventType type;
  final String? ruleName;
  final String? ruleId;
  final DateTime? timestamp;

  RuleStateEvent({
    required this.type,
    this.ruleName,
    this.ruleId,
    this.timestamp,
  });
}

/// 规则事件类型
enum RuleEventType {
  added,
  removed,
  updated,
  enabled,
  disabled,
  triggered,
}

/// 提醒级别
enum ReminderLevel {
  subtle,
  normal,
  strong,
  intervention,
}
