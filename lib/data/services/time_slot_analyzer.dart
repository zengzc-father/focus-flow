import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/schedule.dart';
import '../models/app_usage.dart';
import 'schedule_repository.dart';
import 'system_usage_provider.dart';
import 'chinese_app_database.dart';

/// 应用意图分类器
class AppIntentClassifier {
  /// 判断应用意图（基于中国应用数据库）
  static UsageIntent classify(String packageName) {
    // 优先使用中国应用数据库
    final appInfo = ChineseAppDatabase.getAppInfo(packageName);
    if (appInfo != null) {
      return appInfo.intent;
    }

    // 根据包名关键词推测
    final lower = packageName.toLowerCase();

    // 游戏
    if (lower.contains('tencent.tmgp') ||
        lower.contains('miHoYo') ||
        lower.contains('netease.game') ||
        lower.contains('.game.')) {
      return UsageIntent.entertainment;
    }

    // 短视频/娱乐
    if (lower.contains('douyin') ||
        lower.contains('kuaishou') ||
        lower.contains('bili') ||
        lower.contains('xhs')) {
      return UsageIntent.entertainment;
    }

    // 音乐
    if (lower.contains('music') ||
        lower.contains('audio') ||
        lower.contains('cloudmusic')) {
      return UsageIntent.music;
    }

    // 教育学习
    if (lower.contains('edu') ||
        lower.contains('learn') ||
        lower.contains('study') ||
        lower.contains('chaoxing')) {
      return UsageIntent.study;
    }

    // 通讯
    if (lower.contains('chat') ||
        lower.contains('im.') ||
        lower.contains('message')) {
      return UsageIntent.communication;
    }

    // 工具
    if (lower.contains('tool') ||
        lower.contains('camera') ||
        lower.contains('calc')) {
      return UsageIntent.tool;
    }

    return UsageIntent.unknown;
  }

  /// 获取应用中文名称
  static String getAppName(String packageName) {
    return ChineseAppDatabase.getAppName(packageName);
  }

  /// 判断是否高成瘾性应用
  static bool isHighAddictive(String packageName) {
    return ChineseAppDatabase.isHighAddictive(packageName);
  }

  /// 判断是否为合理短暂使用
  static bool isAcceptableBriefUse(UsageIntent intent, int durationSeconds) {
    // 查看消息（30秒内）可接受
    if (intent == UsageIntent.communication && durationSeconds <= 30) {
      return true;
    }
    // 工具使用（1分钟内）可接受
    if (intent == UsageIntent.tool && durationSeconds <= 60) {
      return true;
    }
    // 音乐（健身时）持续可接受
    if (intent == UsageIntent.music) {
      return true;
    }
    return false;
  }

  /// 获取意图中文名
  static String getIntentName(UsageIntent intent) {
    switch (intent) {
      case UsageIntent.tool:
        return '工具使用';
      case UsageIntent.communication:
        return '查看消息';
      case UsageIntent.entertainment:
        return '娱乐使用';
      case UsageIntent.study:
        return '学习使用';
      case UsageIntent.music:
        return '听音乐';
      case UsageIntent.unknown:
        return '其他使用';
      case UsageIntent.news:
        return '看新闻';
      case UsageIntent.shopping:
        return '购物';
      case UsageIntent.other:
        return '其他';
    }
  }
}

/// 时段使用分析结果
class TimeSlotAnalysis {
  final ScheduleEvent? event;              // 关联的日程
  final DateTime date;                     // 日期
  final int totalSeconds;                  // 总时长
  final int totalPhoneUsageSeconds;        // 总手机使用
  final Map<UsageIntent, int> intentUsage; // 按意图分类的使用
  final double focusScore;                 // 专注度 0-100
  final String assessment;                 // 评估结论
  final List<String> concerns;             // 关注点

  TimeSlotAnalysis({
    required this.event,
    required this.date,
    required this.totalSeconds,
    required this.totalPhoneUsageSeconds,
    required this.intentUsage,
    required this.focusScore,
    required this.assessment,
    required this.concerns,
  });

