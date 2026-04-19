import 'package:flutter/material.dart';
import '../../data/services/model_manager_service.dart';

/// 模型管理页面
/// 用于导入、删除和管理本地LLM模型
class ModelManagerScreen extends StatefulWidget {
  const ModelManagerScreen({super.key});

  @override
  State<ModelManagerScreen> createState() => _ModelManagerScreenState();
}

class _ModelManagerScreenState extends State<ModelManagerScreen> {
  final ModelManagerService _manager = ModelManagerService();

  ModelImportStatus? _status;
  bool _isLoading = true;
  bool _isImporting = false;
  double _importProgress = 0;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    setState(() => _isLoading = true);
    _status = await _manager.getImportStatus();
    setState(() => _isLoading = false);
  }

  Future<void> _importModel(String sourcePath) async {
    setState(() => _isImporting = true);

    final result = await _manager.importModel(sourcePath);

    setState(() => _isImporting = false);

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('模型导入成功！大小: ${result.formattedSize}'),
          backgroundColor: Colors.green,
        ),
      );
      await _loadStatus();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('导入失败: ${result.message}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteModel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除已导入的模型文件吗？\n删除后需要重新导入才能使用本地AI功能。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _manager.deleteInternalModel();
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('模型已删除')),
        );
        await _loadStatus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('模型管理'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStatus,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildStatusCard(),
                  const SizedBox(height: 16),
                  if (_status?.hasExternalSource ?? false)
                    _buildExternalSourcesCard(),
                  if (!(_status?.isInInternalStorage ?? false))
                    _buildImportGuideCard(),
                  const SizedBox(height: 16),
                  _buildModelInfoCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildStatusCard() {
    final isAvailable = _status?.isAvailable ?? false;
    final isInInternal = _status?.isInInternalStorage ?? false;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isAvailable ? Icons.check_circle : Icons.error,
                  color: isAvailable ? Colors.green : Colors.orange,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isAvailable ? '模型已就绪' : '模型未导入',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        isAvailable
                            ? '可以正常使用本地AI功能'
                            : '需要导入模型文件才能使用AI',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (isInInternal) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.storage, color: Colors.grey[600], size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '大小: ${_status?.formattedSize ?? '未知'}',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.folder, color: Colors.grey[600], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _status?.internalPath ?? '',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _deleteModel,
                icon: const Icon(Icons.delete),
                label: const Text('删除模型'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red,
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExternalSourcesCard() {
    final sources = _status?.externalLocations ?? [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.download, color: Colors.blue[700]),
                const SizedBox(width: 8),
                const Text(
                  '发现外部模型文件',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...sources.map((source) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.insert_drive_file,
                          size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          source,
                          style: const TextStyle(fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 12),
            if (_isImporting)
              Column(
                children: [
                  LinearProgressIndicator(value: _importProgress),
                  const SizedBox(height: 8),
                  const Text('正在导入模型...', style: TextStyle(color: Colors.grey)),
                ],
              )
            else
              FilledButton.icon(
                onPressed: () => _importModel(sources.first),
                icon: const Icon(Icons.download),
                label: const Text('导入到应用'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImportGuideCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.help_outline, color: Colors.blue[700]),
                const SizedBox(width: 8),
                const Text(
                  '导入指南',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildGuideStep(1, '准备模型文件',
                '文件名: gemma-4e-2bit.gguf\n大小: 约 2.6GB'),
            _buildGuideStep(2, '复制到手机',
                '路径: 内部存储/Download/\n或其他 Download 文件夹'),
            _buildGuideStep(3, '返回此页面',
                '应用会自动检测模型文件\n点击"导入到应用"按钮'),
            _buildGuideStep(4, '等待导入完成',
                '文件较大，可能需要几分钟\n请保持应用在前台'),
          ],
        ),
      ),
    );
  }

  Widget _buildGuideStep(int step, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.blue[100],
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$step',
                style: TextStyle(
                  color: Colors.blue[700],
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModelInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '关于模型',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildInfoRow('模型', 'Google Gemma 4E'),
            _buildInfoRow('量化', '2-bit'),
            _buildInfoRow('大小', '约 2.6GB'),
            _buildInfoRow('用途', '本地AI推理'),
            _buildInfoRow('功能', '规则生成、建议推荐'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '模型文件较大，请确保手机有至少 4GB 可用空间',
                      style: TextStyle(
                        color: Colors.orange[800],
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 13,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
