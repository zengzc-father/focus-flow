import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'enhanced_agent_tools.dart';
import 'user_override_manager.dart';
import '../data/services/schedule_repository.dart';
import '../data/models/schedule.dart';
import '../data/services/rule_engine.dart';
import 'nl_rule_parser.dart';
import 'agent_rule_parser.dart';

/// 增强版 Focus Agent
/// 拥有应用全部操作权限，提供全方位自律辅助
class EnhancedFocusAgent {
  static final EnhancedFocusAgent _instance = EnhancedFocusAgent._internal();
  factory EnhancedFocusAgent() => _instance;
  EnhancedFocusAgent._internal();

  final EnhancedAgentToolExecutor _tools = EnhancedAgentToolExecutor();
  final UserOverrideManager _overrideManager = UserOverrideManager();
  bool _isInitialized = false;

  // 状态流
  final StreamController<AgentState> _stateController = StreamController<AgentState>.broadcast();
  Stream<AgentState> get stateStream => _stateController.stream;

  // 消息流
  final StreamController<AgentMessage> _messageController = StreamController<AgentMessage>.broadcast();
  Stream<AgentMessage> get messageStream => _messageController.stream;

  // 主动干预流
  final StreamController<AgentIntervention> _interventionController = StreamController<AgentIntervention>.broadcast();
  Stream<AgentIntervention> get interventionStream => _interventionController.stream;

  // 当前状态
  AgentState _currentState = AgentState.idle;
  Timer? _perceptionTimer;

  /// 初始化
  Future<void> initialize() async {
    if (_isInitialized) return;

    _tools.initialize();
    await _overrideManager.initialize();

    // 启动主动感知循环
    _startPerceptionLoop();

    _isInitialized = true;
    debugPrint('🤖 增强 Agent 初始化完成');
  }

  /// 释放资源
  void dispose() {
    _perceptionTimer?.cancel();
    _stateController.close();
    _messageController.close();
    _interventionController.close();
  }

  // ==================== 核心对话处理 ====================

  /// 处理用户自然语言输入
  Future<AgentResponse> processUserInput(String input) async {
    debugPrint('👤 用户: $input');
    _setState(AgentState.processing);

    try {
      // 1. 意图识别
      final intent = _parseIntent(input);
      debugPrint('🎯 意图: ${intent.type}');

      // 2. 根据意图执行
      final response = await _executeIntent(intent, input);

      // 3. 记录对话
      _addMessage(AgentMessage.fromUser(input));
      _addMessage(AgentMessage.fromAgent(response));

      _setState(AgentState.idle);
      return response;
    } catch (e) {
      _setState(AgentState.error);
      return AgentResponse(
        text: '抱歉，处理时出错了：$e',
        type: ResponseType.error,
      );
    }
  }

