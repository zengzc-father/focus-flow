import '../models/app_usage.dart';

/// 中国热门应用分类数据库
///
/// 基于中国用户实际手机应用使用情况设计
/// 包含：包名映射、意图分类、使用场景建议
class ChineseAppDatabase {

  // ==================== 通讯类应用 ====================

  static const Map<String, AppInfo> communicationApps = {
    // 微信生态
    'com.tencent.mm': AppInfo(
      name: '微信',
      package: 'com.tencent.mm',
      intent: UsageIntent.communication,
      subCategory: AppSubCategory.social,
      description: '国民级社交应用',
      commonUsage: '消息、朋友圈、小程序',
    ),
    // QQ
    'com.tencent.mobileqq': AppInfo(
      name: 'QQ',
      package: 'com.tencent.mobileqq',
      intent: UsageIntent.communication,
      subCategory: AppSubCategory.social,
      description: '年轻人社交',
      commonUsage: '群聊、文件传输',
    ),
    // 钉钉
    'com.alibaba.android.rimet': AppInfo(
      name: '钉钉',
      package: 'com.alibaba.android.rimet',
      intent: UsageIntent.communication,
      subCategory: AppSubCategory.work,
      description: '办公通讯',
      commonUsage: '打卡、会议、审批',
    ),
    // 飞书
    'com.ss.android.lark': AppInfo(
      name: '飞书',
      package: 'com.ss.android.lark',
      intent: UsageIntent.communication,
      subCategory: AppSubCategory.work,
      description: '字节办公套件',
      commonUsage: '文档协作、会议',
    ),
    // 企业微信
    'com.tencent.wework': AppInfo(
      name: '企业微信',
      package: 'com.tencent.wework',
      intent: UsageIntent.communication,
      subCategory: AppSubCategory.work,
      description: '企业沟通',
      commonUsage: '工作沟通',
    ),
    // 微博
    'com.sina.weibo': AppInfo(
      name: '微博',
      package: 'com.sina.weibo',
      intent: UsageIntent.entertainment, // 偏向娱乐
      subCategory: AppSubCategory.social,
      description: '社交媒体',
      commonUsage: '看热点、追星',
    ),
  };

  // ==================== 娱乐短视频/内容类 ====================

  static const Map<String, AppInfo> entertainmentApps = {
    // 抖音系
    'com.ss.android.ugc.aweme': AppInfo(
      name: '抖音',
      package: 'com.ss.android.ugc.aweme',
      intent: UsageIntent.entertainment,
      subCategory: AppSubCategory.shortVideo,
      description: '短视频平台老大',
      commonUsage: '刷视频、直播',
      highAddictive: true, // 高成瘾性
    ),
    // 抖音极速版
    'com.ss.android.ugc.aweme.lite': AppInfo(
      name: '抖音极速版',
      package: 'com.ss.android.ugc.aweme.lite',
      intent: UsageIntent.entertainment,
      subCategory: AppSubCategory.shortVideo,
      description: '抖音轻量版',
      highAddictive: true,
    ),
    // 快手
    'com.smile.gifmaker': AppInfo(
      name: '快手',
      package: 'com.smile.gifmaker',
      intent: UsageIntent.entertainment,
      subCategory: AppSubCategory.shortVideo,
      description: '短视频老二',
      commonUsage: '刷视频、看直播',
      highAddictive: true,
    ),
    // 快手极速版
    'com.kuaishou.nebula': AppInfo(
      name: '快手极速版',
      package: 'com.kuaishou.nebula',
      intent: UsageIntent.entertainment,
      subCategory: AppSubCategory.shortVideo,
      highAddictive: true,
    ),
    // B站
    'tv.danmaku.bili': AppInfo(
      name: '哔哩哔哩',
      package: 'tv.danmaku.bili',
      intent: UsageIntent.entertainment,
      subCategory: AppSubCategory.video,
      description: '年轻人视频社区',
      commonUsage: '看番、学习视频',
      note: '也有学习内容，但偏娱乐',
    ),
    // 小红书
    'com.xingin.xhs': AppInfo(
      name: '小红书',
      package: 'com.xingin.xhs',
      intent: UsageIntent.entertainment,
      subCategory: AppSubCategory.social,
      description: '生活方式分享',
      commonUsage: '种草、看攻略',
      highAddictive: true,
    ),
    // 知乎
    'com.zhihu.android': AppInfo(
      name: '知乎',
      package: 'com.zhihu.android',
      intent: UsageIntent.study, // 可算学习
      subCategory: AppSubCategory.knowledge,
      description: '问答社区',
      commonUsage: '查知识、看文章',
    ),
    // 今日头条
    'com.ss.android.article.news': AppInfo(
      name: '今日头条',
      package: 'com.ss.android.article.news',
      intent: UsageIntent.entertainment,
      subCategory: AppSubCategory.news,
      description: '资讯推荐',
      commonUsage: '刷新闻',
      highAddictive: true,
    ),
    // 番茄小说
    'com.dragon.read': AppInfo(
      name: '番茄免费小说',
      package: 'com.dragon.read',
      intent: UsageIntent.entertainment,
      subCategory: AppSubCategory.reading,
      description: '免费小说',
      commonUsage: '看小说',
      highAddictive: true,
    ),
    // 七猫小说
    'com.kmxs.reader': AppInfo(
      name: '七猫免费小说',
      package: 'com.kmxs.reader',
      intent: UsageIntent.entertainment,
      subCategory: AppSubCategory.reading,
      highAddictive: true,
    ),
  };

