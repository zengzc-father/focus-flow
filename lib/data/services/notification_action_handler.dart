import 'dart:async';
import 'package:flutter/material.dart';
import 'notification_service.dart';

/// 通知动作处理器
/// 集中处理用户点击通知按钮的各种操作
class NotificationActionHandler {
  static final NotificationActionHandler _instance = NotificationActionHandler._internal();
  factory NotificationActionHandler() => _instance;
  NotificationActionHandler._internal();

  // 动作回调映射
  final Map<String, Function> _actionCallbacks = {};

  // 状态流
  final _stateController = StreamController<NotificationAction>.broadcast();
  Stream<NotificationAction> get actionStream => _stateController.stream;

  /// 注册动作回调
  void registerCallback(String actionId, Function callback) {
    _actionCallbacks[actionId] = callback;
  }

  /// 处理通知动作
  Future<void> handleAction(String actionId, String? payload) async {
    debugPrint('处理通知动作: $actionId, payload: $payload');

    // 广播动作事件
    _stateController.add(NotificationAction(
      actionId: actionId,
      payload: payload,
      timestamp: DateTime.now(),
    ));

    // 执行具体动作
    switch (actionId) {
      // 休息相关
      case 'take_break':
        await _handleTakeBreak();
        break;
      case 'eye_rest_done':
        await _handleEyeRestDone();
        break;
      case 'posture_fixed':
        await _handlePostureFixed();
        break;
      case 'snooze_10min':
        await _handleSnooze(Duration(minutes: 10));
        break;
      case 'dismiss':
        // 用户忽略提醒，记录即可
        _recordDismiss(actionId, payload);
        break;

      // 专注相关
      case 'start_break':
        await _handleStartBreak();
        break;
      case 'skip_break':
        await _handleSkipBreak();
        break;
      case 'resume_focus':
        await _handleResumeFocus();
        break;
      case 'cancel_focus':
        await _handleCancelFocus();
        break;

      // 活动建议
      case 'accept_activity':
        await _handleAcceptActivity(payload);
        break;
      case 'dismiss_activity':
        await _handleDismissActivity(payload);
        break;

      // 打开应用
      case 'open_app':
        await _handleOpenApp();
        break;

      // Agent消息
      case 'agent_action':
        await _handleAgentAction(payload);
        break;

      default:
        debugPrint('未处理的动作: $actionId');
    }

    // 执行注册的回调
    final callback = _actionCallbacks[actionId];
    if (callback != null) {
      callback(payload);
    }
  }

  // ========== 休息相关 ==========

  Future<void> _handleTakeBreak() async {
    debugPrint('用户选择休息');
    // 可以启动一个短休息计时
    // 显示"休息中"通知
    await NotificationService().showQuietNotification(
      title: '休息中...',
      body: '休息5分钟后再回来继续专注吧！',
    );
  }

  Future<void> _handleEyeRestDone() async {
    debugPrint('用户完成护眼休息');
    // 记录护眼休息完成
    await NotificationService().cancelAll();
  }

  Future<void> _handlePostureFixed() async {
    debugPrint('用户调整姿势');
    // 记录姿势调整
    await NotificationService().cancelAll();
  }

  Future<void> _handleSnooze(Duration duration) async {
    debugPrint('用户延迟 ${duration.inMinutes} 分钟');
    // 设置延迟提醒
    await Future.delayed(duration, () async {
      await NotificationService().showNotification(
        title: '提醒',
        body: '这是您延迟的提醒',
      );
    });
  }

  // ========== 专注相关 ==========

  Future<void> _handleStartBreak() async {
    debugPrint('用户开始休息');
    // 启动休息模式
    await NotificationService().showQuietNotification(
      title: '休息时间',
      body: '享受你的休息时光！',
    );
  }

  Future<void> _handleSkipBreak() async {
    debugPrint('用户跳过休息');
    // 继续专注
    await NotificationService().showNotification(
      title: '继续专注',
      body: '继续保持专注状态！',
    );
  }

  Future<void> _handleResumeFocus() async {
    debugPrint('用户回到专注');
    // 这里需要通知UI层回到专注页面
    // 通过actionStream广播
  }

  Future<void> _handleCancelFocus() async {
    debugPrint('用户取消专注');
    // 结束专注会话
    await NotificationService().showNotification(
      title: '专注已取消',
      body: '下次继续加油！',
    );
  }

  // ========== 活动建议 ==========

  Future<void> _handleAcceptActivity(String? payload) async {
    debugPrint('用户接受活动建议: $payload');
    // 可以记录用户偏好
    await NotificationService().showNotification(
      title: '好的！',
      body: '试试这个活动吧~',
    );
  }

  Future<void> _handleDismissActivity(String? payload) async {
    debugPrint('用户忽略活动建议');
    // 记录用户不感兴趣
  }

  // ========== 其他 ==========

  Future<void> _handleOpenApp() async {
    debugPrint('用户打开应用');
    // 通过actionStream通知App打开主页面
  }

  Future<void> _handleAgentAction(String? payload) async {
    debugPrint('用户执行Agent动作: $payload');
    // Agent相关动作处理
  }

  void _recordDismiss(String actionId, String? payload) {
    debugPrint('用户忽略提醒: $actionId');
    // 可以记录用户响应率
  }

  void dispose() {
    _stateController.close();
  }
}

/// 通知动作事件
class NotificationAction {
  final String actionId;
  final String? payload;
  final DateTime timestamp;

  NotificationAction({
    required this.actionId,
    this.payload,
    required this.timestamp,
  });
}