  /// 解析用户意图
  UserIntent _parseIntent(String input) {
    final lower = input.toLowerCase();

    // ===== 紧急控制 =====
    if (RegExp(r'(跳过|暂停|别管|安静|别提醒|闭嘴)').hasMatch(lower)) {
      return UserIntent(UserIntentType.emergencyOverride, {'raw': input});
    }

    if (RegExp(r'(全部|所有|完全).*(暂停|停止|关掉)').hasMatch(lower)) {
      return UserIntent(UserIntentType.globalPause, {'raw': input});
    }

    // ===== 专注模式 =====
    if (RegExp(r'(开始|启动).*(专注|番茄|计时)').hasMatch(lower) ||
        RegExp(r'我要.*(专注|学习|工作)').hasMatch(lower)) {
      return UserIntent(UserIntentType.startFocus, {'raw': input});
    }

    if (RegExp(r'(停止|结束|完成).*(专注|番茄)').hasMatch(lower)) {
      return UserIntent(UserIntentType.stopFocus, {'raw': input});
    }

    if (RegExp(r'(专注|番茄).*状态').hasMatch(lower) ||
        RegExp(r'正在.*专注').hasMatch(lower)) {
      return UserIntent(UserIntentType.getFocusStatus, {});
    }

    // ===== 查询类 =====
    if (RegExp(r'(今天|今日).*(用了|使用|多久|时间)').hasMatch(lower) ||
        RegExp(r'用了多久|使用情况|统计数据').hasMatch(lower)) {
      return UserIntent(UserIntentType.queryUsage, {'raw': input});
    }

    if (RegExp(r'(现在|当前).*状态').hasMatch(lower)) {
      return UserIntent(UserIntentType.queryRealtimeStatus, {});
    }

    if (RegExp(r'(周报|本周|总结|报告)').hasMatch(lower)) {
      return UserIntent(UserIntentType.getReport, {});
    }

    if (RegExp(r'(建议|推荐|怎么办|做什么)').hasMatch(lower)) {
      return UserIntent(UserIntentType.askAdvice, {});
    }

    // ===== 规则管理 =====
    if (RegExp(r'(创建|添加|设置).*(规则|限制)').hasMatch(lower) ||
        RegExp(r'(如果|超过|达到).*(提醒|通知)').hasMatch(lower) ||
        RegExp(r'(上课|自习).*别.*(刷|玩|用)').hasMatch(lower)) {
      return UserIntent(UserIntentType.createRule, {'raw': input});
    }

    if (RegExp(r'(查看|列出|显示).*(规则|设置)').hasMatch(lower)) {
      return UserIntent(UserIntentType.listRules, {});
    }

    if (RegExp(r'(删除|移除).*(规则)').hasMatch(lower)) {
      return UserIntent(UserIntentType.deleteRule, {'raw': input});
    }

    if (RegExp(r'(开启|启用|关闭|禁用|暂停).*(规则)').hasMatch(lower)) {
      return UserIntent(UserIntentType.toggleRule, {'raw': input});
    }

    // ===== 日程管理 =====
    if (RegExp(r'(添加|创建).*(课程|日程|计划)').hasMatch(lower) ||
        RegExp(r'我有.*课').hasMatch(lower)) {
      return UserIntent(UserIntentType.addSchedule, {'raw': input});
    }

    if (RegExp(r'(今天|今日).*(日程|课程|计划)').hasMatch(lower)) {
      return UserIntent(UserIntentType.getSchedule, {});
    }

    if (RegExp(r'(现在|当前).*(在|上).*(课|什么)').hasMatch(lower)) {
      return UserIntent(UserIntentType.getCurrentContext, {});
    }

    // ===== 目标设置 =====
    if (RegExp(r'(设置|修改|改成).*(目标|时间|时长)').hasMatch(lower)) {
      return UserIntent(UserIntentType.updateGoal, {'raw': input});
    }

    // ===== 应用相关 =====
    if (RegExp(r'(抖音|微信|微博|小红书|b站|快手).*(用了|多久|时间)').hasMatch(lower)) {
      return UserIntent(UserIntentType.queryAppUsage, {'raw': input});
    }

    // ===== 默认 =====
    if (RegExp(r'(你好|在吗|hi|hello)').hasMatch(lower)) {
      return UserIntent(UserIntentType.greeting, {});
    }

    if (RegExp(r'(帮助|怎么用|功能|能做什么)').hasMatch(lower)) {
      return UserIntent(UserIntentType.help, {});
    }

    return UserIntent(UserIntentType.general, {'raw': input});
  }

  /// 执行意图
  Future<AgentResponse> _executeIntent(UserIntent intent, String rawInput) async {
    switch (intent.type) {
      case UserIntentType.greeting:
        return _handleGreeting();
      case UserIntentType.help:
        return _handleHelp();
      case UserIntentType.queryUsage:
        return await _handleQueryUsage();
      case UserIntentType.queryRealtimeStatus:
        return await _handleQueryRealtimeStatus();
      case UserIntentType.queryAppUsage:
        return await _handleQueryAppUsage(rawInput);
      case UserIntentType.getReport:
        return await _handleGetReport();
      case UserIntentType.askAdvice:
        return await _handleAskAdvice();
      case UserIntentType.createRule:
        return await _handleCreateRule(rawInput);
      case UserIntentType.listRules:
        return await _handleListRules();
      case UserIntentType.toggleRule:
        return await _handleToggleRule(rawInput);
      case UserIntentType.deleteRule:
        return await _handleDeleteRule(rawInput);
      case UserIntentType.addSchedule:
        return await _handleAddSchedule(rawInput);
      case UserIntentType.getSchedule:
        return await _handleGetSchedule();
      case UserIntentType.getCurrentContext:
        return await _handleGetCurrentContext();
      case UserIntentType.updateGoal:
        return await _handleUpdateGoal(rawInput);
      case UserIntentType.startFocus:
        return await _handleStartFocus(rawInput);
      case UserIntentType.stopFocus:
        return await _handleStopFocus();
      case UserIntentType.getFocusStatus:
        return await _handleGetFocusStatus();
      case UserIntentType.emergencyOverride:
        return await _handleEmergencyOverride(rawInput);
      case UserIntentType.globalPause:
        return await _handleGlobalPause(rawInput);
      default:
        return _handleGeneralChat(rawInput);
    }
  }