  // ==================== 游戏类 ====================

  static const Map<String, AppInfo> gameApps = {
    // 腾讯系游戏
    'com.tencent.tmgp.sgame': AppInfo(
      name: '王者荣耀',
      package: 'com.tencent.tmgp.sgame',
      intent: UsageIntent.entertainment,
      subCategory: AppSubCategory.game,
      description: '国民MOBA手游',
      commonUsage: '对战',
      highAddictive: true,
      gameSessionMinutes: 20, // 一局约20分钟
    ),
    'com.tencent.jkchess': AppInfo(
      name: '金铲铲之战',
      package: 'com.tencent.jkchess',
      intent: UsageIntent.entertainment,
      subCategory: AppSubCategory.game,
      description: '自走棋',
      highAddictive: true,
    ),
    'com.tencent.tmgp.pubgmhd': AppInfo(
      name: '和平精英',
      package: 'com.tencent.tmgp.pubgmhd',
      intent: UsageIntent.entertainment,
      subCategory: AppSubCategory.game,
      description: '吃鸡手游',
      highAddictive: true,
    ),
    // 米哈游
    'com.miHoYo.Yuanshen': AppInfo(
      name: '原神',
      package: 'com.miHoYo.Yuanshen',
      intent: UsageIntent.entertainment,
      subCategory: AppSubCategory.game,
      description: '开放世界RPG',
      highAddictive: true,
    ),
    'com.miHoYo.hkrpg': AppInfo(
      name: '崩坏：星穹铁道',
      package: 'com.miHoYo.hkrpg',
      intent: UsageIntent.entertainment,
      subCategory: AppSubCategory.game,
      highAddictive: true,
    ),
    // 网易游戏
    'com.netease.onmyoji': AppInfo(
      name: '阴阳师',
      package: 'com.netease.onmyoji',
      intent: UsageIntent.entertainment,
      subCategory: AppSubCategory.game,
      highAddictive: true,
    ),
    // 其他热门
    'com.hypergryph.arknights': AppInfo(
      name: '明日方舟',
      package: 'com.hypergryph.arknights',
      intent: UsageIntent.entertainment,
      subCategory: AppSubCategory.game,
      highAddictive: true,
    ),
    'com.lemon.lv': AppInfo(
      name: '光·遇',
      package: 'com.lemon.lv',
      intent: UsageIntent.entertainment,
      subCategory: AppSubCategory.game,
    ),
  };

  // ==================== 音乐类 ====================

