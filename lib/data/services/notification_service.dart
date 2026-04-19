import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:focus_flow/data/services/rule_engine.dart';
import 'package:focus_flow/data/services/notification_action_handler.dart';

/// 优化的通知服务
/// 支持渐进式提醒和交互按钮
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  /// 初始化
  Future<void> initialize() async {
    if (_isInitialized) return;

    const androidSettings = AndroidInitializationSettings('ic_launcher');
    const iosSettings = DarwinInitializationSettings();

    await _notifications.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    // 创建通知渠道
    await _createNotificationChannels();

    _isInitialized = true;
  }

  /// 创建通知渠道（Android 8.0+）
  Future<void> _createNotificationChannels() async {
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin == null) return;

    // 静默提醒渠道
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        'quiet_reminder',
        '静默提醒',
        description: '不打扰的弱提醒',
        importance: Importance.min,
        playSound: false,
        enableVibration: false,
        showBadge: false,
      ),
    );

    // 标准提醒渠道
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        'normal_reminder',
        '标准提醒',
        description: '普通的休息提醒',
        importance: Importance.defaultImportance,
        playSound: true,
        enableVibration: true,
      ),
    );

    // 强力提醒渠道
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        'strong_reminder',
        '强力提醒',
        description: '需要立即注意的提醒',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
    );
  }

  /// 静默通知（仅更新通知栏，不弹出）
  Future<void> showQuietNotification({
    required String title,
    required String body,
  }) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'quiet_reminder',
        '静默提醒',
        importance: Importance.min,
        priority: Priority.min,
        playSound: false,
        enableVibration: false,
        ongoing: true,
        autoCancel: false,
      ),
    );

    await _notifications.show(
      1000, // 固定ID，会更新同一通知
      title,
      body,
      details,
    );
  }

  /// 标准通知（带动作按钮）
  Future<void> showNotification({
    required String title,
    required String body,
    List<NotificationAction>? actions,
  }) async {
    final androidActions = <AndroidNotificationAction>[];

    if (actions != null) {
      for (var i = 0; i < actions.length; i++) {
        androidActions.add(
          AndroidNotificationAction(
            'action_$i',
            actions[i].title,
          ),
        );
      }
    }

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'normal_reminder',
        '标准提醒',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        actions: androidActions,
        autoCancel: true,
      ),
    );

    await _notifications.show(
      DateTime.now().millisecond,
      title,
      body,
      details,
      payload: actions?.map((a) => a.title).join(','),
    );
  }

  /// 弹窗提醒（Alert）
  Future<void> showAlert({
    required String title,
    required String body,
  }) async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'strong_reminder',
        '强力提醒',
        importance: Importance.high,
        priority: Priority.high,
        fullScreenIntent: true,
        category: AndroidNotificationCategory.alarm,
      ),
    );

    await _notifications.show(
      DateTime.now().millisecond,
      title,
      body,
      details,
    );
  }

  /// 全屏提醒（强制干预）
  Future<void> showFullScreenReminder({
    required String title,
    required String body,
  }) async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'strong_reminder',
        '强力提醒',
        importance: Importance.max,
        priority: Priority.max,
        fullScreenIntent: true,
        category: AndroidNotificationCategory.alarm,
      ),
    );

    await _notifications.show(
      DateTime.now().millisecond,
      title,
      body,
      details,
    );
  }

  /// 高优先级通知（规则触发）
  Future<void> showHighPriorityNotification({
    required String title,
    required String message,
  }) async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'strong_reminder',
        '强力提醒',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
      ),
    );

    await _notifications.show(
      DateTime.now().millisecond,
      title,
      message,
      details,
    );
  }

  /// 规则触发通知
  Future<void> showRuleTriggeredNotification({
    required String title,
    required String message,
    required String ruleId,
    List<String>? actions,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'normal_reminder',
      '标准提醒',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      actions: actions?.map((a) => AndroidNotificationAction(
        'action_${a.hashCode}',
        a,
      )).toList(),
    );

    final details = NotificationDetails(android: androidDetails);

    await _notifications.show(
      ruleId.hashCode,
      title,
      message,
      details,
    );
  }

  /// 专注模式干预通知
  Future<void> showInterventionNotification({
    required String title,
    required String message,
    NotificationImportance importance = NotificationImportance.normal,
  }) async {
    AndroidNotificationDetails androidDetails;

    switch (importance) {
      case NotificationImportance.high:
        androidDetails = const AndroidNotificationDetails(
          'strong_reminder',
          '强力提醒',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
        );
        break;
      case NotificationImportance.low:
        androidDetails = const AndroidNotificationDetails(
          'quiet_reminder',
          '静默提醒',
          importance: Importance.low,
          priority: Priority.low,
          playSound: false,
          enableVibration: false,
        );
        break;
      default:
        androidDetails = const AndroidNotificationDetails(
          'normal_reminder',
          '标准提醒',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        );
    }

    final details = NotificationDetails(android: androidDetails);

    await _notifications.show(
      DateTime.now().millisecond,
      title,
      message,
      details,
    );
  }
}

