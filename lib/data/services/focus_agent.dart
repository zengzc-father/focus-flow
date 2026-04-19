import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'rule_engine.dart' show SmartRule, RuleConditions, RuleAction;
import '../models/app_usage.dart' show DailyUsage, WeeklyAnalysis;

/// Focus Agent Pro - 专业屏幕时间自律助手
///
/// 特点：
/// - 专门化角色：不是通用AI，而是专注屏幕健康的学生助手
/// - 场景感知：自动识别学习/休息/深夜等场景
/// - 个性化建议：基于用户类型（考研/高中/大学）提供不同策略
/// - 主动学习：从用户反馈中不断优化建议
/// - 预测性干预：在使用失控前提前建议
class FocusAgent {
  static final FocusAgent _instance = FocusAgent._internal();
  factory FocusAgent() => _instance;
  FocusAgent._internal();

  // LLM实例（按需加载）
  LocalLLMInterface? _llm;
  bool _isLoaded = false;
  bool _isLoading = false;

  // 用户画像（持久化）
  late UserProfile _profile;

  /// 当前状态
  FocusAgentStatus get state {
    if (_isLoading) return FocusAgentStatus.loading;
    if (_isLoaded) return FocusAgentStatus.ready;
    return FocusAgentStatus.unloaded;
  }

  /// 加载Agent
  Future<void> load() async {
    if (_isLoaded || _isLoading) return;

    _isLoading = true;
    debugPrint('🤖 Focus Agent Pro 启动中...');

    try {
      // 加载LLM
      _llm = await _loadLocalLLM();

      // 加载或创建用户画像
      _profile = await _loadUserProfile();

      _isLoaded = true;
      debugPrint('🤖 Focus Agent Pro 已就绪');
      debugPrint('   用户类型: ${_profile.userType}');
      debugPrint('   高效时段: ${_profile.productiveHours}');
    } catch (e) {
      debugPrint('❌ Agent启动失败: $e');
      _llm = null;
    } finally {
      _isLoading = false;
    }
  }

  /// 释放Agent
  Future<void> unload() async {
    if (!_isLoaded) return;

    // 保存用户画像
    await _saveUserProfile();

    _llm?.dispose();
    _llm = null;
    _isLoaded = false;

    debugPrint('🤖 Focus Agent Pro 已休眠');
  }

  /// ==================== 核心功能 ====================

  /// 1. 智能场景识别
  Scene detectCurrentScene({
    required DateTime time,
    required int todayUsageMinutes,
    required int currentSessionMinutes,
    String? currentApp,
    bool isExamPeriod = false,
  }) {
    final hour = time.hour;
    final weekday = time.weekday;

    // 考试周特殊场景
    if (isExamPeriod) {
      return Scene.examPeriod;
    }

    // 深夜刷手机
    if ((hour >= 23 || hour < 2) && todayUsageMinutes > 120) {
      return Scene.lateNightScroll;
    }

    // 睡前刷手机
    if (hour >= 22 && currentSessionMinutes > 10) {
      return Scene.bedtimeScrolling;
    }

    // 早晨学习时段
    if ((hour >= 7 && hour <= 11) && _profile.productiveHours.contains(hour)) {
      return Scene.morningStudy;
    }

    // 午休时间
    if (hour >= 12 && hour <= 13) {
      return Scene.lunchBreak;
    }

    // 下午茶时间
    if (hour >= 15 && hour <= 16) {
      return Scene.afternoonTea;
    }

    // 晚餐时间
    if (hour >= 18 && hour <= 19) {
      return Scene.dinnerBreak;
    }

    // 周末放松
    if ((weekday == 6 || weekday == 7) && todayUsageMinutes > 180) {
      return Scene.weekendRelax;
    }

    // 连续使用过长
    if (currentSessionMinutes > 60) {
      return Scene.continuousUse;
    }

    // 即将超标
    if (_predictWillExceedLimit(todayUsageMinutes, hour)) {
      return Scene.approachingLimit;
    }

    return Scene.normal;
  }

