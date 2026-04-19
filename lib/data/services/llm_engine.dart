import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// LLM模型类型枚举
enum LLMModelType {
  gemma4E2Bit,      // Gemma 4E 2bit - 2.6GB (当前默认)
  gemma2B,          // Gemma 2B - 1.3GB (更轻量)
  phi3Mini,         // Phi-3 Mini - 2GB (微软)
  qwen2_5_3B,       // Qwen2.5 3B - 1.8GB (阿里)
  llama3_2_3B,      // Llama 3.2 3B - 2GB (Meta)
}

/// 模型配置信息
class LLMModelConfig {
  final LLMModelType type;
  final String name;
  final String fileName;
  final double sizeGB;
  final int contextLength;
  final String? quantization;
  final Map<String, dynamic> parameters;

  const LLMModelConfig({
    required this.type,
    required this.name,
    required this.fileName,
    required this.sizeGB,
    required this.contextLength,
    this.quantization,
    this.parameters = const {},
  });

  // 预定义模型配置
  static const Map<LLMModelType, LLMModelConfig> presets = {
    LLMModelType.gemma4E2Bit: LLMModelConfig(
      type: LLMModelType.gemma4E2Bit,
      name: 'Gemma 4E 2bit',
      fileName: 'gemma-4e-2bit.gguf',
      sizeGB: 2.6,
      contextLength: 4096,
      quantization: 'Q4_0',
      parameters: {
        'n_threads': 4,
        'n_batch': 512,
        'temperature': 0.7,
        'top_p': 0.9,
        'repeat_penalty': 1.1,
      },
    ),
    LLMModelType.gemma2B: LLMModelConfig(
      type: LLMModelType.gemma2B,
      name: 'Gemma 2B',
      fileName: 'gemma-2b-it.gguf',
      sizeGB: 1.3,
      contextLength: 4096,
      quantization: 'Q4_0',
      parameters: {
        'n_threads': 4,
        'n_batch': 512,
        'temperature': 0.7,
        'top_p': 0.9,
      },
    ),
    LLMModelType.phi3Mini: LLMModelConfig(
      type: LLMModelType.phi3Mini,
      name: 'Phi-3 Mini',
      fileName: 'phi-3-mini-4k-instruct.gguf',
      sizeGB: 2.0,
      contextLength: 4096,
      quantization: 'Q4_0',
      parameters: {
        'n_threads': 4,
        'n_batch': 512,
        'temperature': 0.7,
      },
    ),
    LLMModelType.qwen2_5_3B: LLMModelConfig(
      type: LLMModelType.qwen2_5_3B,
      name: 'Qwen2.5 3B',
      fileName: 'qwen2.5-3b-instruct.gguf',
      sizeGB: 1.8,
      contextLength: 4096,
      quantization: 'Q4_0',
      parameters: {
        'n_threads': 4,
        'n_batch': 512,
        'temperature': 0.7,
      },
    ),
    LLMModelType.llama3_2_3B: LLMModelConfig(
      type: LLMModelType.llama3_2_3B,
      name: 'Llama 3.2 3B',
      fileName: 'llama-3.2-3b-instruct.gguf',
      sizeGB: 2.0,
      contextLength: 4096,
      quantization: 'Q4_0',
      parameters: {
        'n_threads': 4,
        'n_batch': 512,
        'temperature': 0.7,
      },
    ),
  };
}

/// LLM推理引擎抽象接口
abstract class LLMEngine {
  /// 当前模型配置
  LLMModelConfig? get currentConfig;

  /// 是否已加载
  bool get isLoaded;

  /// 加载模型
  Future<void> loadModel(LLMModelConfig config);

  /// 卸载模型
  Future<void> unloadModel();

  /// 生成文本（流式）
  Stream<String> generateStream(String prompt);

  /// 生成文本（一次性）
  Future<String> generate(String prompt);

  /// 获取模型信息
  Map<String, dynamic> getModelInfo();

  /// 释放资源
  void dispose();
}

/// llama.cpp 实现
class LlamaCppEngine implements LLMEngine {
  DynamicLibrary? _lib;
  Pointer<Void>? _model;
  Pointer<Void>? _ctx;
  LLMModelConfig? _config;

