import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/focus_session.dart';
import '../data/services/system_usage_provider.dart';
import '../data/services/notification_service.dart';
import '../data/models/schedule.dart';
import '../data/services/schedule_repository.dart';
import '../data/models/app_usage.dart';

/// Agent 工具定义
class AgentTool {
  final String name;
  final String description;
  final Map<String, dynamic> parameters;
  final Future<dynamic> Function(Map<String, dynamic> args) executor;
  final bool requiresConfirmation;
  final String? confirmationMessage;

  AgentTool({
    required this.name,
    required this.description,
    required this.parameters,
    required this.executor,
    this.requiresConfirmation = false,
    this.confirmationMessage,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'parameters': parameters,
    'requires_confirmation': requiresConfirmation,
  };
}

/// 增强版 Agent 工具执行器
/// 提供应用全部功能的操作权限
class EnhancedAgentToolExecutor {
  static final EnhancedAgentToolExecutor _instance = EnhancedAgentToolExecutor._internal();
  factory EnhancedAgentToolExecutor() => _instance;
  EnhancedAgentToolExecutor._internal();

  final Map<String, AgentTool> _tools = {};
  final SystemUsageProvider _usageProvider = SystemUsageProvider();
  final FocusModeManager _focusManager = FocusModeManager();
  final EnhancedNotificationService _notificationService = EnhancedNotificationService();

  /// 初始化所有工具
  void initialize() {
    _registerDataTools();
    _registerActionTools();
    _registerRuleTools();
    _registerScheduleTools();
    _registerAnalysisTools();
    _registerFocusTools();
    _registerSystemTools();
    _registerNotificationTools();
    debugPrint('🛠️ 增强 Agent 工具初始化完成，共 ${_tools.length} 个工具');
  }

  /// 获取所有工具定义
  List<Map<String, dynamic>> getAllToolDefinitions() {
    return _tools.values.map((t) => t.toJson()).toList();
  }

  /// 执行指定工具
  Future<dynamic> execute(String toolName, Map<String, dynamic> args) async {
    final tool = _tools[toolName];
    if (tool == null) {
      throw Exception('未知工具: $toolName');
    }

    try {
      debugPrint('🔧 执行工具: $toolName, 参数: $args');
      final result = await tool.executor(args);
      debugPrint('✅ 工具执行成功: $toolName');
      return result;
    } catch (e) {
      debugPrint('❌ 工具执行失败: $toolName, 错误: $e');
      throw Exception('工具执行失败: $e');
    }
  }

  /// 批量执行工具
  Future<List<dynamic>> executeBatch(List<Map<String, dynamic>> tasks) async {
    final results = <dynamic>[];
    for (final task in tasks) {
      final name = task['tool'] as String;
      final args = task['args'] as Map<String, dynamic>;
      try {
        final result = await execute(name, args);
        results.add({'tool': name, 'success': true, 'result': result});
      } catch (e) {
        results.add({'tool': name, 'success': false, 'error': e.toString()});
      }
    }
    return results;
  }

  // ==================== 数据类工具 ====================