  bool _predictWillExceedLimit(int todayUsage, int currentHour) {
    final limit = _profile.dailyGoalMinutes;
    final hoursLeft = 22 - currentHour; // 假设22点停止
    if (hoursLeft <= 0) return false;

    // 简单线性预测
    final currentSpeed = todayUsage / (currentHour - 7).clamp(1, 24);
    final projected = todayUsage + (currentSpeed * hoursLeft);

    return projected > limit * 0.9;
  }

  /// 2. 生成场景化建议
  Future<String> generateContextualAdvice(Scene scene, {
    int? currentSessionMinutes,
    int? todayUsageMinutes,
  }) async {
    // 首先尝试用LLM生成
    if (_ensureLoaded()) {
      final prompt = _buildContextualPrompt(scene, currentSessionMinutes, todayUsageMinutes);
      return await _llm!.generate(prompt);
    }

    // 离线时使用模板
    return _getTemplateAdvice(scene, currentSessionMinutes);
  }

  /// 3. 自然语言生成规则（专业领域理解）
  Future<SmartRule?> generateRule(String naturalLanguage) async {
    if (!_ensureLoaded()) return null;

    // 预处理：提取关键信息
    final extracted = _extractRuleParameters(naturalLanguage);

    final prompt = _buildRulePrompt(naturalLanguage, extracted);
    final response = await _llm!.generate(prompt);

    try {
      final rule = _parseRule(response);

      // 根据用户类型优化规则
      _optimizeRuleForUserType(rule);

      // 保存规则
      await _saveRule(rule);

      // 记录用户创建规则的行为（学习）
      await _learnRulePreference(extracted);

      return rule;
    } catch (e) {
      debugPrint('规则解析失败: $e');
      return null;
    }
  }

  /// 4. 生成个性化周报
  Future<String> generateWeeklyReport(List<DailyUsage> weekData) async {
    // 分析数据
    final analysis = _analyzeWeeklyData(weekData);

    if (_ensureLoaded()) {
      final prompt = _buildWeeklyReportPrompt(weekData, analysis);
      return await _llm!.generate(prompt);
    }

    return _generateSimpleReport(analysis);
  }

  /// 5. 生成替代活动建议（个性化）
  Future<String> suggestAlternativeActivity(Scene scene) async {
    // 基于用户偏好和场景推荐
    final preferred = _profile.preferredActivities;

    if (preferred.isNotEmpty) {
      // 从用户喜欢的活动中选
      final activity = preferred[Random().nextInt(preferred.length)];
      return '来$activity吧，这是你喜欢的放松方式~';
    }

    // 默认推荐
    return _getDefaultActivityForScene(scene);
  }

  /// 6. 对话交互（专业领域）
  Future<AgentResponse> chat(String userMessage, {
    Scene? currentScene,
    int? todayUsage,
    int? currentSession,
  }) async {
    // 意图识别
    final intent = _detectIntent(userMessage);

    switch (intent) {
      case UserIntent.createRule:
        final rule = await generateRule(userMessage);
        return AgentResponse(
          reply: rule != null
              ? '✅ 已为你创建规则"${rule.name}"，我会按照这个规则提醒你~'
              : '抱歉，我没理解清楚，可以再说详细一点吗？',
          newRule: rule,
        );

      case UserIntent.askAdvice:
        final advice = await generateContextualAdvice(
          currentScene ?? Scene.normal,
          currentSessionMinutes: currentSession,
          todayUsageMinutes: todayUsage,
        );
        return AgentResponse(reply: advice);

      case UserIntent.checkProgress:
        final progress = _generateProgressSummary(todayUsage ?? 0);
        return AgentResponse(reply: progress);

      case UserIntent.expressFrustration:
        return AgentResponse(
          reply: _generateEmpatheticResponse(userMessage),
        );

      case UserIntent.general:
      default:
        if (_ensureLoaded()) {
          final prompt = _buildChatPrompt(userMessage, currentScene);
          final reply = await _llm!.generate(prompt);
          return AgentResponse(reply: reply);
        }
        return AgentResponse(
          reply: '我是Focus，你的屏幕时间助手。你可以让我帮你创建规则、查看使用情况，或者聊聊怎么更好地管理时间~',
        );
    }
  }

