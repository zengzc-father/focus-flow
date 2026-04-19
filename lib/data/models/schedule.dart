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

// ScheduleRepository 类已移至 ../services/schedule_repository.dart
// 请使用: import '../services/schedule_repository.dart';
