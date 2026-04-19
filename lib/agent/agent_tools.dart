import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/services/system_usage_provider.dart';
import '../data/models/schedule.dart';
import '../models/app_usage.dart';

/// Agent工具定义
///
/// 每个工具是一个可执行的功能单元，Agent可以调用这些工具来完成用户请求
class AgentTool {
  final String name;
  final String description;
  final Map<String, dynamic> parameters;
  final Future<dynamic> Function(Map<String, dynamic> args) executor;

  AgentTool({
    required this.name,
    required this.description,
    required this.parameters,
    required this.executor,
  });

  /// 转换为JSON Schema格式（用于LLM function calling）
  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'parameters': parameters,
  };
}

/// Agent工具执行器
///
/// 集中管理所有可用工具，提供工具发现和执行能力
class AgentToolExecutor {
  static final AgentToolExecutor _instance = AgentToolExecutor._internal();
  factory AgentToolExecutor() => _instance;
  AgentToolExecutor._internal();

  final Map<String, AgentTool> _tools = {};
  final SystemUsageProvider _usageProvider = SystemUsageProvider();

  /// 初始化所有工具
  void initialize() {
    _registerDataTools();
    _registerActionTools();
    _registerRuleTools();
    _registerScheduleTools();
    _registerAnalysisTools();
    debugPrint('🛠️ Agent工具初始化完成，共 ${_tools.length} 个工具');
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

  /// 检查工具是否存在
  bool hasTool(String name) => _tools.containsKey(name);

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
        },
      },
      executor: (args) async {
        final detailed = args['include_apps'] as bool? ?? true;
        final usage = await _usageProvider.getTodayUsage(detailed: detailed);
        return {
          'total_minutes': usage.totalScreenTime ~/ 60,
          'total_hours': usage.totalScreenTime ~/ 3600,
          'unlock_count': usage.unlockCount,
          'top_apps': usage.appUsages.take(5).map((a) => {
            'name': a.appName,
            'minutes': a.usageTimeInSeconds ~/ 60,
          }).toList(),
        };
      },
    );

    // 获取应用使用时段
    _tools['get_app_timeline'] = AgentTool(
      name: 'get_app_timeline',
      description: '获取指定应用今天的使用时段记录',
      parameters: {
        'type': 'object',
        'properties': {
          'app_name': {
            'type': 'string',
            'description': '应用名称，如"抖音"、"微信"',
          },
        },
        'required': ['app_name'],
      },
      executor: (args) async {
        final appName = args['app_name'] as String;
        // 简化处理：通过名称匹配包名
        final timeline = await _usageProvider.getAppTimeline(
          _guessPackageName(appName),
          DateTime.now(),
        );
        return timeline.map((s) => {
          'start': s.start.toIso8601String(),
          'end': s.end.toIso8601String(),
          'duration_minutes': s.duration.inMinutes,
        }).toList();
      },
    );

    // 获取本周趋势
    _tools['get_weekly_trend'] = AgentTool(
      name: 'get_weekly_trend',
      description: '获取最近7天的使用趋势数据',
      parameters: {
        'type': 'object',
        'properties': {},
      },
      executor: (args) async {
        final weekly = await _usageProvider.getWeeklyUsage();
        return weekly.map((d) => {
          'date': '${d.date.month}/${d.date.day}',
          'minutes': d.totalScreenTime ~/ 60,
          'unlock_count': d.unlockCount,
        }).toList();
      },
    );

    // 与昨日比较
    _tools['compare_with_yesterday'] = AgentTool(
      name: 'compare_with_yesterday',
      description: '比较今日与昨日的使用情况',
      parameters: {
        'type': 'object',
        'properties': {},
      },
      executor: (args) async {
        final comparison = await _usageProvider.compareWithYesterday();
        return {
          'today_minutes': comparison.todayMinutes,
          'yesterday_minutes': comparison.yesterdayMinutes,
          'difference_minutes': comparison.differenceMinutes,
          'percentage_change': comparison.percentageChange,
          'is_better': comparison.isBetter,
        };
      },
    );

    // 获取连续使用时段
    _tools['get_continuous_sessions'] = AgentTool(
      name: 'get_continuous_sessions',
      description: '获取今日连续使用超过指定时长的时段',
      parameters: {
        'type': 'object',
        'properties': {
          'min_minutes': {
            'type': 'integer',
            'description': '最短连续时长（分钟）',
            'default': 30,
          },
        },
      },
      executor: (args) async {
        final minMinutes = args['min_minutes'] as int? ?? 30;
        final sessions = await _usageProvider.getContinuousSessions(
          DateTime.now(),
          minDurationMinutes: minMinutes,
        );
        return sessions.take(5).map((s) => {
          'app_name': s.appName,
          'start': '${s.start.hour}:${s.start.minute.toString().padLeft(2, '0')}',
          'duration_minutes': s.duration.inMinutes,
        }).toList();
      },
    );

    // 获取指定应用今日使用时长
    _tools['get_app_usage_today'] = AgentTool(
      name: 'get_app_usage_today',
      description: '获取指定应用今天的使用时长',
      parameters: {
        'type': 'object',
        'properties': {
          'app_name': {
            'type': 'string',
            'description': '应用名称，如"抖音"',
          },
        },
        'required': ['app_name'],
      },
      executor: (args) async {
        final appName = args['app_name'] as String;
        final seconds = await _usageProvider.getAppUsageToday(
          _guessPackageName(appName),
        );
        return {
          'app_name': appName,
          'minutes': seconds ~/ 60,
          'is_currently_used': await _usageProvider.isAppCurrentlyUsed(
            _guessPackageName(appName),
          ),
        };
      },
    );
  }

  // ==================== 操作类工具 ====================

  void _registerActionTools() {
    // 发送提醒
    _tools['send_reminder'] = AgentTool(
      name: 'send_reminder',
      description: '向用户发送一条提醒通知',
      parameters: {
        'type': 'object',
        'properties': {
          'message': {
            'type': 'string',
            'description': '提醒内容',
          },
          'title': {
            'type': 'string',
            'description': '提醒标题',
            'default': 'Focus Flow',
          },
        },
        'required': ['message'],
      },
      executor: (args) async {
        // TODO: 接入实际通知服务
        final message = args['message'] as String;
        final title = args['title'] as String? ?? 'Focus Flow';
        debugPrint('🔔 发送通知: $title - $message');
        return {'sent': true, 'title': title, 'message': message};
      },
    );

    // 推荐替代活动
    _tools['suggest_activity'] = AgentTool(
      name: 'suggest_activity',
      description: '根据当前场景推荐替代活动',
      parameters: {
        'type': 'object',
        'properties': {
          'context': {
            'type': 'string',
            'description': '当前场景，如"连续使用40分钟"、"深夜刷手机"',
          },
        },
      },
      executor: (args) async {
        final context = args['context'] as String? ?? '';
        final activities = _getActivitiesForContext(context);
        final activity = activities[_random.nextInt(activities.length)];
        return {
          'activity': activity['name'],
          'description': activity['description'],
          'duration': activity['duration'],
        };
      },
    );

    // 更新每日目标
    _tools['update_daily_goal'] = AgentTool(
      name: 'update_daily_goal',
      description: '更新每日使用目标时长',
      parameters: {
        'type': 'object',
        'properties': {
          'minutes': {
            'type': 'integer',
            'description': '目标时长（分钟）',
          },
        },
        'required': ['minutes'],
      },
      executor: (args) async {
        final minutes = args['minutes'] as int;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('daily_goal_minutes', minutes);
        return {'new_goal_minutes': minutes, 'hours': minutes / 60};
      },
    );

    // 获取当前目标
    _tools['get_daily_goal'] = AgentTool(
      name: 'get_daily_goal',
      description: '获取当前设置的每日使用目标',
      parameters: {
        'type': 'object',
        'properties': {},
      },
      executor: (args) async {
        final prefs = await SharedPreferences.getInstance();
        final minutes = prefs.getInt('daily_goal_minutes') ?? 240; // 默认4小时
        return {
          'minutes': minutes,
          'hours': minutes / 60,
        };
      },
    );
  }

  // ==================== 规则类工具 ====================

  void _registerRuleTools() {
    // 创建规则
    _tools['create_rule'] = AgentTool(
      name: 'create_rule',
      description: '创建一个新的智能提醒规则',
      parameters: {
        'type': 'object',
        'properties': {
          'name': {
            'type': 'string',
            'description': '规则名称',
          },
          'condition': {
            'type': 'string',
            'description': '触发条件描述，如"晚上8点后使用抖音超过30分钟"',
          },
          'action': {
            'type': 'string',
            'description': '触发后的动作，如"发送提醒休息"',
          },
          'enabled': {
            'type': 'boolean',
            'description': '是否立即启用',
            'default': true,
          },
        },
        'required': ['name', 'condition', 'action'],
      },
      executor: (args) async {
        final rule = AgentRule(
          name: args['name'] as String,
          condition: args['condition'] as String,
          action: args['action'] as String,
          enabled: args['enabled'] as bool? ?? true,
          createdAt: DateTime.now(),
        );

        final prefs = await SharedPreferences.getInstance();
        final rules = await _loadRules();
        rules.add(rule);
        await _saveRules(rules);

        return {
          'created': true,
          'rule': rule.toJson(),
          'total_rules': rules.length,
        };
      },
    );

    // 列出所有规则
    _tools['list_rules'] = AgentTool(
      name: 'list_rules',
      description: '列出所有已创建的规则',
      parameters: {
        'type': 'object',
        'properties': {
          'include_disabled': {
            'type': 'boolean',
            'description': '是否包含已禁用的规则',
            'default': false,
          },
        },
      },
      executor: (args) async {
        final includeDisabled = args['include_disabled'] as bool? ?? false;
        final rules = await _loadRules();
        final filtered = includeDisabled
            ? rules
            : rules.where((r) => r.enabled).toList();

        return filtered.map((r) => r.toJson()).toList();
      },
    );

    // 切换规则状态
    _tools['toggle_rule'] = AgentTool(
      name: 'toggle_rule',
      description: '启用或禁用指定规则',
      parameters: {
        'type': 'object',
        'properties': {
          'rule_name': {
            'type': 'string',
            'description': '规则名称',
          },
          'enabled': {
            'type': 'boolean',
            'description': 'true启用，false禁用',
          },
        },
        'required': ['rule_name', 'enabled'],
      },
      executor: (args) async {
        final ruleName = args['rule_name'] as String;
        final enabled = args['enabled'] as bool;

        final rules = await _loadRules();
        var found = false;

        for (var i = 0; i < rules.length; i++) {
          if (rules[i].name == ruleName) {
            rules[i] = rules[i].copyWith(enabled: enabled);
            found = true;
            break;
          }
        }

        if (!found) {
          throw Exception('未找到规则: $ruleName');
        }

        await _saveRules(rules);
        return {'success': true, 'rule_name': ruleName, 'enabled': enabled};
      },
    );

    // 删除规则
    _tools['delete_rule'] = AgentTool(
      name: 'delete_rule',
      description: '删除指定规则',
      parameters: {
        'type': 'object',
        'properties': {
          'rule_name': {
            'type': 'string',
            'description': '要删除的规则名称',
          },
        },
        'required': ['rule_name'],
      },
      executor: (args) async {
        final ruleName = args['rule_name'] as String;
        final rules = await _loadRules();
        final newRules = rules.where((r) => r.name != ruleName).toList();

        if (newRules.length == rules.length) {
          throw Exception('未找到规则: $ruleName');
        }

        await _saveRules(newRules);
        return {'deleted': true, 'rule_name': ruleName, 'remaining': newRules.length};
      },
    );
  }

  // ==================== 日程类工具 ====================

  void _registerScheduleTools() {
    // 添加日程/课程
    _tools['add_schedule'] = AgentTool(
      name: 'add_schedule',
      description: '添加课程或日程安排，如"周一上午8点有高数课"',
      parameters: {
        'type': 'object',
        'properties': {
          'description': {
            'type': 'string',
            'description': '自然语言描述的日程，如"周一上午8点到9点半高数课在A301"',
          },
        },
        'required': ['description'],
      },
      executor: (args) async {
        final description = args['description'] as String;
        final parser = ScheduleNLParser();
        final event = parser.parse(description);

        if (event == null) {
          return {'success': false, 'error': '无法解析日程信息'};
        }

        final repo = ScheduleRepository();
        await repo.load();
        await repo.addEvent(event);

        return {
          'success': true,
          'event': {
            'name': event.name,
            'type': event.type.displayName,
            'time': event.timeSlot.displayTime,
            'weekdays': event.weekdayDisplay,
            'location': event.location,
            'policy': {
              'entertainment_limit': event.policy.entertainmentLimitMinutes,
            },
          },
        };
      },
    );

    // 获取今日日程
    _tools['get_today_schedule'] = AgentTool(
      name: 'get_today_schedule',
      description: '获取今天的所有日程安排',
      parameters: {
        'type': 'object',
        'properties': {},
      },
      executor: (args) async {
        final repo = ScheduleRepository();
        await repo.load();
        final events = repo.getTodayEvents(DateTime.now());

        return events.map((e) => {
          'name': e.name,
          'type': e.type.displayName,
          'time': e.timeSlot.displayTime,
          'location': e.location,
          'is_active': e.isActive(DateTime.now()),
        }).toList();
      },
    );

    // 获取当前上下文
    _tools['get_current_context'] = AgentTool(
      name: 'get_current_context',
      description: '获取当前正在进行的日程和上下文',
      parameters: {
        'type': 'object',
        'properties': {},
      },
      executor: (args) async {
        final repo = ScheduleRepository();
        await repo.load();
        final context = repo.getCurrentContext(DateTime.now());

        return {
          'has_active_event': context.activeEvent != null,
          'event_name': context.eventName,
          'minutes_elapsed': context.minutesElapsed,
          'minutes_remaining': context.minutesRemaining,
          'policy': context.policy != null ? {
            'allow_tools': context.policy!.allowToolUsage,
            'entertainment_limit': context.policy!.entertainmentLimitMinutes,
          } : null,
        };
      },
    );

    // 分析某时段使用
    _tools['analyze_time_slot'] = AgentTool(
      name: 'analyze_time_slot',
      description: '分析某个日程时段的手机使用情况',
      parameters: {
        'type': 'object',
        'properties': {
          'event_name': {
            'type': 'string',
            'description': '日程名称，如"高数课"',
          },
        },
        'required': ['event_name'],
      },
      executor: (args) async {
        final eventName = args['event_name'] as String;

        // 查找事件
        final repo = ScheduleRepository();
        await repo.load();
        final events = repo.getTodayEvents(DateTime.now());
        final event = events.firstWhere(
          (e) => e.name.contains(eventName),
          orElse: () => throw Exception('未找到该日程'),
        );

        // 分析时段使用
        final analyzer = TimeSlotAnalyzer();
        final analysis = await analyzer.analyzeScheduleEvent(event, DateTime.now());

        return {
          'event_name': event.name,
          'total_minutes': analysis.totalSeconds ~/ 60,
          'phone_usage_minutes': analysis.totalPhoneUsageSeconds ~/ 60,
          'entertainment_minutes': analysis.entertainmentSeconds ~/ 60,
          'communication_minutes': analysis.communicationSeconds ~/ 60,
          'focus_score': analysis.focusScore.round(),
          'assessment': analysis.assessment,
          'summary': analysis.summary,
        };
      },
    );

    // 列出所有日程
    _tools['list_schedules'] = AgentTool(
      name: 'list_schedules',
      description: '列出所有已添加的日程/课程',
      parameters: {
        'type': 'object',
        'properties': {},
      },
      executor: (args) async {
        final repo = ScheduleRepository();
        await repo.load();
        final events = repo.getAllEvents();

        return events.map((e) => {
          'name': e.name,
          'type': e.type.displayName,
          'weekdays': e.weekdayDisplay,
          'time': e.timeSlot.displayTime,
          'location': e.location,
        }).toList();
      },
    );
  }

  // ==================== 分析类工具 ====================

  void _registerAnalysisTools() {
    // 分析使用模式
    _tools['analyze_usage_pattern'] = AgentTool(
      name: 'analyze_usage_pattern',
      description: '分析用户的使用习惯和模式',
      parameters: {
        'type': 'object',
        'properties': {},
      },
      executor: (args) async {
        final weekly = await _usageProvider.getWeeklyUsage();
        final today = await _usageProvider.getTodayUsage(detailed: true);
        final continuous = await _usageProvider.getContinuousSessions(
          DateTime.now(),
          minDurationMinutes: 30,
        );

        // 计算平均使用
        final avgMinutes = weekly.isEmpty
            ? 0
            : weekly.fold<int>(0, (sum, d) => sum + d.totalScreenTime) ~/
                weekly.length ~/ 60;

        // 找出最常使用的应用
        final topApps = today.appUsages.take(3).map((a) => a.appName).toList();

        return {
          'daily_average_minutes': avgMinutes,
          'top_apps': topApps,
          'long_sessions_today': continuous.length,
          'pattern_summary': _generatePatternSummary(avgMinutes, topApps, continuous.length),
        };
      },
    );

    // 生成周报
    _tools['export_weekly_report'] = AgentTool(
      name: 'export_weekly_report',
      description: '生成本周使用报告',
      parameters: {
        'type': 'object',
        'properties': {
          'include_suggestions': {
            'type': 'boolean',
            'description': '是否包含改进建议',
            'default': true,
          },
        },
      },
      executor: (args) async {
        final weekly = await _usageProvider.getWeeklyUsage();
        final comparison = await _usageProvider.compareWithYesterday();

        final totalMinutes = weekly.fold<int>(
          0,
          (sum, d) => sum + d.totalScreenTime ~/ 60,
        );
        final avgMinutes = weekly.isEmpty ? 0 : totalMinutes ~/ weekly.length;

        return {
          'week_total_hours': totalMinutes ~/ 60,
          'daily_average_hours': avgMinutes ~/ 60,
          'daily_average_minutes': avgMinutes % 60,
          'compared_to_last_week': comparison.percentageChange,
          'trend': comparison.percentageChange < 0 ? 'improving' : 'needs_attention',
        };
      },
    );
  }

  // ==================== 辅助方法 ====================

  final _random = DateTime.now().millisecond;

  String _guessPackageName(String appName) {
    // 常见应用包名映射
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
    };

    final lower = appName.toLowerCase();
    for (var entry in map.entries) {
      if (lower.contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }

    // 返回原样，让系统尝试匹配
    return appName;
  }

  List<Map<String, dynamic>> _getActivitiesForContext(String context) {
    final lower = context.toLowerCase();

    // 深夜场景
    if (lower.contains('深夜') || lower.contains('晚上') || lower.contains('夜')) {
      return [
        {'name': '放下手机准备睡觉', 'description': '深呼吸5次，很快就能入睡', 'duration': '5分钟'},
        {'name': '简单冥想', 'description': '闭上眼睛，专注呼吸', 'duration': '3分钟'},
        {'name': '回忆今天三件好事', 'description': '感恩练习帮助更好入睡', 'duration': '2分钟'},
      ];
    }

    // 连续使用场景
    if (lower.contains('连续') || lower.contains('长')) {
      return [
        {'name': '眼保健操', 'description': '按压睛明穴、攒竹穴，各10秒', 'duration': '3分钟'},
        {'name': '颈椎放松', 'description': '缓慢转头、低头、仰头各5次', 'duration': '2分钟'},
        {'name': '远眺放松', 'description': '看远处20秒，再看近处20秒，重复3次', 'duration': '2分钟'},
        {'name': '起身走动', 'description': '离开座位走动，喝杯水', 'duration': '3分钟'},
      ];
    }

    // 默认场景
    return [
      {'name': '闭目养神', 'description': '闭上眼睛，深呼吸', 'duration': '2分钟'},
      {'name': '伸展运动', 'description': '伸个懒腰，活动肩颈', 'duration': '2分钟'},
      {'name': '喝杯水', 'description': '起身喝杯水，走动一下', 'duration': '3分钟'},
    ];
  }

  String _generatePatternSummary(int avgMinutes, List<String> topApps, int longSessions) {
    final hours = avgMinutes ~/ 60;
    final mins = avgMinutes % 60;

    var summary = '平均每天使用$hours小时${mins}分钟。';

    if (topApps.isNotEmpty) {
      summary += '主要使用${topApps.join('、')}等应用。';
    }

    if (longSessions > 2) {
      summary += '今天有$longSessions次长时间连续使用，建议注意休息间隔。';
    } else {
      summary += '使用节奏控制得不错。';
    }

    return summary;
  }

  Future<List<AgentRule>> _loadRules() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList('agent_rules') ?? [];
    return jsonList
        .map((json) => AgentRule.fromJson(jsonDecode(json)))
        .toList();
  }

  Future<void> _saveRules(List<AgentRule> rules) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = rules.map((r) => jsonEncode(r.toJson())).toList();
    await prefs.setStringList('agent_rules', jsonList);
  }
}

// ==================== 规则模型 ====================

class AgentRule {
  final String name;
  final String condition;
  final String action;
  final bool enabled;
  final DateTime createdAt;

  AgentRule({
    required this.name,
    required this.condition,
    required this.action,
    required this.enabled,
    required this.createdAt,
  });

  AgentRule copyWith({bool? enabled}) => AgentRule(
    name: name,
    condition: condition,
    action: action,
    enabled: enabled ?? this.enabled,
    createdAt: createdAt,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'condition': condition,
    'action': action,
    'enabled': enabled,
    'created_at': createdAt.toIso8601String(),
  };

  factory AgentRule.fromJson(Map<String, dynamic> json) => AgentRule(
    name: json['name'] as String,
    condition: json['condition'] as String,
    action: json['action'] as String,
    enabled: json['enabled'] as bool,
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}