  /// 7. 记录用户反馈（学习）
  Future<void> recordFeedback({
    required String ruleName,
    required bool acted,
    String? userComment,
  }) async {
    // 更新响应率
    await _profile.updateResponseRate(ruleName, acted);

    // 如果用户有额外评论，学习偏好
    if (userComment != null && userComment.isNotEmpty) {
      await _learnFromComment(userComment);
    }

    debugPrint('📊 学习记录: $ruleName, 响应=$acted');
  }

  /// 8. 获取动态阈值（根据用户状态调整）
  int getDynamicThreshold() {
    int base = _profile.continuousLimit;

    // 根据响应率调整
    final avgResponseRate = _profile.averageResponseRate;
    if (avgResponseRate < 0.2) {
      base += 15; // 低响应率用户放宽标准
    } else if (avgResponseRate > 0.8) {
      base -= 5; // 高响应率用户可以更严格
    }

    return base.clamp(20, 90);
  }

  /// ==================== 私有方法 ====================

  bool _ensureLoaded() {
    if (!_isLoaded) {
      debugPrint('⚠️ Agent未加载');
      return false;
    }
    return true;
  }

  Future<LocalLLMInterface> _loadLocalLLM() async {
    return MockLocalLLM();
  }

  Future<UserProfile> _loadUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('user_profile');
    if (json != null) {
      return UserProfile.fromJson(jsonDecode(json));
    }
    return UserProfile.defaultProfile();
  }

  Future<void> _saveUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_profile', jsonEncode(_profile.toJson()));
  }

  Future<void> _saveRule(SmartRule rule) async {
    final prefs = await SharedPreferences.getInstance();
    final rules = prefs.getStringList('agent_rules') ?? [];
    rules.add(jsonEncode(rule.toJson()));
    await prefs.setStringList('agent_rules', rules);
  }

  Map<String, dynamic> _extractRuleParameters(String input) {
    final params = <String, dynamic>{};

    // 提取时间
    final timeReg = RegExp(r'(\d{1,2})[:点时](\d{0,2})');
    final timeMatch = timeReg.firstMatch(input);
    if (timeMatch != null) {
      final hour = timeMatch.group(1);
      final minute = timeMatch.group(2) ?? '00';
      params['time'] = '$hour:${minute.padLeft(2, '0')}';
    }

    // 提取时长
    final durationReg = RegExp(r'(\d+)[ ]*[分钟分min]*');
    final durationMatch = durationReg.firstMatch(input);
    if (durationMatch != null) {
      params['duration'] = int.parse(durationMatch.group(1)!);
    }

    // 识别应用
    final apps = <String>[];
    if (input.contains('抖音') || input.contains('douyin')) apps.add('douyin');
    if (input.contains('微信') || input.contains('wechat')) apps.add('wechat');
    if (input.contains('游戏') || input.contains('game')) apps.add('game');
    if (input.contains('微博') || input.contains('weibo')) apps.add('weibo');
    params['apps'] = apps;

    return params;
  }

  void _optimizeRuleForUserType(SmartRule rule) {
    switch (_profile.userType) {
      case '考研':
        // 考研生：更严格，但理解放松需求
        if (rule.conditions.timeRange?.contains('20:00') ?? false) {
          rule.action.message = '晚上可以放松，但别太晚，明天还要早起学习呢~';
        }
        break;
      case '高中':
        // 高中生：简单直接
        rule.action.message = rule.action.message?.replaceAll('~', '！');
        break;
      case '大学':
        // 大学生：朋友式建议
        rule.action.message = '${rule.action.message} 你自己把握哈~';
        break;
    }
  }

  WeeklyAnalysis _analyzeWeeklyData(List<DailyUsage> data) {
    if (data.isEmpty) return WeeklyAnalysis.empty();

    final totalMinutes = data.fold<int>(0, (sum, d) => sum + d.totalScreenTime ~/ 60);
    final avgMinutes = totalMinutes ~/ data.length;

    // 找出最高和最低
    var maxDay = data.first;
    var minDay = data.first;
    for (final d in data) {
      if (d.totalScreenTime > maxDay.totalScreenTime) maxDay = d;
      if (d.totalScreenTime < minDay.totalScreenTime) minDay = d;
    }

    // 趋势
    final trend = data.last.totalScreenTime > data.first.totalScreenTime
        ? '上升'
        : '下降';

    return WeeklyAnalysis(
      totalMinutes: totalMinutes,
      avgMinutes: avgMinutes,
      maxDay: maxDay,
      minDay: minDay,
      trend: trend,
      comparedToLastWeek: avgMinutes - _profile.lastWeekAverage,
    );
  }

  String _generateSimpleReport(WeeklyAnalysis analysis) {
    final hours = analysis.avgMinutes ~/ 60;
    final mins = analysis.avgMinutes % 60;

    String trendText = '';
    if (analysis.comparedToLastWeek > 30) {
      trendText = '比上周多了不少，注意控制一下哦';
    } else if (analysis.comparedToLastWeek < -30) {
      trendText = '比上周少了，很棒！';
    } else {
      trendText = '和上周差不多';
    }

    return '这周平均每天使用$hours小时${mins}分钟，$trendText。'
        '用得最多的是${analysis.maxDay.date.month}月${analysis.maxDay.date.day}日，'
        '继续保持良好的使用习惯~';
  }

  String _getDefaultActivityForScene(Scene scene) {
    switch (scene) {
      case Scene.morningStudy:
        return '起来走动一下，看看窗外，让眼睛休息2分钟';
      case Scene.lunchBreak:
        return '午餐时间到！放下手机，专心吃饭，细嚼慢咽对身体好~';
      case Scene.lateNightScroll:
        return '很晚了，放下手机，闭上眼睛，深呼吸5次，很快就能入睡';
      case Scene.continuousUse:
        return '来做个眼保健操吧，或者闭目养神1分钟，眼睛会感谢你的';
      default:
        return '起来活动活动，喝杯水，看看远处，2分钟就好~';
    }
  }

  UserIntent _detectIntent(String message) {
    final lower = message.toLowerCase();

    // 创建规则
    if (lower.contains('规则') ||
        lower.contains('设置') ||
        lower.contains('提醒') &&
            (lower.contains('超过') || lower.contains('点'))) {
      return UserIntent.createRule;
    }

    // 询问建议
    if (lower.contains('建议') ||
        lower.contains('推荐') ||
        lower.contains('干什么') ||
        lower.contains('做什么')) {
      return UserIntent.askAdvice;
    }

    // 查看进度
    if (lower.contains('怎么样') ||
        lower.contains('总结') ||
        lower.contains('用了多久') ||
        lower.contains('数据')) {
      return UserIntent.checkProgress;
    }

    // 情绪表达
    if (lower.contains('忍不住') ||
        lower.contains('愧疚') ||
        lower.contains('控制不住') ||
        lower.contains('烦') ||
        lower.contains('累')) {
      return UserIntent.expressFrustration;
    }

    return UserIntent.general;
  }

  String _generateEmpatheticResponse(String message) {
    final responses = [
      '理解你的感受，改变习惯需要时间，你已经意识到问题就是在进步了。咱们一步步来，今天比昨天好一点就是成功~',
      '别责怪自己，大多数人都有这个困扰。重要的是现在停下来，哪怕只是休息2分钟，也是胜利。',
      '屏幕确实容易让人沉迷，这不是你的错。试试把手机放远一点，或者设置个番茄钟，慢慢来，我陪着你~',
    ];
    return responses[Random().nextInt(responses.length)];
  }

  String _generateProgressSummary(int todayUsageMinutes) {
    final goal = _profile.dailyGoalMinutes;
    final percentage = (todayUsageMinutes / goal * 100).round();

    if (percentage < 50) {
      return '今天表现很棒！才用了$percentage%，还有很大空间，继续保持~';
    } else if (percentage < 90) {
      return '今天用了$percentage%，控制得不错，注意适当休息就好~';
    } else {
      return '今天已经用了$percentage%，接近限额了，接下来尽量休息一下眼睛吧~';
    }
  }

  /// ==================== 提示词构建 ====================

  String _buildContextualPrompt(Scene scene, int? sessionMinutes, int? todayMinutes) {
    return '''
【角色】你是Focus，一位温暖专业的屏幕健康助手，专门帮助学生建立健康的手机使用习惯。

【当前场景】${scene.description}
【用户类型】${_profile.userType}
【连续使用】${sessionMinutes ?? '未知'}分钟
【今日累计】${todayMinutes ?? '未知'}分钟

【说话风格】
- 温暖亲切，像学长学姐
- 简短具体，不超过40字
- 正向鼓励，不批评
- 给出一个具体可执行的建议

请生成提醒文案：
'''.trim();
  }

  String _buildRulePrompt(String input, Map<String, dynamic> extracted) {
    return '''
你是Focus Agent，专门帮助学生创建屏幕使用规则。

用户输入："$input"
提取参数：${jsonEncode(extracted)}

用户类型：${_profile.userType}
用户偏好：${_profile.reminderStyle}

请生成一个智能规则JSON，包含：
1. name: 规则名称（简短）
2. description: 描述
3. conditions: 触发条件（时间、时长等）
4. action: 动作（通知文案要温暖鼓励）

注意：
- 根据用户类型调整文案风格
- 文案简短友好，像朋友说话
- 给出一个具体的休息建议
'''.trim();
  }

  String _buildWeeklyReportPrompt(List<DailyUsage> data, WeeklyAnalysis analysis) {
    return '''
你是Focus，用户的屏幕时间助手。

本周数据：
- 平均日使用：${analysis.avgMinutes}分钟
- 趋势：${analysis.trend}
- 比上周：${analysis.comparedToLastWeek > 0 ? '多' : '少'}${analysis.comparedToLastWeek.abs()}分钟

用户类型：${_profile.userType}

请生成一份周报：
1. 总体评价（积极为主）
2. 具体发现和亮点
3. 一个具体的改进建议
4. 鼓励的话

语气像朋友聊天，温暖真诚，150字以内。
'''.trim();
  }

  String _buildChatPrompt(String message, Scene? scene) {
    return '''
你是Focus，学生的屏幕时间助手。

用户消息："$message"
当前场景：${scene?.description ?? '正常'}
用户类型：${_profile.userType}

请用温暖亲切的方式回复，简短具体，像朋友聊天。
如果需要创建规则，请在回复中包含JSON格式的规则定义。
'''.trim();
  }

  SmartRule _parseRule(String response) {
    final jsonStart = response.indexOf('{');
    final jsonEnd = response.lastIndexOf('}');
    if (jsonStart == -1) throw Exception('未找到JSON');

    final json = jsonDecode(response.substring(jsonStart, jsonEnd + 1));
    return SmartRule.fromJson(json);
  }

  Future<void> _learnRulePreference(Map<String, dynamic> params) async {
    // 学习用户对规则类型的偏好
    if (params.containsKey('time')) {
      _profile.preferredRuleTimes.add(params['time']);
    }
    await _saveUserProfile();
  }

  Future<void> _learnFromComment(String comment) async {
    // 简单学习：如果提到喜欢的活动
    if (comment.contains('喜欢') || comment.contains('想')) {
      // 提取活动偏好
      final activities = ['阅读', '运动', '音乐', '绘画', '散步'];
      for (final activity in activities) {
        if (comment.contains(activity)) {
          _profile.preferredActivities.add(activity);
        }
      }
    }
    await _saveUserProfile();
  }

  String _getTemplateAdvice(Scene scene, int? sessionMinutes) {
    final templates = {
      Scene.continuousUse: [
        '已经用${sessionMinutes}分钟了，起来活动一下吧，眼睛需要休息~',
        '该让眼睛休息一下啦，看看窗外或者闭目养神2分钟~',
        '手指累不累？起来走动走动，喝杯水再继续~',
      ],
      Scene.lateNightScroll: [
        '很晚了，早点休息吧，明天的你会感谢现在早睡的自己~',
        '夜深了，该放下手机了，做个好梦~',
        '熬夜对身体不好，现在睡还能睡个好觉~',
      ],
      Scene.bedtimeScrolling: [
        '该准备睡了，放下手机，15分钟就能入睡~',
        '睡前刷手机影响睡眠质量，现在放下，明天精神更好~',
      ],
    };

    final list = templates[scene] ?? ['起来活动活动，休息一下吧~'];
    return list[Random().nextInt(list.length)];
  }
}