  @override
  LLMModelConfig? get currentConfig => _config;

  @override
  bool get isLoaded => _model != null && _ctx != null;

  @override
  Future<void> loadModel(LLMModelConfig config) async {
    if (isLoaded) {
      if (_config?.type == config.type) return;
      await unloadModel();
    }

    debugPrint('🔄 加载模型: ${config.name}');

    try {
      // 加载动态库
      _lib = _loadLibrary();

      // 加载模型文件
      final modelPath = await _prepareModelFile(config);

      // 初始化 llama.cpp
      await _initLlama(modelPath, config);

      _config = config;
      debugPrint('✅ 模型加载完成: ${config.name}');
    } catch (e) {
      debugPrint('❌ 模型加载失败: $e');
      throw LLMException('模型加载失败: $e');
    }
  }

  DynamicLibrary _loadLibrary() {
    if (Platform.isAndroid) {
      return DynamicLibrary.open('libllama.so');
    } else if (Platform.isIOS) {
      return DynamicLibrary.process();
    }
    throw UnsupportedError('不支持的平台');
  }

  Future<String> _prepareModelFile(LLMModelConfig config) async {
    // 检查模型文件是否存在
    // 实际实现需要从assets复制到缓存目录
    final modelDir = await _getModelDirectory();
    final modelFile = File('$modelDir/${config.fileName}');

    if (!await modelFile.exists()) {
      throw LLMException('模型文件不存在: ${config.fileName}');
    }

    return modelFile.path;
  }

  Future<String> _getModelDirectory() async {
    // 返回模型存储目录
    // 实际实现使用path_provider
    return '/data/data/com.focusflow.app/models';
  }

  Future<void> _initLlama(String modelPath, LLMModelConfig config) async {
    // 调用 llama.cpp 初始化
    // 这里简化，实际需要通过FFI调用C函数
    debugPrint('初始化 llama.cpp with ${config.parameters}');

    // 模拟加载延迟
    await Future.delayed(Duration(milliseconds: 500));
  }

  @override
  Future<void> unloadModel() async {
    debugPrint('🔄 卸载模型');

    // 释放 llama.cpp 资源
    _ctx = null;
    _model = null;
    _lib = null;
    _config = null;

    // 触发垃圾回收
    // ignore: unnecessary_statements
    TimelineTask;

    debugPrint('✅ 模型已卸载');
  }

  @override
  Stream<String> generateStream(String prompt) async* {
    if (!isLoaded) throw LLMException('模型未加载');

    // 构建格式化提示词
    final formattedPrompt = _formatPrompt(prompt);

    // 流式生成
    // 实际实现通过FFI调用llama_decode并流式输出token
    final buffer = StringBuffer();

    // 模拟流式输出
    final words = '这是一条模拟的流式输出响应。在实际实现中，这里会通过FFI调用llama.cpp的生成函数，并逐token返回结果。'.split('');

    for (final char in words) {
      await Future.delayed(Duration(milliseconds: 20));
      buffer.write(char);
      yield char;
    }
  }

  @override
  Future<String> generate(String prompt) async {
    final buffer = StringBuffer();
    await for (final token in generateStream(prompt)) {
      buffer.write(token);
    }
    return buffer.toString();
  }

  String _formatPrompt(String prompt) {
    // 根据不同模型格式化提示词
    switch (_config?.type) {
      case LLMModelType.gemma4E2Bit:
      case LLMModelType.gemma2B:
        return '<start_of_turn>user\n$prompt\n<end_of_turn>\n<start_of_turn>model\n';
      case LLMModelType.phi3Mini:
        return '<|user|>\n$prompt<|end|>\n<|assistant|>\n';
      case LLMModelType.qwen2_5_3B:
        return '<|im_start|>user\n$prompt<|im_end|>\n<|im_start|>assistant\n';
      case LLMModelType.llama3_2_3B:
        return '<|start_header_id|>user<|end_header_id|>\n\n$prompt<|eot_id|><|start_header_id|>assistant<|end_header_id|>\n\n';
      default:
        return prompt;
    }
  }

