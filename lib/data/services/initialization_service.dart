import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';
import 'rule_engine.dart';

/// 应用初始化服务
/// 负责初始化所有必要的组件和服务
class InitializationService {
  static Future<void> initialize() async {
    debugPrint('🚀 开始初始化...');

    // 初始化 SharedPreferences
    await SharedPreferences.getInstance();
    debugPrint('✅ SharedPreferences 初始化完成');

    // 初始化通知服务
    await NotificationService().initialize();
    debugPrint('✅ 通知服务初始化完成');

    // 初始化规则引擎
    await RuleEngine().initialize();
    debugPrint('✅ 规则引擎初始化完成');

    debugPrint('✅ 应用初始化全部完成');
  }
}
