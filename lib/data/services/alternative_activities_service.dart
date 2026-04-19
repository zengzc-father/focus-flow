import 'package:flutter/foundation.dart';
import 'package:focus_flow/data/models/app_usage.dart';

class AlternativeActivitiesService {
  static final AlternativeActivitiesService _instance =
      AlternativeActivitiesService._internal();
  factory AlternativeActivitiesService() => _instance;
  AlternativeActivitiesService._internal();

  // 活动数据库
  final List<AlternativeActivity> _activities = [
    // 学习类
    const AlternativeActivity(
      id: 'read_book',
      title: '阅读一本书',
      description: '拿起一本纸质书，沉浸在文字的世界中。阅读能提升专注力，还能积累知识。',
      category: ActivityCategory.study,
      suggestedDuration: 30,
      icon: '📚',
      benefit: '提升认知能力，减轻压力',
    ),
    const AlternativeActivity(
      id: 'review_notes',
      title: '复习笔记',
      description: '拿出今天的课堂笔记，回顾重点内容。及时复习是记忆的关键。',
      category: ActivityCategory.study,
      suggestedDuration: 20,
      icon: '📝',
      benefit: '巩固记忆，提高学习效率',
    ),
    const AlternativeActivity(
      id: 'plan_tomorrow',
      title: '规划明天',
      description: '拿出笔记本，规划明天的学习任务和时间安排。',
      category: ActivityCategory.study,
      suggestedDuration: 10,
      icon: '📅',
      benefit: '提高执行力，减少焦虑',
    ),

    // 运动类
    const AlternativeActivity(
      id: 'stretching',
      title: '伸展运动',
      description: '站起来，做一些简单的伸展运动，缓解颈部和背部压力。',
      category: ActivityCategory.exercise,
      suggestedDuration: 5,
      icon: '🧘',
      benefit: '缓解疲劳，改善体态',
    ),
    const AlternativeActivity(
      id: 'jump_rope',
      title: '跳绳',
      description: '拿出跳绳，跳100下。跳绳是最好的有氧运动之一。',
      category: ActivityCategory.exercise,
      suggestedDuration: 10,
      icon: '🏃',
      benefit: '增强心肺功能，消耗热量',
    ),
    const AlternativeActivity(
      id: 'eye_exercise',
      title: '眼保健操',
      description: '做一遍眼保健操，让眼睛得到充分放松。',
      category: ActivityCategory.exercise,
      suggestedDuration: 5,
      icon: '👁️',
      benefit: '保护视力，缓解眼疲劳',
    ),
    const AlternativeActivity(
      id: 'walk_outside',
      title: '出门走走',
      description: '放下手机，出门散散步，呼吸新鲜空气。',
      category: ActivityCategory.exercise,
      suggestedDuration: 15,
      icon: '🚶',
      benefit: '放松心情，改善睡眠',
    ),

    // 放松类
    const AlternativeActivity(
      id: 'meditation',
      title: '冥想放松',
      description: '闭上眼睛，深呼吸，进行5分钟冥想，清空思绪。',
      category: ActivityCategory.relaxation,
      suggestedDuration: 5,
      icon: '🧘‍♀️',
      benefit: '减轻压力，提升专注力',
    ),
    const AlternativeActivity(
      id: 'listen_music',
      title: '听音乐',
      description: '播放一首喜欢的音乐，静静欣赏，让音乐治愈心灵。',
      category: ActivityCategory.relaxation,
      suggestedDuration: 10,
      icon: '🎵',
      benefit: '改善情绪，减轻焦虑',
    ),
    const AlternativeActivity(
      id: 'drink_water',
      title: '喝杯温水',
      description: '起身倒一杯温水，慢慢饮用。保持水分充足很重要。',
      category: ActivityCategory.relaxation,
      suggestedDuration: 5,
      icon: '💧',
      benefit: '促进新陈代谢',
    ),

    // 创意类
    const AlternativeActivity(
      id: 'doodle',
      title: '随手涂鸦',
      description: '拿出纸笔，随意涂鸦，释放创造力。',
      category: ActivityCategory.creative,
      suggestedDuration: 10,
      icon: '🎨',
      benefit: '激发创造力，放松心情',
    ),
    const AlternativeActivity(
      id: 'journal',
      title: '写日记',
      description: '记录下今天的心情和想法，或者列一张感恩清单。',
      category: ActivityCategory.creative,
      suggestedDuration: 10,
      icon: '📓',
      benefit: '情绪调节，自我反思',
    ),
    const AlternativeActivity(
      id: 'origami',
      title: '折纸',
      description: '学习折一只纸鹤或其他简单的折纸作品。',
      category: ActivityCategory.creative,
      suggestedDuration: 15,
      icon: '🦢',
      benefit: '锻炼手脑协调，培养耐心',
    ),

    // 社交类
    const AlternativeActivity(
      id: 'call_family',
      title: '联系家人',
      description: '给父母或家人打个电话，关心一下他们的生活。',
      category: ActivityCategory.social,
      suggestedDuration: 10,
      icon: '📞',
      benefit: '增进感情，获得支持',
    ),
    const AlternativeActivity(
      id: 'chat_friend',
      title: '和朋友聊天',
      description: '约朋友见面聊天，或者进行一场有意义的对话。',
      category: ActivityCategory.social,
      suggestedDuration: 20,
      icon: '💬',
      benefit: '获得社交支持，改善心情',
    ),
    const AlternativeActivity(
      id: 'help_others',
      title: '帮助他人',
      description: '帮室友倒杯水，或者做一件力所能及的小事。',
      category: ActivityCategory.social,
      suggestedDuration: 5,
      icon: '🤝',
      benefit: '获得成就感，建立良好关系',
    ),
  ];

