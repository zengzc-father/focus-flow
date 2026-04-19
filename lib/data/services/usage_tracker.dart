import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'rule_engine.dart';

/// 事件驱动的使用追踪器（优化版）
///
/// 优化点：
/// 1. 无轮询，纯事件驱动
/// 2. 批量存储（减少磁盘写入）
/// 3. 智能提醒时机检测
/// 4. 响应率学习
class UsageTracker extends ChangeNotifier {
  static final UsageTracker _instance = UsageTracker._internal();
  factory UsageTracker() => _instance;
  UsageTracker._internal();

  // 存储键
  static const String _keyTodayTotal = 'today_total_seconds';
  static const String _keyLastDate = 'last_date';
  static const String _keyLastBreak = 'last_break_time';
  static const String _keySessionLog = 'session_log';
  static const String _keyResponseRate = 'response_rate';

  // 批量存储
  final List<SessionData> _pendingSaves = [];
  Timer? _flushTimer;
  static const int _batchSize = 5;
  static const Duration _flushInterval = Duration(seconds: 5);

  // 运行时状态
  DateTime? _screenOnTime;
  int _todayTotalSeconds = 0;
  int _currentSessionSeconds = 0;
  DateTime? _lastBreakTime;
  String? _lastApp; // 上次使用的应用

  // 智能提醒
  final SmartReminder _smartReminder = SmartReminder();
  final UserHabitLearner _habitLearner = UserHabitLearner();

  // Getters
  int get todayTotalSeconds => _todayTotalSeconds;
  int get todayTotalMinutes => _todayTotalSeconds ~/ 60;
  int get currentSessionSeconds => _currentSessionSeconds;
  int get currentSessionMinutes => _currentSessionSeconds ~/ 60;
  int get minutesSinceLastBreak {
    if (_lastBreakTime == null) return 999;
    return DateTime.now().difference(_lastBreakTime!).inMinutes;
  }

  /// 初始化
  Future<void> initialize() async {
    await _loadData();
    debugPrint('📱 UsageTracker 初始化完成');
  }