  void _registerDataTools() {
    // 获取今日使用统计
    _tools['get_today_usage'] = AgentTool(
      name: 'get_today_usage',
      description: '获取今日屏幕使用统计，包括总时长、解锁次数和各应用详情',
      parameters: {
        'type': 'object',
        'properties': {
          'include_apps': {
            'type': 'boolean',
            'description': '是否包含各应用详细使用数据',
            'default': true,
          },
          'top_n': {
            'type': 'integer',
            'description': '返回前N个应用',
            'default': 5,
          },
        },
      },
      executor: (args) async {
        final detailed = args['include_apps'] as bool? ?? true;
        final topN = args['top_n'] as int? ?? 5;
        final usage = await _usageProvider.getTodayUsage(detailed: detailed);

        // 获取分类统计
        final categorized = _categorizeApps(usage.appUsage);

        return {
          'total_minutes': usage.totalScreenTime ~/ 60,
          'total_hours': usage.totalScreenTime ~/ 3600,
          'unlock_count': usage.unlockCount,
          'by_category': categorized,
          'top_apps': usage.appUsage.take(topN).map((a) => {
            'name': a.appName,
            'package': a.packageName,
            'minutes': a.usageTimeInSeconds ~/ 60,
            'category': a.category,
            'intent': a.intent.displayName,
          }).toList(),
          'pickups_per_hour': usage.unlockCount > 0 && usage.totalScreenTime > 0
              ? (usage.unlockCount / (usage.totalScreenTime / 3600)).round()
              : 0,
        };
      },
    );

    // 获取实时使用状态
    _tools['get_realtime_status'] = AgentTool(
      name: 'get_realtime_status',
      description: '获取当前实时的手机使用状态',
      parameters: {'type': 'object', 'properties': {}},
      executor: (args) async {
        final currentApp = await _usageProvider.getCurrentForegroundApp();
        final lastUsed = await _usageProvider.getLastUsedTime();
        final today = await _usageProvider.getTodayUsage(detailed: false);

        return {
          'current_app': currentApp,
          'last_used_seconds_ago': lastUsed != null
              ? DateTime.now().difference(lastUsed).inSeconds
              : null,
          'today_total_minutes': today.totalScreenTime ~/ 60,
          'today_unlock_count': today.unlockCount,
          'is_screen_on': await _usageProvider.isScreenOn(),
        };
      },
    );

    // 获取本周趋势
    _tools['get_weekly_trend'] = AgentTool(
      name: 'get_weekly_trend',
      description: '获取最近7天的使用趋势数据',
      parameters: {
        'type': 'object',
        'properties': {
          'include_today': {
            'type': 'boolean',
            'description': '是否包含今天',
            'default': true,
          },
        },
      },
      executor: (args) async {
        final includeToday = args['include_today'] as bool? ?? true;
        final weekly = await _usageProvider.getWeeklyUsage();

        final data = weekly.map((d) => {
          'date': '${d.date.month}/${d.date.day}',
          'weekday': _getWeekdayName(d.date.weekday),
          'minutes': d.totalScreenTime ~/ 60,
          'unlock_count': d.unlockCount,
          'is_today': _isToday(d.date),
        }).toList();

        if (!includeToday) {
          data.removeWhere((d) => d['is_today'] == true);
        }

        // 计算趋势
        final avgMinutes = data.isEmpty ? 0 : data.fold<int>(0, (sum, d) => sum + (d['minutes'] as int)) ~/ data.length;
        final maxMinutes = data.isEmpty ? 0 : data.map((d) => d['minutes'] as int).reduce((a, b) => a > b ? a : b);
        final minMinutes = data.isEmpty ? 0 : data.map((d) => d['minutes'] as int).reduce((a, b) => a < b ? a : b);

        return {
          'daily_data': data,
          'average_minutes': avgMinutes,
          'max_minutes': maxMinutes,
          'min_minutes': minMinutes,
          'trend': data.length >= 2
              ? (data.last['minutes'] as int) > (data.first['minutes'] as int) ? 'up' : 'down'
              : 'stable',
        };
      },
    );

    // 获取特定应用详细使用
    _tools['get_app_usage_details'] = AgentTool(
      name: 'get_app_usage_details',
      description: '获取指定应用的详细使用数据',
      parameters: {
        'type': 'object',
        'properties': {
          'app_name': {
            'type': 'string',
            'description': '应用名称',
          },
          'days': {
            'type': 'integer',
            'description': '查询天数',
            'default': 7,
          },
        },
        'required': ['app_name'],
      },
      executor: (args) async {
        final appName = args['app_name'] as String;
        final days = args['days'] as int? ?? 7;

        final packageName = _guessPackageName(appName);
        final history = await _usageProvider.getAppUsageHistory(packageName, days);

        final totalMinutes = history.fold<int>(0, (sum, d) => sum + (d['minutes'] as int));
        final avgMinutes = history.isEmpty ? 0 : totalMinutes ~/ history.length;

        return {
          'app_name': appName,
          'total_minutes_last_$days\_days': totalMinutes,
          'average_daily_minutes': avgMinutes,
          'daily_breakdown': history,
          'trend': history.length >= 2
              ? history.last['minutes'] > history.first['minutes'] ? 'increasing' : 'decreasing'
              : 'stable',
        };
      },
    );
  }

