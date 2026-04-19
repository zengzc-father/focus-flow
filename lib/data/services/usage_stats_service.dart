import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:usage_stats/usage_stats.dart';
import 'package:focus_flow/data/models/app_usage.dart';

class UsageStatsService {
  static final UsageStatsService _instance = UsageStatsService._internal();
  factory UsageStatsService() => _instance;
  UsageStatsService._internal();

  Timer? _usageTimer;
  final StreamController<DailyUsage> _usageStreamController =
      StreamController<DailyUsage>.broadcast();

  Stream<DailyUsage> get usageStream => _usageStreamController.stream;

  // 检查是否有权限
  Future<bool> checkUsageStatsPermission() async {
    try {
      return await UsageStats.checkUsagePermission() ?? false;
    } catch (e) {
      debugPrint('检查权限错误: $e');
      return false;
    }
  }

  // 请求权限（需要跳转到系统设置）
  Future<void> requestUsageStatsPermission() async {
    await UsageStats.grantUsagePermission();
  }

  // 获取今天的应用使用统计
  Future<DailyUsage> getTodayUsage() async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);

      // 查询今天的使用事件
      final events = await UsageStats.queryEvents(startOfDay, now);

      // 按应用分组统计
      final Map<String, List<UsageEvent>> eventsByPackage = {};
      for (var event in events) {
        final package = event.packageName ?? 'unknown';
        eventsByPackage.putIfAbsent(package, () => []);
        eventsByPackage[package]!.add(event);
      }

      // 计算每个应用的使用时间
      final List<AppUsage> appUsages = [];
      int totalScreenTime = 0;

      for (var entry in eventsByPackage.entries) {
        final package = entry.key;
        final eventList = entry.value;

        int usageTime = 0;
        DateTime? lastStartTime;

        for (var event in eventList) {
          if (event.eventType == UsageEvent.resumed) {
            lastStartTime = DateTime.fromMillisecondsSinceEpoch(
              int.parse(event.timeStamp ?? '0'),
            );
          } else if (event.eventType == UsageEvent.paused && lastStartTime != null) {
            final endTime = DateTime.fromMillisecondsSinceEpoch(
              int.parse(event.timeStamp ?? '0'),
            );
            usageTime += endTime.difference(lastStartTime).inSeconds;
            lastStartTime = null;
          }
        }

        if (usageTime > 0) {
          appUsages.add(AppUsage(
            packageName: package,
            appName: await _getAppName(package),
            usageTimeInSeconds: usageTime,
            date: now,
            category: _categorizeApp(package),
          ));
          totalScreenTime += usageTime;
        }
      }

      // 按使用时间排序
      appUsages.sort((a, b) => b.usageTimeInSeconds.compareTo(a.usageTimeInSeconds));

      return DailyUsage(
        date: now,
        totalScreenTime: totalScreenTime,
        unlockCount: await _getUnlockCount(startOfDay, now),
        appUsages: appUsages,
      );
    } catch (e) {
      debugPrint('获取使用统计错误: $e');
      return DailyUsage(
        date: DateTime.now(),
        totalScreenTime: 0,
        unlockCount: 0,
        appUsages: [],
      );
    }
  }

  // 获取应用名称
  Future<String> _getAppName(String packageName) async {
    // 这里可以通过 PackageManager 获取应用名称
    // 简化处理，直接返回包名最后部分
    if (packageName.contains('.')) {
      final parts = packageName.split('.');
      return parts.last.substring(0, 1).toUpperCase() + parts.last.substring(1);
    }
    return packageName;
  }

  // 应用分类
  String _categorizeApp(String packageName) {
    final lower = packageName.toLowerCase();
    if (lower.contains('com.tencent.mm') ||
        lower.contains('wechat') ||
        lower.contains('qq') ||
        lower.contains('weibo')) {
      return '社交';
    } else if (lower.contains('douyin') ||
        lower.contains('tiktok') ||
        lower.contains('bilibili') ||
        lower.contains('video')) {
      return '娱乐';
    } else if (lower.contains('game')) {
      return '游戏';
    } else if (lower.contains('edu') ||
        lower.contains('study') ||
        lower.contains('learn')) {
      return '学习';
    } else if (lower.contains('browser') ||
        lower.contains('chrome')) {
      return '浏览';
    }
    return '其他';
  }

  // 获取解锁次数
  Future<int> _getUnlockCount(DateTime start, DateTime end) async {
    try {
      final events = await UsageStats.queryEvents(start, end);
      int unlockCount = 0;
      for (var event in events) {
        if (event.eventType == UsageEvent.resumed &&
            event.packageName == 'android.systemui') {
          unlockCount++;
        }
      }
      return unlockCount;
    } catch (e) {
      return 0;
    }
  }

  // 开始监控
  void startMonitoring({Duration interval = const Duration(minutes: 1)}) {
    _usageTimer?.cancel();
    _usageTimer = Timer.periodic(interval, (_) async {
      final usage = await getTodayUsage();
      _usageStreamController.add(usage);
    });
  }

  // 停止监控
  void stopMonitoring() {
    _usageTimer?.cancel();
    _usageTimer = null;
  }

  // 获取本周使用趋势
  Future<List<DailyUsage>> getWeeklyUsage() async {
    final List<DailyUsage> weekly = [];
    final now = DateTime.now();

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      try {
        final events = await UsageStats.queryEvents(startOfDay, endOfDay);
        int totalTime = 0;
        int unlockCount = 0;

        for (var event in events) {
          if (event.eventType == UsageEvent.paused &&
              event.timeStamp != null) {
            totalTime += 1; // 简化计算
          }
          if (event.eventType == UsageEvent.resumed &&
              event.packageName == 'android.systemui') {
            unlockCount++;
          }
        }

        weekly.add(DailyUsage(
          date: date,
          totalScreenTime: totalTime,
          unlockCount: unlockCount,
          appUsages: [],
        ));
      } catch (e) {
        weekly.add(DailyUsage(
          date: date,
          totalScreenTime: 0,
          unlockCount: 0,
          appUsages: [],
        ));
      }
    }

    return weekly;
  }

  void dispose() {
    stopMonitoring();
    _usageStreamController.close();
  }
}