  /// 加载数据
  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    // 检查是否跨天
    final lastDateStr = prefs.getString(_keyLastDate);
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month}-${today.day}';

    if (lastDateStr != todayStr) {
      _resetDailyData();
      await prefs.setString(_keyLastDate, todayStr);
    } else {
      _todayTotalSeconds = prefs.getInt(_keyTodayTotal) ?? 0;
      final lastBreakStr = prefs.getInt(_keyLastBreak);
      if (lastBreakStr != null) {
        _lastBreakTime = DateTime.fromMillisecondsSinceEpoch(lastBreakStr);
      }
    }
  }

  void _resetDailyData() {
    _todayTotalSeconds = 0;
    _lastBreakTime = null;
  }

  /// 屏幕点亮
  Future<void> onScreenOn() async {
    _screenOnTime = DateTime.now();

    // 检查是否是"休息后首次使用"
    if (minutesSinceLastBreak > 10) {
      _currentSessionSeconds = 0; // 新会话
    }

    debugPrint('📱 屏幕点亮');
    notifyListeners();
  }

  /// 屏幕熄灭
  Future<void> onScreenOff({String? currentApp}) async {
    if (_screenOnTime == null) return;

    final now = DateTime.now();
    final duration = now.difference(_screenOnTime!);
    final seconds = duration.inSeconds;

    // 过滤异常数据（<3秒可能是误触）
    if (seconds < 3) {
      _screenOnTime = null;
      return;
    }

    // 更新统计
    _todayTotalSeconds += seconds;
    _currentSessionSeconds += seconds;

    // 批量存储
    _queueSave(SessionData(
      startTime: _screenOnTime!,
      durationSeconds: seconds,
      appPackage: currentApp,
    ));

    // 检查应用切换（记录最后一个应用）
    if (currentApp != null) {
      _lastApp = currentApp;
    }

    debugPrint('📱 屏幕熄灭: ${seconds}s, 今日累计: ${_todayTotalSeconds ~/ 60}m');

    _screenOnTime = null;
    notifyListeners();
  }

  /// 批量存储队列
  void _queueSave(SessionData data) {
    _pendingSaves.add(data);

    // 达到批量大小，立即刷新
    if (_pendingSaves.length >= _batchSize) {
      _flushPendingSaves();
      return;
    }

    // 设置定时刷新
    _flushTimer?.cancel();
    _flushTimer = Timer(_flushInterval, _flushPendingSaves);
  }

  /// 刷新到存储
  Future<void> _flushPendingSaves() async {
    if (_pendingSaves.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();

    // 只保存今日总计（减少存储）
    await prefs.setInt(_keyTodayTotal, _todayTotalSeconds);

    // 详细日志可选（默认不存，节省空间）
    if (_shouldLogDetails()) {
      final existing = prefs.getStringList(_keySessionLog) ?? [];
      for (final session in _pendingSaves) {
        existing.add('${session.startTime},${session.durationSeconds}');
      }
      // 只保留最近100条
      if (existing.length > 100) {
        existing.removeRange(0, existing.length - 100);
      }
      await prefs.setStringList(_keySessionLog, existing);
    }

    _pendingSaves.clear();
    _flushTimer?.cancel();
  }

  bool _shouldLogDetails() {
    // 仅在调试模式或用户开启详细记录
    return kDebugMode;
  }

  /// 检查是否应该提醒（智能时机）
  ReminderDecision shouldRemind({
    required int continuousLimit,
    required int dailyLimitMinutes,
  }) {
    // 1. 检查阈值
    final continuousExceeded = currentSessionMinutes >= continuousLimit;
    final dailyExceeded = todayTotalMinutes >= dailyLimitMinutes;

    if (!continuousExceeded && !dailyExceeded) {
      return ReminderDecision.dontRemind;
    }

    // 2. 智能时机检测
    if (!_smartReminder.isGoodTiming()) {
      return ReminderDecision.waitBetterTiming;
    }

    // 3. 检查用户响应率（避免无效提醒）
    final rule = continuousExceeded ? 'continuous' : 'daily';
    if (!_habitLearner.shouldRemind(rule)) {
      return ReminderDecision.userIgnoresThis;
    }

    // 4. 确定提醒强度
    final level = _calculateReminderLevel(rule);

    return ReminderDecision.remind(
      level: level,
      message: _generateMessage(continuousExceeded, dailyExceeded),
    );
  }

  /// 计算提醒强度
  ReminderLevel _calculateReminderLevel(String rule) {
    final ignoredCount = _habitLearner.getIgnoredCount(rule);

    if (ignoredCount == 0) return ReminderLevel.subtle;
    if (ignoredCount < 2) return ReminderLevel.normal;
    if (ignoredCount < 4) return ReminderLevel.strong;
    return ReminderLevel.intervention;
  }

  String _generateMessage(bool continuousExceeded, bool dailyExceeded) {
    if (dailyExceeded && continuousExceeded) {
      return '今日使用已超限额，且连续使用较久，建议立即休息';
    }
    if (dailyExceeded) {
      return '今日使用已超限，注意休息';
    }
    return '已连续使用$currentSessionMinutes分钟，起来活动一下吧';
  }

  /// 记录用户对提醒的反应
  Future<void> recordReminderResponse(bool acted) async {
    await _habitLearner.recordResponse(
      currentSessionMinutes >= 45 ? 'continuous' : 'daily',
      acted,
    );
  }

  /// 手动标记休息
  Future<void> markBreak() async {
    _currentSessionSeconds = 0;
    _lastBreakTime = DateTime.now();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLastBreak, _lastBreakTime!.millisecondsSinceEpoch);

    await recordReminderResponse(true);
    notifyListeners();
  }

  /// 更新设置
  Future<void> updateSettings({
    int? continuousLimit,
    int? dailyLimit,
    String? bedtime,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    if (continuousLimit != null) {
      await prefs.setInt('continuous_limit', continuousLimit);
    }
    if (dailyLimit != null) {
      await prefs.setInt('daily_limit', dailyLimit);
    }
    if (bedtime != null) {
      await prefs.setString('bedtime', bedtime);
    }
  }

  /// 获取设置
  Future<TrackerSettings> getSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return TrackerSettings(
      continuousLimitMinutes: prefs.getInt('continuous_limit') ?? 45,
      dailyLimitHours: prefs.getInt('daily_limit') ?? 3,
      bedtime: prefs.getString('bedtime') ?? '22:30',
    );
  }
}

