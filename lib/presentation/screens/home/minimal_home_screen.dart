import 'dart:async';
import 'package:flutter/material.dart';
import '../../agent/enhanced_focus_agent.dart' as agent;
import '../../data/services/system_usage_provider.dart';
import '../../data/models/app_usage.dart';
import '../../data/services/schedule_repository.dart';
import '../../data/models/schedule.dart';
import '../focus/focus_mode_screen.dart';
import '../schedule/schedule_edit_screen.dart';
import '../settings/settings_screen.dart';

/// Focus Flow 首页（DeepSeek/Kimi 风格）
///
/// 布局：
/// 1. 顶部：今日计划和当前状态
/// 2. 中间：手机使用统计（亮屏时间、应用使用）
/// 3. 底部：Chat 输入框
class MinimalHomeScreen extends StatefulWidget {
  const MinimalHomeScreen({super.key});

  @override
  State<MinimalHomeScreen> createState() => _MinimalHomeScreenState();
}

class _MinimalHomeScreenState extends State<MinimalHomeScreen> {
  final EnhancedFocusAgent _agent = EnhancedFocusAgent();
  final SystemUsageProvider _usageProvider = SystemUsageProvider();
  final ScheduleRepository _scheduleRepo = ScheduleRepository();

  // 数据状态
  int _todayMinutes = 0;
  int _unlockCount = 0;
  Map<String, AppUsageInfo> _appUsage = {};
  bool _isLoading = true;
  bool _hasPermission = false;

  // 日程数据
  List<ScheduleEvent> _todayEvents = [];

  // Agent 消息
  final List<agent.AgentMessage> _messages = [];
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    // Agent 已在 InitializationService 中初始化

    _hasPermission = await _usageProvider.checkPermission();
    if (!_hasPermission) {
      setState(() => _isLoading = false);
      return;
    }

    await _refreshData();
    await _loadTodayPlans(); // 加载今日日程