/// ==================== 数据模型 ====================

enum FocusAgentStatus { unloaded, loading, ready }

abstract class LocalLLMInterface {
  Future<String> generate(String prompt);
  void dispose();
}

class MockLocalLLM implements LocalLLMInterface {
  @override
  Future<String> generate(String prompt) async {
    await Future.delayed(const Duration(milliseconds: 300));

    if (prompt.contains('场景')) {
      return '刷了好久啦，起来活动活动？做个眼保健操，眼睛会感谢你的~';
    }

    if (prompt.contains('规则')) {
      return '''
好的，我为你创建了这个规则：

{
  "name": "晚间抖音提醒",
  "description": "晚上使用抖音超过30分钟提醒",
  "conditions": {
    "timeRange": "20:00-23:59",
    "consecutiveMinutes": 30
  },
  "action": {
    "type": "notify",
    "title": "休息提醒",
    "message": "刷了很久了，起来活动一下吧，看看窗外放松下眼睛~"
  },
  "enabled": true
}
'''.trim();
    }

    if (prompt.contains('周报')) {
      return '这周你平均每天用了3.5小时，比上周少了20分钟，进步很大！继续保持，下周可以挑战再减少半小时。加油！';
    }

    return '我理解，有什么我可以帮你的吗？';
  }

