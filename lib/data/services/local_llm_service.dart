import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:ffi/ffi.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// 本地LLM推理服务
/// 基于llama.cpp + Gemma 4E 2bit模型
class LocalLLMService {
  static final LocalLLMService _instance = LocalLLMService._internal();
  factory LocalLLMService() => _instance;
  LocalLLMService._internal();

  DynamicLibrary? _lib;
  Pointer<Void>? _model;
  Pointer<Void>? _ctx;

  bool _isInitialized = false;
  bool _isLoading = false;

  // 模型配置
  static const int _contextSize = 2048;
  static const int _maxTokens = 512;
  static const double _temperature = 0.7;

  /// 初始化模型
  Future<void> initialize() async {
    if (_isInitialized || _isLoading) return;
    _isLoading = true;

    try {
      // 加载动态库
      await _loadLibrary();

      // 检查/复制模型文件
      final modelPath = await _prepareModel();

      // 加载模型
      await _loadModel(modelPath);

      _isInitialized = true;
      debugPrint('🧠 LLM模型加载完成');
    } catch (e) {
      debugPrint('❌ LLM初始化失败: $e');
      rethrow;
    } finally {
      _isLoading = false;
    }
  }

  /// 加载动态库
  Future<void> _loadLibrary() async {
    if (Platform.isAndroid) {
      _lib = DynamicLibrary.open('libllama.so');
    } else if (Platform.isIOS) {
      _lib = DynamicLibrary.process();
    } else {
      throw UnsupportedError('不支持的平台: ${Platform.operatingSystem}');
    }
  }

  /// 准备模型文件
  Future<String> _prepareModel() async {
    final appDir = await getApplicationDocumentsDirectory();
    final modelDir = Directory(path.join(appDir.path, 'models'));

    if (!await modelDir.exists()) {
      await modelDir.create(recursive: true);
    }

    final modelFile = File(path.join(modelDir.path, 'gemma-4e-2bit.gguf'));

    // 如果模型不存在，从assets复制
    if (!await modelFile.exists()) {
      debugPrint('📦 复制模型文件...');
      // 实际实现需要从assets复制大文件
      // 这里简化处理
      throw Exception('请先将模型文件放入 ${modelFile.path}');
    }

    return modelFile.path;
  }

  /// 加载模型到内存
  Future<void> _loadModel(String modelPath) async {
    // 这里调用llama.cpp的C函数
    // 简化示例，实际需要通过FFI绑定C函数

    // final loadModel = _lib!.lookupFunction<
    //   Pointer<Void> Function(Pointer<Utf8> path, Int32 contextSize),
    //   Pointer<Void> Function(Pointer<Utf8> path, int contextSize)
    // >('llama_load_model');
    // _model = loadModel(modelPath.toNativeUtf8(), _contextSize);

    debugPrint('📥 模型路径: $modelPath');
  }

  /// 生成文本
  Future<String> generate(
    String prompt, {
    int maxTokens = _maxTokens,
    double temperature = _temperature,
  }) async {
    if (!_isInitialized) {
      throw StateError('LLM未初始化');
    }

    // 构建系统提示词
    final fullPrompt = _buildSystemPrompt(prompt);

    // 调用推理
    // 实际实现需要通过FFI调用llama.cpp
    final response = await _inference(fullPrompt, maxTokens, temperature);

    // 解析响应
    return _parseResponse(response);
  }

  /// 构建系统提示词
  String _buildSystemPrompt(String userPrompt) {
    return '''<start_of_turn>user
你是一位专业的学习助手AI Agent，帮助用户管理手机使用时间，建立健康习惯。

你的职责：
1. 分析用户的屏幕使用模式
2. 主动识别需要干预的时刻
3. 生成个性化的规则和提醒
4. 推荐合适的替代活动
5. 用简短友好的中文回复

当前用户消息: $userPrompt
<end_of_turn>
<start_of_turn>model
'''.trim();
  }

  /// 执行推理
  Future<String> _inference(String prompt, int maxTokens, double temperature) async {
    // 模拟推理延迟
    await Future.delayed(const Duration(milliseconds: 500));

    // 实际实现：
    // 1. tokenize prompt
    // 2. 调用 llama_decode
    // 3. 采样生成token
    // 4. 解码为文本

    // 模拟响应（实际开发时删除）
    return _simulateResponse(prompt);
  }

  /// 解析模型响应
  String _parseResponse(String rawResponse) {
    // 去除特殊token
    var cleaned = rawResponse
        .replaceAll('<start_of_turn>', '')
        .replaceAll('<end_of_turn>', '')
        .replaceAll('<eos>', '')
        .trim();

    // 提取JSON（如果存在）
    if (cleaned.contains('{') && cleaned.contains('}')) {
      final start = cleaned.indexOf('{');
      final end = cleaned.lastIndexOf('}') + 1;
      if (start >= 0 && end > start) {
        cleaned = cleaned.substring(start, end);
      }
    }

    return cleaned;
  }

  /// 模拟响应（开发测试用）
  String _simulateResponse(String prompt) {
    // 基于关键词返回模拟响应
    if (prompt.contains('创建规则') || prompt.contains('设置')) {
      return '''{
  "reasoning": "用户要求创建规则，基于当前时间20:00和使用时长4小时，建议设置晚间限制",
  "decision": "create_rule",
  "confidence": 0.92,
  "action": {
    "type": "notification",
    "content": "已为您创建晚间使用限制规则",
    "timing": "immediate"
  },
  "new_rule": {
    "name": "晚间使用限制",
    "condition": {"timeAfter": "20:00", "dailyUsageOver": 240},
    "action": {"type": "notify", "message": "今天使用已达标，建议休息"}
  }
}'''.trim();
    }

    if (prompt.contains('推荐') || prompt.contains('建议')) {
      return '基于您今天的使用模式，建议现在进行20分钟的眼保健操，然后复习今天的课堂笔记。这符合您的学习习惯，也有助于缓解眼疲劳。';
    }

    if (prompt.contains('时间') || prompt.contains('用了多久')) {
      return '您今天已经使用了4小时15分钟手机，主要集中在社交和娱乐类应用。比昨天多了30分钟，建议适当控制。';
    }

    return '我理解您的需求。作为您的学习助手，我会持续监控您的使用情况，在合适的时候给出建议。';
  }

  /// 释放资源
  void dispose() {
    // 释放模型和上下文
    _model = null;
    _ctx = null;
    _isInitialized = false;
  }

  /// 获取模型状态
  LLMStatus get status => LLMStatus(
        isInitialized: _isInitialized,
        isLoading: _isLoading,
        modelPath: null,
        contextSize: _contextSize,
      );
}

/// LLM状态
class LLMStatus {
  final bool isInitialized;
  final bool isLoading;
  final String? modelPath;
  final int contextSize;

  LLMStatus({
    required this.isInitialized,
    required this.isLoading,
    this.modelPath,
    required this.contextSize,
  });
}
