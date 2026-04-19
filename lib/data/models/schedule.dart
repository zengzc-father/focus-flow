import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 日程事件类型
enum EventType {
  course,     // 正式课程
  study,      // 自习时间
  exercise,   // 健身/运动
  meeting,    // 会议
  custom,     // 自定义活动
}

extension EventTypeExtension on EventType {
  String get displayName {
    switch (this) {
      case EventType.course:
        return '课程';
      case EventType.study:
        return '自习';
      case EventType.exercise:
        return '健身';
      case EventType.meeting:
        return '会议';
      case EventType.custom:
        return '活动';
    }
  }
}

/// 设备使用策略
class DeviceUsagePolicy {
  final bool allowToolUsage;      // 允许工具使用
  final int entertainmentLimitMinutes; // 娱乐使用限制（分钟，0表示禁止）
  final bool requireCheckIn;      // 是否需要专注打卡

  DeviceUsagePolicy({
    this.allowToolUsage = true,
    this.entertainmentLimitMinutes = 5, // 默认5分钟
    this.requireCheckIn = false,
  });

  // 专注模式（上课/自习）
  factory DeviceUsagePolicy.focusMode() => DeviceUsagePolicy(
    allowToolUsage: true,
    entertainmentLimitMinutes: 5,
    requireCheckIn: false,
  );

  // 严格模式（重要考试前）
  factory DeviceUsagePolicy.strictMode() => DeviceUsagePolicy(
    allowToolUsage: false,
    entertainmentLimitMinutes: 0,
    requireCheckIn: true,
  );

  // 宽松模式（休息时间）
  factory DeviceUsagePolicy.relaxedMode() => DeviceUsagePolicy(
    allowToolUsage: true,
    entertainmentLimitMinutes: 30,
    requireCheckIn: false,
  );

  Map<String, dynamic> toJson() => {
    'allowToolUsage': allowToolUsage,
    'entertainmentLimitMinutes': entertainmentLimitMinutes,
    'requireCheckIn': requireCheckIn,
  };

  factory DeviceUsagePolicy.fromJson(Map<String, dynamic> json) => DeviceUsagePolicy(
    allowToolUsage: json['allowToolUsage'] as bool? ?? true,
    entertainmentLimitMinutes: json['entertainmentLimitMinutes'] as int? ?? 5,
    requireCheckIn: json['requireCheckIn'] as bool? ?? false,
  );
}

/// 时间段
class TimeSlot {
  final int hour;      // 开始小时
  final int minute;    // 开始分钟
  final int durationMinutes; // 持续分钟

  TimeSlot({
    required this.hour,
    required this.minute,
    required this.durationMinutes,
  });

  DateTime get startTime => DateTime(2024, 1, 1, hour, minute);
  DateTime get endTime => startTime.add(Duration(minutes: durationMinutes));

  String get displayTime {
    final end = endTime;
    return '${_pad(hour)}:${_pad(minute)}-${_pad(end.hour)}:${_pad(end.minute)}';
  }