  @override
  void dispose() {}
}

/// 用户画像
class UserProfile {
  String userType; // 考研/高中/大学/在职
  List<int> productiveHours;
  List<int> restHours;
  List<String> preferredActivities;
  List<String> preferredRuleTimes;
  int dailyGoalMinutes;
  int continuousLimit;
  String reminderStyle; // 温和/直接/幽默
  Map<String, double> responseRates;
  int lastWeekAverage;

  UserProfile({
    required this.userType,
    required this.productiveHours,
    required this.restHours,
    required this.preferredActivities,
    required this.preferredRuleTimes,
    required this.dailyGoalMinutes,
    required this.continuousLimit,
    required this.reminderStyle,
    required this.responseRates,
    required this.lastWeekAverage,
  });

  factory UserProfile.defaultProfile() => UserProfile(
        userType: '大学',
        productiveHours: [9, 10, 14, 15, 16, 20],
        restHours: [12, 13, 18, 19, 22, 23],
        preferredActivities: ['听音乐', '散步', '阅读'],
        preferredRuleTimes: [],
        dailyGoalMinutes: 180,
        continuousLimit: 45,
        reminderStyle: '温和',
        responseRates: {},
        lastWeekAverage: 180,
      );

  double get averageResponseRate {
    if (responseRates.isEmpty) return 0.5;
    return responseRates.values.reduce((a, b) => a + b) / responseRates.length;
  }