/// 通知重要性级别
enum NotificationImportance {
  low,
  normal,
  high,
}

/// 提醒级别（渐进式干预）
enum ReminderLevel {
  subtle, // L1: 轻微提示（静默通知栏）
  normal, // L2: 温和打断（弹窗+声音）
  strong, // L3: 强力提醒（全屏覆盖）
  intervention, // L4: 强制干预（配合锁屏）
}

/// 通知调度器 - 防止通知疲劳
class NotificationScheduler {
  static final NotificationScheduler _instance = NotificationScheduler._internal();
  factory NotificationScheduler() => _instance;
  NotificationScheduler._internal();

  // 各类型通知的最后发送时间
  final Map<String, DateTime> _lastSentTime = {};

  // 冷却时间配置
  final Map<String, Duration> _cooldownDurations = {
    'health_eye': const Duration(minutes: 20), // 护眼提醒间隔
    'health_posture': const Duration(minutes: 30), // 姿势提醒间隔
    'focus_break': const Duration(minutes: 15), // 专注休息提醒间隔
    'continuous_use': const Duration(minutes: 30), // 连续使用提醒间隔
    'agent_suggestion': const Duration(minutes: 60), // Agent建议间隔
  };

  // 每日最大次数
  final Map<String, int> _dailyLimits = {
    'health_eye': 10,
    'health_posture': 8,
    'focus_break': 12,
    'continuous_use': 8,
    'agent_suggestion': 5,
  };

  // 今日发送计数
  final Map<String, int> _dailyCounts = {};

  /// 检查是否可以发送通知
  bool canSend(String type) {
    final now = DateTime.now();

    // 检查冷却时间
    final lastSent = _lastSentTime[type];
    if (lastSent != null) {
      final cooldown = _cooldownDurations[type] ?? const Duration(minutes: 30);
      if (now.difference(lastSent) < cooldown) {
        return false;
      }
    }

    // 检查每日限制
    final dailyLimit = _dailyLimits[type] ?? 10;
    final todayCount = _dailyCounts[type] ?? 0;
    if (todayCount >= dailyLimit) {
      return false;
    }

    // 检查夜间免打扰 (23:00 - 08:00)
    final hour = now.hour;
    if (hour >= 23 || hour < 8) {
      // 只有健康类提醒可以在夜间发送
      if (!type.startsWith('health_')) {
        return false;
      }
    }

    return true;
  }

  /// 记录通知已发送
  void recordSent(String type) {
    _lastSentTime[type] = DateTime.now();
    _dailyCounts[type] = (_dailyCounts[type] ?? 0) + 1;
  }

  /// 重置每日计数（应在每天0点调用）
  void resetDailyCounts() {
    _dailyCounts.clear();
  }

