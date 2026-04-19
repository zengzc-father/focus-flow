import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'agent_tools.dart';
import 'nl_rule_parser.dart';
import 'user_override_manager.dart';
import '../data/services/smart_slot_monitor.dart';
import '../data/services/rule_engine.dart';

/// Focus Agent - 极简界面驱动的Agent
///
/// 核心设计理念：
/// 1. Agent通过tools执行所有操作
/// 2. 用户通过自然语言与Agent交互
/// 3. Agent主动感知并推送消息
/// 4. 界面只展示状态和Agent消息
/// 5. 用户拥有最高控制权
class FocusAgentCore {
  static final FocusAgentCore _instance = FocusAgentCore._internal();
  factory FocusAgentCore() => _instance;
  FocusAgentCore._internal();

  final AgentToolExecutor _toolExecutor = AgentToolExecutor();
  final SmartSlotMonitor _slotMonitor = SmartSlotMonitor();
  final UserOverrideManager _overrideManager = UserOverrideManager();
  bool _isInitialized = false;

  // 消息流控制器
  final StreamController<AgentMessage> _messageController =
      StreamController<AgentMessage>.broadcast();
  Stream<AgentMessage> get messageStream => _messageController.stream;

  // 初始化
  Future<void> initialize() async {
    if (_isInitialized) return;

    _toolExecutor.initialize();
    _slotMonitor.startMonitoring();
    await _overrideManager.initialize();

    // 监听用户覆盖事件
    _overrideManager.overrideStream.listen((event) {
      _addMessage(AgentMessage.fromAgent(AgentResponse(
        text: event.message,
        type: ResponseType.info,
      )));
    });

    _isInitialized = true;
    debugPrint('🤖 Focus Agent Core 已初始化');
  }

  /// 释放资源
  Future<void> dispose() async {
    _slotMonitor.stopMonitoring();
    _messageController.close();
  }

  /// 处理用户自然语言输入
  ///
  /// 1. 解析用户意图
  /// 2. 选择并执行相关tools
  /// 3. 生成自然语言回复
  Future<AgentResponse> processUserInput(String input) async {
    debugPrint('👤 用户输入: $input');

    // 意图识别
    final intent = _parseIntent(input);
    debugPrint('🎯 识别意图: $intent');

    // 根据意图执行相应操作
    try {
      switch (intent.type) {
        case UserIntentType.emergencyOverride:
          return await _handleEmergencyOverride(intent, input);
        case UserIntentType.globalPause:
          return await _handleGlobalPause(intent, input);
        case UserIntentType.rescheduleEvent:
          return await _handleRescheduleEvent(intent, input);
        case UserIntentType.temporaryDiscipline:
          return await _handleTemporaryDiscipline(intent, input);
        case UserIntentType.queryUsage:
          return await _handleQueryUsage(intent);
        case UserIntentType.createRule:
          return await _handleCreateRule(intent, input);
        case UserIntentType.listRules:
          return await _handleListRules();
        case UserIntentType.modifyRule:
          return await _handleModifyRule(intent);
        case UserIntentType.askAdvice:
          return await _handleAskAdvice(intent);
        case UserIntentType.updateGoal:
          return await _handleUpdateGoal(intent);
        case UserIntentType.getReport:
          return await _handleGetReport();
        case UserIntentType.suggestActivity:
          return await _handleSuggestActivity();
        case UserIntentType.getCurrentContext:
          return await _handleGetCurrentContext();
        case UserIntentType.general:
        default:
          return await _handleGeneralChat(input);
      }
    } catch (e) {
      debugPrint('❌ 处理失败: $e');
      return AgentResponse(
        text: '抱歉，处理时出错了，可以换个说法再试一次~',
        type: ResponseType.error,
      );
    }
  }

  /// Agent主动感知并决策
  ///
  /// 定期调用，检查是否需要主动干预
  Future<AgentResponse?> perceiveAndDecide() async {
    try {
      // 1. 优先检查日程时段内的智能监控
      final intervention = await _checkScheduledIntervention();
      if (intervention != null) {
        return intervention;
      }

      // 2. 检查全天使用情况
      return await _checkDailyUsage();
    } catch (e) {
      debugPrint('感知决策失败: $e');
      return null;
    }
  }

