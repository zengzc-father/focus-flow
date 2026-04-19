# Focus Flow 项目结构

```
focus-flow-app/
├── android/                          # Android原生代码
│   ├── app/
│   │   ├── build.gradle             # 应用构建配置
│   │   └── src/
│   │       └── main/
│   │           ├── AndroidManifest.xml   # 权限声明
│   │           ├── kotlin/               # Kotlin代码
│   │           └── res/                  # 资源文件
│   └── build.gradle                 # 项目构建配置
│
├── ios/                             # iOS原生代码
│   ├── Podfile                      # CocoaPods配置
│   ├── Runner/
│   │   ├── Info.plist               # 应用配置
│   │   └── AppDelegate.swift        # 应用入口
│   └── Runner.xcworkspace           # Xcode工作区
│
├── lib/                             # Dart源代码
│   ├── main.dart                    # 应用入口
│   ├── app.dart                     # 应用配置
│   │
│   ├── core/                        # 核心层
│   │   ├── constants/               # 常量定义
│   │   ├── theme/                   # 主题配置
│   │   │   └── app_theme.dart       # 颜色/样式定义
│   │   ├── utils/                   # 工具类
│   │   └── extensions/              # 扩展方法
│   │
│   ├── data/                        # 数据层
│   │   ├── models/                  # 数据模型
│   │   │   └── app_usage.dart       # 使用统计模型
│   │   ├── repositories/            # 数据仓库
│   │   └── services/                # 服务类
│   │       ├── usage_stats_service.dart      # 使用统计服务
│   │       ├── notification_service.dart     # 通知服务
│   │       ├── background_service.dart       # 后台任务
│   │       ├── alternative_activities_service.dart  # 活动建议
│   │       └── initialization_service.dart   # 初始化
│   │
│   ├── domain/                      # 领域层
│   │   ├── entities/                # 领域实体
│   │   ├── usecases/                # 用例
│   │   └── providers/               # Riverpod提供者
│   │
│   └── presentation/                # 表现层
│       ├── screens/                 # 页面
│       │   ├── home/                # 首页
│       │   │   ├── home_screen.dart
│       │   │   └── widgets/         # 首页组件
│       │   │       ├── usage_card.dart
│       │   │       ├── quick_actions.dart
│       │   │       ├── today_stats.dart
│       │   │       └── alternative_activities_preview.dart
│       │   ├── stats/               # 统计页
│       │   │   ├── stats_screen.dart
│       │   │   └── widgets/
│       │   │       ├── weekly_chart.dart
│       │   │       └── app_usage_list.dart
│       │   ├── settings/            # 设置页
│       │   │   └── settings_screen.dart
│       │   └── alternatives/        # 替代活动页
│       │       └── alternatives_screen.dart
│       ├── widgets/                 # 通用组件
│       └── viewmodels/              # 视图模型
│
├── assets/                          # 静态资源
│   ├── images/                      # 图片
│   ├── animations/                  # Lottie动画
│   ├── icons/                       # 图标
│   └── models/                      # LLM模型文件
│
├── test/                            # 测试代码
├── pubspec.yaml                     # 依赖配置
├── analysis_options.yaml            # Dart分析配置
└── README.md                        # 项目说明
```

## 关键文件说明

| 文件 | 作用 |
|------|------|
| `main.dart` | 应用入口，初始化Provider |
| `app.dart` | 应用配置，路由定义 |
| `app_theme.dart` | 主题色、字体、组件样式 |
| `app_usage.dart` | 数据模型（Freezed生成） |
| `usage_stats_service.dart` | 调用Android UsageStatsManager |
| `notification_service.dart` | 本地通知管理 |
| `background_service.dart` | 后台定时任务 |
| `home_screen.dart` | 主界面，使用统计展示 |
