import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 专注会话数据模型
/// 极简设计：专注时长、任务名称、完成状态
class FocusSession {
  final String id;
  final String taskName;
  final DateTime startTime;
  final DateTime? endTime;
  final int durationMinutes;
  final int actualMinutes;
  final FocusSessionStatus status;
  final bool isCompleted;
  final String? tag;

  FocusSession({
    required this.id,
    required this.taskName,
    required this.startTime,
    this.endTime,
    required this.durationMinutes,
    this.actualMinutes = 0,
    this.status = FocusSessionStatus.active,
    this.isCompleted = false,
    this.tag,
  });

  factory FocusSession.start({
    required String taskName,
    int durationMinutes = 25,
    String? tag,
  }) {
    return FocusSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      taskName: taskName,
      startTime: DateTime.now(),
      durationMinutes: durationMinutes,
      tag: tag,
    );
  }

  FocusSession copyWith({
    DateTime? endTime,
    int? actualMinutes,
    FocusSessionStatus? status,
    bool? isCompleted,
  }) {
    return FocusSession(
      id: id,
      taskName: taskName,
      startTime: startTime,
      endTime: endTime ?? this.endTime,
      durationMinutes: durationMinutes,
      actualMinutes: actualMinutes ?? this.actualMinutes,
      status: status ?? this.status,
      isCompleted: isCompleted ?? this.isCompleted,
      tag: tag,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'taskName': taskName,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime?.toIso8601String(),
        'durationMinutes': durationMinutes,
        'actualMinutes': actualMinutes,
        'status': status.index,
        'isCompleted': isCompleted,
        'tag': tag,
      };

  factory FocusSession.fromJson(Map<String, dynamic> json) => FocusSession(
        id: json['id'] ?? '',
        taskName: json['taskName'] ?? '',
        startTime: DateTime.parse(json['startTime']),
        endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
        durationMinutes: json['durationMinutes'] ?? 25,
        actualMinutes: json['actualMinutes'] ?? 0,
        status: FocusSessionStatus.values[json['status'] ?? 0],
        isCompleted: json['isCompleted'] ?? false,
        tag: json['tag'],
      );

  /// 获取剩余秒数
  int get remainingSeconds {
    if (endTime != null) return 0;
    final elapsed = DateTime.now().difference(startTime).inSeconds;
    return (durationMinutes * 60 - elapsed).clamp(0, durationMinutes * 60);
  }

  /// 获取进度（0.0 - 1.0）
  double get progress {
    if (endTime != null) return 1.0;
    final elapsed = DateTime.now().difference(startTime).inSeconds;
    return (elapsed / (durationMinutes * 60)).clamp(0.0, 1.0);
  }
}

enum FocusSessionStatus {
  active,
  paused,
  completed,
  cancelled,
}

/// 番茄钟设置
class PomodoroSettings {
  int focusDurationMinutes;
  int shortBreakMinutes;
  int longBreakMinutes;
  bool strictMode;

  PomodoroSettings({
    this.focusDurationMinutes = 25,
    this.shortBreakMinutes = 5,
    this.longBreakMinutes = 15,
    this.strictMode = false,
  });

  Map<String, dynamic> toJson() => {
        'focusDurationMinutes': focusDurationMinutes,
        'shortBreakMinutes': shortBreakMinutes,
        'longBreakMinutes': longBreakMinutes,
        'strictMode': strictMode,
      };

  factory PomodoroSettings.fromJson(Map<String, dynamic> json) => PomodoroSettings(
        focusDurationMinutes: json['focusDurationMinutes'] ?? 25,
        shortBreakMinutes: json['shortBreakMinutes'] ?? 5,
        longBreakMinutes: json['longBreakMinutes'] ?? 15,
        strictMode: json['strictMode'] ?? false,
      );
}

/// 专注模式管理器
class FocusModeManager {
  static final FocusModeManager _instance = FocusModeManager._internal();
  factory FocusModeManager() => _instance;
  FocusModeManager._internal();

  FocusSession? _currentSession;
  PomodoroSettings _settings = PomodoroSettings();

  final _sessionController = StreamController<FocusSession?>.broadcast();
  Stream<FocusSession?> get sessionStream => _sessionController.stream;

  FocusSession? get currentSession => _currentSession;
  PomodoroSettings get settings => _settings;

  /// 初始化
  Future<void> initialize() async {
    await _loadSettings();
    debugPrint('🍅 FocusModeManager 初始化完成');
  }

  /// 开始专注
  Future<FocusSession> startFocus({
    required String taskName,
    int? durationMinutes,
  }) async {
    final session = FocusSession.start(
      taskName: taskName,
      durationMinutes: durationMinutes ?? _settings.focusDurationMinutes,
    );

    _currentSession = session;
    _sessionController.add(session);
    await _saveSession(session);

    debugPrint('🍅 开始专注: $taskName (${session.durationMinutes}分钟)');
    return session;
  }

  /// 完成专注
  Future<void> completeFocus() async {
    if (_currentSession == null) return;

    final completedSession = _currentSession!.copyWith(
      endTime: DateTime.now(),
      status: FocusSessionStatus.completed,
      isCompleted: true,
      actualMinutes: DateTime.now()
          .difference(_currentSession!.startTime)
          .inMinutes,
    );

    await _saveSession(completedSession);
    await _saveToHistory(completedSession);

    _currentSession = null;
    _sessionController.add(null);

    debugPrint('✅ 专注完成: ${completedSession.taskName}');
  }

  /// 取消专注
  Future<void> cancelFocus() async {
    if (_currentSession == null) return;
    if (_settings.strictMode) {
      throw Exception('严格模式下无法取消专注');
    }

    final cancelledSession = _currentSession!.copyWith(
      endTime: DateTime.now(),
      status: FocusSessionStatus.cancelled,
      actualMinutes: DateTime.now()
          .difference(_currentSession!.startTime)
          .inMinutes,
    );

    await _saveSession(cancelledSession);

    _currentSession = null;
    _sessionController.add(null);

    debugPrint('❌ 专注取消');
  }

  /// 更新设置
  Future<void> updateSettings(PomodoroSettings newSettings) async {
    _settings = newSettings;
    await _saveSettings();
  }

  /// 获取今日专注总时长（分钟）
  Future<int> getTodayFocusMinutes() async {
    final history = await _loadHistory();
    final today = DateTime.now();
    return history
        .where((s) =>
            s.isCompleted &&
            s.startTime.year == today.year &&
            s.startTime.month == today.month &&
            s.startTime.day == today.day)
        .fold(0, (sum, s) => sum + s.actualMinutes);
  }

  // 持久化方法
  Future<void> _saveSession(FocusSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_focus_session', jsonEncode(session.toJson()));
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pomodoro_settings', jsonEncode(_settings.toJson()));
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final settingsJson = prefs.getString('pomodoro_settings');
    if (settingsJson != null) {
      _settings = PomodoroSettings.fromJson(jsonDecode(settingsJson));
    }
  }

  Future<void> _saveToHistory(FocusSession session) async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getStringList('focus_history') ?? [];
    historyJson.add(jsonEncode(session.toJson()));
    // 只保留最近100条
    if (historyJson.length > 100) {
      historyJson.removeAt(0);
    }
    await prefs.setStringList('focus_history', historyJson);
  }

  Future<List<FocusSession>> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getStringList('focus_history') ?? [];
    return historyJson.map((j) => FocusSession.fromJson(jsonDecode(j))).toList();
  }

  void dispose() {
    _sessionController.close();
  }
}