  // ==================== 专注模式工具 ====================

  void _registerFocusTools() {
    // 启动专注模式
    _tools['start_focus_mode'] = AgentTool(
      name: 'start_focus_mode',
      description: '启动专注模式（番茄钟）',
      parameters: {
        'type': 'object',
        'properties': {
          'task_name': {
            'type': 'string',
            'description': '专注任务名称',
          },
          'duration_minutes': {
            'type': 'integer',
            'description': '专注时长（分钟）',
            'default': 25,
          },
        },
        'required': ['task_name'],
      },
      executor: (args) async {
        final taskName = args['task_name'] as String;
        final duration = args['duration_minutes'] as int? ?? 25;

        final session = await _focusManager.startFocus(
          taskName: taskName,
          durationMinutes: duration,
        );

        // 发送专注开始通知
        await _notificationService.showFocusModeNotification(
          taskName: taskName,
          remainingMinutes: duration,
        );

        return {
          'started': true,
          'session_id': session.id,
          'task_name': taskName,
          'duration_minutes': duration,
          'end_time': session.startTime.add(Duration(minutes: duration)).toIso8601String(),
        };
      },
    );

    // 停止专注模式
    _tools['stop_focus_mode'] = AgentTool(
      name: 'stop_focus_mode',
      description: '停止当前专注模式',
      parameters: {
        'type': 'object',
        'properties': {
          'completed': {
            'type': 'boolean',
            'description': '是否标记为完成',
            'default': true,
          },
        },
      },
      executor: (args) async {
        final completed = args['completed'] as bool? ?? true;
        final currentSession = _focusManager.currentSession;

        if (currentSession == null) {
          return {'success': false, 'error': '当前没有进行中的专注'};
        }

        if (completed) {
          await _focusManager.completeFocus();
          await _notificationService.showFocusCompleted(
            taskName: currentSession.taskName,
            durationMinutes: currentSession.actualMinutes,
          );
        } else {
          await _focusManager.cancelFocus();
        }

        return {
          'success': true,
          'task_name': currentSession.taskName,
          'actual_minutes': currentSession.actualMinutes,
          'completed': completed,
        };
      },
    );

    // 获取专注状态
    _tools['get_focus_status'] = AgentTool(
      name: 'get_focus_status',
      description: '获取当前专注模式状态',
      parameters: {'type': 'object', 'properties': {}},
      executor: (args) async {
        final session = _focusManager.currentSession;
        final todayFocusMinutes = await _focusManager.getTodayFocusMinutes();

        if (session == null) {
          return {
            'is_focusing': false,
            'today_focus_minutes': todayFocusMinutes,
            'today_focus_hours': todayFocusMinutes ~/ 60,
          };
        }

        return {
          'is_focusing': true,
          'task_name': session.taskName,
          'remaining_seconds': session.remainingSeconds,
          'remaining_minutes': session.remainingSeconds ~/ 60,
          'progress': session.progress,
          'started_at': session.startTime.toIso8601String(),
          'today_focus_minutes': todayFocusMinutes,
        };
      },
    );

    // 获取专注历史
    _tools['get_focus_history'] = AgentTool(
      name: 'get_focus_history',
      description: '获取专注历史记录',
      parameters: {
        'type': 'object',
        'properties': {
          'limit': {
            'type': 'integer',
            'description': '返回条数',
            'default': 10,
          },
        },
      },
      executor: (args) async {
        final limit = args['limit'] as int? ?? 10;
        final prefs = await SharedPreferences.getInstance();
        final historyJson = prefs.getStringList('focus_history') ?? [];

        final history = historyJson
            .map((j) => FocusSession.fromJson(jsonDecode(j)))
            .where((s) => s.isCompleted)
            .toList()
          ..sort((a, b) => b.startTime.compareTo(a.startTime));

        final limited = history.take(limit).toList();

        return {
          'total_sessions': history.length,
          'sessions': limited.map((s) => {
            'task_name': s.taskName,
            'date': '${s.startTime.month}/${s.startTime.day}',
            'duration_minutes': s.actualMinutes,
            'completed': s.isCompleted,
          }).toList(),
        };
      },
    );
  }

  // ==================== 通知工具 ====================