  // ==================== 具体处理实现 ====================

  Future<AgentResponse> _handleGreeting() async {
    final hour = DateTime.now().hour;
    String greeting = '你好';
    if (hour < 12) greeting = '早上好';
    else if (hour < 18) greeting = '下午好';
    else greeting = '晚上好';

    return AgentResponse(
      text: '$greeting！我是 Focus，你的屏幕时间助手。\n\n我可以帮你：\n• 查看使用统计\n• 创建提醒规则\n• 启动专注模式\n• 分析使用习惯\n\n直接说出你的需求就行~',
      type: ResponseType.greeting,
    );
  }

  Future<AgentResponse> _handleHelp() async {
    return AgentResponse(
      text: '''我可以帮你完成这些任务：

📊 **查询数据**
• "今天用了多久" - 今日使用统计
• "抖音用了多久" - 特定应用使用
• "给我周报" - 本周使用报告

⏱️ **专注模式**
• "开始专注" / "我要学习" - 启动番茄钟
• "专注状态" - 查看当前专注
• "停止专注" - 结束专注

📋 **规则管理**
• "上课别让我刷抖音" - 创建场景规则
• "晚上8点后刷抖音超过30分钟提醒我" - 创建时间规则
• "列出规则" - 查看所有规则
• "暂停第一条规则" - 管理规则

📅 **日程管理**
• "周一上午8点有高数课" - 添加课程
• "今天有什么课" - 查看今日日程
• "现在在上课吗" - 查看当前状态

🎯 **其他**
• "把目标改成3小时" - 修改每日目标
• "给我建议" - 获取个性化建议
• "今天全部暂停" - 全局暂停监控

直接说出你的需求就行~''',
      type: ResponseType.help,
    );
  }

  Future<AgentResponse> _handleQueryUsage() async {
    final data = await _tools.execute('get_today_usage', {'include_apps': true, 'top_n': 3});
    final totalMinutes = data['total_minutes'] as int;
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    final topApps = data['top_apps'] as List<dynamic>;
    final byCategory = data['by_category'] as Map<String, dynamic>;

    var text = '今日使用统计\n\n';
    text += '**总时长**：';
    if (hours > 0) text += '$hours小时';
    text += '$minutes分钟\n';
    text += '**解锁次数**：${data['unlock_count']}次\n';
    text += '**查看频率**：每小时${data['pickups_per_hour']}次\n\n';

    if (topApps.isNotEmpty) {
      text += '**使用最多的应用**：\n';
      for (final app in topApps) {
        text += '• ${app['name']}: ${app['minutes']}分钟\n';
      }
      text += '\n';
    }

    // 分类统计
    text += '**分类统计**：\n';
    if (byCategory['entertainment'] > 0) {
      text += '• 娱乐: ${byCategory['entertainment']}分钟\n';
    }
    if (byCategory['communication'] > 0) {
      text += '• 通讯: ${byCategory['communication']}分钟\n';
    }
    if (byCategory['study'] > 0) {
      text += '• 学习: ${byCategory['study']}分钟\n';
    }

    return AgentResponse(text: text, type: ResponseType.info, data: data);
  }

  Future<AgentResponse> _handleQueryRealtimeStatus() async {
    final data = await _tools.execute('get_realtime_status', {});

    var text = '**当前状态**\n\n';
    text += '当前应用：${data['current_app'] ?? '无'}\n';
    text += '屏幕状态：${data['is_screen_on'] ? '亮屏' : '熄屏'}\n';

    if (data['last_used_seconds_ago'] != null) {
      final seconds = data['last_used_seconds_ago'] as int;
      if (seconds < 60) {
        text += '最近使用：${seconds}秒前\n';
      } else {
        text += '最近使用：${seconds ~/ 60}分钟前\n';
      }
    }

    text += '\n今日已使用：${data['today_total_minutes']}分钟';

    return AgentResponse(text: text, type: ResponseType.info, data: data);
  }