  Future<void> updateResponseRate(String rule, bool acted) async {
    final current = responseRates[rule] ?? 0.5;
    responseRates[rule] = current * 0.9 + (acted ? 0.1 : 0);
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        userType: json['userType'] ?? '大学',
        productiveHours: (json['productiveHours'] as List?)?.cast<int>() ?? [9, 14, 20],
        restHours: (json['restHours'] as List?)?.cast<int>() ?? [12, 18, 22],
        preferredActivities: (json['preferredActivities'] as List?)?.cast<String>() ?? [],
        preferredRuleTimes: (json['preferredRuleTimes'] as List?)?.cast<String>() ?? [],
        dailyGoalMinutes: json['dailyGoalMinutes'] ?? 180,
        continuousLimit: json['continuousLimit'] ?? 45,
        reminderStyle: json['reminderStyle'] ?? '温和',
        responseRates: (json['responseRates'] as Map?)?.cast<String, double>() ?? {},
        lastWeekAverage: json['lastWeekAverage'] ?? 180,
      );

  Map<String, dynamic> toJson() => {
        'userType': userType,
        'productiveHours': productiveHours,
        'restHours': restHours,
        'preferredActivities': preferredActivities,
        'preferredRuleTimes': preferredRuleTimes,
        'dailyGoalMinutes': dailyGoalMinutes,
        'continuousLimit': continuousLimit,
        'reminderStyle': reminderStyle,
        'responseRates': responseRates,
        'lastWeekAverage': lastWeekAverage,
      };
}