  void _registerNotificationTools() {
    // 发送提醒
    _tools['send_notification'] = AgentTool(
      name: 'send_notification',
      description: '向用户发送通知',
      parameters: {
        'type': 'object',
        'properties': {
          'title': {
            'type': 'string',
            'description': '通知标题',
          },
          'message': {
            'type': 'string',
            'description': '通知内容',
          },
          'level': {
            'type': 'string',
            'description': '提醒级别: subtle/normal/strong/intervention',
            'default': 'normal',
          },
        },
        'required': ['title', 'message'],
      },
      executor: (args) async {
        final title = args['title'] as String;
        final message = args['message'] as String;
        final levelStr = args['level'] as String? ?? 'normal';
        final level = ReminderLevel.values.firstWhere(
          (l) => l.name == levelStr,
          orElse: () => ReminderLevel.normal,
        );

        await _notificationService.showNotification(
          title: title,
          body: message,
        );

        return {'sent': true, 'title': title, 'level': level.name};
      },
    );

    // 发送护眼提醒
    _tools['send_eye_rest_reminder'] = AgentTool(
      name: 'send_eye_rest_reminder',
      description: '发送20-20-20护眼提醒',
      parameters: {'type': 'object', 'properties': {}},
      executor: (args) async {
        await _notificationService.showEyeRestReminder();
        return {'sent': true, 'type': 'eye_rest'};
      },
    );

    // 发送连续使用提醒
    _tools['send_continuous_use_reminder'] = AgentTool(
      name: 'send_continuous_use_reminder',
      description: '发送连续使用提醒',
      parameters: {
        'type': 'object',
        'properties': {
          'minutes': {
            'type': 'integer',
            'description': '连续使用分钟数',
          },
          'level': {
            'type': 'string',
            'description': '提醒级别',
            'default': 'normal',
          },
        },
        'required': ['minutes'],
      },
      executor: (args) async {
        final minutes = args['minutes'] as int;
        final levelStr = args['level'] as String? ?? 'normal';
        final level = ReminderLevel.values.firstWhere(
          (l) => l.name == levelStr,
          orElse: () => ReminderLevel.normal,
        );

        await _notificationService.showContinuousUseReminder(
          minutes: minutes,
          level: level,
        );

        return {'sent': true, 'minutes': minutes, 'level': level.name};
      },
    );

    // 发送替代活动建议
    _tools['send_activity_suggestion'] = AgentTool(
      name: 'send_activity_suggestion',
      description: '发送替代活动建议',
      parameters: {
        'type': 'object',
        'properties': {
          'activity': {
            'type': 'string',
            'description': '建议的活动',
          },
          'reason': {
            'type': 'string',
            'description': '建议原因',
          },
        },
        'required': ['activity', 'reason'],
      },
      executor: (args) async {
        final activity = args['activity'] as String;
        final reason = args['reason'] as String;

        await _notificationService.showAlternativeActivitySuggestion(
          activity: activity,
          reason: reason,
        );

        return {'sent': true, 'activity': activity};
      },
    );
  }

  // ==================== 规则类工具 ====================

