import 'dart:convert';
import 'package:flutter/material.dart';
import 'rule_engine.dart';

/// Agent规则自然语言解析器
/// 将用户自然语言输入的规则解析为结构化的SmartRule
class AgentRuleParser {
  /// 解析自然语言规则
  ///
  /// 支持格式：
  /// - "上课别让我刷抖音超过5分钟"
  /// - "晚上8点后刷抖音超过30分钟提醒我"
  /// - "每天使用手机超过3小时提醒我"
  /// - "高数课期间限制娱乐应用使用"
  SmartRule? parse(String input) {
    try {
      final lower = input.toLowerCase();

      // 提取规则名称
      final name = _extractRuleName(input);

      // 提取时间段条件
      final timeRange = _extractTimeRange(lower);
      final days = _extractDays(lower);

      // 提取使用时长条件
      final consecutiveMinutes = _extractConsecutiveMinutes(lower);
      final totalMinutes = _extractTotalMinutes(lower);

      // 提取目标应用
      final targetApps = _extractTargetApps(lower);

      // 提取限制时长
      final limitMinutes = _extractLimitMinutes(lower);

      // 如果没有提取到任何有效条件，返回null
      if (timeRange == null && days == null &&
          consecutiveMinutes == null && totalMinutes == null &&
          limitMinutes == null) {
        return null;
      }

      // 构建消息
      String message = _buildMessage(input, targetApps, limitMinutes);

      return SmartRule(
        name: name,
        description: input,
        conditions: RuleConditions(
          timeRange: timeRange,
          days: days,
          consecutiveMinutes: consecutiveMinutes ?? limitMinutes,
          totalMinutes: totalMinutes,
        ),
        action: RuleAction(
          type: 'notify',
          message: message,
        ),
        enabled: true,
      );
    } catch (e) {
      debugPrint('解析规则失败: $e');
      return null;
    }
  }

  String _extractRuleName(String input) {
    final lower = input.toLowerCase();

    // 根据关键词提取名称
    if (lower.contains('上课') || lower.contains('课程')) {
      return '上课专注规则';
    }
    if (lower.contains('自习') || lower.contains('学习')) {
      return '自习专注规则';
    }
    if (lower.contains('晚上') || lower.contains('睡前')) {
      return '晚间使用限制';
    }
    if (lower.contains('抖音')) {
      return '抖音使用限制';
    }
    if (lower.contains('微信')) {
      return '微信使用提醒';
    }
    if (lower.contains('游戏')) {
      return '游戏时间限制';
    }

    return '自定义规则';
  }

  String? _extractTimeRange(String input) {
    // 匹配 "晚上8点"、"8:00-10:00"、"下午2点到4点"

    // 提取具体时间段
    final timeReg = RegExp(r'(\d{1,2})[:点](\d{0,2})?');
    final matches = timeReg.allMatches(input).toList();

    if (matches.length >= 2) {
      // 有开始和结束时间
      final start = _formatTime(matches[0], input);
      final end = _formatTime(matches[1], input);
      return '$start-$end';
    }

    // 特定时段关键词
    if (input.contains('晚上') || input.contains('睡前')) {
      return '22:00-24:00';
    }
    if (input.contains('下午')) {
      return '14:00-18:00';
    }
    if (input.contains('上午')) {
      return '08:00-12:00';
    }

    return null;
  }

