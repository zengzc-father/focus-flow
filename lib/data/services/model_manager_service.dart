import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'local_llm_service.dart';

/// 模型管理服务
/// 负责模型文件的检测、导入和管理
class ModelManagerService {
  static final ModelManagerService _instance = ModelManagerService._internal();
  factory ModelManagerService() => _instance;
  ModelManagerService._internal();

  // 模型文件名
  static const String modelFileName = 'gemma-4e-2bit.gguf';

  /// 检查模型是否可用
  Future<bool> isModelAvailable() async {
    return await LocalLLMService().checkModelAvailable();
  }

  /// 获取模型导入状态
  Future<ModelImportStatus> getImportStatus() async {
    final available = await isModelAvailable();
    final locations = await _scanModelLocations();
    final internalPath = await _getInternalModelPath();

    // 检查内部存储
    final internalExists = internalPath != null && await File(internalPath).exists();

    return ModelImportStatus(
      isAvailable: available,
      externalLocations: locations,
      internalPath: internalPath,
      isInInternalStorage: internalExists,
      modelSize: internalExists ? await _getFileSize(internalPath!) : null,
    );
  }

  /// 扫描可能的模型位置
  Future<List<String>> _scanModelLocations() async {
    final locations = <String>[];
    final possiblePaths = [
      '/storage/emulated/0/Download/$modelFileName',
      '/sdcard/Download/$modelFileName',
      '/storage/sdcard0/Download/$modelFileName',
      '/storage/sdcard1/Download/$modelFileName',
      '/storage/emulated/0/Documents/$modelFileName',
    ];

    for (final path in possiblePaths) {
      if (await File(path).exists()) {
        locations.add(path);
      }
    }

    return locations;
  }

  /// 获取内部存储的模型路径
  Future<String?> _getInternalModelPath() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final modelFile = File('${appDir.path}/models/$modelFileName');
      return modelFile.path;
    } catch (e) {
      debugPrint('获取内部路径失败: $e');
      return null;
    }
  }

  /// 获取文件大小
  Future<int?> _getFileSize(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        return await file.length();
      }
    } catch (e) {
      debugPrint('获取文件大小失败: $e');
    }
    return null;
  }

  /// 导入模型到应用目录
  /// 从外部存储复制到内部存储
  Future<ModelImportResult> importModel(String sourcePath) async {
    try {
      // 检查源文件
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        return ModelImportResult(
          success: false,
          message: '源文件不存在: $sourcePath',
        );
      }

      // 检查目标目录
      final appDir = await getApplicationDocumentsDirectory();
      final modelDir = Directory('${appDir.path}/models');
      if (!await modelDir.exists()) {
        await modelDir.create(recursive: true);
      }

      final destPath = '${modelDir.path}/$modelFileName';
      final destFile = File(destPath);

      // 如果已存在，先删除
      if (await destFile.exists()) {
        await destFile.delete();
      }

      // 复制文件（使用流式复制避免大文件内存问题）
      final sourceSize = await sourceFile.length();
      debugPrint('📦 开始导入模型，大小: ${_formatFileSize(sourceSize)}');

      final sourceStream = sourceFile.openRead();
      final sink = destFile.openWrite();

      var copied = 0;
      await for (final chunk in sourceStream) {
        sink.add(chunk);
        copied += chunk.length;
        if (copied % (100 * 1024 * 1024) == 0) {
          debugPrint('复制进度: ${(copied / sourceSize * 100).toStringAsFixed(1)}%');
        }
      }
      await sink.close();

      // 验证
      final destSize = await destFile.length();
      if (destSize != sourceSize) {
        await destFile.delete();
        return ModelImportResult(
          success: false,
          message: '文件复制不完整',
        );
      }

      debugPrint('✅ 模型导入完成: $destPath');
      return ModelImportResult(
        success: true,
        message: '模型导入成功',
        modelPath: destPath,
        fileSize: destSize,
      );
    } catch (e) {
      debugPrint('❌ 模型导入失败: $e');
      return ModelImportResult(
        success: false,
        message: '导入失败: $e',
      );
    }
  }

  /// 删除内部存储的模型
  Future<bool> deleteInternalModel() async {
    try {
      final internalPath = await _getInternalModelPath();
      if (internalPath != null) {
        final file = File(internalPath);
        if (await file.exists()) {
          await file.delete();
          debugPrint('🗑️ 内部模型已删除');
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('删除模型失败: $e');
      return false;
    }
  }

  /// 请求存储权限
  Future<bool> requestStoragePermission() async {
    // Android 13+ 使用更精细的权限
    if (await Permission.storage.isGranted) {
      return true;
    }

    // 尝试请求存储权限
    var status = await Permission.storage.request();
    if (status.isGranted) {
      return true;
    }

    // Android 11+ 可能需要 MANAGE_EXTERNAL_STORAGE
    if (await Permission.manageExternalStorage.isGranted) {
      return true;
    }

    status = await Permission.manageExternalStorage.request();
    return status.isGranted;
  }

  /// 格式化文件大小
  String formatFileSize(int? bytes) {
    return _formatFileSize(bytes);
  }

  static String _formatFileSize(int? bytes) {
    if (bytes == null) return '未知';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

/// 模型导入状态
class ModelImportStatus {
  final bool isAvailable;
  final List<String> externalLocations;
  final String? internalPath;
  final bool isInInternalStorage;
  final int? modelSize;

  ModelImportStatus({
    required this.isAvailable,
    required this.externalLocations,
    this.internalPath,
    required this.isInInternalStorage,
    this.modelSize,
  });

  bool get hasExternalSource => externalLocations.isNotEmpty;
  String get formattedSize => ModelManagerService._formatFileSize(modelSize);
}

/// 模型导入结果
class ModelImportResult {
  final bool success;
  final String message;
  final String? modelPath;
  final int? fileSize;

  ModelImportResult({
    required this.success,
    required this.message,
    this.modelPath,
    this.fileSize,
  });

  String get formattedSize => ModelManagerService._formatFileSize(fileSize);
}