  void _registerRuleTools() {
    // 创建智能规则
    _tools['create_smart_rule'] = AgentTool(
      name: 'create_smart_rule',
      description: '创建智能提醒规则',
      parameters: {
        'type': 'object',
        'properties': {
          'name': {
            'type': 'string',
            'description': '规则名称',
          },
          'condition_type': {
            'type': 'string',
            'description': '条件类型: continuous_use/app_use/time_based',
          },
          'condition_params': {
            'type': 'object',
            'description': '条件参数',
          },
          'action_type': {
            'type': 'string',
            'description': '动作类型: notify/remind/intervention',
          },
          'action_params': {
            'type': 'object',
            'description': '动作参数',
          },
        },
        'required': ['name', 'condition_type', 'action_type'],
      },
      executor: (args) async {
        final prefs = await SharedPreferences.getInstance();
        final rules = prefs.getStringList('smart_rules') ?? [];

        final rule = {
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'name': args['name'],
          'condition_type': args['condition_type'],
          'condition_params': args['condition_params'],
          'action_type': args['action_type'],
          'action_params': args['action_params'],
          'enabled': true,
          'created_at': DateTime.now().toIso8601String(),
        };

        rules.add(jsonEncode(rule));
        await prefs.setStringList('smart_rules', rules);

        return {'created': true, 'rule': rule, 'total_rules': rules.length};
      },
    );

    // 获取所有规则
    _tools['get_all_rules'] = AgentTool(
      name: 'get_all_rules',
      description: '获取所有规则',
      parameters: {
        'type': 'object',
        'properties': {
          'include_disabled': {
            'type': 'boolean',
            'default': false,
          },
        },
      },
      executor: (args) async {
        final includeDisabled = args['include_disabled'] as bool? ?? false;
        final prefs = await SharedPreferences.getInstance();
        final rulesJson = prefs.getStringList('smart_rules') ?? [];

        final rules = rulesJson
            .map((j) => jsonDecode(j) as Map<String, dynamic>)
            .where((r) => includeDisabled || r['enabled'] == true)
            .toList();

        return {'rules': rules, 'count': rules.length};
      },
    );

    // 切换规则状态
    _tools['toggle_rule'] = AgentTool(
      name: 'toggle_rule',
      description: '启用或禁用规则',
      parameters: {
        'type': 'object',
        'properties': {
          'rule_id': {
            'type': 'string',
            'description': '规则ID',
          },
          'enabled': {
            'type': 'boolean',
            'description': 'true启用，false禁用',
          },
        },
        'required': ['rule_id', 'enabled'],
      },
      executor: (args) async {
        final ruleId = args['rule_id'] as String;
        final enabled = args['enabled'] as bool;

        final prefs = await SharedPreferences.getInstance();
        final rulesJson = prefs.getStringList('smart_rules') ?? [];

        final rules = rulesJson.map((j) => jsonDecode(j) as Map<String, dynamic>).toList();
        final index = rules.indexWhere((r) => r['id'] == ruleId);

        if (index >= 0) {
          rules[index]['enabled'] = enabled;
          await prefs.setStringList('smart_rules', rules.map(jsonEncode).toList());
          return {'success': true, 'rule_id': ruleId, 'enabled': enabled};
        }

        return {'success': false, 'error': '规则不存在'};
      },
    );

    // 删除规则
    _tools['delete_rule'] = AgentTool(
      name: 'delete_rule',
      description: '删除规则',
      parameters: {
        'type': 'object',
        'properties': {
          'rule_id': {
            'type': 'string',
            'description': '规则ID',
          },
        },
        'required': ['rule_id'],
      },
      executor: (args) async {
        final ruleId = args['rule_id'] as String;

        final prefs = await SharedPreferences.getInstance();
        final rulesJson = prefs.getStringList('smart_rules') ?? [];

        final rules = rulesJson.map((j) => jsonDecode(j) as Map<String, dynamic>).toList();
        final newRules = rules.where((r) => r['id'] != ruleId).toList();

        if (newRules.length < rules.length) {
          await prefs.setStringList('smart_rules', newRules.map(jsonEncode).toList());
          return {'success': true, 'deleted': ruleId};
        }

        return {'success': false, 'error': '规则不存在'};
      },
    );
  }

  // ==================== 日程类工具 ====================