  // 根据使用时长获取建议
  List<AlternativeActivity> getSuggestionsByUsageTime(
    int usageMinutes, {
    List<ActivityCategory>? preferredCategories,
    int limit = 3,
  }) {
    // 根据使用时长选择合适类型的活动
    late List<ActivityCategory> targetCategories;

    if (usageMinutes < 30) {
      // 短时间使用：建议快速休息活动
      targetCategories = [ActivityCategory.exercise, ActivityCategory.relaxation];
    } else if (usageMinutes < 60) {
      // 中等时间：建议休息或学习转换
      targetCategories = [ActivityCategory.exercise, ActivityCategory.study, ActivityCategory.relaxation];
    } else if (usageMinutes < 120) {
      // 较长时间：强烈建议运动和放松
      targetCategories = [ActivityCategory.exercise, ActivityCategory.creative, ActivityCategory.social];
    } else {
      // 长时间使用：必须休息，远离屏幕
      targetCategories = [ActivityCategory.exercise, ActivityCategory.social, ActivityCategory.creative];
    }

    // 如果有偏好设置，优先考虑
    if (preferredCategories != null && preferredCategories.isNotEmpty) {
      targetCategories = preferredCategories;
    }

    // 筛选匹配的活动
    final suggestions = _activities
        .where((activity) => targetCategories.contains(activity.category))
        .toList();

    // 随机打乱并取前N个
    suggestions.shuffle();
    return suggestions.take(limit).toList();
  }

  // 获取特定类别的活动
  List<AlternativeActivity> getActivitiesByCategory(ActivityCategory category) {
    return _activities.where((a) => a.category == category).toList();
  }

  // 获取所有活动
  List<AlternativeActivity> getAllActivities() {
    return List.unmodifiable(_activities);
  }

  // 获取随机活动建议
  AlternativeActivity getRandomSuggestion() {
    return _activities[_randomIndex()];
  }

  int _randomIndex() {
    final now = DateTime.now();
    return now.millisecond % _activities.length;
  }

  // 根据时间段获取建议
  List<AlternativeActivity> getSuggestionsByTimeOfDay(DateTime time) {
    final hour = time.hour;

    if (hour >= 6 && hour < 12) {
      // 上午：建议学习或运动类
      return _activities
          .where((a) => a.category == ActivityCategory.study || a.category == ActivityCategory.exercise)
          .toList()
        ..shuffle();
    } else if (hour >= 12 && hour < 14) {
      // 中午：建议放松或社交
      return _activities
          .where((a) => a.category == ActivityCategory.relaxation || a.category == ActivityCategory.social)
          .toList()
        ..shuffle();
    } else if (hour >= 14 && hour < 18) {
      // 下午：建议学习或创意
      return _activities
          .where((a) => a.category == ActivityCategory.study || a.category == ActivityCategory.creative)
          .toList()
        ..shuffle();
    } else if (hour >= 18 && hour < 22) {
      // 晚上：建议运动、放松或社交
      return _activities
          .where((a) =>
              a.category == ActivityCategory.exercise ||
              a.category == ActivityCategory.relaxation ||
              a.category == ActivityCategory.social)
          .toList()
        ..shuffle();
    } else {
      // 深夜：建议休息
      return _activities
          .where((a) => a.category == ActivityCategory.relaxation)
          .toList()
        ..shuffle();
    }
  }
}