  static const Map<String, AppInfo> musicApps = {
    'com.netease.cloudmusic': AppInfo(
      name: '网易云音乐',
      package: 'com.netease.cloudmusic',
      intent: UsageIntent.music,
      subCategory: AppSubCategory.music,
      description: '音乐平台',
      commonUsage: '听歌',
      note: '健身时推荐使用',
    ),
    'com.tencent.qqmusic': AppInfo(
      name: 'QQ音乐',
      package: 'com.tencent.qqmusic',
      intent: UsageIntent.music,
      subCategory: AppSubCategory.music,
      description: '腾讯音乐',
      commonUsage: '听歌',
    ),
    'com.kugou.android': AppInfo(
      name: '酷狗音乐',
      package: 'com.kugou.android',
      intent: UsageIntent.music,
      subCategory: AppSubCategory.music,
      description: '酷狗音乐',
    ),
    'cn.kuwo.player': AppInfo(
      name: '酷我音乐',
      package: 'cn.kuwo.player',
      intent: UsageIntent.music,
      subCategory: AppSubCategory.music,
    ),
    'com.spotify.music': AppInfo(
      name: 'Spotify',
      package: 'com.spotify.music',
      intent: UsageIntent.music,
      subCategory: AppSubCategory.music,
    ),
    'com.apple.android.music': AppInfo(
      name: 'Apple Music',
      package: 'com.apple.android.music',
      intent: UsageIntent.music,
      subCategory: AppSubCategory.music,
    ),
  };

  // ==================== 学习/工具类 ====================

  static const Map<String, AppInfo> studyApps = {
    // 学习平台
    'com.chaoxing.mobile': AppInfo(
      name: '学习通',
      package: 'com.chaoxing.mobile',
      intent: UsageIntent.study,
      subCategory: AppSubCategory.education,
      description: '高校学习平台',
      commonUsage: '签到、看课件',
    ),
    'com.zhihu.android': AppInfo(
      name: '知乎',
      package: 'com.zhihu.android',
      intent: UsageIntent.study,
      subCategory: AppSubCategory.knowledge,
      description: '知识问答',
    ),
    'com.baidu.wenku': AppInfo(
      name: '百度文库',
      package: 'com.baidu.wenku',
      intent: UsageIntent.study,
      subCategory: AppSubCategory.education,
      description: '文档资料',
    ),
    'com.wanmei.tiger': AppInfo(
      name: '不背单词',
      package: 'com.wanmei.tiger',
      intent: UsageIntent.study,
      subCategory: AppSubCategory.education,
      description: '背单词',
    ),
    'com.youxiang.soyoungapp': AppInfo(
      name: '百词斩',
      package: 'com.youxiang.soyoungapp',
      intent: UsageIntent.study,
      subCategory: AppSubCategory.education,
      description: '背单词',
    ),
    'com.fenbi.android.zhexue': AppInfo(
      name: '粉笔',
      package: 'com.fenbi.android.zhexue',
      intent: UsageIntent.study,
      subCategory: AppSubCategory.education,
      description: '考公/考研',
    ),
    'com.eebbk.parentalcontrol': AppInfo(
      name: ' Timing ',
      package: 'com.eebbk.parentalcontrol',
      intent: UsageIntent.study,
      subCategory: AppSubCategory.education,
      description: '学习计时',
    ),
    // WPS办公
    'cn.wps.moffice_eng': AppInfo(
      name: 'WPS Office',
      package: 'cn.wps.moffice_eng',
      intent: UsageIntent.tool,
      subCategory: AppSubCategory.productivity,
      description: '办公软件',
      commonUsage: '文档、表格',
    ),
    // 笔记类
    'com.yinxiang': AppInfo(
      name: '印象笔记',
      package: 'com.yinxiang',
      intent: UsageIntent.tool,
      subCategory: AppSubCategory.productivity,
      description: '笔记软件',
    ),
    'com.jianshu.haruki': AppInfo(
      name: '简书',
      package: 'com.jianshu.haruki',
      intent: UsageIntent.study,
      subCategory: AppSubCategory.writing,
      description: '写作阅读',
    ),
    // 词典翻译
    'com.kingsoft': AppInfo(
      name: '金山词霸',
      package: 'com.kingsoft',
      intent: UsageIntent.tool,
      subCategory: AppSubCategory.education,
    ),
    'com.youdao.dict': AppInfo(
      name: '有道词典',
      package: 'com.youdao.dict',
      intent: UsageIntent.tool,
      subCategory: AppSubCategory.education,
    ),
  };

