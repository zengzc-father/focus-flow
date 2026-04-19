import 'package:flutter/material.dart';
import '../../data/models/schedule.dart';
import '../../data/services/schedule_repository.dart';

/// 日程编辑/添加页面
class ScheduleEditScreen extends StatefulWidget {
  final ScheduleEvent? event; // 如果传入了event，则是编辑模式

  const ScheduleEditScreen({super.key, this.event});

  @override
  State<ScheduleEditScreen> createState() => _ScheduleEditScreenState();
}

class _ScheduleEditScreenState extends State<ScheduleEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();

  EventType _selectedType = EventType.course;
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  int _durationMinutes = 90; // 默认90分钟
  final Set<int> _selectedWeekdays = {1}; // 默认周一

  final List<String> _weekdayNames = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

  bool get _isEditMode => widget.event != null;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      _loadEventData();
    }
  }

  void _loadEventData() {
    final event = widget.event!;
    _nameController.text = event.name;
    _locationController.text = event.location ?? '';
    _selectedType = event.type;
    _startTime = TimeOfDay(hour: event.timeSlot.hour, minute: event.timeSlot.minute);
    _durationMinutes = event.timeSlot.durationMinutes;
    _selectedWeekdays.addAll(event.weekdays);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _selectStartTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (time != null) {
      setState(() => _startTime = time);
    }
  }

  Future<void> _saveSchedule() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入事件名称')),
      );
      return;
    }

    if (_selectedWeekdays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请至少选择一天')),
      );
      return;
    }

    final event = ScheduleEvent(
      id: _isEditMode ? widget.event!.id : DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      type: _selectedType,
      timeSlot: TimeSlot(
        hour: _startTime.hour,
        minute: _startTime.minute,
        durationMinutes: _durationMinutes,
      ),
      weekdays: _selectedWeekdays.toList()..sort(),
      location: _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
      policy: DeviceUsagePolicy.focusMode(),
      createdAt: _isEditMode ? widget.event!.createdAt : DateTime.now(),
    );

    if (_isEditMode) {
      await ScheduleRepository().removeEvent(widget.event!.id);
    }
    await ScheduleRepository().addEvent(event);

    Navigator.pop(context, true);
  }

  String _formatDuration() {
    final hours = _durationMinutes ~/ 60;
    final minutes = _durationMinutes % 60;
    if (hours > 0 && minutes > 0) {
      return '${hours}小时${minutes}分钟';
    } else if (hours > 0) {
      return '${hours}小时';
    } else {
      return '${minutes}分钟';
    }
  }

  String _formatEndTime() {
    final startMinutes = _startTime.hour * 60 + _startTime.minute;
    final endMinutes = startMinutes + _durationMinutes;
    final endHour = endMinutes ~/ 60;
    final endMinute = endMinutes % 60;
    return '${endHour.toString().padLeft(2, '0')}:${endMinute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF2D3436)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isEditMode ? '编辑日程' : '添加日程',
          style: const TextStyle(color: Color(0xFF2D3436)),
        ),
        actions: [
          TextButton(
            onPressed: _saveSchedule,
            child: const Text(
              '保存',
              style: TextStyle(color: Color(0xFF4A90D9), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 事件名称
              _buildSectionTitle('事件名称'),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: '例如：高数课、健身、自习',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 类型选择
              _buildSectionTitle('类型'),
              Wrap(
                spacing: 8,
                children: EventType.values.map((type) {
                  final isSelected = _selectedType == type;
                  return ChoiceChip(
                    label: Text(type.displayName),
                    selected: isSelected,
                    selectedColor: const Color(0xFF4A90D9),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                    onSelected: (_) => setState(() => _selectedType = type),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // 时间选择
              _buildSectionTitle('时间'),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    // 开始时间
                    ListTile(
                      leading: const Icon(Icons.access_time, color: Color(0xFF4A90D9)),
                      title: const Text('开始时间'),
                      trailing: Text(
                        '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                      onTap: _selectStartTime,
                    ),
                    const Divider(height: 1),
                    // 时长
                    ListTile(
                      leading: const Icon(Icons.timelapse, color: Color(0xFF4A90D9)),
                      title: const Text('时长'),
                      trailing: Text(
                        _formatDuration(),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                    Slider(
                      value: _durationMinutes.toDouble(),
                      min: 30,
                      max: 240,
                      divisions: 14, // 30分钟步进
                      label: _formatDuration(),
                      onChanged: (v) => setState(() => _durationMinutes = v.round()),
                    ),
                    // 结束时间预览
                    ListTile(
                      leading: const Icon(Icons.schedule, color: Colors.grey),
                      title: const Text('结束时间'),
                      trailing: Text(
                        _formatEndTime(),
                        style: const TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 重复
              _buildSectionTitle('重复'),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(7, (index) {
                    final weekday = index + 1;
                    final isSelected = _selectedWeekdays.contains(weekday);
                    return FilterChip(
                      label: Text(_weekdayNames[index]),
                      selected: isSelected,
                      selectedColor: const Color(0xFF4A90D9),
                      checkmarkColor: Colors.white,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                      ),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedWeekdays.add(weekday);
                          } else {
                            _selectedWeekdays.remove(weekday);
                          }
                        });
                      },
                    );
                  }),
                ),
              ),
              const SizedBox(height: 24),

              // 地点
              _buildSectionTitle('地点（可选）'),
              TextFormField(
                controller: _locationController,
                decoration: InputDecoration(
                  hintText: '例如：A301教室、图书馆',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // 保存按钮
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _saveSchedule,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A90D9),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('保存', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.grey,
        ),
      ),
    );
  }
}