  String get startDisplay => '${_pad(hour)}:${_pad(minute)}';
  String get endDisplay {
    final end = endTime;
    return '${_pad(end.hour)}:${_pad(end.minute)}';
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  /// 检查某时间是否在该时段内
  bool contains(DateTime time) {
    final checkMinutes = time.hour * 60 + time.minute;
    final startMinutes = hour * 60 + minute;
    final endMinutes = startMinutes + durationMinutes;
    return checkMinutes >= startMinutes && checkMinutes < endMinutes;
  }

  /// 获取当前已进行时长（分钟）
  int elapsedMinutes(DateTime now) {
    final currentMinutes = now.hour * 60 + now.minute;
    final startMinutes = hour * 60 + minute;
    return currentMinutes - startMinutes;
  }

  /// 获取剩余时长（分钟）
  int remainingMinutes(DateTime now) {
    final currentMinutes = now.hour * 60 + now.minute;
    final endMinutes = hour * 60 + minute + durationMinutes;
    return endMinutes - currentMinutes;
  }

  Map<String, dynamic> toJson() => {
    'hour': hour,
    'minute': minute,
    'durationMinutes': durationMinutes,
  };

  factory TimeSlot.fromJson(Map<String, dynamic> json) => TimeSlot(
    hour: json['hour'] as int,
    minute: json['minute'] as int,
    durationMinutes: json['durationMinutes'] as int,
  );
}

/// 日程事件
class ScheduleEvent {
  final String id;
  final String name;                    // 事件名称
  final EventType type;                 // 类型
  final TimeSlot timeSlot;              // 时间段
  final List<int> weekdays;             // 重复星期 [1,3,5] 周一三五
  final String? location;               // 地点
  final String? description;            // 描述
  final DeviceUsagePolicy policy;       // 使用策略
  final DateTime createdAt;             // 创建时间

  ScheduleEvent({
    required this.id,
    required this.name,
    required this.type,
    required this.timeSlot,
    required this.weekdays,
    this.location,
    this.description,
    required this.policy,
    required this.createdAt,
  });

  /// 检查某天是否有该事件
  bool occursOn(DateTime date) {
    final weekday = date.weekday; // 1=周一, 7=周日
    return weekdays.contains(weekday);
  }

  /// 检查当前是否在进行中
  bool isActive(DateTime now) {
    if (!occursOn(now)) return false;
    return timeSlot.contains(now);
  }

  /// 获取星期几显示
  String get weekdayDisplay {
    final names = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    if (weekdays.length == 7) return '每天';
    if (weekdays.length == 5 &&
        weekdays.contains(1) &&
        weekdays.contains(2) &&
        weekdays.contains(3) &&
        weekdays.contains(4) &&
        weekdays.contains(5)) {
      return '工作日';
    }
    return weekdays.map((w) => names[w - 1]).join('、');
  }

  String get fullDisplay {
    var text = '$name (${type.displayName})\n';
    text += '$weekdayDisplay ${timeSlot.displayTime}';
    if (location != null) {
      text += ' @$location';
    }
    return text;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type.toString().split('.').last,
    'timeSlot': timeSlot.toJson(),
    'weekdays': weekdays,
    'location': location,
    'description': description,
    'policy': policy.toJson(),
    'createdAt': createdAt.toIso8601String(),
  };

  factory ScheduleEvent.fromJson(Map<String, dynamic> json) => ScheduleEvent(
    id: json['id'] as String,
    name: json['name'] as String,
    type: EventType.values.firstWhere(
      (e) => e.toString().split('.').last == json['type'],
      orElse: () => EventType.custom,
    ),
    timeSlot: TimeSlot.fromJson(json['timeSlot'] as Map<String, dynamic>),
    weekdays: (json['weekdays'] as List<dynamic>).cast<int>(),
    location: json['location'] as String?,
    description: json['description'] as String?,
    policy: DeviceUsagePolicy.fromJson(json['policy'] as Map<String, dynamic>),
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}

/// 当前上下文
class CurrentContext {
  final ScheduleEvent? activeEvent;     // 当前进行的事件
  final DeviceUsagePolicy? policy;      // 当前策略
  final int minutesElapsed;             // 已开始多久
  final int minutesRemaining;           // 还剩多久
  final bool isInScheduledTime;         // 是否在安排的时间内

  CurrentContext({
    this.activeEvent,
    this.policy,
    required this.minutesElapsed,
    required this.minutesRemaining,
    required this.isInScheduledTime,
  });

  factory CurrentContext.idle() => CurrentContext(
    activeEvent: null,
    policy: null,
    minutesElapsed: 0,
    minutesRemaining: 0,
    isInScheduledTime: false,
  );

  String get displayText {
    if (activeEvent == null) {
      return '空闲时间';
    }
    return '${activeEvent!.name} 进行中\n'
           '已进行 $minutesElapsed 分钟，剩余 $minutesRemaining 分钟';
  }