  // ==================== 购物/生活类 ====================

  static const Map<String, AppInfo> shoppingApps = {
    // 电商
    'com.taobao.taobao': AppInfo(
      name: '淘宝',
      package: 'com.taobao.taobao',
      intent: UsageIntent.entertainment, // 容易刷
      subCategory: AppSubCategory.shopping,
      description: '电商平台',
      commonUsage: '购物、刷推荐',
      highAddictive: true,
    ),
    'com.jingdong.app.mall': AppInfo(
      name: '京东',
      package: 'com.jingdong.app.mall',
      intent: UsageIntent.tool, // 目的性强
      subCategory: AppSubCategory.shopping,
      description: '京东购物',
    ),
    'com.xunmeng.pinduoduo': AppInfo(
      name: '拼多多',
      package: 'com.xunmeng.pinduoduo',
      intent: UsageIntent.entertainment,
      subCategory: AppSubCategory.shopping,
      description: '拼团购物',
      highAddictive: true,
    ),
    'com.sankuai.meituan': AppInfo(
      name: '美团',
      package: 'com.sankuai.meituan',
      intent: UsageIntent.tool,
      subCategory: AppSubCategory.life,
      description: '外卖/团购',
    ),
    'com.dianping.v1': AppInfo(
      name: '大众点评',
      package: 'com.dianping.v1',
      intent: UsageIntent.tool,
      subCategory: AppSubCategory.life,
      description: '找餐厅',
    ),
    // 出行
    'com.autonavi.minimap': AppInfo(
      name: '高德地图',
      package: 'com.autonavi.minimap',
      intent: UsageIntent.tool,
      subCategory: AppSubCategory.navigation,
      description: '导航',
    ),
    'com.baidu.BaiduMap': AppInfo(
      name: '百度地图',
      package: 'com.baidu.BaiduMap',
      intent: UsageIntent.tool,
      subCategory: AppSubCategory.navigation,
    ),
    'com.didichuxing': AppInfo(
      name: '滴滴出行',
      package: 'com.didichuxing',
      intent: UsageIntent.tool,
      subCategory: AppSubCategory.navigation,
    ),
    // 支付
    'com.eg.android.AlipayGphone': AppInfo(
      name: '支付宝',
      package: 'com.eg.android.AlipayGphone',
      intent: UsageIntent.tool,
      subCategory: AppSubCategory.finance,
      description: '支付/生活服务',
    ),
  };

  // ==================== 系统工具类 ====================

  static const Map<String, AppInfo> systemApps = {
    'com.android.chrome': AppInfo(
      name: 'Chrome',
      package: 'com.android.chrome',
      intent: UsageIntent.tool,
      subCategory: AppSubCategory.browser,
      description: '浏览器',
      note: '查资料是正当使用',
    ),
    'com.android.browser': AppInfo(
      name: '浏览器',
      package: 'com.android.browser',
      intent: UsageIntent.tool,
      subCategory: AppSubCategory.browser,
    ),
    'com.android.camera': AppInfo(
      name: '相机',
      package: 'com.android.camera',
      intent: UsageIntent.tool,
      subCategory: AppSubCategory.system,
      description: '拍板书/资料',
    ),
    'com.android.calculator2': AppInfo(
      name: '计算器',
      package: 'com.android.calculator2',
      intent: UsageIntent.tool,
      subCategory: AppSubCategory.system,
    ),
    'com.android.settings': AppInfo(
      name: '设置',
      package: 'com.android.settings',
      intent: UsageIntent.tool,
      subCategory: AppSubCategory.system,
    ),
  };

  // ==================== 合并所有应用 ====================

  static Map<String, AppInfo> get allApps => {
    ...communicationApps,
    ...entertainmentApps,
    ...gameApps,
    ...musicApps,
    ...studyApps,
    ...shoppingApps,
    ...systemApps,
  };

