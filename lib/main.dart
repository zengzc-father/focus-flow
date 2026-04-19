import 'package:flutter/material.dart';
import 'app.dart';
import 'data/services/initialization_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化所有服务
  await InitializationService.initialize();

  runApp(const FocusFlowApp());
}