    // 每分钟刷新
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) => _refreshData());

    // Agent 初始问候
    Future.delayed(const Duration(seconds: 1), () {
      _addAgentMessage(agent.AgentResponse(
        text: '你好！我是 Focus，你的屏幕时间助手。告诉我你的日程安排，我会帮你监控使用时间。',
        type: agent.ResponseType.greeting,
      ));
    });

    setState(() => _isLoading = false);
  }

  Future<void> _refreshData() async {
    try {
      final usage = await _usageProvider.getTodayUsage(detailed: true);
      setState(() {
        _todayMinutes = usage.totalScreenTime ~/ 60;
        _unlockCount = usage.unlockCount;
        _appUsage = usage.appUsage;
      });
    } catch (e) {
      debugPrint('刷新数据失败: $e');
    }
  }

  Future<void> _loadTodayPlans() async {
    try {
      await _scheduleRepo.load();
      final events = _scheduleRepo.getTodayEvents(DateTime.now());
      setState(() {
        _todayEvents = events;
      });
    } catch (e) {
      debugPrint('加载日程失败: $e');
    }
  }

  void _addAgentMessage(agent.AgentResponse response) {
    setState(() {
      _messages.add(agent.AgentMessage.fromAgent(response));
    });
    _scrollToBottom();
  }

  void _sendMessage() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(agent.AgentMessage.fromUser(text));
    });
    _inputController.clear();
    _scrollToBottom();

    _agent.processUserInput(text).then((response) {
      _addAgentMessage(response);
    });
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _requestPermission() async {
    await _usageProvider.requestPermission();
    _hasPermission = await _usageProvider.checkPermission();
    if (_hasPermission) {
      await _refreshData();
    }
    setState(() {});
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _inputController.dispose();
    _scrollController.dispose();
    _agent.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _hasPermission
                ? _buildMainContent()
                : _buildPermissionRequest(),
      ),
    );
  }

  /// 权限请求页面
  Widget _buildPermissionRequest() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.security, size: 64, color: Color(0xFF4A90D9)),
            const SizedBox(height: 24),
            const Text(
              '需要权限',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Focus Flow 需要访问应用使用数据，才能帮你监控屏幕时间。',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _requestPermission,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A90D9),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('授权访问', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  /// 主内容
  Widget _buildMainContent() {
    return Column(
      children: [
        // 顶部状态栏
        _buildHeader(),

        // 可滚动内容
        Expanded(
          child: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              // 今日计划和状态
              _buildTodayPlan(),

              const SizedBox(height: 16),

              // 手机使用统计
              _buildUsageStats(),

              const SizedBox(height: 16),

              // 专注模式入口
              _buildFocusModeEntry(),

              const SizedBox(height: 16),

              // Agent 对话区域
              _buildChatSection(),

              const SizedBox(height: 100), // 底部留白
            ],
          ),
        ),

        // 底部输入框
        _buildInputBar(),
      ],
    );
  }

  /// 顶部标题栏
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4A90D9), Color(0xFF63B8FF)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.timer, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          const Text(
            'Focus Flow',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2D3436),
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
            icon: const Icon(Icons.settings_outlined, color: Colors.grey, size: 20),
          ),
        ],
      ),
    );
  }

  /// 今日计划
  Widget _buildTodayPlan() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.today, size: 16, color: Color(0xFF4A90D9)),
              const SizedBox(width: 8),
              const Text(
                '今日计划',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2D3436),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ScheduleEditScreen()),
                  );
                  if (result == true) {
                    _loadTodayPlans(); // 刷新日程列表
                  }
                },
                child: Text(
                  '+ 添加',
                  style: TextStyle(
                    fontSize: 13,
                    color: const Color(0xFF4A90D9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 真实日程数据
          if (_todayEvents.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text(
                  '今天还没有安排\n点击"+ 添加"创建日程',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                ),
              ),
            )
          else
            ..._todayEvents.map((event) => _buildPlanItemFromEvent(event)),
        ],
      ),
    );
  }

  Widget _buildPlanItem(String time, String title, String tag, Color tagColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text(
            time,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF2D3436),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: tagColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              tag,
              style: TextStyle(
                fontSize: 11,
                color: tagColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 从ScheduleEvent构建计划项
  Widget _buildPlanItemFromEvent(ScheduleEvent event) {
    final isActive = event.isActive(DateTime.now());
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFE3F2FD) : Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: isActive ? Border.all(color: const Color(0xFF4A90D9), width: 1) : null,
      ),
      child: Row(
        children: [
          Text(
            event.timeSlot.displayTime,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF2D3436),
                  ),
                ),
                if (event.location != null)
                  Text(
                    event.location!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: _getEventTypeColor(event.type).withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              event.type.displayName,
              style: TextStyle(
                fontSize: 11,
                color: _getEventTypeColor(event.type),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (isActive)
            Container(
              margin: const EdgeInsets.only(left: 8),
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFF4A90D9),
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }

  Color _getEventTypeColor(EventType type) {
    switch (type) {
      case EventType.course:
        return Colors.orange;
      case EventType.study:
        return const Color(0xFF00BFA5);
      case EventType.exercise:
        return Colors.pink;
      case EventType.meeting:
        return Colors.purple;
      case EventType.custom:
        return Colors.blue;
    }
  }
  Widget _buildUsageStats() {
    final hours = _todayMinutes ~/ 60;
    final minutes = _todayMinutes % 60;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.phone_android, size: 16, color: Color(0xFF4A90D9)),
              const SizedBox(width: 8),
              const Text(
                '今日使用',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2D3436),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _todayMinutes > 240 ? Colors.red[50] : Colors.green[50],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _todayMinutes > 240 ? Colors.red : Colors.green,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 亮屏时间大数字
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                hours > 0 ? '$hours' : '$minutes',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: _todayMinutes > 240 ? Colors.red : const Color(0xFF2D3436),
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  hours > 0 ? '小时' : '分钟',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),

          if (hours > 0)
            Text(
              '${minutes}分钟',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),

          const SizedBox(height: 12),

          // 解锁次数
          Row(
            children: [
              Icon(Icons.lock_open, size: 14, color: Colors.grey[400]),
              const SizedBox(width: 4),
              Text(
                '解锁 $_unlockCount 次',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),

          // 应用使用排行
          if (_appUsage.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            ..._buildAppUsageList(),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildAppUsageList() {
    final sortedApps = _appUsage.entries
        .where((e) => e.value.durationMinutes > 0)
        .toList()
      ..sort((a, b) => b.value.durationMinutes.compareTo(a.value.durationMinutes));

    final topApps = sortedApps.take(3);

    return topApps.map((entry) {
      final app = entry.value;
      final minutes = app.durationMinutes;
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;

      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _getAppColor(entry.key),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                app.appName,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF2D3436),
                ),
              ),
            ),
            Text(
              hours > 0 ? '${hours}h ${remainingMinutes}m' : '${minutes}m',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Color _getAppColor(String packageName) {
    final colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
    ];
    return colors[packageName.hashCode % colors.length];
  }

  /// 专注模式入口
  Widget _buildFocusModeEntry() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const FocusModeScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF00BFA5), Color(0xFF00E5FF)],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.play_circle_fill, color: Colors.white, size: 28),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '开始专注',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '25分钟番茄钟',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
          ],
        ),
      ),
    );
  }

  /// Chat 对话区域
  Widget _buildChatSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF9B59B6), Color(0xFFBB8FCE)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.smart_toy, color: Colors.white, size: 14),
            ),
            const SizedBox(width: 8),
            const Text(
              'Focus',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2D3436),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._messages.map((msg) => _buildMessageBubble(msg)),
      ],
    );
  }

  /// 消息气泡
  Widget _buildMessageBubble(agent.AgentMessage message) {
    if (message.isFromAgent) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12, right: 48),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Text(
          message.text,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF2D3436),
            height: 1.5,
          ),
        ),
      );
    } else {
      return Container(
        margin: const EdgeInsets.only(bottom: 12, left: 48),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF4A90D9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Align(
          alignment: Alignment.centerRight,
          child: Text(
            message.text,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white,
            ),
          ),
        ),
      );
    }
  }

  /// 底部输入栏
  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              decoration: InputDecoration(
                hintText: '发送消息...',
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                filled: true,
                fillColor: const Color(0xFFF8F9FA),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4A90D9), Color(0xFF63B8FF)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.send, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}
