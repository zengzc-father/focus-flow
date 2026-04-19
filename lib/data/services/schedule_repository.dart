import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/schedule.dart';

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

    return null;
  }
}