  @override
  Map<String, dynamic> getModelInfo() {
    if (!isLoaded) return {'status': '未加载'};

    return {
      'name': _config?.name,
      'type': _config?.type.toString(),
      'size_gb': _config?.sizeGB,
      'context_length': _config?.contextLength,
      'quantization': _config?.quantization,
      'parameters': _config?.parameters,
    };
  }

  @override
  void dispose() {
    unloadModel();
  }
}

/// 模拟引擎（开发测试用）
class MockLLMEngine implements LLMEngine {
  LLMModelConfig? _config;

  @override
  LLMModelConfig? get currentConfig => _config;

  @override
  bool get isLoaded => _config != null;

  @override
  Future<void> loadModel(LLMModelConfig config) async {
    _config = config;
    await Future.delayed(Duration(milliseconds: 300));
    debugPrint('✅ Mock模型加载: ${config.name}');
  }

  @override
  Future<void> unloadModel() async {
    _config = null;
    debugPrint('✅ Mock模型卸载');
  }

  @override
  Stream<String> generateStream(String prompt) async* {
    if (!isLoaded) throw LLMException('模型未加载');

    // 模拟流式输出
    final response = _generateMockResponse(prompt);
    final words = response.split('');

    for (final char in words) {
      await Future.delayed(Duration(milliseconds: 15));
      yield char;
    }
  }

  @override
  Future<String> generate(String prompt) async {
    final buffer = StringBuffer();
    await for (final token in generateStream(prompt)) {
      buffer.write(token);
    }
    return buffer.toString();
  }

  String _generateMockResponse(String prompt) {
    if (prompt.contains('规则')) {
      return '好的，我为你创建了这个规则。我会在你设定的时间提醒你休息，帮助你建立健康的使用习惯。';
    }
    if (prompt.contains('周报')) {
      return '这周你的屏幕使用情况很稳定，平均每天3小时左右。比上周减少了20分钟，继续保持！周末稍微放松一些也没关系。';
    }
    if (prompt.contains('建议')) {
      return '现在连续使用了一段时间，建议起来活动活动。可以做做眼保健操，或者看看窗外远处的景色，让眼睛放松一下。';
    }
    return '我是Focus，你的屏幕时间助手。我会帮助你建立健康的手机使用习惯，在合适的时候提醒你休息。有什么我可以帮你的吗？';
  }

  @override
  Map<String, dynamic> getModelInfo() {
    return {
      'name': _config?.name ?? '未加载',
      'status': isLoaded ? '已加载' : '未加载',
    };
  }

  @override
  void dispose() {
    unloadModel();
  }
}

/// LLM管理器（单例）
class LLMManager {
  static final LLMManager _instance = LLMManager._internal();
  factory LLMManager() => _instance;
  LLMManager._internal();

  LLMEngine? _engine;
  LLMModelType? _currentModelType;

  /// 当前使用的引擎
  LLMEngine get engine => _engine ?? MockLLMEngine();

  /// 当前模型类型
  LLMModelType? get currentModelType => _currentModelType;

  /// 初始化（默认使用模拟引擎）
  Future<void> initialize({bool useRealLLM = false}) async {
    if (useRealLLM) {
      _engine = LlamaCppEngine();
    } else {
      _engine = MockLLMEngine();
    }
  }

  /// 切换模型
  Future<void> switchModel(LLMModelType type) async {
    final config = LLMModelConfig.presets[type]!;

    // 如果当前已加载同类型模型，跳过
    if (_currentModelType == type && engine.isLoaded) {
      return;
    }

    // 加载新模型
    await engine.loadModel(config);
    _currentModelType = type;
  }

  /// 获取可用模型列表
  List<LLMModelConfig> getAvailableModels() {
    return LLMModelConfig.presets.values.toList();
  }

  /// 释放资源
  Future<void> dispose() async {
    _engine?.dispose();
    _engine = null;
  }
}

/// LLM异常
class LLMException implements Exception {
  final String message;
  LLMException(this.message);

  @override
  String toString() => 'LLMException: $message';
}
