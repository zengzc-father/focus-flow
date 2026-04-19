import 'dart:async';
import 'package:flutter/material.dart';
import 'package:circular_countdown_timer/circular_countdown_timer.dart';
import 'package:focus_flow/data/models/focus_session.dart';
import 'package:focus_flow/data/models/schedule.dart';
import 'package:focus_flow/data/services/focus_session_monitor.dart';
import 'package:focus_flow/data/services/schedule_repository.dart';
import 'package:focus_flow/presentation/screens/focus/widgets/white_noise_player.dart';

/// 专注模式主页面（增强版）
/// 核心功能：倒计时、白噪音、任务绑定、使用检测
class FocusModeScreen extends StatefulWidget {
  final String? initialTaskName;
  final int? initialDuration;
  final String? boundEventId; // 绑定的日程事件ID

  const FocusModeScreen({
    super.key,
    this.initialTaskName,
    this.initialDuration,
    this.boundEventId,
  });

  @override
  State<FocusModeScreen> createState() => _FocusModeScreenState();
}

class _FocusModeScreenState extends State<FocusModeScreen>
    with TickerProviderStateMixin {
  final FocusModeManager _focusManager = FocusModeManager();
  final FocusSessionMonitor _sessionMonitor = FocusSessionMonitor();
  final ScheduleRepository _scheduleRepo = ScheduleRepository();

  FocusSession? _currentSession;
  PomodoroSettings _settings = PomodoroSettings();
  FocusScreenState _screenState = FocusScreenState.setup;

  CountDownController? _countdownController;
  Timer? _refreshTimer;

  final TextEditingController _taskController = TextEditingController();

  // 实时使用统计
  Map<String, dynamic> _usageStats = {};
  Timer? _usageStatsTimer;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _focusManager.initialize();
    await _scheduleRepo.load();
    _settings = _focusManager.settings;
    _taskController.text = widget.initialTaskName ?? '';

    _focusManager.sessionStream.listen((session) {
      setState(() => _currentSession = session);
      if (session != null) {
        _onSessionStateChanged(session.status);
      }
    });

    final currentSession = _focusManager.currentSession;
    if (currentSession != null) {
      setState(() {
        _currentSession = currentSession;
        _screenState = FocusScreenState.focusing;
        _taskController.text = currentSession.taskName;
      });
      _startCountdown(currentSession.remainingSeconds);
      _startUsageMonitoring();
    }

    setState(() {});
  }

  /// 启动使用监控
  void _startUsageMonitoring() {
    if (_currentSession == null) return;

    // 查找绑定的日程事件
    ScheduleEvent? boundEvent;
    if (widget.boundEventId != null) {
      final events = _scheduleRepo.getAllEvents();
      boundEvent = events.where((e) => e.id == widget.boundEventId).firstOrNull;
    }

    // 启动监控
    _sessionMonitor.startMonitoring(_currentSession!, boundEvent: boundEvent);

    // 定时更新使用统计UI
    _usageStatsTimer?.cancel();
    _usageStatsTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      setState(() {
        _usageStats = _sessionMonitor.getRealTimeStats();
      });
    });

    debugPrint('🔍 专注使用监控已启动${boundEvent != null ? "，绑定日程: ${boundEvent.name}" : ""}');
  }

  /// 停止使用监控
  Future<void> _stopUsageMonitoring() async {
    await _sessionMonitor.stopMonitoring();
    _usageStatsTimer?.cancel();
    _usageStatsTimer = null;
  }

  void _onSessionStateChanged(FocusSessionStatus status) {
    switch (status) {
      case FocusSessionStatus.active:
        setState(() => _screenState = FocusScreenState.focusing);
        _startUsageMonitoring();
        break;
      case FocusSessionStatus.completed:
        setState(() => _screenState = FocusScreenState.completed);
        _refreshTimer?.cancel();
        _stopUsageMonitoring();
        break;
      case FocusSessionStatus.cancelled:
        setState(() => _screenState = FocusScreenState.setup);
        _refreshTimer?.cancel();
        _stopUsageMonitoring();
        break;
      default:
        break;
    }
  }

  void _startCountdown(int seconds) {
    _countdownController = CountDownController();
    _countdownController?.start();

    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_currentSession?.remainingSeconds == 0) {
        timer.cancel();
        _focusManager.completeFocus();
      }
    });
  }

  Future<void> _startFocus() async {
    if (_taskController.text.trim().isEmpty) {
      _showTaskRequiredDialog();
      return;
    }

    final session = await _focusManager.startFocus(
      taskName: _taskController.text.trim(),
      durationMinutes: widget.initialDuration ?? _settings.focusDurationMinutes,
    );

    _startCountdown(session.durationMinutes * 60);
  }

  Future<void> _completeFocus() async {
    await _focusManager.completeFocus();
    _refreshTimer?.cancel();
  }

  Future<void> _cancelFocus() async {
    final confirmed = await _showCancelConfirmDialog();
    if (confirmed) {
      await _focusManager.cancelFocus();
      _refreshTimer?.cancel();
      if (mounted) Navigator.pop(context);
    }
  }

  void _showTaskRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('需要任务名称'),
        content: const Text('请告诉 Focus 你要专注完成什么任务。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  Future<bool> _showCancelConfirmDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('确定要放弃专注吗？'),
            content: const Text('中断专注会影响你的习惯养成。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('继续专注'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('放弃'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _startBreak() async {
    setState(() => _screenState = FocusScreenState.breakTime);
    final isLongBreak = _focusManager.getTodayFocusMinutes() >= 120;
    final breakMinutes = isLongBreak ? _settings.longBreakMinutes : _settings.shortBreakMinutes;
    _startCountdown(breakMinutes * 60);
  }

  void _skipBreak() {
    setState(() => _screenState = FocusScreenState.setup);
    _taskController.clear();
  }

  @override
  void dispose() {
    _taskController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _getBackgroundColor(),
      body: SafeArea(
        child: _buildContent(),
      ),
    );
  }

  Color _getBackgroundColor() {
    switch (_screenState) {
      case FocusScreenState.focusing:
        return const Color(0xFF1A1A2E);
      case FocusScreenState.breakTime:
        return const Color(0xFF0F3460);
      case FocusScreenState.completed:
        return const Color(0xFF16213E);
      default:
        return const Color(0xFFF8F9FA);
    }
  }

  Widget _buildContent() {
    switch (_screenState) {
      case FocusScreenState.setup:
        return _buildSetupView();
      case FocusScreenState.focusing:
        return _buildFocusingView();
      case FocusScreenState.completed:
        return _buildCompletedView();
      case FocusScreenState.breakTime:
        return _buildBreakView();
    }
  }

  /// 设置页面
  Widget _buildSetupView() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: Color(0xFF2D3436)),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 32),
          const Text(
            '开始专注',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3436),
            ),
          ),
          const SizedBox(height: 48),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '你要专注做什么？',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2D3436),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _taskController,
                  decoration: InputDecoration(
                    hintText: '例如：完成数学作业...',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    filled: true,
                    fillColor: const Color(0xFFF8F9FA),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '专注时长',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2D3436),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildDurationChip('15分钟', 15),
                    const SizedBox(width: 12),
                    _buildDurationChip('25分钟', 25, isSelected: true),
                    const SizedBox(width: 12),
                    _buildDurationChip('45分钟', 45),
                  ],
                ),
              ],
            ),
          ),
          const Spacer(),
          const WhiteNoisePlayerPreview(),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _startFocus,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00BFA5),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                '开始专注',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDurationChip(String label, int minutes, {bool isSelected = false}) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        // TODO: 更新时长
      },
      selectedColor: const Color(0xFF00BFA5),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.grey[700],
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  /// 专注中页面
  Widget _buildFocusingView() {
    final remainingSeconds = _currentSession?.remainingSeconds ?? 0;
    final usageBreakdown = _usageStats['usage_breakdown'] as Map<String, dynamic>? ?? {};

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: _settings.strictMode ? null : _cancelFocus,
                icon: const Icon(Icons.close, color: Colors.white70),
              ),
              // 使用统计按钮
              if (usageBreakdown.isNotEmpty)
                IconButton(
                  onPressed: _showUsageStats,
                  icon: const Icon(Icons.bar_chart, color: Colors.white70),
                ),
            ],
          ),
          const Spacer(),
          CircularCountDownTimer(
            duration: remainingSeconds,
            initialDuration: 0,
            controller: _countdownController,
            width: 280,
            height: 280,
            ringColor: Colors.white.withOpacity(0.1),
            fillColor: const Color(0xFF00BFA5),
            backgroundColor: Colors.transparent,
            strokeWidth: 12,
            strokeCap: StrokeCap.round,
            textStyle: const TextStyle(
              fontSize: 56,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textFormat: CountdownTextFormat.MM_SS,
            isReverse: true,
            isTimerTextShown: true,
            autoStart: true,
            onComplete: () {
              _focusManager.completeFocus();
            },
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _currentSession?.taskName ?? '',
              style: const TextStyle(
                fontSize: 18,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 显示使用统计摘要
          if (usageBreakdown.isNotEmpty)
            _buildUsageStatsSummary(usageBreakdown),
          const Spacer(),
          const WhiteNoisePlayerWidget(),
          const SizedBox(height: 32),
          const Text(
            '保持专注，不要离开这个页面',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  /// 使用统计摘要
  Widget _buildUsageStatsSummary(Map<String, dynamic> breakdown) {
    final totalDistraction = breakdown.entries
        .where((e) => e.key != '学习' && e.key != '工具')
        .fold<int>(0, (sum, e) => sum + (e.value as int));

    if (totalDistraction == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: totalDistraction > 5 ? Colors.orange : Colors.white70,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            '已使用手机 ${totalDistraction}分钟',
            style: TextStyle(
              color: totalDistraction > 5 ? Colors.orange : Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  /// 显示使用统计弹窗
  void _showUsageStats() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final breakdown = _usageStats['usage_breakdown'] as Map<String, dynamic>? ?? {};
        final appsUsed = _usageStats['apps_used'] as int? ?? 0;

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '使用统计',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '打开了 $appsUsed 个应用',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              ...breakdown.entries.map((e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      e.key,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    Text(
                      '${e.value}分钟',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              )),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00BFA5),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('知道了'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 完成页面
  Widget _buildCompletedView() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.check_circle,
            size: 80,
            color: Color(0xFF00BFA5),
          ),
          const SizedBox(height: 32),
          const Text(
            '专注完成',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _currentSession?.taskName ?? '',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 48),
          ElevatedButton(
            onPressed: _startBreak,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00BFA5),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('开始休息'),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _skipBreak,
            child: Text(
              '跳过休息',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 休息页面
  Widget _buildBreakView() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.coffee,
            size: 64,
            color: Color(0xFF00BFA5),
          ),
          const SizedBox(height: 32),
          const Text(
            '休息时间',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '起来活动一下，喝口水',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 48),
          if (_countdownController != null)
            CircularCountDownTimer(
              duration: _settings.shortBreakMinutes * 60,
              initialDuration: 0,
              controller: _countdownController,
              width: 180,
              height: 180,
              ringColor: Colors.white.withOpacity(0.1),
              fillColor: const Color(0xFF00BFA5),
              backgroundColor: Colors.transparent,
              strokeWidth: 8,
              textStyle: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textFormat: CountdownTextFormat.MM_SS,
              isReverse: true,
              isTimerTextShown: true,
              autoStart: true,
            ),
          const Spacer(),
          ElevatedButton(
            onPressed: _skipBreak,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00BFA5),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('结束休息'),
          ),
        ],
      ),
    );
  }
}

enum FocusScreenState {
  setup,
  focusing,
  completed,
  breakTime,
}