  Future<AgentResponse> _handleQueryAppUsage(String input) async {
    // 提取应用名
    final apps = ['抖音', '微信', '微博', '小红书', 'b站', '快手', '知乎', '淘宝'];
    String? targetApp;
    for (final app in apps) {
      if (input.contains(app)) {
        targetApp = app;
        break;
      }
    }

    if (targetApp == null) {
      return AgentResponse(
        text: '请告诉我你想查询哪个应用，比如"抖音用了多久"~',
        type: ResponseType.prompt,
      );
    }

    final data = await _tools.execute('get_app_usage_details', {
      'app_name': targetApp,
      'days': 7,
    });

    final total = data['total_minutes_last_7_days'] as int;
    final avg = data['average_daily_minutes'] as int;

    var text = '**$targetApp 使用统计**\n\n';
    text += '近7天总计：$total分钟（约${total ~/ 60}小时）\n';
    text += '日均使用：$avg分钟\n';
    text += '趋势：${data['trend'] == 'increasing' ? '上升 ↑' : '下降 ↓'}\n\n';

    if (avg > 60) {
      text += '💡 使用时间较长，建议设置使用限制。';
    } else if (avg > 30) {
      text += '💡 使用适中，继续保持。';
    } else {
      text += '💡 使用较少，很好！';
    }

    return AgentResponse(text: text, type: ResponseType.info, data: data);
  }

  Future<AgentResponse> _handleGetReport() async {
    final weekly = await _tools.execute('get_weekly_trend', {'include_today': true});
    final analysis = await _tools.execute('analyze_usage_pattern', {'days': 7});

    final data = weekly['daily_data'] as List<dynamic>;
    final avg = weekly['average_minutes'] as int;

    var text = '📊 **本周使用报告**\n\n';
    text += '日均使用：${avg ~/ 60}小时${avg % 60}分钟\n';
    text += '解锁频率：每天${analysis['pickup_frequency']}次\n';
    text += '风险等级：${analysis['risk_level'] == 'high' ? '高 ⚠️' : analysis['risk_level'] == 'medium' ? '中 ⚡' : '低 ✅'}\n\n';

    if ((analysis['problem_apps'] as List).isNotEmpty) {
      text += '**需要注意的应用**：\n';
      for (final app in analysis['problem_apps']) {
        text += '• ${app['name']}: ${app['minutes']}分钟/天\n';
      }
      text += '\n';
    }

    text += '趋势：${weekly['trend'] == 'up' ? '较上周有所上升' : '较上周有所下降'}';

    return AgentResponse(text: text, type: ResponseType.report, data: weekly);
  }

  Future<AgentResponse> _handleAskAdvice() async {
    final suggestions = await _tools.execute('generate_suggestions', {'focus_area': 'general'});
    final suggestionList = suggestions['suggestions'] as List<dynamic>;

    if (suggestionList.isEmpty) {
      return AgentResponse(
        text: '你的使用情况很健康！继续保持~\n\n小建议：每使用30分钟起来活动一下，保护眼睛。',
        type: ResponseType.suggestion,
      );
    }

    var text = '💡 **个性化建议**\n\n';
    for (final s in suggestionList.take(3)) {
      text += '**${s['title']}**\n';
      text += '${s['description']}\n\n';
    }

    return AgentResponse(text: text, type: ResponseType.suggestion, data: suggestions);
  }

  Future<AgentResponse> _handleCreateRule(String input) async {
    // 使用自然语言解析器解析规则
    final parser = AgentRuleParser();
    final rule = parser.parse(input);

    if (rule == null) {
      return AgentResponse(
        text: '我没理解这条规则，请说"上课刷抖音超过5分钟提醒我"或"每天使用手机超过3小时提醒我"这样的格式~',
        type: ResponseType.prompt,
      );
    }

    // 保存到RuleEngine
    await RuleEngine().addAgentRule(rule);

    // 构建确认消息
    var text = '✅ 已创建规则：**${rule.name}**\n\n';
    text += '📝 条件：${rule.description}\n';
    if (rule.conditions.timeRange != null) {
      text += '⏰ 时间段：${rule.conditions.timeRange}\n';
    }
    if (rule.conditions.days != null && rule.conditions.days!.isNotEmpty) {
      final dayNames = ['一', '二', '三', '四', '五', '六', '日'];
      final days = rule.conditions.days!.map((d) => '周${dayNames[d - 1]}').join('、');
      text += '📅 重复：$days\n';
    }
    if (rule.conditions.consecutiveMinutes != null) {
      text += '⏱️ 限制：连续使用超过${rule.conditions.consecutiveMinutes}分钟\n';
    }
    if (rule.conditions.totalMinutes != null) {
      text += '📊 限制：今日累计超过${rule.conditions.totalMinutes! ~/ 60}小时\n';
    }
    text += '\n💡 规则已生效，条件满足时会提醒你！';

    return AgentResponse(
      text: text,
      type: ResponseType.success,
      data: rule.toJson(),
    );
  }