  /// 根据包名获取应用信息
  static AppInfo? getAppInfo(String packageName) {
    return allApps[packageName];
  }

  /// 根据应用名称获取应用信息
  static AppInfo? getAppByName(String appName) {
    final lowerName = appName.toLowerCase();

    for (var entry in allApps.entries) {
      final app = entry.value;
      if (app.name.toLowerCase() == lowerName ||
          app.name.toLowerCase().contains(lowerName) ||
          lowerName.contains(app.name.toLowerCase())) {
        return app;
      }
    }

    return null;
  }

  /// 获取应用意图（自动识别）
  static UsageIntent getAppIntent(String packageName) {
    final app = getAppInfo(packageName);
    if (app != null) {
      return app.intent;
    }

    // 根据包名关键词推测
    final lower = packageName.toLowerCase();
    if (lower.contains('game') || lower.contains('tencent.tmgp')) {
      return UsageIntent.entertainment;
    }
    if (lower.contains('music') || lower.contains('audio')) {
      return UsageIntent.music;
    }
    if (lower.contains('edu') || lower.contains('learn')) {
      return UsageIntent.study;
    }
    if (lower.contains('chat') || lower.contains('im.')) {
      return UsageIntent.communication;
    }

    return UsageIntent.unknown;
  }

  /// 判断是否高成瘾性应用
  static bool isHighAddictive(String packageName) {
    final app = getAppInfo(packageName);
    return app?.highAddictive ?? false;
  }

  /// 获取应用名称
  static String getAppName(String packageName) {
    final app = getAppInfo(packageName);
    return app?.name ?? packageName.split('.').last;
  }
}

/// 应用信息
class AppInfo {
  final String name;
  final String package;
  final UsageIntent intent;
  final AppSubCategory subCategory;
  final String description;
  final String? commonUsage;
  final bool highAddictive;
  final int? gameSessionMinutes;
  final String? note;

  const AppInfo({
    required this.name,
    required this.package,
    required this.intent,
    required this.subCategory,
    this.description = '',
    this.commonUsage,
    this.highAddictive = false,
    this.gameSessionMinutes,
    this.note,
  });
}

/// 应用子分类
enum AppSubCategory {
  social,       // 社交
  work,         // 办公
  shortVideo,   // 短视频
  video,        // 长视频
  news,         // 新闻资讯
  reading,      // 阅读
  game,         // 游戏
  music,        // 音乐
  education,    // 教育学习
  knowledge,    // 知识
  productivity, // 生产力
  writing,      // 写作
  shopping,     // 购物
  life,         // 生活服务
  navigation,   // 导航出行
  finance,      // 金融支付
  browser,      // 浏览器
  system,       // 系统工具
}

/// 中国用户典型应用使用场景
class ChineseUsageScenarios {

  /// 上课场景典型行为
  static Map<String, int> classScenarioThresholds = {
    '抖音': 3,
    '快手': 3,
    '小红书': 5,
    '微信': 10,
    'QQ': 10,
    '知乎': 20,
    'B站': 10,
    '游戏': 0, // 完全禁止
    '音乐': 0, // 不推荐
  };

  /// 自习场景典型行为
  static Map<String, int> studyScenarioThresholds = {
    '抖音': 5,
    'B站学习视频': 30, // 学习视频容忍度较高
    '微信': 15,
    '知乎': 30,
    'WPS': 60, // 学习工具宽容
    '学习通': 60,
  };

  /// 健身场景典型行为
  static Map<String, int> exerciseScenarioThresholds = {
    '网易云音乐': 120, // 鼓励！
    'QQ音乐': 120,
    '抖音': 10, // 组间休息可以刷
    '微信': 20,
    '游戏': 5, // 不太合理
  };

  /// 睡前场景（需要提醒）
  static Map<String, int> bedtimeScenarioThresholds = {
    '抖音': 10, // 睡前刷视频容易停不下来
    '游戏': 0, // 睡前不应游戏
    '小说': 15, // 看小说容易熬夜
  };
}