  void _registerScheduleTools() {
    // 添加日程
    _tools['add_schedule_event'] = AgentTool(
      name: 'add_schedule_event',
      description: '添加日程/课程',
      parameters: {
        'type': 'object',
        'properties': {
          'name': {
            'type': 'string',
            'description': '日程名称',
          },
          'start_time': {
            'type': 'string',
            'description': '开始时间，如"08:00"',
          },
          'duration_minutes': {
            'type': 'integer',
            'description': '持续分钟数',
          },
          'weekdays': {
            'type': 'array',
            'description': '重复的星期，如[1,2,3]表示周一到周三',
          },
          'location': {
            'type': 'string',
            'description': '地点',
          },
        },
        'required': ['name', 'start_time', 'duration_minutes', 'weekdays'],
      },
      executor: (args) async {
        final name = args['name'] as String;
        final startTime = args['start_time'] as String;
        final duration = args['duration_minutes'] as int;
        final weekdays = (args['weekdays'] as List).cast<int>();
        final location = args['location'] as String?;

        // 解析时间
        final timeParts = startTime.split(':');
        final hour = int.parse(timeParts[0]);
        final minute = int.parse(timeParts[1]);

        final event = ScheduleEvent(
          name: name,
          type: EventType.course,
          timeSlot: TimeSlot(
            startHour: hour,
            startMinute: minute,
            durationMinutes: duration,
          ),
          weekdays: weekdays,
          location: location,
        );

        final repo = ScheduleRepository();
        await repo.load();
        await repo.addEvent(event);

        return {
          'added': true,
          'event': {
            'name': event.name,
            'time': event.timeSlot.displayTime,
            'weekdays': event.weekdayDisplay,
            'location': event.location,
          },
        };
      },
    );

    // 获取今日日程
    _tools['get_today_schedule'] = AgentTool(
      name: 'get_today_schedule',
      description: '获取今日日程',
      parameters: {'type': 'object', 'properties': {}},
      executor: (args) async {
        final repo = ScheduleRepository();
        await repo.load();
        final events = repo.getTodayEvents(DateTime.now());
        final now = DateTime.now();

        return events.map((e) => {
          'name': e.name,
          'time': e.timeSlot.displayTime,
          'location': e.location,
          'is_active': e.isActive(now),
          'is_upcoming': e.timeSlot.startTime.isAfter(now),
          'minutes_until_start': e.timeSlot.startTime.isAfter(now)
              ? e.timeSlot.startTime.difference(now).inMinutes
              : 0,
        }).toList();
      },
    );

    // 获取当前上下文
    _tools['get_current_context'] = AgentTool(
      name: 'get_current_context',
      description: '获取当前日程上下文',
      parameters: {'type': 'object', 'properties': {}},
      executor: (args) async {
        final repo = ScheduleRepository();
        await repo.load();
        final context = repo.getCurrentContext(DateTime.now());

        return {
          'has_active_event': context.activeEvent != null,
          'event_name': context.eventName,
          'event_type': context.eventType?.displayName,
          'minutes_elapsed': context.minutesElapsed,
          'minutes_remaining': context.minutesRemaining,
          'is_free_time': context.isFreeTime,
          'can_use_entertainment': context.canUseEntertainment,
        };
      },
    );

    // 分析日程时段使用
    _tools['analyze_schedule_slot'] = AgentTool(
      name: 'analyze_schedule_slot',
      description: '分析特定日程时段的手机使用',
      parameters: {
        'type': 'object',
        'properties': {
          'event_name': {
            'type': 'string',
            'description': '日程名称',
          },
        },
        'required': ['event_name'],
      },
      executor: (args) async {
        final eventName = args['event_name'] as String;

        final repo = ScheduleRepository();
        await repo.load();
        final events = repo.getTodayEvents(DateTime.now());
        final event = events.firstWhere(
          (e) => e.name.contains(eventName),
          orElse: () => throw Exception('未找到该日程'),
        );

        final analyzer = TimeSlotAnalyzer();
        final analysis = await analyzer.analyzeScheduleEvent(event, DateTime.now());

        return {
          'event_name': event.name,
          'total_phone_minutes': analysis.totalPhoneUsageSeconds ~/ 60,
          'entertainment_minutes': analysis.entertainmentSeconds ~/ 60,
          'communication_minutes': analysis.communicationSeconds ~/ 60,
          'study_tool_minutes': analysis.studyToolSeconds ~/ 60,
          'focus_score': analysis.focusScore,
          'assessment': analysis.assessment,
        };
      },
    );
  }

  // ==================== 分析类工具 ====================

