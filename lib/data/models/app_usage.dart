import 'package:flutter/foundation.dart';

/// 应用使用数据模型（手动实现，不依赖 freezed）
class AppUsage {
  final String packageName;
  final String appName;
  final int usageTimeInSeconds;
  final DateTime date;
  final String? category;
  final UsageIntent intent;

  AppUsage({
    required this.packageName,
    required this.appName,
    required this.usageTimeInSeconds,
    required this.date,
    this.category,
    this.intent = UsageIntent.other,
  });

  factory AppUsage.fromJson(Map<String, dynamic> json) => AppUsage(
    packageName: json['packageName'] ?? '',
    appName: json['appName'] ?? '',
    usageTimeInSeconds: json['usageTimeInSeconds'] ?? 0,
    date: DateTime.parse(json['date'] ?? DateTime.now().toIso8601String()),
    category: json['category'],
    intent: UsageIntent.values[json['intent'] ?? 0],
  );

  Map<String, dynamic> toJson() => {
    'packageName': packageName,
    'appName': appName,
    'usageTimeInSeconds': usageTimeInSeconds,
    'date': date.toIso8601String(),
    'category': category,
    'intent': intent.index,
  };

  factory AppUsage.empty(String packageName) => AppUsage(
    packageName: packageName,
    appName: packageName,
    usageTimeInSeconds: 0,
    date: DateTime.now(),
  );

  int get usageTimeInMinutes => usageTimeInSeconds ~/ 60;

  AppUsage copyWith({
    String? packageName,
    String? appName,
    int? usageTimeInSeconds,
    DateTime? date,
    String? category,
    UsageIntent? intent,
  }) => AppUsage(
    packageName: packageName ?? this.packageName,
    appName: appName ?? this.appName,
    usageTimeInSeconds: usageTimeInSeconds ?? this.usageTimeInSeconds,
    date: date ?? this.date,
    category: category ?? this.category,
    intent: intent ?? this.intent,
  );

  @override
  String toString() => 'AppUsage($appName: ${usageTimeInMinutes}min)';
}

/// 应用使用意图分类
enum UsageIntent {
  entertainment,  // 娱乐（抖音、游戏等）
  communication,  // 通讯（微信、QQ等）
  study,          // 学习（学习通、知乎等）
  tool,           // 工具（相机、计算器等）
  music,          // 音乐
  news,           // 新闻
  shopping,       // 购物
  other,          // 其他
  unknown,        // 未知
}

extension UsageIntentExtension on UsageIntent {
  String get displayName {
    switch (this) {
      case UsageIntent.entertainment:
        return '娱乐';
      case UsageIntent.communication:
        return '通讯';
      case UsageIntent.study:
        return '学习';
      case UsageIntent.tool:
        return '工具';
      case UsageIntent.music:
        return '音乐';
      case UsageIntent.news:
        return '新闻';
      case UsageIntent.shopping:
        return '购物';
      case UsageIntent.other:
        return '其他';
      case UsageIntent.unknown:
        return '未知';
    }
  }

  bool get isEntertainment => this == UsageIntent.entertainment;
  bool get isCommunication => this == UsageIntent.communication;
  bool get isStudy => this == UsageIntent.study;
}

/// 每日使用统计
class DailyUsage {
  final DateTime date;
  final int totalScreenTime;
  final int unlockCount;
  final List<AppUsage> appUsages;

  DailyUsage({
    required this.date,
    required this.totalScreenTime,
    required this.unlockCount,
    required this.appUsages,
  });