  /// 检查日程时段内的干预需求（分级阈值系统）
  Future<AgentResponse?> _checkScheduledIntervention() async {
    // 获取当前干预结果（由SmartSlotMonitor每分钟更新）
    // 这里简化处理，实际应该在UI层监听SmartSlotMonitor的结果

    // 检查当前上下文
    final contextResult = await _toolExecutor.execute('get_current_context', {});
    final hasActiveEvent = contextResult['has_active_event'] as bool;

    if (!hasActiveEvent) return null;

    // 如果在日程中，分析该时段使用
    final eventName = contextResult['event_name'] as String;

    try {
      final analysis = await _toolExecutor.execute('analyze_time_slot', {
        'event_name': eventName,
      });

      final entertainmentMinutes = analysis['entertainment_minutes'] as int;
      final focusScore = analysis['focus_score'] as int;

      // 娱乐使用超过3分钟（分级阈值）
      if (entertainmentMinutes >= 3 && entertainmentMinutes < 5) {
        return AgentResponse(
          text: '已经刷${entertainmentMinutes}分钟了，$eventName还顺利吗？适度放松就好~',
          type: ResponseType.gentleReminder,
        );
      }

      // 娱乐使用超过5分钟（强烈警告）
      if (entertainmentMinutes >= 5) {
        return AgentResponse(
          text: '$eventName时间已用${entertainmentMinutes}分钟娱乐，有点久了，现在放下，等结束再玩吧！',
          type: ResponseType.intervention,
        );
      }

      // 通讯使用超过10分钟（温和提醒）
      final communicationMinutes = analysis['communication_minutes'] as int;
      if (communicationMinutes >= 10 && communicationMinutes < 20) {
        return AgentResponse(
          text: '回消息用了${communicationMinutes}分钟，$eventName别落下太多哦~',
          type: ResponseType.gentleReminder,
        );
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// 检查全天使用情况
  Future<AgentResponse?> _checkDailyUsage() async {
    final usage = await _toolExecutor.execute('get_today_usage', {'include_apps': true});
    final totalMinutes = usage['total_minutes'] as int;

    final goal = await _toolExecutor.execute('get_daily_goal', {});
    final goalMinutes = goal['minutes'] as int;

    final continuous = await _toolExecutor.execute('get_continuous_sessions', {'min_minutes': 30});

    // 检查连续使用
    if (continuous.isNotEmpty) {
      final session = continuous[0];
      final appName = session['app_name'];
      final duration = session['duration_minutes'];

      if (duration >= 45) {
        return AgentResponse(
          text: '检测到你已连续使用$appName${duration}分钟，建议起来活动一下~',
          type: ResponseType.intervention,
        );
      }
    }

    // 检查是否接近目标
    if (totalMinutes > goalMinutes * 0.9 && totalMinutes < goalMinutes) {
      final remaining = goalMinutes - totalMinutes;
      return AgentResponse(
        text: '今天已经用了$totalMinutes分钟，距离目标只剩$remaining分钟~',
        type: ResponseType.reminder,
      );
    }

    return null;
  }

  /// 执行Tool并返回结果
  Future<dynamic> executeTool(String toolName, Map<String, dynamic> args) async {
    return await _toolExecutor.execute(toolName, args);
  }

  // ==================== 意图处理 ====================

  /// 解析用户意图 - 增强版
  UserIntent _parseIntent(String input) {
    final lower = input.toLowerCase();

    // ========== 最高优先级：用户紧急控制 ==========

    // 紧急跳过/暂停
    if (lower.contains('跳过') ||
        (lower.contains('暂停') && (lower.contains('提醒') || lower.contains('干预'))) ||
        lower.contains('别管') ||
        lower.contains('安静') ||
        lower.contains('别提醒')) {
      return UserIntent(type: UserIntentType.emergencyOverride, data: {'raw': input});
    }

    // 全局暂停监控
    if ((lower.contains('全部') || lower.contains('所有') || lower.contains('完全')) &&
        (lower.contains('暂停') || lower.contains('停止') || lower.contains('关掉'))) {
      return UserIntent(type: UserIntentType.globalPause, data: {'raw': input});
    }

    // ========== 临时调课/日程调整 ==========

    // 调课/改时间/取消
    if ((lower.contains('调课') || lower.contains('改时间') || lower.contains('换到') ||
         lower.contains('取消') || lower.contains('停课') || lower.contains('放假')) &&
        (lower.contains('课') || lower.contains('会议') || lower.contains('高数') ||
         lower.contains('英语') || lower.contains('物理'))) {
      return UserIntent(type: UserIntentType.rescheduleEvent, data: {'raw': input});
    }

    // ========== 自律模式（用户主动）==========

    // 接下来X小时别让我... / 我要专注
    if ((lower.contains('接下来') || lower.contains('现在') || lower.contains('我要') ||
         lower.contains('帮我')) &&
        (lower.contains('别') || lower.contains('不要') || lower.contains('专注') ||
         lower.contains('自律') || lower.contains('防止') || lower.contains('阻止'))) {
      return UserIntent(type: UserIntentType.temporaryDiscipline, data: {'raw': input});
    }

    // ========== 创建规则意图（最优先）==========
    // 复杂规则：包含"如果...就..."、"超过...就..."
    if (lower.contains('如果') ||
        lower.contains('超过') ||
        lower.contains('达到') ||
        lower.contains('用时') ||
        (lower.contains('提醒') && (lower.contains('超过') || lower.contains('达到')))) {
      return UserIntent(type: UserIntentType.createRule, data: {'raw': input});
    }

    // 场景化规则：上课/自习期间...
    if ((lower.contains('上课') || lower.contains('自习') || lower.contains('健身')) &&
        (lower.contains('刷') || lower.contains('用') || lower.contains('玩') || lower.contains('看'))) {
      return UserIntent(type: UserIntentType.createRule, data: {'raw': input});
    }

    // 时间+应用+时长组合
    if ((lower.contains('点') || lower.contains('晚上') || lower.contains('下午')) &&
        (_containsAny(lower, ['抖音', '微信', '微博', '小红书', 'b站', '快手', '游戏', '淘宝'])) &&
        (lower.contains('分钟') || lower.contains('小时'))) {
      return UserIntent(type: UserIntentType.createRule, data: {'raw': input});
    }

    // 简单规则：直接说"X超过Y分钟提醒我"
    if ((lower.contains('超过') || lower.contains('达到')) &&
        lower.contains('分钟') &&
        (lower.contains('提醒') || lower.contains('通知'))) {
      return UserIntent(type: UserIntentType.createRule, data: {'raw': input});
    }

    // ========== 查询使用情况 ==========
    if (lower.contains('多久') ||
        lower.contains('用了') ||
        lower.contains('时间') ||
        lower.contains('统计') ||
        lower.contains('数据') ||
        (lower.contains('今天') && lower.contains('手机'))) {
      return UserIntent(type: UserIntentType.queryUsage, data: {'raw': input});
    }

    // ========== 列出规则 ==========
    if ((lower.contains('规则') || lower.contains('设置')) &&
        (lower.contains('哪些') || lower.contains('列出') || lower.contains('查看') ||
         lower.contains('有什么') || lower.contains('都有'))) {
      return UserIntent(type: UserIntentType.listRules, data: {});
    }

    // ========== 修改规则 ==========
    if ((lower.contains('暂停') || lower.contains('启用') || lower.contains('删除') ||
         lower.contains('关掉') || lower.contains('打开') || lower.contains('开启')) &&
        (lower.contains('规则') || _containsRuleReference(lower))) {
      final action = lower.contains('暂停') || lower.contains('关掉') || lower.contains('禁用') || lower.contains('关闭')
          ? 'disable'
          : lower.contains('删除') || lower.contains('移除')
              ? 'delete'
              : 'enable';
      return UserIntent(type: UserIntentType.modifyRule, data: {'action': action, 'raw': input});
    }

    // ========== 询问建议 ==========
    if (lower.contains('建议') ||
        lower.contains('推荐') ||
        lower.contains('干什么') ||
        lower.contains('做什么') ||
        lower.contains('怎么办') ||
        lower.contains('休息') ||
        lower.contains('放松')) {
      return UserIntent(type: UserIntentType.askAdvice, data: {'raw': input});
    }

    // ========== 修改目标 ==========
    if ((lower.contains('目标') || lower.contains('改成') || lower.contains('设置')) &&
        (lower.contains('小时') || lower.contains('分钟') || lower.contains('时间'))) {
      return UserIntent(type: UserIntentType.updateGoal, data: {'raw': input});
    }

    // ========== 获取报告 ==========
    if (lower.contains('周报') ||
        lower.contains('报告') ||
        lower.contains('总结') ||
        lower.contains('分析') ||
        lower.contains('本周')) {
      return UserIntent(type: UserIntentType.getReport, data: {});
    }

    // ========== 推荐活动 ==========
    if (lower.contains('活动') || lower.contains('休息') || lower.contains('放松')) {
      return UserIntent(type: UserIntentType.suggestActivity, data: {});
    }

    // 默认：可能是创建规则的模糊表达
    if (lower.contains('让') || lower.contains('帮') || lower.contains('给我')) {
      return UserIntent(type: UserIntentType.createRule, data: {'raw': input});
    }

    return UserIntent(type: UserIntentType.general, data: {'raw': input});
  }

  /// 检查是否包含规则引用
  bool _containsRuleReference(String input) {
    final ruleKeywords = ['第', '条', '个', '抖音', '微信', '游戏', '淘宝', '刷'];
    return ruleKeywords.any((k) => input.contains(k));
  }

  /// 检查是否包含任意关键词
  bool _containsAny(String input, List<String> keywords) {
    return keywords.any((k) => input.contains(k));
  }

  // ==================== 具体处理逻辑 ====================

  /// 处理使用情况查询
  Future<AgentResponse> _handleQueryUsage(UserIntent intent) async {
    final data = await _toolExecutor.execute('get_today_usage', {'include_apps': true});
    final totalMinutes = data['total_minutes'] as int;
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    final topApps = (data['top_apps'] as List<dynamic>).take(3).toList();

    // 获取目标
    final goal = await _toolExecutor.execute('get_daily_goal', {});
    final goalMinutes = goal['minutes'] as int;
    final percentage = (totalMinutes / goalMinutes * 100).clamp(0, 100).round();

    // 获取与昨日比较
    final comparison = await _toolExecutor.execute('compare_with_yesterday', {});
    final diff = comparison['difference_minutes'] as int;
    final isBetter = comparison['is_better'] as bool;

    var text = '今天用了';
    if (hours > 0) {
      text += '$hours小时';
    }
    text += '$minutes分钟';
    text += '，是目标的$percentage%。';

    if (isBetter) {
      text += '比昨天少了${diff.abs()}分钟，继续保持~';
    } else {
      text += '比昨天多了${diff.abs()}分钟，注意控制哦~';
    }

    if (topApps.isNotEmpty) {
      text += '\n\n用得最多的是：';
      text += topApps.map((a) => '${a['name']} ${a['minutes']}分钟').join('、');
    }

    return AgentResponse(
      text: text,
      type: ResponseType.info,
      data: data,
    );
  }

  /// 处理创建规则 - 增强版自然语言解析
  Future<AgentResponse> _handleCreateRule(UserIntent intent, String rawInput) async {
    debugPrint('🎯 处理创建规则请求: $rawInput');

    // 使用增强的自然语言解析器
    final parseResult = NLRuleParser.parse(rawInput);

    // 解析成功，创建规则
    if (parseResult.isValid && parseResult.rule != null) {
      final rule = parseResult.rule!;

      // 添加到 RuleEngine
      final ruleEngine = RuleEngine();
      await ruleEngine.initialize();
      await ruleEngine.addAgentRule(rule);

      // 生成友好的确认消息
      final msg = _generateRuleConfirmation(rule, parseResult.parsedElements);

      return AgentResponse(
        text: msg,
        type: ResponseType.success,
        data: {
          'rule': rule.toJson(),
          'parsed': parseResult.parsedElements,
        },
      );
    }

    // 解析失败，返回引导信息
    return AgentResponse(
      text: parseResult.getFeedback() + '\n\n💡 你可以这样说：\n'
            '"周一到周五晚上8点后刷抖音超过30分钟提醒我休息"\n'
            '"上课期间使用微信超过1小时强烈提醒"',
      type: ResponseType.prompt,
      data: {'missing': parseResult.missingElements},
    );
  }

  /// 生成规则确认消息
  String _generateRuleConfirmation(SmartRule rule, ParsedElements elements) {
    final buffer = StringBuffer();
    buffer.writeln('✅ 已创建规则：${rule.name}');
    buffer.writeln('');
    buffer.writeln('📋 规则详情：');
    buffer.writeln('   ${rule.description}');

    // 显示解析出的元素
    buffer.writeln('');
    buffer.writeln('🔍 我识别到了：');

    if (elements.hasApp) {
      buffer.writeln('   • 应用：${elements.appName}');
    }
    if (elements.hasDuration) {
      buffer.writeln('   • 时长：${elements.durationMinutes}分钟');
    }
    if (elements.hasTimeRange) {
      buffer.writeln('   • 时段：${elements.timeRange}');
    }
    if (elements.hasWeekdays) {
      final weekdayText = _formatWeekdays(elements.weekdays);
      buffer.writeln('   • 周期：$weekdayText');
    }
    if (elements.eventContext != null) {
      buffer.writeln('   • 场景：${elements.eventContext}');
    }

    // 根据强度添加提示
    switch (elements.intensity) {
      case ReminderIntensity.gentle:
        buffer.writeln('');
        buffer.writeln('💡 这是一个温和提醒规则，会以静默方式通知你。');
        break;
      case ReminderIntensity.strong:
        buffer.writeln('');
        buffer.writeln('⚠️ 这是一个强烈提醒规则，触发时会强制弹出提醒。');
        break;
      default:
        buffer.writeln('');
        buffer.writeln('💡 规则已生效，我会在条件满足时提醒你。');
    }

    return buffer.toString();
  }

  /// 格式化星期显示
  String _formatWeekdays(List<int> weekdays) {
    if (weekdays.length == 7) return '每天';
    if (weekdays.length == 5 && weekdays.toSet().containsAll([1, 2, 3, 4, 5])) {
      return '工作日';
    }
    if (weekdays.length == 2 && weekdays.toSet().containsAll([6, 7])) {
      return '周末';
    }

    final names = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return weekdays.map((d) => names[d]).join('、');
  }

  /// 处理列出规则
  Future<AgentResponse> _handleListRules() async {
    final rules = await _toolExecutor.execute('list_rules', {'include_disabled': true});

    if (rules.isEmpty) {
      return AgentResponse(
        text: '你还没有设置任何规则，可以对我说"晚上8点后刷抖音超过30分钟提醒我"来创建一个~',
        type: ResponseType.info,
      );
    }

    var text = '你目前有${rules.length}条规则：\n\n';
    for (var i = 0; i < rules.length; i++) {
      final rule = rules[i];
      final status = rule['enabled'] ? '✅' : '⏸️';
      text += '$status ${i + 1}. ${rule['name']}\n';
      text += '   条件：${rule['condition']}\n';
      if (i < rules.length - 1) text += '\n';
    }

    text += '\n你可以说"暂停第2条"或"删除抖音规则"来管理规则~';

    return AgentResponse(
      text: text,
      type: ResponseType.info,
      data: {'rules': rules},
    );
  }

  /// 处理修改规则
  Future<AgentResponse> _handleModifyRule(UserIntent intent) async {
    final action = intent.data['action'] as String;
    final raw = intent.data['raw'] as String;

    // 提取规则名称（简化处理）
    // 实际应该更智能地匹配
    return AgentResponse(
      text: '请告诉我具体要${action == 'delete' ? '删除' : action == 'disable' ? '暂停' : '启用'}哪条规则，比如"删除抖音规则"~',
      type: ResponseType.prompt,
    );
  }

  /// 处理询问建议
  Future<AgentResponse> _handleAskAdvice(UserIntent intent) async {
    // 获取连续使用情况
    final continuous = await _toolExecutor.execute('get_continuous_sessions', {'min_minutes': 20});

    if (continuous.isNotEmpty) {
      final session = continuous.first;
      final app = session['app_name'];
      final duration = session['duration_minutes'];

      final suggestion = await _toolExecutor.execute('suggest_activity', {
        'context': '连续使用${app}${duration}分钟',
      });

      return AgentResponse(
        text: '你已连续使用$app${duration}分钟，${suggestion['description']}，大概需要${suggestion['duration']}~',
        type: ResponseType.suggestion,
        data: suggestion,
      );
    }

    // 通用建议
    return AgentResponse(
      text: '现在状态不错！如果已经用了30分钟以上，可以起来走动一下，看看远处放松眼睛~',
      type: ResponseType.suggestion,
    );
  }

  /// 处理更新目标 - 使用NLRuleParser的提取逻辑
  Future<AgentResponse> _handleUpdateGoal(UserIntent intent) async {
    final raw = intent.data['raw'] as String;
    final minutes = _extractGoalMinutes(raw);

    if (minutes == null || minutes < 30 || minutes > 720) {
      return AgentResponse(
        text: '请输入合理的时长（30分钟到12小时之间），比如"把目标改成3小时"~',
        type: ResponseType.error,
      );
    }

    final result = await _toolExecutor.execute('update_daily_goal', {'minutes': minutes});

    return AgentResponse(
      text: '✅ 每日目标已更新为${result['hours'].toStringAsFixed(1)}小时，我会帮你盯着这个目标~',
      type: ResponseType.success,
      data: result,
    );
  }

  /// 提取目标分钟数
  int? _extractGoalMinutes(String input) {
    // 匹配"X小时"
    final hourMatch = RegExp(r'(\d+(?:\.\d+)?)[\s]*小时').firstMatch(input);
    if (hourMatch != null) {
      final hours = double.tryParse(hourMatch.group(1)!) ?? 0;
      return (hours * 60).round();
    }

    // 匹配"X分钟"
    final minMatch = RegExp(r'(\d+)[\s]*分钟').firstMatch(input);
    if (minMatch != null) {
      return int.tryParse(minMatch.group(1)!);
    }

    // 匹配纯数字（假设为分钟）
    final numMatch = RegExp(r'(\d{2,3})').firstMatch(input);
    if (numMatch != null) {
      final num = int.tryParse(numMatch.group(1)!);
      if (num != null && num >= 30 && num <= 720) {
        return num;
      }
    }

    return null;
  }

  /// 处理获取报告
  Future<AgentResponse> _handleGetReport() async {
    final report = await _toolExecutor.execute('export_weekly_report', {'include_suggestions': true});

    final hours = report['week_total_hours'] as int;
    final avgHours = report['daily_average_hours'] as int;
    final avgMins = report['daily_average_minutes'] as int;
    final trend = report['trend'] as String;

    var text = '📊 本周使用报告\n\n';
    text += '本周累计：$hours小时\n';
    text += '平均每天：${avgHours}小时${avgMins}分钟\n';

    if (trend == 'improving') {
      text += '\n趋势：比上周有所减少，继续保持！💪';
    } else {
      text += '\n趋势：比上周有所增加，下周可以尝试减少半小时~';
    }

    return AgentResponse(
      text: text,
      type: ResponseType.report,
      data: report,
    );
  }

  /// 处理推荐活动
  Future<AgentResponse> _handleSuggestActivity() async {
    final activity = await _toolExecutor.execute('suggest_activity', {'context': '一般场景'});

    return AgentResponse(
      text: '来${activity['name']}吧！${activity['description']}，只需要${activity['duration']}~',
      type: ResponseType.suggestion,
      data: activity,
    );
  }

  /// 处理通用对话
  Future<AgentResponse> _handleGeneralChat(String input) async {
    // 问候语
    if (input.contains('你好') || input.contains('在吗') || input.contains('hi')) {
      return AgentResponse(
        text: '你好！我是Focus，你的屏幕时间助手。我可以帮你查看使用情况、创建提醒规则、或者推荐休息活动~',
        type: ResponseType.greeting,
      );
    }

    // 帮助
    if (input.contains('帮助') || input.contains('怎么用') || input.contains('功能')) {
      return AgentResponse(
        text: '''我可以帮你：
📊 查看使用统计："今天用了多久"
➕ 创建规则："晚上8点后刷抖音超过30分钟提醒我"
📋 管理规则："列出所有规则"
📅 临时调课："今天高数课取消了"
💪 自律模式："接下来2小时别让我刷抖音"
🌴 全局暂停："今天全部暂停"
📈 生成报告："给我周报"
🎯 修改目标："把目标改成3小时"

直接说出你的需求就行~''',
        type: ResponseType.help,
      );
    }

    // 默认回复
    return AgentResponse(
      text: '抱歉，我可能没理解清楚。你可以说"帮助"查看我能做什么，或者直接说出你的需求~',
      type: ResponseType.unknown,
    );
  }

  // ==================== 用户控制功能 ====================

  /// 处理紧急覆盖
  Future<AgentResponse> _handleEmergencyOverride(UserIntent intent, String rawInput) async {
    final result = await _overrideManager.emergencySkip(
      currentIntervention: 'active',
      reason: rawInput,
      skipDuration: const Duration(minutes: 15),
    );

    return AgentResponse(
      text: result.message,
      type: ResponseType.success,
    );
  }

  /// 处理全局暂停
  Future<AgentResponse> _handleGlobalPause(UserIntent intent, String rawInput) async {
    // 尝试提取时长
    final duration = _extractDurationFromInput(rawInput) ?? const Duration(hours: 2);

    final result = await _overrideManager.pauseAllMonitoring(
      duration: duration,
      reason: rawInput,
    );

    return AgentResponse(
      text: result.message,
      type: ResponseType.success,
    );
  }

  /// 处理调课/改时间
  Future<AgentResponse> _handleRescheduleEvent(UserIntent intent, String rawInput) async {
    final lower = rawInput.toLowerCase();

    // 检测是否是取消
    final isCancellation = lower.contains('取消') ||
                          lower.contains('不') ||
                          lower.contains('没') ||
                          lower.contains('停课') ||
                          lower.contains('放假');

    // 尝试提取课程名称
    final eventName = _extractEventName(rawInput);

    if (eventName == null) {
      return AgentResponse(
        text: '请告诉我具体是哪门课，比如"今天高数课取消了"或"调一下英语课时间"~',
        type: ResponseType.prompt,
      );
    }

    final result = await _overrideManager.rescheduleEvent(
      eventName: eventName,
      originalDate: DateTime.now(),
      isCancellation: isCancellation,
      reason: rawInput,
    );

    return AgentResponse(
      text: result.message,
      type: result.success ? ResponseType.success : ResponseType.error,
    );
  }

  /// 处理临时自律模式
  Future<AgentResponse> _handleTemporaryDiscipline(UserIntent intent, String rawInput) async {
    final lower = rawInput.toLowerCase();

    // 提取目标应用
    final appName = _extractAppName(rawInput);

    // 提取时长
    final durationMinutes = _extractDurationMinutes(rawInput) ?? 120;

    // 检测强度
    final intensity = lower.contains('强烈') || lower.contains('必须') || lower.contains('一定')
        ? ReminderIntensity.strong
        : ReminderIntensity.normal;

    // 提取目标/原因
    String? goal;
    if (lower.contains('写') || lower.contains('作业') || lower.contains('论文')) {
      goal = '专注写作业';
    } else if (lower.contains('学') || lower.contains('复习') || lower.contains('考试')) {
      goal = '专注学习';
    } else if (lower.contains('工作') || lower.contains('项目')) {
      goal = '专注工作';
    }

    final result = await _overrideManager.quickDiscipline(
      appName: appName ?? '所有娱乐应用',
      durationMinutes: durationMinutes,
      goal: goal,
    );

    return AgentResponse(
      text: result.message,
      type: ResponseType.success,
    );
  }

  /// 处理获取当前上下文
  Future<AgentResponse> _handleGetCurrentContext() async {
    final context = await _toolExecutor.execute('get_current_context', {});

    if (context['has_active_event'] == true) {
      final eventName = context['event_name'];
      final minutesElapsed = context['minutes_elapsed'];
      final minutesRemaining = context['minutes_remaining'];

      return AgentResponse(
        text: '📚 当前正在进行：$eventName\n'
              '⏱️ 已进行：${minutesElapsed}分钟\n'
              '⏳ 剩余：${minutesRemaining}分钟',
        type: ResponseType.info,
        data: context,
      );
    }

    return AgentResponse(
      text: '🌟 现在是自由时间，没有安排的活动~',
      type: ResponseType.info,
    );
  }

  // ==================== 辅助方法 ====================

  /// 从输入中提取时长
  Duration? _extractDurationFromInput(String input) {
    // 匹配"X小时"
    final hourMatch = RegExp(r'(\d+(?:\.\d+)?)[\s]*小时').firstMatch(input);
    if (hourMatch != null) {
      final hours = double.tryParse(hourMatch.group(1)!) ?? 0;
      return Duration(minutes: (hours * 60).round());
    }

    // 匹配"X分钟"
    final minMatch = RegExp(r'(\d+)[\s]*分钟').firstMatch(input);
    if (minMatch != null) {
      final mins = int.tryParse(minMatch.group(1)!) ?? 0;
      return Duration(minutes: mins);
    }

    return null;
  }

  /// 提取课程/事件名称
  String? _extractEventName(String input) {
    final lower = input.toLowerCase();

    // 常见课程关键词
    final courseKeywords = ['高数', '英语', '物理', '化学', '数学', '语文', '政治', '历史', '地理', '生物',
                           '计算机', '编程', '算法', '数据结构', '线代', '概率论'];

    for (final keyword in courseKeywords) {
      if (lower.contains(keyword)) {
        return keyword;
      }
    }

    // 尝试匹配"XX课"
    final match = RegExp(r'([\u4e00-\u9fa5]{1,4})课').firstMatch(input);
    if (match != null) {
      return match.group(1);
    }

    return null;
  }

  /// 提取应用名称
  String? _extractAppName(String input) {
    final lower = input.toLowerCase();

    final appKeywords = ['抖音', '微信', '微博', '小红书', 'b站', '快手', '知乎',
                        '淘宝', '游戏', '王者', '吃鸡', '手机'];

    for (final app in appKeywords) {
      if (lower.contains(app)) {
        return app;
      }
    }

    return null;
  }

  /// 提取分钟数
  int? _extractDurationMinutes(String input) {
    // 匹配"X小时"
    final hourMatch = RegExp(r'(\d+(?:\.\d+)?)[\s]*小时').firstMatch(input);
    if (hourMatch != null) {
      final hours = double.tryParse(hourMatch.group(1)!) ?? 0;
      return (hours * 60).round();
    }

    // 匹配"X分钟"
    final minMatch = RegExp(r'(\d+)[\s]*分钟').firstMatch(input);
    if (minMatch != null) {
      return int.tryParse(minMatch.group(1)!);
    }

    // 匹配纯数字
    final numMatch = RegExp(r'(\d+)').firstMatch(input);
    if (numMatch != null) {
      final num = int.tryParse(numMatch.group(1)!);
      if (num != null && num <= 240) {
        return num;
      }
    }

    return null;
  }

  /// 添加消息到流
  void _addMessage(AgentMessage message) {
    _messageController.add(message);
  }
}

// ==================== 数据模型 ====================

enum UserIntentType {
  queryUsage,          // 查询使用
  createRule,          // 创建规则
  listRules,           // 列出规则
  modifyRule,          // 修改规则
  askAdvice,           // 询问建议
  updateGoal,          // 更新目标
  getReport,           // 获取报告
  suggestActivity,     // 推荐活动
  getCurrentContext,   // 获取当前场景
  emergencyOverride,   // 紧急覆盖
  globalPause,         // 全局暂停
  rescheduleEvent,     // 调课/改时间
  temporaryDiscipline, // 临时自律
  general,             // 通用对话
}

class UserIntent {
  final UserIntentType type;
  final Map<String, dynamic> data;

  UserIntent({required this.type, required this.data});
}

enum ResponseType {
  info,            // 信息
  success,         // 成功
  error,           // 错误
  warning,         // 警告
  suggestion,      // 建议
  intervention,    // 干预（强烈）
  gentleReminder,  // 温和提醒（首次）
  reminder,        // 普通提醒
  report,          // 报告
  greeting,        // 问候
  help,            // 帮助
  prompt,          // 提示
  unknown,         // 未知
}

class AgentResponse {
  final String text;
  final ResponseType type;
  final Map<String, dynamic>? data;

  AgentResponse({
    required this.text,
    required this.type,
    this.data,
  });
}

class AgentMessage {
  final String id;
  final String text;
  final bool isFromAgent;
  final DateTime timestamp;
  final ResponseType? type;
  final Map<String, dynamic>? data;

  AgentMessage({
    required this.id,
    required this.text,
    required this.isFromAgent,
    required this.timestamp,
    this.type,
    this.data,
  });

  factory AgentMessage.fromAgent(AgentResponse response) => AgentMessage(
    id: DateTime.now().millisecondsSinceEpoch.toString(),
    text: response.text,
    isFromAgent: true,
    timestamp: DateTime.now(),
    type: response.type,
    data: response.data,
  );

  factory AgentMessage.fromUser(String text) => AgentMessage(
    id: DateTime.now().millisecondsSinceEpoch.toString(),
    text: text,
    isFromAgent: false,
    timestamp: DateTime.now(),
    type: null,
    data: null,
  );
}