  int get entertainmentSeconds => intentUsage[UsageIntent.entertainment] ?? 0;
  int get communicationSeconds => intentUsage[UsageIntent.communication] ?? 0;
  int get toolSeconds => intentUsage[UsageIntent.tool] ?? 0;

  /// 娱乐占比
  double get entertainmentRatio {
    if (totalPhoneUsageSeconds == 0) return 0;
    return entertainmentSeconds / totalPhoneUsageSeconds;
  }

  String get summary {
    final eventName = event?.name ?? '该时段';
    final totalMin = totalPhoneUsageSeconds ~/ 60;
    final entMin = entertainmentSeconds ~/ 60;

    if (totalMin == 0) {
      return '$eventName完全专注，没有使用手机，太棒了！';
    }

    if (entertainmentRatio > 0.5) {
      return '$eventName用了$totalMin分钟手机，其中娱乐$entMin分钟，需要更专注哦~';
    } else if (totalMin > 10) {
      return '$eventName用了$totalMin分钟手机，但主要是工具使用，控制得不错~';
    } else {
      return '$eventName只用了$totalMin分钟手机，很专注！';
    }
  }
}

/// 时段使用分析器
class TimeSlotAnalyzer {
  final SystemUsageProvider _usageProvider = SystemUsageProvider();

  /// 分析某日程时段的使用情况
  Future<TimeSlotAnalysis> analyzeScheduleEvent(
    ScheduleEvent event,
    DateTime date,
  ) async {
    // 构建时段
    final start = DateTime(
      date.year, date.month, date.day,
      event.timeSlot.hour, event.timeSlot.minute,
    );
    final end = start.add(Duration(minutes: event.timeSlot.durationMinutes));

    return await analyzeTimeSlot(start, end, event: event);
  }

  /// 分析任意时段的使用情况
  Future<TimeSlotAnalysis> analyzeTimeSlot(
    DateTime start,
    DateTime end, {
    ScheduleEvent? event,
  }) async {
    try {
      // 获取该时段的所有使用事件
      final events = await _usageProvider.getEventsInRange(start, end);

      // 按意图分类统计
      final intentUsage = <UsageIntent, int>{};
      int totalPhoneUsage = 0;

      for (var event in events) {
        final intent = AppIntentClassifier.classify(event.packageName);
        final duration = event.duration.inSeconds;

        intentUsage[intent] = (intentUsage[intent] ?? 0) + duration;
        totalPhoneUsage += duration;
      }

      final totalSeconds = end.difference(start).inSeconds;
      final entertainmentSeconds = intentUsage[UsageIntent.entertainment] ?? 0;

      // 计算专注度
      final focusScore = _calculateFocusScore(
        totalSeconds: totalSeconds,
        phoneUsageSeconds: totalPhoneUsage,
        entertainmentSeconds: entertainmentSeconds,
        eventType: event?.type,
      );

      // 生成评估
      final assessment = _generateAssessment(
        event: event,
        focusScore: focusScore,
        entertainmentSeconds: entertainmentSeconds,
        totalPhoneUsage: totalPhoneUsage,
      );

      // 识别关注点
      final concerns = _identifyConcerns(
        event: event,
        intentUsage: intentUsage,
        focusScore: focusScore,
      );

      return TimeSlotAnalysis(
        event: event,
        date: start,
        totalSeconds: totalSeconds,
        totalPhoneUsageSeconds: totalPhoneUsage,
        intentUsage: intentUsage,
        focusScore: focusScore,
        assessment: assessment,
        concerns: concerns,
      );
    } catch (e) {
      debugPrint('分析时段使用失败: $e');
      return TimeSlotAnalysis(
        event: event,
        date: start,
        totalSeconds: end.difference(start).inSeconds,
        totalPhoneUsageSeconds: 0,
        intentUsage: {},
        focusScore: 100,
        assessment: '数据获取失败，无法评估',
        concerns: [],
      );
    }
  }