  factory DailyUsage.fromJson(Map<String, dynamic> json) => DailyUsage(
    date: DateTime.parse(json['date'] ?? DateTime.now().toIso8601String()),
    totalScreenTime: json['totalScreenTime'] ?? 0,
    unlockCount: json['unlockCount'] ?? 0,
    appUsages: (json['appUsages'] as List?)
        ?.map((e) => AppUsage.fromJson(e as Map<String, dynamic>))
        .toList() ?? [],
  );

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'totalScreenTime': totalScreenTime,
    'unlockCount': unlockCount,
    'appUsages': appUsages.map((e) => e.toJson()).toList(),
  };

  factory DailyUsage.empty(DateTime date) => DailyUsage(
    date: date,
    totalScreenTime: 0,
    unlockCount: 0,
    appUsages: [],
  );

  int get totalScreenTimeMinutes => totalScreenTime ~/ 60;
  int get totalScreenTimeHours => totalScreenTime ~/ 3600;

  /// 获取应用使用映射表
  Map<String, AppUsage> get appUsage => {for (var u in appUsages) u.packageName: u};

  /// 按意图分类的使用时长
  Map<UsageIntent, int> get usageByIntent {
    final result = <UsageIntent, int>{};
    for (final usage in appUsages) {
      result[usage.intent] = (result[usage.intent] ?? 0) + usage.usageTimeInSeconds;
    }
    return result;
  }

  /// 获取娱乐使用时长
  int get entertainmentSeconds => usageByIntent[UsageIntent.entertainment] ?? 0;
  int get entertainmentMinutes => entertainmentSeconds ~/ 60;

  /// 获取学习使用时长
  int get studySeconds => usageByIntent[UsageIntent.study] ?? 0;
  int get studyMinutes => studySeconds ~/ 60;

  DailyUsage copyWith({
    DateTime? date,
    int? totalScreenTime,
    int? unlockCount,
    List<AppUsage>? appUsages,
  }) => DailyUsage(
    date: date ?? this.date,
    totalScreenTime: totalScreenTime ?? this.totalScreenTime,
    unlockCount: unlockCount ?? this.unlockCount,
    appUsages: appUsages ?? this.appUsages,
  );
}

/// 休息提醒
class RestReminder {
  final String id;
  final String title;
  final String message;
  final DateTime scheduledTime;
  final bool isCompleted;
  final String? alternativeActivity;

  RestReminder({
    required this.id,
    required this.title,
    required this.message,
    required this.scheduledTime,
    this.isCompleted = false,
    this.alternativeActivity,
  });

  factory RestReminder.fromJson(Map<String, dynamic> json) => RestReminder(
    id: json['id'] ?? '',
    title: json['title'] ?? '',
    message: json['message'] ?? '',
    scheduledTime: DateTime.parse(json['scheduledTime'] ?? DateTime.now().toIso8601String()),
    isCompleted: json['isCompleted'] ?? false,
    alternativeActivity: json['alternativeActivity'],
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'message': message,
    'scheduledTime': scheduledTime.toIso8601String(),
    'isCompleted': isCompleted,
    'alternativeActivity': alternativeActivity,
  };
}

/// 替代活动
class AlternativeActivity {
  final String id;
  final String title;
  final String description;
  final ActivityCategory category;
  final int suggestedDuration;
  final String icon;
  final String? benefit;

  const AlternativeActivity({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.suggestedDuration,
    required this.icon,
    this.benefit,
  });

  factory AlternativeActivity.fromJson(Map<String, dynamic> json) => AlternativeActivity(
    id: json['id'] ?? '',
    title: json['title'] ?? '',
    description: json['description'] ?? '',
    category: ActivityCategory.values[json['category'] ?? 0],
    suggestedDuration: json['suggestedDuration'] ?? 0,
    icon: json['icon'] ?? '',
    benefit: json['benefit'],
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'category': category.index,
    'suggestedDuration': suggestedDuration,
    'icon': icon,
    'benefit': benefit,
  };
}

/// 活动分类
enum ActivityCategory {
  study,
  exercise,
  relaxation,
  creative,
  social,
}

extension ActivityCategoryExtension on ActivityCategory {
  String get displayName {
    switch (this) {
      case ActivityCategory.study:
        return '学习';
      case ActivityCategory.exercise:
        return '运动';
      case ActivityCategory.relaxation:
        return '放松';
      case ActivityCategory.creative:
        return '创作';
      case ActivityCategory.social:
        return '社交';
    }
  }
}

/// 应用信息（从系统获取）
class AppUsageInfo {
  final String packageName;
  final String appName;
  final int durationMinutes;
  final UsageIntent intent;
  final bool isHighAddictive;

