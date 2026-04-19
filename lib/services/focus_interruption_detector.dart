import 'dart:async';
import 'package:flutter/material.dart';
import '../data/services/system_usage_provider.dart';
import '../data/services/notification_service.dart';

/// 专注模式打断检测器
///
/// 在专注期间监控手机使用情况
/// - 检测用户是否离开专注页面
/// - 记录打断次数和使用的应用
/// - 在严重打断时发送提醒
class FocusInterruptionDetector {
  static final FocusInterruptionDetector _instance = FocusInterruptionDetector._internal();
  factory FocusInterruptionDetector() => _instance;
  FocusInterruptionDetector._internal();

  bool _isMonitoring = false;
  Timer? _checkTimer;
  String? _currentAppPackage;
  int _interruptionCount = 0;
  final Map<String, int> _interruptionDurations = {}; // 应用 -> 打断时长（秒）
  DateTime? _interruptionStart;
  String? _interruptedApp;

  // 监控间隔
  static const _checkInterval = Duration(seconds: 5);

  // 打断阈值：离开专注超过多少秒算作一次打断
  static const _interruptionThreshold = Duration(seconds: 10);

  /// 开始监控专注期间的打断
  Future<void> startMonitoring() async {
    if (_isMonitoring) return;

    _isMonitoring = true;
    _interruptionCount = 0;
    _interruptionDurations.clear();
    _interruptionStart = null;
    _interruptedApp = null;

    debugPrint('🔍 开始检测专注打断...');

    // 定期检测当前应用
    _checkTimer = Timer.periodic(_checkInterval, (_) async {
      await _checkCurrentApp();
    });

    // 立即检查一次
    await _checkCurrentApp();
  }

  /// 停止监控
  void stopMonitoring() {
    _isMonitoring = false;
    _checkTimer?.cancel();

    // 如果还有未结束的打断，记录它
    if (_interruptionStart != null && _interruptedApp != null) {
      final duration = DateTime.now().difference(_interruptionStart!).inSeconds;
      _recordInterruption(_interruptedApp!, duration);
    }

    debugPrint('🛑 停止检测专注打断');
    debugPrint('   总打断次数: $_interruptionCount');
    debugPrint('   打断详情: $_interruptionDurations');
  }

  /// 获取打断统计
  FocusInterruptionReport getReport() {
    return FocusInterruptionReport(
      totalInterruptions: _interruptionCount,
      interruptionsByApp: Map.from(_interruptionDurations),
      totalInterruptionSeconds: _interruptionDurations.values.fold(0, (a, b) => a + b),
    );
  }

  /// 重置统计
  void reset() {
    _interruptionCount = 0;
    _interruptionDurations.clear();
    _interruptionStart = null;
    _interruptedApp = null;
  }

  Future<void> _checkCurrentApp() async {
    if (!_isMonitoring) return;

    try {
      final currentApp = await SystemUsageProvider().getCurrentApp();

      // Focus Flow 的包名
      const focusFlowPackage = 'com.focusflow.app';

      if (currentApp == null) {
        // 无法获取当前应用，可能是系统应用或权限问题
        return;
      }

      if (currentApp == focusFlowPackage || currentApp.contains('focusflow')) {
        // 用户正在专注页面
        _handleBackToFocus();
      } else {
        // 用户离开了专注页面
        _handleLeftFocus(currentApp);
      }
    } catch (e) {
      debugPrint('检测当前应用失败: $e');
    }
  }

  void _handleLeftFocus(String appPackage) {
    if (_interruptionStart == null) {
      // 开始记录打断
      _interruptionStart = DateTime.now();
      _interruptedApp = appPackage;
      debugPrint('⚠️ 离开专注页面: $appPackage');
    } else {
      // 继续在其他应用
      final duration = DateTime.now().difference(_interruptionStart!).inSeconds;

      // 如果打断时间超过阈值，算作一次正式打断
      if (duration >= _interruptionThreshold.inSeconds) {
        // 可以在这里发送提醒
        if (_interruptionCount == 0) {
          _sendFirstInterruptionReminder(appPackage);
        } else if (_interruptionCount >= 2) {
          _sendMultipleInterruptionReminder(appPackage);
        }
      }
    }
  }

  void _handleBackToFocus() {
    if (_interruptionStart != null && _interruptedApp != null) {
      final duration = DateTime.now().difference(_interruptionStart!).inSeconds;

      if (duration >= _interruptionThreshold.inSeconds) {
        // 算作一次正式打断
        _recordInterruption(_interruptedApp!, duration);
        debugPrint('✅ 回到专注，记录打断: $_interruptedApp (${duration}s)');
      } else {
        // 只是短暂离开，不算打断
        debugPrint('↩️ 短暂离开，不计入打断');
      }

      _interruptionStart = null;
      _interruptedApp = null;
    }
  }

  void _recordInterruption(String appPackage, int seconds) {
    _interruptionCount++;
    _interruptionDurations[appPackage] =
        (_interruptionDurations[appPackage] ?? 0) + seconds;
  }

  void _sendFirstInterruptionReminder(String appPackage) {
    // 第一次打断，温和提醒
    NotificationService().showNotification(
      title: '🍅 专注被打断',
      body: '你似乎离开了专注页面，需要回来继续吗？',
    );
  }

  void _sendMultipleInterruptionReminder(String appPackage) {
    // 多次打断，加强提醒
    NotificationService().showNotification(
      title: '⚠️ 频繁打断',
      body: '已经第$_interruptionCount次打断专注了，坚持就是胜利！',
    );
  }
}

/// 专注打断报告
class FocusInterruptionReport {
  final int totalInterruptions;
  final Map<String, int> interruptionsByApp;
  final int totalInterruptionSeconds;

  FocusInterruptionReport({
    required this.totalInterruptions,
    required this.interruptionsByApp,
    required this.totalInterruptionSeconds,
  });

  String get summary {
    if (totalInterruptions == 0) {
      return '🎉 完美专注！没有被任何事情打断';
    }

    final minutes = totalInterruptionSeconds ~/ 60;
    final seconds = totalInterruptionSeconds % 60;
    var text = '被打断 $totalInterruptions 次';
    if (minutes > 0) {
      text += '，共计 ${minutes}分${seconds}秒';
    } else {
      text += '，共计 ${seconds}秒';
    }

    if (interruptionsByApp.isNotEmpty) {
      text += '\n\n打扰最多的应用：';
      final sorted = interruptionsByApp.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      for (var i = 0; i < sorted.length && i < 3; i++) {
        final appName = sorted[i].key.split('.').last;
        final dur = sorted[i].value;
        text += '\n• $appName: ${dur ~/ 60}分${dur % 60}秒';
      }
    }

    return text;
  }
}
