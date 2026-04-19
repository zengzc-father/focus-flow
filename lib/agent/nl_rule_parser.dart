import 'dart:async';
import 'package:flutter/foundation.dart';
import '../data/services/chinese_app_database.dart';
import '../data/services/rule_engine.dart';
import '../data/models/app_usage.dart' show UsageIntent;

/// 自然语言规则解析器（增强版）
///
/// 支持复杂的自然语言规则创建，如：
/// - "周一到周五晚上8点后刷抖音超过30分钟就提醒我休息"
/// - "如果连续使用微信超过1小时，发送通知"
/// - "上课期间玩游戏超过5分钟强烈提醒"
class NLRuleParser {
  /// 解析自然语言输入，生成可执行的规则
  static ParseResult parse(String input) {
    debugPrint('📝 解析规则: $input');

    final lower = input.toLowerCase();

    // 1. 提取应用名称
    final appInfo = _extractAppInfo(input);

    // 2. 提取时间条件
    final timeCondition = _extractTimeCondition(input);

    // 3. 提取时长阈值
    final durationThreshold = _extractDurationThreshold(input);

    // 4. 提取星期条件
    final weekdays = _extractWeekdays(input);

    // 5. 提取提醒强度
    final intensity = _extractIntensity(input);

    // 6. 提取场景/日程限制
    final eventContext = _extractEventContext(input);

    // 7. 生成规则名称和描述
    final ruleName = _generateRuleName(appInfo, timeCondition, eventContext);
    final description = _generateDescription(
      appInfo,
      timeCondition,
      durationThreshold,
      weekdays,
      eventContext,
      intensity,
    );

    // 8. 构建条件对象
    final conditions = RuleConditions(
      timeRange: timeCondition?.timeRange,
      days: weekdays.isEmpty ? null : weekdays,
      consecutiveMinutes: durationThreshold?.minutes,
      totalMinutes: null, // 可以扩展支持累计时长
    );

    // 9. 构建动作对象
    final action = RuleAction(
      type: _mapIntensityToActionType(intensity),
      message: _generateMessage(appInfo, durationThreshold, eventContext, intensity),
    );

    // 检查是否解析成功
    final isValid = appInfo != null && durationThreshold != null;

    return ParseResult(
      isValid: isValid,
      rule: isValid
          ? SmartRule(
              name: ruleName,
              description: description,
              conditions: conditions,
              action: action,
              enabled: true,
            )
          : null,
      parsedElements: ParsedElements(
        appName: appInfo?.displayName,
        durationMinutes: durationThreshold?.minutes,
        timeRange: timeCondition?.timeRange,
        weekdays: weekdays,
        intensity: intensity,
        eventContext: eventContext,
      ),
      missingElements: _identifyMissingElements(
        appInfo,
        durationThreshold,
        timeCondition,
      ),
    );
  }

  /// 提取应用信息
  static AppMatch? _extractAppInfo(String input) {
    final lower = input.toLowerCase();

    // 遍历中国应用数据库匹配
    final allApps = ChineseAppDatabase.allApps;
    for (final entry in allApps.entries) {
      final appInfo = entry.value;

      // 检查主名称
      if (lower.contains(appInfo.name.toLowerCase())) {
        return AppMatch(
          packageName: entry.key,
          displayName: appInfo.name,
          intent: appInfo.intent,
        );
      }

      // 检查包名关键词（部分应用名可能在包名中）
      final packageKeywords = entry.key.toLowerCase().split('.');
      for (final keyword in packageKeywords) {
        if (keyword.length > 3 && lower.contains(keyword)) {
          return AppMatch(
            packageName: entry.key,
            displayName: appInfo.name,
            intent: appInfo.intent,
          );
        }
      }
    }

    // 模糊匹配常见应用关键词
    final appKeywords = {
      '抖音': ['抖音', 'tiktok', 'douyin', 'aweme'],
      '微信': ['微信', 'wechat', 'tencent.mm'],
      'QQ': ['qq', '腾讯qq', 'tencent.mobileqq'],
      '微博': ['微博', 'weibo', 'sina'],
      '小红书': ['小红书', 'xhs', 'red', 'xingin'],
      'B站': ['b站', 'bilibili', '哔哩哔哩', 'danmaku'],
      '快手': ['快手', 'kuaishou', 'gifmaker'],
      '知乎': ['知乎', 'zhihu'],
      '淘宝': ['淘宝', 'taobao', '购物'],
      '游戏': ['游戏', '王者', '吃鸡', '原神', '崩铁', '阴阳师'],
      '网易云': ['网易云', 'cloudmusic', 'netease.music'],
      'QQ音乐': ['qq音乐', 'qqmusic'],
    };

    for (final entry in appKeywords.entries) {
      for (final keyword in entry.value) {
        if (lower.contains(keyword.toLowerCase())) {
          return AppMatch(
            packageName: 'keyword:${entry.key}',
            displayName: entry.key,
            intent: UsageIntent.unknown,
          );
        }
      }
    }

    return null;
  }