  String get eventName => activeEvent?.name ?? '空闲';
}

/// 日程仓储
class ScheduleRepository {
  static final ScheduleRepository _instance = ScheduleRepository._internal();
  factory ScheduleRepository() => _instance;
  ScheduleRepository._internal();

  final List<ScheduleEvent> _events = [];
  bool _isLoaded = false;

  /// 加载日程
  Future<void> load() async {
    if (_isLoaded) return;

    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList('schedule_events') ?? [];

    _events.clear();
    for (var json in jsonList) {
      try {
        final event = ScheduleEvent.fromJson(jsonDecode(json));
        _events.add(event);
      } catch (e) {
        debugPrint('加载日程失败: $e');
      }
    }

    _isLoaded = true;
    debugPrint('📅 加载了 ${_events.length} 个日程');
  }

  /// 保存日程
  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _events.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList('schedule_events', jsonList);
  }

  /// 添加日程
  Future<void> addEvent(ScheduleEvent event) async {
    _events.add(event);
    await save();
  }

  /// 删除日程
  Future<void> removeEvent(String id) async {
    _events.removeWhere((e) => e.id == id);
    await save();
  }

  /// 获取所有日程
  List<ScheduleEvent> getAllEvents() => List.unmodifiable(_events);

  /// 获取今日日程
  List<ScheduleEvent> getTodayEvents(DateTime date) {
    return _events.where((e) => e.occursOn(date)).toList()
      ..sort((a, b) => (a.timeSlot.hour * 60 + a.timeSlot.minute)
          .compareTo(b.timeSlot.hour * 60 + b.timeSlot.minute));
  }

  /// 获取当前上下文
  CurrentContext getCurrentContext(DateTime now) {
    final todayEvents = getTodayEvents(now);

    for (var event in todayEvents) {
      if (event.isActive(now)) {
        return CurrentContext(
          activeEvent: event,
          policy: event.policy,
          minutesElapsed: event.timeSlot.elapsedMinutes(now),
          minutesRemaining: event.timeSlot.remainingMinutes(now),
          isInScheduledTime: true,
        );
      }
    }

    return CurrentContext.idle();
  }

  /// 获取某时段的日程（用于分析）
  ScheduleEvent? getEventForTimeSlot(DateTime date, TimeSlot slot) {
    final dayEvents = getTodayEvents(date);
    for (var event in dayEvents) {
      // 检查时段重叠
      if (event.timeSlot.hour == slot.hour &&
          event.timeSlot.minute == slot.minute) {
        return event;
      }
    }
    return null;
  }

  /// 清空所有日程
  Future<void> clearAll() async {
    _events.clear();
    await save();
  }