  AppUsageInfo({
    required this.packageName,
    required this.appName,
    required this.durationMinutes,
    this.intent = UsageIntent.other,
    this.isHighAddictive = false,
  });
}

/// 用户使用设置
class UserSettings {
  final int continuousUseLimitMinutes;
  final int shortBreakDurationMinutes;
  final bool enableEyeProtection;
  final bool enableBedtimeReminder;
  final int bedtimeHour;
  final int bedtimeMinute;
  final bool enableSmartSuggestions;
  final List<String> preferredActivityCategories;
  final bool notificationsEnabled;
  final int dailyGoalMinutes;

  const UserSettings({
    this.continuousUseLimitMinutes = 45,
    this.shortBreakDurationMinutes = 20,
    this.enableEyeProtection = true,
    this.enableBedtimeReminder = true,
    this.bedtimeHour = 22,
    this.bedtimeMinute = 30,
    this.enableSmartSuggestions = true,
    this.preferredActivityCategories = const [],
    this.notificationsEnabled = true,
    this.dailyGoalMinutes = 240,
  });

  factory UserSettings.fromJson(Map<String, dynamic> json) => UserSettings(
    continuousUseLimitMinutes: json['continuousUseLimitMinutes'] ?? 45,
    shortBreakDurationMinutes: json['shortBreakDurationMinutes'] ?? 20,
    enableEyeProtection: json['enableEyeProtection'] ?? true,
    enableBedtimeReminder: json['enableBedtimeReminder'] ?? true,
    bedtimeHour: json['bedtimeHour'] ?? 22,
    bedtimeMinute: json['bedtimeMinute'] ?? 30,
    enableSmartSuggestions: json['enableSmartSuggestions'] ?? true,
    preferredActivityCategories: (json['preferredActivityCategories'] as List?)
        ?.map((e) => e.toString())
        .toList() ?? [],
    notificationsEnabled: json['notificationsEnabled'] ?? true,
    dailyGoalMinutes: json['dailyGoalMinutes'] ?? 240,
  );

  Map<String, dynamic> toJson() => {
    'continuousUseLimitMinutes': continuousUseLimitMinutes,
    'shortBreakDurationMinutes': shortBreakDurationMinutes,
    'enableEyeProtection': enableEyeProtection,
    'enableBedtimeReminder': enableBedtimeReminder,
    'bedtimeHour': bedtimeHour,
    'bedtimeMinute': bedtimeMinute,
    'enableSmartSuggestions': enableSmartSuggestions,
    'preferredActivityCategories': preferredActivityCategories,
    'notificationsEnabled': notificationsEnabled,
    'dailyGoalMinutes': dailyGoalMinutes,
  };

  UserSettings copyWith({
    int? continuousUseLimitMinutes,
    int? shortBreakDurationMinutes,
    bool? enableEyeProtection,
    bool? enableBedtimeReminder,
    int? bedtimeHour,
    int? bedtimeMinute,
    bool? enableSmartSuggestions,
    List<String>? preferredActivityCategories,
    bool? notificationsEnabled,
    int? dailyGoalMinutes,
  }) => UserSettings(
    continuousUseLimitMinutes: continuousUseLimitMinutes ?? this.continuousUseLimitMinutes,
    shortBreakDurationMinutes: shortBreakDurationMinutes ?? this.shortBreakDurationMinutes,
    enableEyeProtection: enableEyeProtection ?? this.enableEyeProtection,
    enableBedtimeReminder: enableBedtimeReminder ?? this.enableBedtimeReminder,
    bedtimeHour: bedtimeHour ?? this.bedtimeHour,
    bedtimeMinute: bedtimeMinute ?? this.bedtimeMinute,
    enableSmartSuggestions: enableSmartSuggestions ?? this.enableSmartSuggestions,
    preferredActivityCategories: preferredActivityCategories ?? this.preferredActivityCategories,
    notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    dailyGoalMinutes: dailyGoalMinutes ?? this.dailyGoalMinutes,
  );
}