  Future<AgentResponse> _handleListRules() async {
    final data = await _tools.execute('get_all_rules', {'include_disabled': true});
    final rules = data['rules'] as List<dynamic>;

    if (rules.isEmpty) {
      return AgentResponse(
        text: '你还没有设置任何规则。\n\n对我说"上课别让我刷抖音"或"晚上8点后抖音超过30分钟提醒我"来创建规则~',
        type: ResponseType.info,
      );
    }

    var text = '📋 **你的规则（${rules.length}条）**\n\n';
    for (var i = 0; i < rules.length; i++) {
      final rule = rules[i];
      final status = rule['enabled'] ? '✅' : '⏸️';
      text += '$status ${i + 1}. ${rule['name']}\n';
    }

    text += '\n对我说"暂停第N条"或"删除XX规则"来管理规则~';

    return AgentResponse(text: text, type: ResponseType.info, data: data);
  }

  Future<AgentResponse> _handleToggleRule(String input) async {
    final prefs = await SharedPreferences.getInstance();
    final rules = prefs.getStringList('agent_rules') ?? [];

    if (rules.isEmpty) {
      return AgentResponse(
        text: '你还没有设置任何规则~',
        type: ResponseType.info,
      );
    }

    // 尝试解析规则索引（如"第1条"、"第一条"）
    int? targetIndex;
    final indexMatch = RegExp(r'第(\d+)[条个]').firstMatch(input);
    if (indexMatch != null) {
      targetIndex = int.parse(indexMatch.group(1)!) - 1; // 转为0-based索引
    }

    // 尝试解析规则名称
    String? targetName;
    for (var ruleJson in rules) {
      final rule = jsonDecode(ruleJson) as Map<String, dynamic>;
      if (input.contains(rule['name'].toString())) {
        targetName = rule['name'];
        break;
      }
    }

    if (targetIndex == null && targetName == null) {
      return AgentResponse(
        text: '请说"暂停第1条规则"或"启用XX规则"来切换规则状态~',
        type: ResponseType.prompt,
      );
    }

    // 找到并切换规则状态
    for (var i = 0; i < rules.length; i++) {
      final ruleJson = rules[i];
      final rule = jsonDecode(ruleJson) as Map<String, dynamic>;

      if ((targetIndex != null && i == targetIndex) ||
          (targetName != null && rule['name'] == targetName)) {
        final currentStatus = rule['enabled'] as bool? ?? true;
        rule['enabled'] = !currentStatus;
        rules[i] = jsonEncode(rule);

        await prefs.setStringList('agent_rules', rules);

        final newStatus = !currentStatus ? '✅ 已启用' : '⏸️ 已暂停';
        return AgentResponse(
          text: '$newStatus：**${rule['name']}**\n\n规则状态已更新。',
          type: ResponseType.success,
        );
      }
    }

    return AgentResponse(
      text: '没找到对应的规则，说"列出规则"查看所有规则~',
      type: ResponseType.error,
    );
  }

  Future<AgentResponse> _handleDeleteRule(String input) async {
    final prefs = await SharedPreferences.getInstance();
    final rules = prefs.getStringList('agent_rules') ?? [];

    if (rules.isEmpty) {
      return AgentResponse(
        text: '你还没有设置任何规则~',
        type: ResponseType.info,
      );
    }

    // 尝试解析规则索引
    int? targetIndex;
    final indexMatch = RegExp(r'第(\d+)[条个]').firstMatch(input);
    if (indexMatch != null) {
      targetIndex = int.parse(indexMatch.group(1)!) - 1;
    }

    // 尝试解析规则名称
    String? targetName;
    for (var ruleJson in rules) {
      final rule = jsonDecode(ruleJson) as Map<String, dynamic>;
      if (input.contains(rule['name'].toString())) {
        targetName = rule['name'];
        break;
      }
    }

    if (targetIndex == null && targetName == null) {
      return AgentResponse(
        text: '请说"删除第1条规则"或"删除XX规则"来删除规则~',
        type: ResponseType.prompt,
      );
    }

    // 找到并删除规则
    for (var i = 0; i < rules.length; i++) {
      final ruleJson = rules[i];
      final rule = jsonDecode(ruleJson) as Map<String, dynamic>;

      if ((targetIndex != null && i == targetIndex) ||
          (targetName != null && rule['name'] == targetName)) {
        final ruleName = rule['name'];
        rules.removeAt(i);
        await prefs.setStringList('agent_rules', rules);

        return AgentResponse(
          text: '🗑️ 已删除规则：**$ruleName**',
          type: ResponseType.success,
        );
      }
    }

    return AgentResponse(
      text: '没找到对应的规则，说"列出规则"查看所有规则~',
      type: ResponseType.error,
    );
  }