/// 会话数据
class SessionData {
  final DateTime startTime;
  final int durationSeconds;
  final String? appPackage;

  SessionData({
    required this.startTime,
    required this.durationSeconds,
    this.appPackage,
  });
}

/// 提醒决策
class ReminderDecision {
  final bool shouldRemind;
  final ReminderLevel? level;
  final String? message;
  final String reason;

  ReminderDecision._({
    required this.shouldRemind,
    this.level,
    this.message,
    required this.reason,
  });

  static ReminderDecision dontRemind = ReminderDecision._(
    shouldRemind: false,
    reason: '阈值未满足',
  );

  static ReminderDecision waitBetterTiming = ReminderDecision._(
    shouldRemind: false,
    reason: '等待更好时机',
  );

  static ReminderDecision userIgnoresThis = ReminderDecision._(
    shouldRemind: false,
    reason: '用户通常无视此提醒',
  );

  static ReminderDecision remind({
    required ReminderLevel level,
    required String message,
  }) => ReminderDecision._(
    shouldRemind: true,
    level: level,
    message: message,
    reason: '满足所有条件',
  );
}

/// 提醒强度 - 使用 rule_engine.dart 中的定义
// ReminderLevel 已在 rule_engine.dart 中统一定义

/// 智能提醒时机检测
class SmartReminder {
  DateTime? _lastUnlockTime;

  void onUnlock() {
    _lastUnlockTime = DateTime.now();
  }

  bool isGoodTiming() {
    final now = DateTime.now();

    // 1. 刚解锁5秒内（用户刚拿起手机，不要立即打扰）
    if (_lastUnlockTime != null) {
      if (now.difference(_lastUnlockTime!).inSeconds < 5) {
        return false;
      }
    }

    // 2. 深夜（22:00-07:00）且非紧急
    final hour = now.hour;
    if (hour >= 22 || hour < 7) {
      // 深夜可以降低提醒频率
      return now.minute % 10 == 0; // 只在整10分钟提醒
    }

    // 3. 整点或半点（心理时间边界，用户更容易接受）
    if (now.minute == 0 || now.minute == 30) {
      return true;
    }

    return true;
  }
}

/// 用户习惯学习
class UserHabitLearner {
  // 响应率记录
  Map<String, double> _responseRates = {};
  Map<String, int> _ignoredCounts = {};

  Future<void> recordResponse(String rule, bool acted) async {
    final prefs = await SharedPreferences.getInstance();

    // 读取历史
    final key = 'response_$rule';
    final history = prefs.getStringList(key) ?? [];

    // 添加新记录（保留最近20次）
    history.add(acted ? '1' : '0');
    if (history.length > 20) {
      history.removeAt(0);
    }
    await prefs.setStringList(key, history);

    // 计算响应率
    final actedCount = history.where((h) => h == '1').length;
    _responseRates[rule] = actedCount / history.length;

    // 记录连续忽略次数
    if (!acted) {
      _ignoredCounts[rule] = (_ignoredCounts[rule] ?? 0) + 1;
    } else {
      _ignoredCounts[rule] = 0;
    }
  }

  bool shouldRemind(String rule) {
    final rate = _responseRates[rule] ?? 0.5;

    // 响应率低于10%，暂停此规则提醒
    if (rate < 0.1) {
      return false;
    }

    return true;
  }

  int getIgnoredCount(String rule) {
    return _ignoredCounts[rule] ?? 0;
  }
}

class TrackerSettings {
  final int continuousLimitMinutes;
  final int dailyLimitHours;
  final String bedtime;

  TrackerSettings({
    required this.continuousLimitMinutes,
    required this.dailyLimitHours,
    required this.bedtime,
  });
}