/// 场景枚举
enum Scene {
  morningStudy('早晨学习', '高效学习时段，保持专注'),
  lunchBreak('午休时间', '午餐休息，适度放松'),
  afternoonTea('下午茶', '午后小憩，恢复精力'),
  dinnerBreak('晚餐时间', '晚餐休息，享受生活'),
  lateNightScroll('深夜刷手机', '深夜使用，影响睡眠'),
  bedtimeScrolling('睡前刷手机', '睡前使用，影响入睡'),
  weekendRelax('周末放松', '周末时间，适度娱乐'),
  continuousUse('连续使用', '连续使用过长，需要休息'),
  approachingLimit('即将超标', '按当前速度将超标'),
  examPeriod('考试周', '考试期间，专注学习'),
  normal('正常', '正常使用中');

  final String name;
  final String description;
  const Scene(this.name, this.description);
}

/// 用户意图
enum UserIntent {
  createRule,
  askAdvice,
  checkProgress,
  expressFrustration,
  general,
}

/// Agent响应
class AgentResponse {
  final String reply;
  final SmartRule? newRule;

  AgentResponse({required this.reply, this.newRule});
}

/// 周报分析
class WeeklyAnalysis {
  final int totalMinutes;
  final int avgMinutes;
  final DailyUsage maxDay;
  final DailyUsage minDay;
  final String trend;
  final int comparedToLastWeek;

  WeeklyAnalysis({
    required this.totalMinutes,
    required this.avgMinutes,
    required this.maxDay,
    required this.minDay,
    required this.trend,
    required this.comparedToLastWeek,
  });

  factory WeeklyAnalysis.empty() => WeeklyAnalysis(
        totalMinutes: 0,
        avgMinutes: 0,
        maxDay: DailyUsage(date: DateTime.now(), totalScreenTime: 0, unlockCount: 0, appUsages: []),
        minDay: DailyUsage(date: DateTime.now(), totalScreenTime: 0, unlockCount: 0, appUsages: []),
        trend: '持平',
        comparedToLastWeek: 0,
      );
}