  Future<AgentResponse> _handleAddSchedule(String input) async {
    // 使用自然语言解析器解析日程
    final parser = ScheduleNLParser();
    final event = parser.parse(input);

    if (event == null) {
      return AgentResponse(
        text: '我没理解日程信息，请说"周一上午8点高数课在A301"或"每天下午4点健身1小时"这样的格式~',
        type: ResponseType.prompt,
      );
    }

    // 保存到日程仓库
    await ScheduleRepository().addEvent(event);

    // 构建回复
    var text = '✅ 已添加日程：**${event.name}**\n\n';
    text += '📅 时间：${event.weekdayDisplay} ${event.timeSlot.displayTime}\n';
    if (event.location != null) {
      text += '📍 地点：${event.location}\n';
    }
    text += '🏷️ 类型：${event.type.displayName}\n\n';
    text += '我会在${event.type == EventType.course || event.type == EventType.study ? "专注" : "提醒"}时段帮你监控使用手机的情况~';

    return AgentResponse(
      text: text,
      type: ResponseType.success,
      data: {
        'event_id': event.id,
        'name': event.name,
        'time_slot': event.timeSlot.displayTime,
        'weekdays': event.weekdays,
      },
    );
  }

  Future<AgentResponse> _handleGetSchedule() async {
    final schedule = await _tools.execute('get_today_schedule', {});

    if ((schedule as List).isEmpty) {
      return AgentResponse(
        text: '📅 今天没有安排课程或日程~\n\n对我说"周一上午8点有高数课"来添加。',
        type: ResponseType.info,
      );
    }

    var text = '📅 **今日日程**\n\n';
    for (final event in schedule) {
      final status = event['is_active'] ? '●' : event['is_upcoming'] ? '○' : '✓';
      text += '$status ${event['time']} ${event['name']}\n';
      if (event['location'] != null) {
        text += '   📍 ${event['location']}\n';
      }
    }

    return AgentResponse(text: text, type: ResponseType.info, data: schedule);
  }

  Future<AgentResponse> _handleGetCurrentContext() async {
    final context = await _tools.execute('get_current_context', {});

    if (context['has_active_event'] == true) {
      return AgentResponse(
        text: '📚 **当前状态**\n\n'
              '正在进行：${context['event_name']}\n'
              '类型：${context['event_type']}\n'
              '已进行：${context['minutes_elapsed']}分钟\n'
              '剩余：${context['minutes_remaining']}分钟\n\n'
              '${context['can_use_entertainment'] ? '可以使用娱乐应用' : '建议专注，减少娱乐应用使用'}',
        type: ResponseType.info,
        data: context,
      );
    }

    return AgentResponse(
      text: '🌟 **当前是自由时间**\n\n没有安排的活动，可以自由支配时间~',
      type: ResponseType.info,
    );
  }

  Future<AgentResponse> _handleUpdateGoal(String input) async {
    // 提取分钟数
    final minutes = _extractMinutes(input);
    if (minutes == null) {
      return AgentResponse(
        text: '请说"把目标改成X小时"或"目标设为X分钟"~',
        type: ResponseType.prompt,
      );
    }

    await _tools.execute('update_daily_goal', {'minutes': minutes});

    return AgentResponse(
      text: '✅ 每日目标已更新为${minutes ~/ 60}小时${minutes % 60}分钟\n\n我会帮你监控这个目标！',
      type: ResponseType.success,
    );
  }

  Future<AgentResponse> _handleStartFocus(String input) async {
    // 提取任务名和时长
    String taskName = '专注任务';
    int duration = 25;

    if (input.contains('学习')) taskName = '学习';
    else if (input.contains('工作')) taskName = '工作';
    else if (input.contains('作业')) taskName = '写作业';
    else if (input.contains('看书')) taskName = '阅读';

    // 提取时长
    final hourMatch = RegExp(r'(\d+)小时').firstMatch(input);
    final minMatch = RegExp(r'(\d+)分钟').firstMatch(input);
    if (hourMatch != null) {
      duration = int.parse(hourMatch.group(1)!) * 60;
    } else if (minMatch != null) {
      duration = int.parse(minMatch.group(1)!);
    }

    final result = await _tools.execute('start_focus_mode', {
      'task_name': taskName,
      'duration_minutes': duration,
    });

    return AgentResponse(
      text: '🍅 **专注模式已启动**\n\n任务：$taskName\n时长：$duration分钟\n\n保持专注，你可以的！',
      type: ResponseType.success,
      data: result,
    );
  }