  /// 提取时间条件
  static TimeCondition? _extractTimeCondition(String input) {
    final lower = input.toLowerCase();

    // 匹配 "X点后"、"晚上X点"、"下午X点"
    final timePatterns = [
      // 晚上8点后、晚上八点后
      RegExp(r'晚上(\d{1,2})[点:]'),
      RegExp(r'晚(\d{1,2})[点:]'),
      // 下午X点
      RegExp(r'下午(\d{1,2})[点:]'),
      // X点后
      RegExp(r'(\d{1,2})[点:]\s*后'),
      RegExp(r'(\d{1,2})[点:]\s*之后'),
      // 从X点到Y点
      RegExp(r'从\s*(\d{1,2})[点:]\s*到\s*(\d{1,2})[点:]'),
    ];

    for (final pattern in timePatterns) {
      final match = pattern.firstMatch(lower);
      if (match != null) {
        if (match.groupCount >= 2 && match.group(2) != null) {
          // 范围时间 从X点到Y点
          final startHour = int.tryParse(match.group(1)!) ?? 0;
          final endHour = int.tryParse(match.group(2)!) ?? 0;
          return TimeCondition(
            startHour: startHour,
            endHour: endHour,
            timeRange: '${startHour.toString().padLeft(2, '0')}:00-${endHour.toString().padLeft(2, '0')}:00',
          );
        } else {
          // 单点时间 X点后
          var hour = int.tryParse(match.group(1)!) ?? 0;

          // 处理下午/晚上
          if (lower.contains('下午') && hour < 12) hour += 12;
          if (lower.contains('晚上') && hour < 12) hour += 12;

          return TimeCondition(
            startHour: hour,
            endHour: 23,
            timeRange: '${hour.toString().padLeft(2, '0')}:00-23:59',
          );
        }
      }
    }

    // 特殊时间段关键词
    if (lower.contains('深夜') || lower.contains('半夜') || lower.contains('凌晨')) {
      return TimeCondition(
        startHour: 0,
        endHour: 6,
        timeRange: '00:00-06:00',
      );
    }

    if (lower.contains('上班时间') || lower.contains('工作时间')) {
      return TimeCondition(
        startHour: 9,
        endHour: 18,
        timeRange: '09:00-18:00',
      );
    }

    return null;
  }