  /// 获取剩余可发送次数
  int getRemainingCount(String type) {
    final dailyLimit = _dailyLimits[type] ?? 10;
    final todayCount = _dailyCounts[type] ?? 0;
    return (dailyLimit - todayCount).clamp(0, dailyLimit);
  }
}

/// 增强的通知服务
class EnhancedNotificationService {
  static final EnhancedNotificationService _instance = EnhancedNotificationService._internal();
  factory EnhancedNotificationService() => _instance;
  EnhancedNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  final NotificationScheduler _scheduler = NotificationScheduler();

  bool _isInitialized = false;

  /// 初始化
  Future<void> initialize() async {
    if (_isInitialized) return;

    const androidSettings = AndroidInitializationSettings('ic_launcher');
    const iosSettings = DarwinInitializationSettings();

    await _notifications.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: _onNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: _onBackgroundNotificationResponse,
    );

    await _createNotificationChannels();

    _isInitialized = true;
    debugPrint('🔔 EnhancedNotificationService 初始化完成');
  }

  /// 创建通知渠道
  Future<void> _createNotificationChannels() async {
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin == null) return;

    // 创建所有需要的渠道
    final channels = [
      const AndroidNotificationChannel(
        'health_reminders',
        '健康提醒',
        description: '护眼、姿势等健康相关提醒',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
      const AndroidNotificationChannel(
        'focus_reminders',
        '专注提醒',
        description: '专注模式和休息提醒',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
      const AndroidNotificationChannel(
        'agent_messages',
        'Agent消息',
        description: 'AI助手主动推送的消息',
        importance: Importance.defaultImportance,
        playSound: true,
      ),
      const AndroidNotificationChannel(
        'silent_status',
        '静默状态',
        description: '静默显示当前状态',
        importance: Importance.min,
        playSound: false,
        enableVibration: false,
        showBadge: false,
      ),
      const AndroidNotificationChannel(
        'intervention',
        '强制干预',
        description: '需要立即注意的重要提醒',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        fullScreenIntent: true,
      ),
      const AndroidNotificationChannel(
        'focus_mode_foreground',
        '专注模式前台服务',
        description: '专注模式持续运行通知',
        importance: Importance.low,
        playSound: false,
        enableVibration: false,
        showBadge: false,
      ),
    ];

    for (final channel in channels) {
      await androidPlugin.createNotificationChannel(channel);
    }
  }

  // ========== 专注模式相关通知 ==========

  /// 显示专注模式前台服务通知
  Future<void> showFocusModeNotification({
    required String taskName,
    required int remainingMinutes,
  }) async {
    final details = const NotificationDetails(
      android: AndroidNotificationDetails(
        'focus_mode_foreground',
        '专注模式前台服务',
        importance: Importance.low,
        priority: Priority.low,
        ongoing: true,
        autoCancel: false,
        showProgress: true,
        maxProgress: 100,
        onlyAlertOnce: true,
      ),
    );

    await _notifications.show(
      9999, // 固定ID，用于更新
      '专注中: $taskName',
      '剩余 $remainingMinutes 分钟',
      details,
    );
  }

  /// 专注完成通知
  Future<void> showFocusCompleted({
    required String taskName,
    required int durationMinutes,
  }) async {
    final details = const NotificationDetails(
      android: AndroidNotificationDetails(
        'focus_reminders',
        '专注提醒',
        importance: Importance.high,
        priority: Priority.high,
        actions: [
          AndroidNotificationAction(
            'start_break',
            '开始休息',
            showsUserInterface: true,
          ),
          AndroidNotificationAction(
            'skip_break',
            '跳过',
          ),
        ],
      ),
    );

    await _notifications.show(
      DateTime.now().millisecond,
      '🎉 专注完成！',
      '你完成了 "$taskName"，专注了 $durationMinutes 分钟',
      details,
      payload: 'focus_completed',
    );
  }

  /// 专注被打断提醒
  Future<void> showFocusInterrupted() async {
    final details = const NotificationDetails(
      android: AndroidNotificationDetails(
        'focus_reminders',
        '专注提醒',
        importance: Importance.high,
        priority: Priority.high,
        actions: [
          AndroidNotificationAction(
            'resume_focus',
            '回到专注',
            showsUserInterface: true,
          ),
          AndroidNotificationAction(
            'cancel_focus',
            '放弃',
          ),
        ],
      ),
    );

    await _notifications.show(
      DateTime.now().millisecond,
      '⚠️ 专注被打断',
      '你似乎离开了专注页面，需要回来继续吗？',
      details,
      payload: 'focus_interrupted',
    );
  }

  // ========== 健康提醒 ==========

  /// 20-20-20 护眼提醒
  Future<void> showEyeRestReminder() async {
    if (!_scheduler.canSend('health_eye')) return;

    final details = const NotificationDetails(
      android: AndroidNotificationDetails(
        'health_reminders',
        '健康提醒',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        actions: [
          AndroidNotificationAction(
            'eye_rest_done',
            '已完成',
          ),
        ],
      ),
    );

    await _notifications.show(
      DateTime.now().millisecond,
      '👀 护眼时间',
      '你已经看了20分钟屏幕，向20英尺外看20秒放松眼睛吧',
      details,
      payload: 'eye_rest',
    );

    _scheduler.recordSent('health_eye');
  }

  /// 姿势提醒
  Future<void> showPostureReminder() async {
    if (!_scheduler.canSend('health_posture')) return;

    final details = const NotificationDetails(
      android: AndroidNotificationDetails(
        'health_reminders',
        '健康提醒',
        importance: Importance.defaultImportance,
        actions: [
          AndroidNotificationAction(
            'posture_fixed',
            '已调整',
          ),
        ],
      ),
    );

    await _notifications.show(
      DateTime.now().millisecond,
      '🧘 调整姿势',
      '坐久了，起来活动一下，调整坐姿',
      details,
      payload: 'posture',
    );

    _scheduler.recordSent('health_posture');
  }

  // ========== 连续使用提醒 ==========

  /// 连续使用提醒（渐进式）
  Future<void> showContinuousUseReminder({
    required int minutes,
    ReminderLevel level = ReminderLevel.normal,
  }) async {
    if (!_scheduler.canSend('continuous_use')) return;

    switch (level) {
      case ReminderLevel.subtle:
        await _showSubtleReminder(minutes);
        break;
      case ReminderLevel.normal:
        await _showNormalReminder(minutes);
        break;
      case ReminderLevel.strong:
        await _showStrongReminder(minutes);
        break;
      case ReminderLevel.intervention:
        await _showInterventionReminder(minutes);
        break;
    }

    _scheduler.recordSent('continuous_use');
  }

  Future<void> _showSubtleReminder(int minutes) async {
    final details = const NotificationDetails(
      android: AndroidNotificationDetails(
        'silent_status',
        '静默状态',
        importance: Importance.min,
        priority: Priority.min,
        ongoing: true,
        autoCancel: false,
      ),
    );

    await _notifications.show(
      1000, // 固定ID用于更新
      'Focus Flow',
      '已连续使用 $minutes 分钟',
      details,
    );
  }

  Future<void> _showNormalReminder(int minutes) async {
    final details = const NotificationDetails(
      android: AndroidNotificationDetails(
        'focus_reminders',
        '专注提醒',
        importance: Importance.defaultImportance,
        actions: [
          AndroidNotificationAction(
            'take_break',
            '休息一下',
            showsUserInterface: true,
          ),
          AndroidNotificationAction(
            'snooze_10min',
            '10分钟后再说',
          ),
        ],
      ),
    );

    await _notifications.show(
      DateTime.now().millisecond,
      '⏰ 该休息了',
      '你已经连续使用了 $minutes 分钟，起来活动一下吧',
      details,
      payload: 'take_break_$minutes',
    );
  }

  Future<void> _showStrongReminder(int minutes) async {
    final details = const NotificationDetails(
      android: AndroidNotificationDetails(
        'intervention',
        '强制干预',
        importance: Importance.high,
        priority: Priority.high,
        fullScreenIntent: true,
        category: AndroidNotificationCategory.alarm,
        actions: [
          AndroidNotificationAction(
            'open_app',
            '打开 Focus Flow',
            showsUserInterface: true,
          ),
          AndroidNotificationAction(
            'dismiss',
            '知道了',
          ),
        ],
      ),
    );

    await _notifications.show(
      DateTime.now().millisecond,
      '⚠️ 使用时间过长',
      '你已经连续使用了 $minutes 分钟，眼睛和身体都需要休息',
      details,
      payload: 'strong_intervention_$minutes',
    );
  }

  Future<void> _showInterventionReminder(int minutes) async {
    final details = const NotificationDetails(
      android: AndroidNotificationDetails(
        'intervention',
        '强制干预',
        importance: Importance.max,
        priority: Priority.max,
        fullScreenIntent: true,
        category: AndroidNotificationCategory.alarm,
      ),
    );

    await _notifications.show(
      DateTime.now().millisecond,
      '🛑 强制休息',
      '你已连续使用 $minutes 分钟，必须休息至少5分钟',
      details,
      payload: 'force_break_$minutes',
    );
  }

  // ========== Agent 消息 ==========

  /// Agent 主动消息
  Future<void> showAgentMessage({
    required String title,
    required String body,
    String? actionLabel,
  }) async {
    if (!_scheduler.canSend('agent_suggestion')) return;

    final actions = <AndroidNotificationAction>[];
    if (actionLabel != null) {
      actions.add(
        AndroidNotificationAction(
          'agent_action',
          actionLabel,
          showsUserInterface: true,
        ),
      );
    }
    actions.add(const AndroidNotificationAction('dismiss', '忽略'));

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'agent_messages',
        'Agent消息',
        importance: Importance.defaultImportance,
        actions: actions.isNotEmpty ? actions : null,
      ),
    );

    await _notifications.show(
      DateTime.now().millisecond,
      '🤖 $title',
      body,
      details,
      payload: 'agent_message',
    );

    _scheduler.recordSent('agent_suggestion');
  }

  /// 替代活动建议
  Future<void> showAlternativeActivitySuggestion({
    required String activity,
    required String reason,
  }) async {
    final details = const NotificationDetails(
      android: AndroidNotificationDetails(
        'agent_messages',
        'Agent消息',
        importance: Importance.defaultImportance,
        actions: [
          AndroidNotificationAction(
            'accept_activity',
            '好主意',
            showsUserInterface: true,
          ),
          AndroidNotificationAction(
            'dismiss',
            '稍后',
          ),
        ],
      ),
    );

    await _notifications.show(
      DateTime.now().millisecond,
      '💡 休息建议',
      '与其刷手机，不如$activity？$reason',
      details,
      payload: 'alternative_activity',
    );
  }

  // ========== 工具方法 ==========

  /// 取消所有通知
  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }

  /// 取消特定ID的通知
  Future<void> cancel(int id) async {
    await _notifications.cancel(id);
  }

  /// 处理通知响应（前台）
  void _onNotificationResponse(NotificationResponse response) {
    final actionId = response.actionId;
    final payload = response.payload;

    debugPrint('通知响应: action=$actionId, payload=$payload');

    // 交给动作处理器处理
    NotificationActionHandler().handleAction(actionId ?? '', payload);
  }

  /// 处理后台通知响应（静态方法）
  @pragma('vm:entry-point')
  static void _onBackgroundNotificationResponse(NotificationResponse response) {
    debugPrint('后台通知响应: ${response.actionId}');
  }
}