  void _registerAnalysisTools() {
    // 分析使用模式
    _tools['analyze_usage_pattern'] = AgentTool(
      name: 'analyze_usage_pattern',
      description: '深度分析使用模式',
      parameters: {
        'type': 'object',
        'properties': {
          'days': {
            'type': 'integer',
            'description': '分析天数',
            'default': 7,
          },
        },
      },
      executor: (args) async {
        final days = args['days'] as int? ?? 7;
        final today = await _usageProvider.getTodayUsage(detailed: true);
        final weekly = await _usageProvider.getWeeklyUsage();

        // 计算统计数据
        final totalMinutes = weekly.fold<int>(0, (sum, d) => sum + d.totalScreenTime ~/ 60);
        final avgMinutes = weekly.isEmpty ? 0 : totalMinutes ~/ weekly.length;
        final totalUnlocks = weekly.fold<int>(0, (sum, d) => sum + d.unlockCount);

        // 识别问题应用
        final entertainmentApps = today.appUsage
            .where((a) => a.intent == UsageIntent.entertainment)
            .take(3)
            .toList();

        // 识别高峰时段
        final hourlyUsage = await _usageProvider.getHourlyDistribution();
        final peakHours = hourlyUsage.entries
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        return {
          'average_daily_minutes': avgMinutes,
          'average_daily_hours': avgMinutes ~/ 60,
          'total_unlocks': totalUnlocks,
          'pickup_frequency': weekly.isEmpty ? 0 : totalUnlocks ~/ weekly.length,
          'problem_apps': entertainmentApps.map((a) => {
            'name': a.appName,
            'minutes': a.usageTimeInSeconds ~/ 60,
          }).toList(),
          'peak_hours': peakHours.take(3).map((e) => {
            'hour': e.key,
            'minutes': e.value,
          }).toList(),
          'risk_level': avgMinutes > 360 ? 'high' : avgMinutes > 240 ? 'medium' : 'low',
        };
      },
    );

    // 生成建议
    _tools['generate_suggestions'] = AgentTool(
      name: 'generate_suggestions',
      description: '基于使用数据生成个性化建议',
      parameters: {
        'type': 'object',
        'properties': {
          'focus_area': {
            'type': 'string',
            'description': '关注领域: time/app/schedule/general',
            'default': 'general',
          },
        },
      },
      executor: (args) async {
        final focusArea = args['focus_area'] as String? ?? 'general';
        final analysis = await execute('analyze_usage_pattern', {'days': 7});

        final suggestions = <Map<String, dynamic>>[];

        if (analysis['risk_level'] == 'high') {
          suggestions.add({
            'type': 'urgent',
            'title': '使用时长过高',
            'description': '日均使用超过6小时，建议设置更严格的使用限制',
            'action': 'create_strict_rules',
          });
        }

        if ((analysis['problem_apps'] as List).isNotEmpty) {
          final topApp = (analysis['problem_apps'] as List).first;
          suggestions.add({
            'type': 'app_control',
            'title': '控制 ${topApp['name']} 使用',
            'description': '${topApp['name']} 占用了大量时间，建议设置使用限制',
            'action': 'create_app_rule',
            'target_app': topApp['name'],
          });
        }

        if ((analysis['pickup_frequency'] as int) > 60) {
          suggestions.add({
            'type': 'habit',
            'title': '减少查看手机频率',
            'description': '平均每天解锁超过60次，建议开启专注模式减少干扰',
            'action': 'enable_focus_mode',
          });
        }

        return {'suggestions': suggestions, 'focus_area': focusArea};
      },
    );
  }

  // ==================== 系统工具 ====================