  /// 获取下一事件
  ScheduleEvent? getNextEvent(DateTime now) {
    final todayEvents = getTodayEvents(now);
    final currentMinutes = now.hour * 60 + now.minute;

    for (var event in todayEvents) {
      final eventStartMinutes = event.timeSlot.hour * 60 + event.timeSlot.minute;
      if (eventStartMinutes > currentMinutes) {
        return event;
      }
    }

    return null; // 今天没有更多事件
  }
}

/// 自然语言日程解析器
class ScheduleNLParser {
  /// 从自然语言解析日程
  ///
  /// 支持格式:
  /// - "周一上午8点到9点半有高数课"
  /// - "每天下午4点健身1小时"
  /// - "周三下午2点在图书馆自习3小时"
  ScheduleEvent? parse(String input) {
    try {
      // 提取星期
      final weekdays = _extractWeekdays(input);
      if (weekdays.isEmpty) return null;

      // 提取时间
      final timeSlot = _extractTimeSlot(input);
      if (timeSlot == null) return null;

      // 提取事件名称
      final name = _extractEventName(input);
      if (name.isEmpty) return null;

      // 提取地点
      final location = _extractLocation(input);

      // 判断事件类型
      final type = _detectEventType(input, name);

      // 根据类型选择策略
      final policy = _getPolicyForType(type);

      return ScheduleEvent(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        type: type,
        timeSlot: timeSlot,
        weekdays: weekdays,
        location: location,
        description: null,
        policy: policy,
        createdAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('解析日程失败: $e');
      return null;
    }
  }

  List<int> _extractWeekdays(String input) {
    final weekdays = <int>[];
    final lower = input.toLowerCase();

    // 每天
    if (lower.contains('每天') || lower.contains('每日')) {
      return [1, 2, 3, 4, 5, 6, 7];
    }

    // 工作日
    if (lower.contains('工作日') || lower.contains('周一到周五')) {
      return [1, 2, 3, 4, 5];
    }

    // 周末
    if (lower.contains('周末')) {
      return [6, 7];
    }

    // 具体星期
    final weekdayMap = {
      '周一': 1, '星期一': 1,
      '周二': 2, '星期二': 2,
      '周三': 3, '星期三': 3,
      '周四': 4, '星期四': 4,
      '周五': 5, '星期五': 5,
      '周六': 6, '星期六': 6,
      '周日': 7, '星期天': 7, '星期日': 7,
    };

    for (var entry in weekdayMap.entries) {
      if (lower.contains(entry.key)) {
        if (!weekdays.contains(entry.value)) {
          weekdays.add(entry.value);
        }
      }
    }

    return weekdays..sort();
  }

  TimeSlot? _extractTimeSlot(String input) {
    // 匹配 "8点"、"8:00"、"8点半"、"9点30"
    final timeReg = RegExp(r'(\d{1,2})[:点](\d{0,2})?([分时]?)');
    final matches = timeReg.allMatches(input).toList();

    if (matches.isEmpty) return null;

    // 解析开始时间
    final startMatch = matches[0];
    final startHour = int.parse(startMatch.group(1)!);
    var startMinute = 0;
    if (startMatch.group(2) != null && startMatch.group(2)!.isNotEmpty) {
      startMinute = int.parse(startMatch.group(2)!);
    } else if (startMatch.group(3) == '半') {
      startMinute = 30;
    }

    // 判断是否为12小时制（上午/下午）
    var adjustedStartHour = startHour;
    if (input.contains('下午') || input.contains('晚上')) {
      if (startHour < 12) adjustedStartHour += 12;
    }

    // 解析结束时间或时长
    var durationMinutes = 60; // 默认1小时

    if (matches.length >= 2) {
      // 有明确的结束时间
      final endMatch = matches[1];
      final endHour = int.parse(endMatch.group(1)!);
      var endMinute = 0;
      if (endMatch.group(2) != null && endMatch.group(2)!.isNotEmpty) {
        endMinute = int.parse(endMatch.group(2)!);
      } else if (endMatch.group(3) == '半') {
        endMinute = 30;
      }

      var adjustedEndHour = endHour;
      if (input.contains('下午') || input.contains('晚上')) {
        if (endHour < 12) adjustedEndHour += 12;
      }

      durationMinutes = (adjustedEndHour * 60 + endMinute) -
                        (adjustedStartHour * 60 + startMinute);
    } else {
      // 没有结束时间，尝试提取时长
      final durationReg = RegExp(r'(\d+)[\s]*小时');
      final durationMatch = durationReg.firstMatch(input);
      if (durationMatch != null) {
        durationMinutes = int.parse(durationMatch.group(1)!) * 60;
      }

      // 匹配 "一个半小时"
      if (input.contains('一个半小时')) {
        durationMinutes = 90;
      } else if (input.contains('半小时')) {
        durationMinutes = 30;
      }
    }

    if (durationMinutes <= 0) durationMinutes = 60;

    return TimeSlot(
      hour: adjustedStartHour,
      minute: startMinute,
      durationMinutes: durationMinutes,
    );
  }

  String _extractEventName(String input) {
    // 常见课程关键词
    final courseKeywords = [
      '高数', '数学', '英语', '物理', '化学', '语文',
      '专业课', '选修', '必修', '实验', '讨论',
    ];

    // 常见活动关键词
    final activityKeywords = [
      '健身', '跑步', '瑜伽', '运动', '游泳',
      '自习', '学习', '复习', '预习', '阅读',
      '会议', '组会', '班会', '面试', '约会',
    ];

    // 尝试提取 "有X课" 或 "X时间"
    final haveReg = RegExp(r'有([\u4e00-\u9fa5]{2,5})[课]');
    final haveMatch = haveReg.firstMatch(input);
    if (haveMatch != null) {
      return haveMatch.group(1)!;
    }

    // 尝试提取关键词组合
    for (var keyword in [...courseKeywords, ...activityKeywords]) {
      if (input.contains(keyword)) {
        // 查找关键词前后是否有更完整的名称
        final reg = RegExp('([\\u4e00-\\u9fa5]{0,3}$keyword[\\u4e00-\\u9fa5]{0,3})');
        final match = reg.firstMatch(input);
        if (match != null) {
          return match.group(1)!.trim();
        }
        return keyword;
      }
    }

    // 默认提取"点"和"到"之间的内容
    final reg = RegExp(r'点(.+?)(到|至|-)');
    final match = reg.firstMatch(input);
    if (match != null) {
      return match.group(1)!.trim();
    }

    return '';
  }

  String? _extractLocation(String input) {
    // 匹配 "@地点" 或 "在地点"
    final atReg = RegExp(r'[@在]([\u4e00-\u9fa5a-zA-Z0-9\-]+(?:教室|楼|馆|室|房|厅))');
    final atMatch = atReg.firstMatch(input);
    if (atMatch != null) {
      return atMatch.group(1);
    }

    // 匹配 "XX教室"、"XX楼"
    final roomReg = RegExp(r'([\u4e00-\u9fa5]*[a-zA-Z]?\d+[\-a-zA-Z0-9]*(?:教室|楼))');
    final roomMatch = roomReg.firstMatch(input);
    if (roomMatch != null) {
      return roomMatch.group(1);
    }

    return null;
  }

  EventType _detectEventType(String input, String name) {
    final lower = input.toLowerCase();
    final nameLower = name.toLowerCase();

    // 课程相关
    if (lower.contains('课') ||
        nameLower.contains('数学') ||
        nameLower.contains('英语') ||
        nameLower.contains('物理') ||
        nameLower.contains('化学') ||
        nameLower.contains('专业')) {
      return EventType.course;
    }

    // 健身相关
    if (lower.contains('健身') ||
        lower.contains('跑步') ||
        lower.contains('运动') ||
        lower.contains('瑜伽') ||
        lower.contains('游泳')) {
      return EventType.exercise;
    }

    // 自习/学习
    if (lower.contains('自习') ||
        lower.contains('学习') ||
        lower.contains('复习') ||
        lower.contains('阅读')) {
      return EventType.study;
    }

    // 会议
    if (lower.contains('会议') ||
        lower.contains('组会') ||
        lower.contains('面试') ||
        lower.contains('讨论')) {
      return EventType.meeting;
    }

    return EventType.custom;
  }

  DeviceUsagePolicy _getPolicyForType(EventType type) {
    switch (type) {
      case EventType.course:
      case EventType.meeting:
        return DeviceUsagePolicy.focusMode(); // 专注模式
      case EventType.study:
        return DeviceUsagePolicy.focusMode(); // 专注模式
      case EventType.exercise:
        return DeviceUsagePolicy(
          allowToolUsage: true,
          entertainmentLimitMinutes: 10, // 健身可以稍微宽松
        );
      case EventType.custom:
        return DeviceUsagePolicy.relaxedMode(); // 宽松模式
    }
  }
}