  String _formatTime(RegExpMatch match, String input) {
    var hour = int.parse(match.group(1)!);
    var minute = 0;

    if (match.group(2) != null && match.group(2)!.isNotEmpty) {
      minute = int.parse(match.group(2)!);
    }

    // 判断上午下午
    if (input.contains('下午') || input.contains('晚上')) {
      if (hour < 12) hour += 12;
    }

    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  List<int>? _extractDays(String input) {
    final days = <int>[];
    final lower = input.toLowerCase();

    // 每天
    if (lower.contains('每天') || lower.contains('每日')) {
      return [1, 2, 3, 4, 5, 6, 7];
    }

    // 工作日
    if (lower.contains('工作日') || lower.contains('周一到周五')) {
      return [1, 2, 3, 4, 5];
    }

    // 周末
    if (lower.contains('周末')) {
      return [6, 7];
    }

    // 具体星期
    final weekdayMap = {
      '周一': 1, '周二': 2, '周三': 3, '周四': 4,
      '周五': 5, '周六': 6, '周日': 7, '星期天': 7, '星期日': 7,
    };

    for (var entry in weekdayMap.entries) {
      if (lower.contains(entry.key)) {
        if (!days.contains(entry.value)) {
          days.add(entry.value);
        }
      }
    }

    return days.isEmpty ? null : days..sort();
  }

  int? _extractConsecutiveMinutes(String input) {
    // 匹配 "连续使用X分钟"、"超过X分钟"
    final reg = RegExp(r'(连续|超过|达到|大于)(\d+)[\s]*(分钟|分|min)');
    final match = reg.firstMatch(input.toLowerCase());
    if (match != null) {
      return int.parse(match.group(2)!);
    }
    return null;
  }

  int? _extractTotalMinutes(String input) {
    // 匹配 "超过X小时"、"X小时"
    final hourReg = RegExp(r'(超过|达到|大于)?(\d+)[\s]*小时');
    final match = hourReg.firstMatch(input.toLowerCase());
    if (match != null) {
      return int.parse(match.group(2)!) * 60;
    }
    return null;
  }

  int? _extractLimitMinutes(String input) {
    // 匹配 "超过X分钟提醒我"、"限制X分钟"
    final reg = RegExp(r'(超过|限制|大于|多于)(\d+)[\s]*(分钟|分)');
    final match = reg.firstMatch(input.toLowerCase());
    if (match != null) {
      return int.parse(match.group(2)!);
    }
    return null;
  }

  List<String> _extractTargetApps(String input) {
    final apps = <String>[];
    final lower = input.toLowerCase();

    final appKeywords = {
      '抖音': 'com.ss.android.ugc.aweme',
      '微信': 'com.tencent.mm',
      '微博': 'com.sina.weibo',
      '小红书': 'com.xingin.xhs',
      'b站': 'tv.danmaku.bili',
      '哔哩哔哩': 'tv.danmaku.bili',
      '快手': 'com.smile.gifmaker',
      '知乎': 'com.zhihu.android',
      '淘宝': 'com.taobao.taobao',
      '游戏': 'game',
      '娱乐': 'entertainment',
    };

    for (var entry in appKeywords.entries) {
      if (lower.contains(entry.key)) {
        apps.add(entry.value);
      }
    }

    return apps;
  }

  String _buildMessage(String input, List<String> targetApps, int? limitMinutes) {
    if (targetApps.isNotEmpty && limitMinutes != null) {
      return '你在${targetApps.first}已使用超过$limitMinutes分钟，该休息一下了~';
    }
    if (limitMinutes != null) {
      return '你已使用手机超过$limitMinutes分钟，建议休息一下~';
    }
    if (targetApps.isNotEmpty) {
      return '${targetApps.first}使用提醒：注意控制时间哦~';
    }
    return '该休息一下了，保护眼睛和身体~';
  }
}

/// 扩展SmartRule以支持应用特定的规则
class AppSpecificRule {
  final String packageName;
  final String appName;
  final int limitMinutes;
  final List<int>? weekdays;
  final String? timeRange;

  AppSpecificRule({
    required this.packageName,
    required this.appName,
    required this.limitMinutes,
    this.weekdays,
    this.timeRange,
  });

  Map<String, dynamic> toJson() => {
    'packageName': packageName,
    'appName': appName,
    'limitMinutes': limitMinutes,
    'weekdays': weekdays,
    'timeRange': timeRange,
  };

  factory AppSpecificRule.fromJson(Map<String, dynamic> json) => AppSpecificRule(
    packageName: json['packageName'],
    appName: json['appName'],
    limitMinutes: json['limitMinutes'],
    weekdays: (json['weekdays'] as List?)?.cast<int>(),
    timeRange: json['timeRange'],
  );
}