  Future<AgentResponse> _handleStopFocus() async {
    final status = await _tools.execute('get_focus_status', {});

    if (status['is_focusing'] != true) {
      return AgentResponse(
        text: '当前没有在专注~',
        type: ResponseType.info,
      );
    }

    final result = await _tools.execute('stop_focus_mode', {'completed': true});

    return AgentResponse(
      text: '✅ **专注完成！**\n\n任务：${result['task_name']}\n实际专注：${result['actual_minutes']}分钟\n\n休息一下吧~',
      type: ResponseType.success,
      data: result,
    );
  }

  Future<AgentResponse> _handleGetFocusStatus() async {
    final status = await _tools.execute('get_focus_status', {});

    if (status['is_focusing'] != true) {
      return AgentResponse(
        text: '当前没有进行专注\n\n今日专注总计：${status['today_focus_minutes']}分钟\n\n说"开始专注"来启动番茄钟~',
        type: ResponseType.info,
      );
    }

    final remaining = status['remaining_minutes'] as int;
    final progress = (status['progress'] as double * 100).round();

    return AgentResponse(
      text: '🍅 **专注中**\n\n任务：${status['task_name']}\n剩余：$remaining分钟\n进度：$progress%\n\n保持专注！',
      type: ResponseType.info,
      data: status,
    );
  }

  Future<AgentResponse> _handleEmergencyOverride(String input) async {
    final result = await _overrideManager.emergencySkip(
      currentIntervention: 'active',
      reason: input,
      skipDuration: const Duration(minutes: 15),
    );

    return AgentResponse(
      text: result.message,
      type: ResponseType.success,
    );
  }

  Future<AgentResponse> _handleGlobalPause(String input) async {
    final duration = _extractDuration(input) ?? const Duration(hours: 2);

    final result = await _overrideManager.pauseAllMonitoring(
      duration: duration,
      reason: input,
    );

    return AgentResponse(
      text: result.message,
      type: ResponseType.success,
    );
  }

  Future<AgentResponse> _handleGeneralChat(String input) async {
    return AgentResponse(
      text: '抱歉，我可能没理解清楚。你可以说"帮助"查看我能做什么，或者直接说出你的需求~',
      type: ResponseType.unknown,
    );
  }

  // ==================== 主动感知循环 ====================