  /// 分析今日某类活动的整体情况
  Future<String> analyzeTodayByType(EventType type, DateTime date) async {
    final repo = ScheduleRepository();
    await repo.load();

    final events = repo.getTodayEvents(date)
        .where((e) => e.type == type)
        .toList();

    if (events.isEmpty) {
      return '今天没有安排${type.displayName}时间';
    }

    final analyses = <TimeSlotAnalysis>[];
    for (var event in events) {
      final analysis = await analyzeScheduleEvent(event, date);
      analyses.add(analysis);
    }

    // 汇总
    final totalMinutes = analyses.fold<int>(
      0, (sum, a) => sum + a.totalSeconds ~/ 60,
    );
    final totalPhoneMinutes = analyses.fold<int>(
      0, (sum, a) => sum + a.totalPhoneUsageSeconds ~/ 60,
    );
    final totalEntMinutes = analyses.fold<int>(
      0, (sum, a) => sum + a.entertainmentSeconds ~/ 60,
    );
    final avgFocus = analyses.isEmpty
        ? 0
        : analyses.fold<double>(0, (sum, a) => sum + a.focusScore) / analyses.length;

    return '今天共${events.length}段${type.displayName}时间，'
           '总计${totalMinutes}分钟。\n'
           '期间使用手机${totalPhoneMinutes}分钟，'
           '其中娱乐${totalEntMinutes}分钟。\n'
           '平均专注度${avgFocus.round()}%。';
  }

  /// 计算专注度评分
  double _calculateFocusScore({
    required int totalSeconds,
    required int phoneUsageSeconds,
    required int entertainmentSeconds,
    EventType? eventType,
  }) {
    if (totalSeconds == 0) return 100;

    // 基础分：未使用手机的时间占比
    var score = ((totalSeconds - phoneUsageSeconds) / totalSeconds) * 100;

    // 根据活动类型调整
    if (eventType == EventType.course || eventType == EventType.study) {
      // 上课/自习：娱乐使用惩罚更重
      final entertainmentPenalty = (entertainmentSeconds / totalSeconds) * 150;
      score -= entertainmentPenalty;
    } else if (eventType == EventType.exercise) {
      // 健身：允许适当音乐，通讯较宽松
      score -= (entertainmentSeconds / totalSeconds) * 50;
    }

    // 通讯和工具使用惩罚较轻
    final toolSeconds = phoneUsageSeconds - entertainmentSeconds;
    score -= (toolSeconds / totalSeconds) * 20;

    return score.clamp(0, 100);
  }

  /// 生成评估
  String _generateAssessment({
    ScheduleEvent? event,
    required double focusScore,
    required int entertainmentSeconds,
    required int totalPhoneUsage,
  }) {
    final eventName = event?.name ?? '该时段';
    final entMinutes = entertainmentSeconds ~/ 60;

    if (focusScore >= 90) {
      return '$eventName非常专注，继续保持！';
    } else if (focusScore >= 70) {
      return '$eventName整体不错，略有分心。';
    } else if (focusScore >= 50) {
      if (entMinutes > 10) {
        return '$eventName娱乐使用了${entMinutes}分钟，需要提高专注力。';
      }
      return '$eventName有较多工具使用，注意控制时间。';
    } else {
      return '$eventName专注度较低，建议调整状态。';
    }
  }

  /// 识别关注点
  List<String> _identifyConcerns({
    ScheduleEvent? event,
    required Map<UsageIntent, int> intentUsage,
    required double focusScore,
  }) {
    final concerns = <String>[];
    final entertainmentSeconds = intentUsage[UsageIntent.entertainment] ?? 0;

    // 娱乐使用过长
    if (entertainmentSeconds > 300) { // 超过5分钟
      concerns.add('娱乐使用${entertainmentSeconds ~/ 60}分钟');
    }

    // 专注度过低
    if (focusScore < 50) {
      concerns.add('专注度较低');
    }

    // 根据事件类型特定关注
    if (event?.type == EventType.course && entertainmentSeconds > 180) {
      concerns.add('上课时间娱乐使用较多');
    }

    return concerns;
  }
}

/// 使用事件（内部使用）
class _UsageEvent {
  final String packageName;
  final DateTime start;
  final DateTime end;
  final Duration duration;

  _UsageEvent({
    required this.packageName,
    required this.start,
    required this.end,
  }) : duration = end.difference(start);
}
