import 'package:flutter/material.dart';
import 'package:focus_flow/core/theme/app_theme.dart';
import 'package:focus_flow/data/services/focus_agent.dart';

/// Agent页面（按需加载）
class AgentHubScreen extends StatefulWidget {
  const AgentHubScreen({super.key});

  @override
  State<AgentHubScreen> createState() => _AgentHubScreenState();
}

class _AgentHubScreenState extends State<AgentHubScreen> {
  final FocusAgent _agent = FocusAgent();
  final TextEditingController _inputController = TextEditingController();

  bool _isLoading = false;
  String _response = '';

  @override
  void initState() {
    super.initState();
    _loadAgent();
  }

  Future<void> _loadAgent() async {
    setState(() => _isLoading = true);
    await _agent.load();
    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _inputController.dispose();
    _agent.unload(); // 离开页面时释放
    super.dispose();
  }

  Future<void> _generateRule() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isLoading = true);

    final rule = await _agent.generateRule(text);

    setState(() {
      _isLoading = false;
      if (rule != null) {
        _response = '✅ 已创建规则：${rule.name}\n\n'
            '条件：${_ruleDescription(rule)}\n'
            '动作：${rule.action.message}';
      } else {
        _response = '❌ 创建失败，请重试';
      }
    });
  }

  String _ruleDescription(SmartRule rule) {
    final cond = rule.conditions;
    final parts = <String>[];
    if (cond.timeRange != null) parts.add(cond.timeRange!);
    if (cond.consecutiveMinutes != null) parts.add('连续${cond.consecutiveMinutes}分钟');
    if (cond.totalMinutes != null) parts.add('累计${cond.totalMinutes}分钟');
    return parts.join('，');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Focus Agent'),
        actions: [
          // Agent状态指示
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _agent.state == AgentLoadState.ready
                      ? Colors.green
                      : _agent.state == AgentLoadState.loading
                          ? Colors.orange
                          : Colors.grey,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 说明
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.psychology, color: AppTheme.primaryColor),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '用自然语言创建规则，Agent会帮你转换为自动提醒',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 输入框
            TextField(
              controller: _inputController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: '例如：晚上8点后刷抖音超30分钟提醒我',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 快捷示例
            Wrap(
              spacing: 8,
              children: [
                _buildExampleChip('午休时间提醒'),
                _buildExampleChip('学习时段专注'),
                _buildExampleChip('晚上限制游戏'),
              ],
            ),

            const SizedBox(height: 16),

            // 生成按钮
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _generateRule,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('创建规则'),
              ),
            ),

            const SizedBox(height: 24),

            // 响应显示
            if (_response.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(_response),
              ),

            const Spacer(),

            // 提示
            Center(
              child: Text(
                'Agent只在打开此页面时工作，日常提醒不耗电',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[400],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExampleChip(String text) {
    return ActionChip(
      label: Text(text),
      onPressed: () {
        _inputController.text = text;
      },
    );
  }
}