  void _startPerceptionLoop() {
    _perceptionTimer?.cancel();
    _perceptionTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _checkAndIntervene();
    });
  }

  Future<void> _checkAndIntervene() async {
    try {
      // 1. 检查当前是否在专注模式
      final focusStatus = await _tools.execute('get_focus_status', {});
      if (focusStatus['is_focusing'] == true) {
        // 检查专注是否被打断
        final realtime = await _tools.execute('get_realtime_status', {});
        if (realtime['current_app'] != 'Focus Flow') {
          // 用户离开了专注页面
          _interventionController.add(AgentIntervention(
            type: InterventionType.focusInterrupted,
            title: '专注被打断',
            message: '你似乎离开了专注页面，需要回来继续吗？',
            actions: ['回到专注', '结束专注'],
          ));
        }
        return;
      }

      // 2. 检查日程时段内使用
      final context = await _tools.execute('get_current_context', {});
      if (context['has_active_event'] == true && context['can_use_entertainment'] == false) {
        // 在上课时间，检查娱乐使用
        final analysis = await _tools.execute('analyze_schedule_slot', {
          'event_name': context['event_name'],
        });

        final entertainmentMinutes = analysis['entertainment_minutes'] as int;

        if (entertainmentMinutes >= 5) {
          _interventionController.add(AgentIntervention(
            type: InterventionType.scheduleIntervention,
            title: '${context['event_name']} 提醒',
            message: '你已使用娱乐应用${entertainmentMinutes}分钟，建议回到课堂内容~',
            actions: ['我知道了', '暂停提醒'],
          ));
        }
      }

      // 3. 检查连续使用
      final continuous = await _tools.execute('get_continuous_sessions', {'min_minutes': 45});
      if (continuous.isNotEmpty) {
        final session = continuous.first;
        _interventionController.add(AgentIntervention(
          type: InterventionType.continuousUse,
          title: '该休息了',
          message: '你已持续使用${session['app_name']}${session['duration_minutes']}分钟，起来活动一下吧~',
          actions: ['休息一下', '稍后提醒'],
        ));
      }

      // 4. 检查是否接近每日目标
      final today = await _tools.execute('get_today_usage', {'include_apps': false});
      final goal = await _tools.execute('get_daily_goal', {});
      final totalMinutes = today['total_minutes'] as int;
      final goalMinutes = goal['minutes'] as int;

      if (totalMinutes > goalMinutes * 0.9 && totalMinutes < goalMinutes) {
        _interventionController.add(AgentIntervention(
          type: InterventionType.approachingGoal,
          title: '接近今日目标',
          message: '今日已使用$totalMinutes分钟，距离目标${goalMinutes - totalMinutes}分钟~',
          actions: ['知道了'],
        ));
      }
    } catch (e) {
      debugPrint('主动感知失败: $e');
    }
  }

  // ==================== 辅助方法 ====================

  void _setState(AgentState state) {
    _currentState = state;
    _stateController.add(state);
  }

  void _addMessage(AgentMessage message) {
    _messageController.add(message);
  }

  int? _extractMinutes(String input) {
    final hourMatch = RegExp(r'(\d+)小时').firstMatch(input);
    if (hourMatch != null) {
      return int.parse(hourMatch.group(1)!) * 60;
    }

    final minMatch = RegExp(r'(\d+)分钟').firstMatch(input);
    if (minMatch != null) {
      return int.parse(minMatch.group(1)!);
    }

    final numMatch = RegExp(r'(\d+)').firstMatch(input);
    if (numMatch != null) {
      final num = int.parse(numMatch.group(1)!);
      if (num >= 30 && num <= 720) return num;
    }

    return null;
  }

  Duration? _extractDuration(String input) {
    final hourMatch = RegExp(r'(\d+)小时').firstMatch(input);
    if (hourMatch != null) {
      return Duration(hours: int.parse(hourMatch.group(1)!));
    }

    final minMatch = RegExp(r'(\d+)分钟').firstMatch(input);
    if (minMatch != null) {
      return Duration(minutes: int.parse(minMatch.group(1)!));
    }

    return null;
  }
}

// ==================== 数据模型 ====================

enum AgentState {
  idle,
  processing,
  intervening,
  error,
}

enum UserIntentType {
  greeting,
  help,
  queryUsage,
  queryRealtimeStatus,
  queryAppUsage,
  getReport,
  askAdvice,
  createRule,
  listRules,
  toggleRule,
  deleteRule,
  addSchedule,
  getSchedule,
  getCurrentContext,
  updateGoal,
  startFocus,
  stopFocus,
  getFocusStatus,
  emergencyOverride,
  globalPause,
  general,
}

class UserIntent {
  final UserIntentType type;
  final Map<String, dynamic> data;
  UserIntent(this.type, this.data);
}

enum ResponseType {
  info,
  success,
  error,
  warning,
  suggestion,
  intervention,
  gentleReminder,
  reminder,
  report,
  greeting,
  help,
  prompt,
  unknown,
}

class AgentResponse {
  final String text;
  final ResponseType type;
  final Map<String, dynamic>? data;
  AgentResponse({required this.text, required this.type, this.data});
}

class AgentMessage {
  final String id;
  final String text;
  final bool isFromAgent;
  final DateTime timestamp;
  final ResponseType? type;

  AgentMessage({
    required this.id,
    required this.text,
    required this.isFromAgent,
    required this.timestamp,
    this.type,
  });

  factory AgentMessage.fromAgent(AgentResponse response) => AgentMessage(
    id: DateTime.now().millisecondsSinceEpoch.toString(),
    text: response.text,
    isFromAgent: true,
    timestamp: DateTime.now(),
    type: response.type,
  );

  factory AgentMessage.fromUser(String text) => AgentMessage(
    id: DateTime.now().millisecondsSinceEpoch.toString(),
    text: text,
    isFromAgent: false,
    timestamp: DateTime.now(),
  );
}

enum InterventionType {
  focusInterrupted,
  scheduleIntervention,
  continuousUse,
  approachingGoal,
  bedtimeReminder,
}

class AgentIntervention {
  final InterventionType type;
  final String title;
  final String message;
  final List<String> actions;
  final DateTime timestamp;

  AgentIntervention({
    required this.type,
    required this.title,
    required this.message,
    required this.actions,
  }) : timestamp = DateTime.now();
}