  /// 提取时长阈值
  static DurationThreshold? _extractDurationThreshold(String input) {
    final lower = input.toLowerCase();

    // 匹配各种时长表达方式
    final patterns = [
      // X分钟、X分
      RegExp(r'(\d+)\s*分钟'),
      RegExp(r'(\d+)\s*分'),
      // X小时、X个小时
      RegExp(r'(\d+(?:\.\d+)?)\s*小时'),
      RegExp(r'(\d+(?:\.\d+)?)\s*个?小时'),
      // 半小时
      RegExp(r'半小时'),
      // 一刻钟
      RegExp(r'一刻钟'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(lower);
      if (match != null) {
        if (match.pattern.toString().contains('半小时')) {
          return DurationThreshold(minutes: 30, displayText: '30分钟');
        }
        if (match.pattern.toString().contains('一刻钟')) {
          return DurationThreshold(minutes: 15, displayText: '15分钟');
        }

        final value = match.group(1);
        if (value != null) {
          final numValue = double.tryParse(value) ?? 0;

          if (match.pattern.toString().contains('小时')) {
            final minutes = (numValue * 60).round();
            return DurationThreshold(
              minutes: minutes,
              displayText: '${numValue.toStringAsFixed(1)}小时',
            );
          } else {
            return DurationThreshold(
              minutes: numValue.round(),
              displayText: '${numValue.round()}分钟',
            );
          }
        }
      }
    }

    return null;
  }

  /// 提取星期条件
  static List<int> _extractWeekdays(String input) {
    final lower = input.toLowerCase();
    final weekdays = <int>[];

    // 匹配星期几
    final weekdayMap = {
      '周一': 1, '星期一': 1, '礼拜一': 1,
      '周二': 2, '星期二': 2, '礼拜二': 2,
      '周三': 3, '星期三': 3, '礼拜三': 3,
      '周四': 4, '星期四': 4, '礼拜四': 4,
      '周五': 5, '星期五': 5, '礼拜五': 5,
      '周六': 6, '星期六': 6, '礼拜六': 6, '周末': 6,
      '周日': 7, '星期天': 7, '礼拜天': 7, '星期日': 7, '周末': 7,
    };

    // 检查特定星期
    for (final entry in weekdayMap.entries) {
      if (lower.contains(entry.key)) {
        if (!weekdays.contains(entry.value)) {
          weekdays.add(entry.value);
        }
      }
    }

    // 检查范围表达
    if (lower.contains('工作日') || lower.contains('周一到周五') || lower.contains('星期一到星期五')) {
      weekdays.addAll([1, 2, 3, 4, 5]);
    }

    if (lower.contains('每天') || lower.contains('天天') || lower.contains('总是')) {
      weekdays.addAll([1, 2, 3, 4, 5, 6, 7]);
    }

    return weekdays.toSet().toList()..sort();
  }

  /// 提取提醒强度
  static ReminderIntensity _extractIntensity(String input) {
    final lower = input.toLowerCase();

    // 强烈提醒关键词
    if (lower.contains('强烈') ||
        lower.contains('强制') ||
        lower.contains('必须') ||
        lower.contains('弹窗') ||
        lower.contains('阻止') ||
        lower.contains('不许')) {
      return ReminderIntensity.strong;
    }

    // 温和提醒关键词
    if (lower.contains('温柔') ||
        lower.contains('轻声') ||
        lower.contains('默默') ||
        lower.contains('安静')) {
      return ReminderIntensity.gentle;
    }

    // 普通提醒（默认）
    return ReminderIntensity.normal;
  }

  /// 提取场景/日程上下文
  static String? _extractEventContext(String input) {
    final lower = input.toLowerCase();

    // 上课、自习、健身等场景
    if (lower.contains('上课') || lower.contains('课堂') || lower.contains('课程')) {
      return '上课';
    }
    if (lower.contains('自习') || lower.contains('学习') || lower.contains('图书馆')) {
      return '自习';
    }
    if (lower.contains('健身') || lower.contains('运动') || lower.contains('锻炼')) {
      return '健身';
    }
    if (lower.contains('开会') || lower.contains('会议') || lower.contains('上班')) {
      return '会议';
    }

    return null;
  }

  /// 生成规则名称
  static String _generateRuleName(AppMatch? app, TimeCondition? time, String? event) {
    final parts = <String>[];

    if (event != null) {
      parts.add(event);
    }

    if (time != null) {
      parts.add('${time.startHour}点后');
    }

    if (app != null) {
      parts.add(app.displayName);
    } else {
      parts.add('屏幕时间');
    }

    parts.add('规则');

    return parts.join('');
  }

  /// 生成规则描述
  static String _generateDescription(
    AppMatch? app,
    TimeCondition? time,
    DurationThreshold? duration,
    List<int> weekdays,
    String? eventContext,
    ReminderIntensity intensity,
  ) {
    final parts = <String>[];

    if (weekdays.isNotEmpty && weekdays.length < 7) {
      parts.add(_formatWeekdays(weekdays));
    }

    if (time != null) {
      parts.add('${time.startHour}点到${time.endHour}点之间');
    }

    if (eventContext != null) {
      parts.add('在$eventContext期间');
    }

    if (app != null) {
      parts.add('使用${app.displayName}');
    } else {
      parts.add('使用手机');
    }

    if (duration != null) {
      parts.add('超过${duration.displayText}');
    }

    parts.add('时${_mapIntensityToText(intensity)}提醒');

    return parts.join('，');
  }

  /// 生成提醒消息
  static String _generateMessage(
    AppMatch? app,
    DurationThreshold? duration,
    String? eventContext,
    ReminderIntensity intensity,
  ) {
    final appName = app?.displayName ?? '手机';
    final durationText = duration?.displayText ?? '很久了';

    final templates = {
      ReminderIntensity.gentle: [
        '已经用了$durationText$appName了，注意休息哦~',
        '$appName用了$durationText了，起来活动一下吧',
        '温馨提示：$appName使用时长已达到$durationText',
      ],
      ReminderIntensity.normal: [
        '$appName已使用$durationText，该休息一下了',
        '检测到连续使用$appName$durationText，建议休息',
        eventContext != null
            ? '$eventContext期间使用$appName$durationText了，注意分配时间'
            : '已经用了$durationText$appName了，该停下来了',
      ],
      ReminderIntensity.strong: [
        '$appName已使用$durationText，请立即停止！',
        eventContext != null
            ? '$eventContext时间已用$durationText$appName，现在放下！'
            : '警告：连续使用$appName$durationText，必须休息！',
        '你已经用了$durationText$appName了，强制执行休息',
      ],
    };

    final msgs = templates[intensity] ?? templates[ReminderIntensity.normal]!;
    return msgs[DateTime.now().millisecond % msgs.length];
  }

  /// 格式化星期显示
  static String _formatWeekdays(List<int> weekdays) {
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

  /// 映射强度到动作类型
  static String _mapIntensityToActionType(ReminderIntensity intensity) {
    switch (intensity) {
      case ReminderIntensity.gentle:
        return 'notify_quiet';
      case ReminderIntensity.normal:
        return 'notify';
      case ReminderIntensity.strong:
        return 'notify_strong';
    }
  }

  /// 映射强度到文本
  static String _mapIntensityToText(ReminderIntensity intensity) {
    switch (intensity) {
      case ReminderIntensity.gentle:
        return '温和';
      case ReminderIntensity.normal:
        return '';
      case ReminderIntensity.strong:
        return '强烈';
    }
  }

  /// 识别缺失的元素
  static List<String> _identifyMissingElements(
    AppMatch? app,
    DurationThreshold? duration,
    TimeCondition? time,
  ) {
    final missing = <String>[];

    if (app == null) {
      missing.add('应用名称（如抖音、微信）');
    }

    if (duration == null) {
      missing.add('时长阈值（如30分钟、1小时）');
    }

    return missing;
  }
}

/// 解析结果
class ParseResult {
  final bool isValid;
  final SmartRule? rule;
  final ParsedElements parsedElements;
  final List<String> missingElements;

  ParseResult({
    required this.isValid,
    this.rule,
    required this.parsedElements,
    required this.missingElements,
  });

  /// 生成用户友好的反馈
  String getFeedback() {
    if (isValid && rule != null) {
      return '✅ 已理解规则：${rule!.description}';
    }

    if (missingElements.isNotEmpty) {
      return '❓ 还需要以下信息：${missingElements.join('、')}';
    }

    return '❌ 无法解析规则，请尝试这样说：\n'
           '"周一到周五晚上8点后刷抖音超过30分钟提醒我"';
  }
}

/// 解析出的元素
class ParsedElements {
  final String? appName;
  final int? durationMinutes;
  final String? timeRange;
  final List<int> weekdays;
  final ReminderIntensity intensity;
  final String? eventContext;

  ParsedElements({
    this.appName,
    this.durationMinutes,
    this.timeRange,
    this.weekdays = const [],
    this.intensity = ReminderIntensity.normal,
    this.eventContext,
  });

  bool get hasApp => appName != null;
  bool get hasDuration => durationMinutes != null;
  bool get hasTimeRange => timeRange != null;
  bool get hasWeekdays => weekdays.isNotEmpty;
}

/// 应用匹配结果
class AppMatch {
  final String packageName;
  final String displayName;
  final UsageIntent intent;

  AppMatch({
    required this.packageName,
    required this.displayName,
    required this.intent,
  });
}

/// 时间条件
class TimeCondition {
  final int startHour;
  final int endHour;
  final String timeRange;

  TimeCondition({
    required this.startHour,
    required this.endHour,
    required this.timeRange,
  });
}

/// 时长阈值
class DurationThreshold {
  final int minutes;
  final String displayText;

  DurationThreshold({
    required this.minutes,
    required this.displayText,
  });
}

/// 提醒强度
enum ReminderIntensity {
  gentle,   // 温和
  normal,   // 普通
  strong,   // 强烈
}