  void _registerSystemTools() {
    // 获取应用信息
    _tools['get_app_info'] = AgentTool(
      name: 'get_app_info',
      description: '获取已安装应用信息',
      parameters: {
        'type': 'object',
        'properties': {
          'category': {
            'type': 'string',
            'description': '应用分类筛选',
          },
        },
      },
      executor: (args) async {
        final category = args['category'] as String?;
        final apps = await _usageProvider.getInstalledApps();

        var filtered = apps;
        if (category != null) {
          filtered = apps.where((a) =>
            a.category.toLowerCase().contains(category.toLowerCase())
          ).toList();
        }

        return {
          'total_apps': apps.length,
          'filtered_count': filtered.length,
          'apps': filtered.take(20).map((a) => {
            'name': a.appName,
            'package': a.packageName,
            'category': a.category,
            'is_system': a.isSystemApp,
          }).toList(),
        };
      },
    );

    // 更新设置
    _tools['update_settings'] = AgentTool(
      name: 'update_settings',
      description: '更新应用设置',
      parameters: {
        'type': 'object',
        'properties': {
          'key': {
            'type': 'string',
            'description': '设置键名',
          },
          'value': {
            'type': 'object',
            'description': '设置值',
          },
        },
        'required': ['key', 'value'],
      },
      executor: (args) async {
        final key = args['key'] as String;
        final value = args['value'];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('settings_$key', jsonEncode(value));

        return {'updated': true, 'key': key};
      },
    );

    // 获取设置
    _tools['get_settings'] = AgentTool(
      name: 'get_settings',
      description: '获取应用设置',
      parameters: {
        'type': 'object',
        'properties': {
          'key': {
            'type': 'string',
            'description': '设置键名，空则返回所有',
          },
        },
      },
      executor: (args) async {
        final key = args['key'] as String?;
        final prefs = await SharedPreferences.getInstance();

        if (key != null) {
          final value = prefs.getString('settings_$key');
          return {'key': key, 'value': value != null ? jsonDecode(value) : null};
        }

        // 返回所有设置
        final allKeys = prefs.getKeys().where((k) => k.startsWith('settings_'));
        final settings = <String, dynamic>{};
        for (final k in allKeys) {
          final value = prefs.getString(k);
          if (value != null) {
            settings[k.substring(9)] = jsonDecode(value);
          }
        }

        return {'settings': settings};
      },
    );
  }

  // ==================== 操作类工具 ====================

  void _registerActionTools() {
    // 更新每日目标
    _tools['update_daily_goal'] = AgentTool(
      name: 'update_daily_goal',
      description: '更新每日使用目标',
      parameters: {
        'type': 'object',
        'properties': {
          'minutes': {
            'type': 'integer',
            'description': '目标分钟数',
          },
        },
        'required': ['minutes'],
      },
      executor: (args) async {
        final minutes = args['minutes'] as int;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('daily_goal_minutes', minutes);

        return {
          'updated': true,
          'minutes': minutes,
          'hours': minutes / 60,
        };
      },
    );

    // 获取每日目标
    _tools['get_daily_goal'] = AgentTool(
      name: 'get_daily_goal',
      description: '获取每日使用目标',
      parameters: {'type': 'object', 'properties': {}},
      executor: (args) async {
        final prefs = await SharedPreferences.getInstance();
        final minutes = prefs.getInt('daily_goal_minutes') ?? 240;

        return {
          'minutes': minutes,
          'hours': minutes / 60,
          'percentage_used': 0, // 需要结合今日使用计算
        };
      },
    );
  }

  // ==================== 辅助方法 ====================

  Map<String, dynamic> _categorizeApps(Map<String, AppUsageInfo> apps) {
    final categories = <String, int>{
      'entertainment': 0,
      'communication': 0,
      'study': 0,
      'tools': 0,
      'others': 0,
    };

    for (final app in apps.values) {
      final minutes = app.usageTimeInSeconds ~/ 60;
      switch (app.intent) {
        case UsageIntent.entertainment:
          categories['entertainment'] = categories['entertainment']! + minutes;
          break;
        case UsageIntent.communication:
          categories['communication'] = categories['communication']! + minutes;
          break;
        case UsageIntent.study:
          categories['study'] = categories['study']! + minutes;
          break;
        case UsageIntent.tool:
          categories['tools'] = categories['tools']! + minutes;
          break;
        default:
          categories['others'] = categories['others']! + minutes;
      }
    }

    return categories;
  }

  String _getWeekdayName(int weekday) {
    const names = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return names[weekday];
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  String _guessPackageName(String appName) {
    final map = {
      '抖音': 'com.ss.android.ugc.aweme',
      '微信': 'com.tencent.mm',
      'qq': 'com.tencent.mobileqq',
      '微博': 'com.sina.weibo',
      'b站': 'tv.danmaku.bili',
      'bilibili': 'tv.danmaku.bili',
      '小红书': 'com.xingin.xhs',
      '淘宝': 'com.taobao.taobao',
      '支付宝': 'com.eg.android.AlipayGphone',
      '知乎': 'com.zhihu.android',
      '网易云': 'com.netease.cloudmusic',
      'qq音乐': 'com.tencent.qqmusic',
    };

    final lower = appName.toLowerCase();
    for (final entry in map.entries) {
      if (lower.contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }
    return appName;
  }
}
