import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:usage_stats/usage_stats.dart';
import '../../data/models/app_usage.dart';

/// 系统UsageStats数据提供者
///
/// 核心设计：直接读取Android系统已记录的应用使用数据
/// 不进行重复计时，零额外功耗
class SystemUsageProvider {
  static final SystemUsageProvider _instance = SystemUsageProvider._internal();
  factory SystemUsageProvider() => _instance;
  SystemUsageProvider._internal();

  // 应用名称缓存
  final Map<String, String> _appNameCache = {};

  // ==================== 权限管理 ====================

  /// 检查是否有UsageStats权限
  Future<bool> checkPermission() async {
    try {
      return await UsageStats.checkUsagePermission() ?? false;
    } catch (e) {
      debugPrint('检查权限错误: $e');
      return false;
    }
  }

  /// 请求权限（跳转到系统设置）
  Future<void> requestPermission() async {
    await UsageStats.grantUsagePermission();
  }

  // ==================== 核心数据查询 ====================

  /// 获取今日使用统计
  ///
  /// 直接查询系统UsageStats，解析事件计算使用时长
  Future<DailyUsage> getTodayUsage({bool detailed = true}) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    try {
      final events = await UsageStats.queryEvents(startOfDay, now);
      return _parseEventsToDailyUsage(events, now, detailed: detailed);
    } catch (e) {
      debugPrint('获取今日使用数据失败: $e');
      return DailyUsage.empty(now);
    }
  }

  /// 获取指定日期的使用统计
  Future<DailyUsage> getUsageForDate(DateTime date, {bool detailed = true}) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));

    try {
      final events = await UsageStats.queryEvents(start, end);
      return _parseEventsToDailyUsage(events, date, detailed: detailed);
    } catch (e) {
      debugPrint('获取日期使用数据失败: $e');
      return DailyUsage.empty(date);
    }
  }

  /// 获取指定日期范围的使用统计
  Future<List<DailyUsage>> getUsageRange(DateTime start, DateTime end, {bool detailed = false}) async {
    final List<DailyUsage> results = [];
    var current = start;

    while (current.isBefore(end) || current.isAtSameMomentAs(end)) {
      final usage = await getUsageForDate(current, detailed: detailed);
      results.add(usage);
      current = current.add(const Duration(days: 1));
    }

    return results;
  }

  /// 获取本周使用统计（最近7天）
  Future<List<DailyUsage>> getWeeklyUsage() async {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 6));
    return getUsageRange(weekAgo, now, detailed: false);
  }

  /// 获取某应用的详细使用时段
  ///
  /// 返回该应用每次使用的开始和结束时间
  Future<List<UsageSession>> getAppTimeline(String packageName, DateTime date) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));

    try {
      final events = await UsageStats.queryEvents(start, end);
      return _extractAppSessions(events, packageName);
    } catch (e) {
      debugPrint('获取应用时间线失败: $e');
      return [];
    }
  }

  /// 获取当前活动应用（最近使用的应用）
  Future<String?> getCurrentApp() async {
    final now = DateTime.now();
    final fiveMinutesAgo = now.subtract(const Duration(minutes: 5));

    try {
      final events = await UsageStats.queryEvents(fiveMinutesAgo, now);
      if (events.isEmpty) return null;

      // 找最近的事件
      UsageEvent? lastEvent;
      for (var event in events.reversed) {
        if (event.eventType == UsageEvent.resumed) {
          lastEvent = event;
          break;
        }
      }

      return lastEvent?.packageName;
    } catch (e) {
      return null;
    }
  }

  /// 获取今日解锁次数
  Future<int> getUnlockCount() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    try {
      final events = await UsageStats.queryEvents(startOfDay, now);
      return _countUnlocks(events);
    } catch (e) {
      return 0;
    }
  }

  /// 获取指定应用今日使用时长
  Future<int> getAppUsageToday(String packageName) async {
    final usage = await getTodayUsage(detailed: true);
    final app = usage.appUsages.firstWhere(
      (a) => a.packageName == packageName,
      orElse: () => AppUsage.empty(packageName),
    );
    return app.usageTimeInSeconds;
  }

  /// 检测某应用当前是否正在使用
  Future<bool> isAppCurrentlyUsed(String packageName) async {
    final currentApp = await getCurrentApp();
    return currentApp == packageName;
  }

  // ==================== 数据分析方法 ====================

  /// 分析使用模式（返回各时段使用分布）
  Future<Map<int, int>> getHourlyDistribution(DateTime date) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));

    final events = await UsageStats.queryEvents(start, end);
    final hourlyMinutes = <int, int>{};

    for (var i = 0; i < 24; i++) {
      hourlyMinutes[i] = 0;
    }

    final sessions = _extractAllSessions(events);
    for (var session in sessions) {
      final hour = session.start.hour;
      final minutes = session.duration.inMinutes;
      hourlyMinutes[hour] = (hourlyMinutes[hour] ?? 0) + minutes;
    }

    return hourlyMinutes;
  }

  /// 获取连续使用时段（识别长时连续使用）
  Future<List<ContinuousSession>> getContinuousSessions(
    DateTime date, {
    int minDurationMinutes = 30,
  }) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));

    final events = await UsageStats.queryEvents(start, end);
    final sessions = _extractAllSessions(events);
    final continuousSessions = <ContinuousSession>[];

    for (var session in sessions) {
      if (session.duration.inMinutes >= minDurationMinutes) {
        final appName = await _getAppName(session.packageName);
        continuousSessions.add(ContinuousSession(
          packageName: session.packageName,
          appName: appName,
          start: session.start,
          end: session.end,
          duration: session.duration,
        ));
      }
    }

    // 按时长降序
    continuousSessions.sort((a, b) => b.duration.compareTo(a.duration));
    return continuousSessions;
  }

  /// 获取指定时间范围内的原始使用事件
  Future<List<RawUsageEvent>> getEventsInRange(DateTime start, DateTime end) async {
    try {
      final events = await UsageStats.queryEvents(start, end);
      final result = <RawUsageEvent>[];

      // 按应用分组，提取会话
      final byPackage = _groupEventsByPackage(events);

      for (var package in byPackage.keys) {
        final sessions = _extractAppSessions(events, package);
        for (var session in sessions) {
          result.add(RawUsageEvent(
            packageName: package,
            start: session.start,
            end: session.end,
            duration: session.duration,
          ));
        }
      }

      // 按开始时间排序
      result.sort((a, b) => a.start.compareTo(b.start));
      return result;
    } catch (e) {
      debugPrint('获取时段事件失败: $e');
      return [];
    }
  }

  /// 比较今日与昨日数据
  Future<DayComparison> compareWithYesterday() async {
    final today = await getTodayUsage(detailed: false);
    final yesterday = await getUsageForDate(
      DateTime.now().subtract(const Duration(days: 1)),
      detailed: false,
    );

    final diff = today.totalScreenTime - yesterday.totalScreenTime;
    final percentage = yesterday.totalScreenTime > 0
        ? (diff / yesterday.totalScreenTime * 100).round()
        : 0;

    return DayComparison(
      todayMinutes: today.totalScreenTime ~/ 60,
      yesterdayMinutes: yesterday.totalScreenTime ~/ 60,
      differenceMinutes: diff ~/ 60,
      percentageChange: percentage,
    );
  }

  /// 获取当前前台应用
  Future<String?> getCurrentForegroundApp() async {
    return await getCurrentApp();
  }

  /// 获取最后使用时间
  Future<DateTime?> getLastUsedTime() async {
    try {
      final now = DateTime.now();
      final thirtyMinutesAgo = now.subtract(const Duration(minutes: 30));
      final events = await UsageStats.queryEvents(thirtyMinutesAgo, now);

      if (events.isEmpty) return null;

      // 找最近的resumed事件
      UsageEvent? lastEvent;
      for (var event in events.reversed) {
        if (event.eventType == UsageEvent.resumed) {
          lastEvent = event;
          break;
        }
      }

      if (lastEvent?.timeStamp != null) {
        final timestamp = int.tryParse(lastEvent!.timeStamp!) ?? 0;
        return DateTime.fromMillisecondsSinceEpoch(timestamp);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// 检查屏幕是否亮着
  Future<bool> isScreenOn() async {
    try {
      final now = DateTime.now();
      final oneMinuteAgo = now.subtract(const Duration(minutes: 1));
      final events = await UsageStats.queryEvents(oneMinuteAgo, now);

      if (events.isEmpty) return false;

      // 检查最近的事件
      final lastEvent = events.last;
      return lastEvent.eventType == UsageEvent.resumed;
    } catch (e) {
      return false;
    }
  }

  /// 获取每小时使用分布
  Future<Map<int, int>> getHourlyDistribution() async {
    return await getHourlyDistributionForDate(DateTime.now());
  }

  /// 获取指定日期的每小时分布
  Future<Map<int, int>> getHourlyDistributionForDate(DateTime date) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));

    try {
      final events = await UsageStats.queryEvents(start, end);
      return await _calculateHourlyDistribution(events);
    } catch (e) {
      return {for (var i = 0; i < 24; i++) i: 0};
    }
  }

  /// 获取应用使用历史
  Future<List<Map<String, dynamic>>> getAppUsageHistory(String packageName, int days) async {
    final result = <Map<String, dynamic>>[];
    final now = DateTime.now();

    for (var i = 0; i < days; i++) {
      final date = now.subtract(Duration(days: i));
      final usage = await getUsageForDate(date, detailed: true);

      final app = usage.appUsages.firstWhere(
        (a) => a.packageName == packageName,
        orElse: () => AppUsage.empty(packageName),
      );

      result.add({
        'date': '${date.month}/${date.day}',
        'minutes': app.usageTimeInSeconds ~/ 60,
        'seconds': app.usageTimeInSeconds,
      });
    }

    return result.reversed.toList();
  }

  /// 获取已安装应用列表
  Future<List<InstalledAppInfo>> getInstalledApps() async {
    // 获取今日使用数据中的所有应用
    final usage = await getTodayUsage(detailed: true);

    final apps = <InstalledAppInfo>[];
    for (var appUsage in usage.appUsages) {
      apps.add(InstalledAppInfo(
        packageName: appUsage.packageName,
        appName: appUsage.appName,
        category: appUsage.category,
        isSystemApp: false,
      ));
    }

    return apps;
  }

  /// 计算每小时使用分布
  Future<Map<int, int>> _calculateHourlyDistribution(List<UsageEvent> events) async {
    final hourlyMinutes = <int, int>{for (var i = 0; i < 24; i++) i: 0};

    final sessions = _extractAllSessions(events);
    for (var session in sessions) {
      final hour = session.start.hour;
      final minutes = session.duration.inMinutes;
      if (hourlyMinutes.containsKey(hour)) {
        hourlyMinutes[hour] = hourlyMinutes[hour]! + minutes;
      }
    }

    return hourlyMinutes;
  }

  // ==================== 私有方法 ====================

  /// 解析事件为DailyUsage
  DailyUsage _parseEventsToDailyUsage(
    List<UsageEvent> events,
    DateTime date, {
    required bool detailed,
  }) {
    final appUsageMap = <String, int>{};
    int totalScreenTime = 0;

    // 按应用分组处理事件
    final eventsByPackage = _groupEventsByPackage(events);

    for (var entry in eventsByPackage.entries) {
      final packageName = entry.key;
      final packageEvents = entry.value;

      int appTime = 0;
      DateTime? lastStartTime;

      for (var event in packageEvents) {
        final timestamp = int.tryParse(event.timeStamp ?? '0') ?? 0;
        final eventTime = DateTime.fromMillisecondsSinceEpoch(timestamp);

        if (event.eventType == UsageEvent.resumed) {
          lastStartTime = eventTime;
        } else if (event.eventType == UsageEvent.paused && lastStartTime != null) {
          final duration = eventTime.difference(lastStartTime).inSeconds;
          if (duration > 0 && duration < 3600) { // 过滤异常值（超过1小时的可能是系统事件）
            appTime += duration;
          }
          lastStartTime = null;
        }
      }

      if (appTime > 0) {
        appUsageMap[packageName] = appTime;
        totalScreenTime += appTime;
      }
    }

    // 构建AppUsage列表
    final appUsages = <AppUsage>[];
    if (detailed) {
      for (var entry in appUsageMap.entries) {
        appUsages.add(AppUsage(
          packageName: entry.key,
          appName: _appNameCache[entry.key] ?? entry.key.split('.').last,
          usageTimeInSeconds: entry.value,
          date: date,
        ));
      }
      appUsages.sort((a, b) => b.usageTimeInSeconds.compareTo(a.usageTimeInSeconds));
    }

    return DailyUsage(
      date: date,
      totalScreenTime: totalScreenTime,
      unlockCount: _countUnlocks(events),
      appUsages: appUsages,
    );
  }

  /// 按包名分组事件
  Map<String, List<UsageEvent>> _groupEventsByPackage(List<UsageEvent> events) {
    final map = <String, List<UsageEvent>>{};
    for (var event in events) {
      final package = event.packageName ?? 'unknown';
      map.putIfAbsent(package, () => []);
      map[package]!.add(event);
    }
    return map;
  }

  /// 提取某应用的使用会话
  List<UsageSession> _extractAppSessions(List<UsageEvent> events, String packageName) {
    final sessions = <UsageSession>[];
    final appEvents = events.where((e) => e.packageName == packageName).toList()
      ..sort((a, b) => (a.timeStamp ?? '0').compareTo(b.timeStamp ?? '0'));

    DateTime? currentStart;

    for (var event in appEvents) {
      final timestamp = int.tryParse(event.timeStamp ?? '0') ?? 0;
      final eventTime = DateTime.fromMillisecondsSinceEpoch(timestamp);

      if (event.eventType == UsageEvent.resumed) {
        currentStart = eventTime;
      } else if (event.eventType == UsageEvent.paused && currentStart != null) {
        sessions.add(UsageSession(
          packageName: packageName,
          start: currentStart,
          end: eventTime,
          duration: eventTime.difference(currentStart),
        ));
        currentStart = null;
      }
    }

    return sessions;
  }

  /// 提取所有应用的使用会话
  List<UsageSession> _extractAllSessions(List<UsageEvent> events) {
    final sessions = <UsageSession>[];
    final byPackage = _groupEventsByPackage(events);

    for (var package in byPackage.keys) {
      sessions.addAll(_extractAppSessions(events, package));
    }

    return sessions;
  }

  /// 统计解锁次数（通过检测Keyguard/系统UI事件）
  int _countUnlocks(List<UsageEvent> events) {
    int unlockCount = 0;

    for (var event in events) {
      // 检测系统UI恢复事件作为解锁指示
      if (event.eventType == UsageEvent.resumed &&
          (event.packageName?.contains('systemui') ?? false ||
           event.packageName?.contains('keyguard') ?? false)) {
        unlockCount++;
      }
    }

    // 如果系统UI检测不准确，使用屏幕开启事件作为备选
    if (unlockCount == 0) {
      for (var i = 0; i < events.length - 1; i++) {
        final current = events[i];
        final next = events[i + 1];

        // 检测到应用从停止状态恢复，可能是解锁后使用
        if (current.eventType == UsageEvent.paused &&
            next.eventType == UsageEvent.resumed) {
          final currentTime = int.tryParse(current.timeStamp ?? '0') ?? 0;
          final nextTime = int.tryParse(next.timeStamp ?? '0') ?? 0;
          final gap = nextTime - currentTime;

          // 间隔超过5分钟，认为是新会话（解锁）
          if (gap > 5 * 60 * 1000) {
            unlockCount++;
          }
        }
      }
    }

    return unlockCount.clamp(0, 1000); // 合理性检查
  }

  /// 获取应用名称（带缓存）
  Future<String> _getAppName(String packageName) async {
    if (_appNameCache.containsKey(packageName)) {
      return _appNameCache[packageName]!;
    }

    // 简化处理：提取包名最后部分并格式化
    var name = packageName;
    if (packageName.contains('.')) {
      final parts = packageName.split('.');
      name = parts.last;
    }

    // 首字母大写
    if (name.isNotEmpty) {
      name = name[0].toUpperCase() + name.substring(1);
    }

    _appNameCache[packageName] = name;
    return name;
  }
}

// ==================== 数据模型 ====================

/// 原始使用事件（用于分析）
class RawUsageEvent {
  final String packageName;
  final DateTime start;
  final DateTime end;
  final Duration duration;

  RawUsageEvent({
    required this.packageName,
    required this.start,
    required this.end,
    required this.duration,
  });

  @override
  String toString() => '$packageName: ${duration.inMinutes}min';
}

/// 使用会话
class UsageSession {
  final String packageName;
  final DateTime start;
  final DateTime end;
  final Duration duration;

  UsageSession({
    required this.packageName,
    required this.start,
    required this.end,
    required this.duration,
  });

  String get appName => packageName.split('.').last;
}

/// 连续使用会话
class ContinuousSession {
  final String packageName;
  final String appName;
  final DateTime start;
  final DateTime end;
  final Duration duration;

  ContinuousSession({
    required this.packageName,
    required this.appName,
    required this.start,
    required this.end,
    required this.duration,
  });
}

/// 两日比较
class DayComparison {
  final int todayMinutes;
  final int yesterdayMinutes;
  final int differenceMinutes;
  final int percentageChange;

  DayComparison({
    required this.todayMinutes,
    required this.yesterdayMinutes,
    required this.differenceMinutes,
    required this.percentageChange,
  });

  bool get isBetter => differenceMinutes < 0;
  bool get isWorse => differenceMinutes > 0;
}

/// 已安装应用信息
class InstalledAppInfo {
  final String packageName;
  final String appName;
  final String category;
  final bool isSystemApp;

  InstalledAppInfo({
    required this.packageName,
    required this.appName,
    required this.category,
    required this.isSystemApp,
  });
}
