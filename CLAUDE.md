# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Focus Flow** is an agent-driven screen time management app for students, built with Flutter. The core philosophy: users describe needs in natural language, and the Agent executes via Tools.

Key principles:
- **System UsageStats over custom tracking**: Zero extra battery drain, reads Android UsageStatsManager directly
- **On-demand Agent**: Only loads when app opens, releases immediately after
- **Context-aware monitoring**: Different thresholds for class/study/gym/free time
- **Chinese app database**: 50+ apps (WeChat, Douyin, Honor of Kings, etc.) with addiction ratings

## Build Commands

```bash
# Development
flutter pub get                          # Install dependencies
flutter run                             # Debug mode with hot reload
flutter run -d <device-id>              # Run on specific device
flutter devices                         # List available devices

# Code quality
flutter analyze                         # Static analysis
flutter format .                        # Format all Dart files
flutter test                            # Run all tests
flutter test test/widget_test.dart      # Run single test file

# Building
flutter build apk --release             # Release APK
flutter build apk --debug               # Debug APK (faster)
flutter build appbundle --release       # Google Play bundle

# Utilities
flutter clean && flutter pub get        # Clean rebuild
flutter logs                            # View device logs
flutter pub deps                        # View dependency tree
```

## Project Structure

```
lib/
├── main.dart                           # Entry point, initializes services
├── app.dart                            # App configuration (routes, theme)
│
├── agent/                              # Agent core - natural language processing
│   ├── agent_tools.dart                # Tool definitions (get_today_usage, create_rule, etc.)
│   ├── focus_agent_core.dart           # Agent orchestration
│   ├── nl_rule_parser.dart             # Natural language to rule parsing
│   ├── agent_rule_parser.dart          # Rule execution logic
│   └── user_override_manager.dart      # User preference learning
│
├── data/
│   ├── models/
│   │   ├── app_usage.dart              # Usage data models
│   │   ├── focus_session.dart          # Focus session tracking
│   │   └── schedule.dart               # Class schedule models + NL parser
│   │
│   └── services/                       # Business logic
│       ├── system_usage_provider.dart  # Reads Android UsageStats
│       ├── chinese_app_database.dart   # 50+ Chinese apps with intent classification
│       ├── context_aware_monitor.dart  # Scene detection (class/gym/study)
│       ├── focus_session_monitor.dart  # Real-time usage monitoring
│       ├── rule_engine.dart            # Rule evaluation and triggering
│       ├── schedule_repository.dart    # Schedule persistence
│       ├── time_slot_analyzer.dart     # Usage pattern analysis
│       ├── notification_service.dart   # Local notifications
│       ├── background_service.dart     # Background task scheduling
│       └── initialization_service.dart # App startup initialization
│
├── presentation/
│   └── screens/
│       ├── home/
│       │   ├── home_screen.dart        # Main dashboard
│       │   ├── minimal_home_screen.dart# Simplified home UI
│       │   └── widgets/                # Status cards, quick actions
│       ├── agent/
│       │   └── agent_hub_screen.dart   # Agent interaction UI
│       ├── focus/
│       │   └── focus_mode_screen.dart  # Focus timer UI
│       ├── schedule/
│       │   └── schedule_edit_screen.dart # Schedule management
│       └── settings/
│           └── settings_screen.dart    # App settings
│
└── core/
    └── theme/
        └── app_theme.dart              # App theme configuration

docs/
├── AGENT_MINIMAL_DESIGN.md             # Agent architecture design
├── CONTEXT_AWARE_AGENT_DESIGN.md       # Context detection design
├── CONTEXTUAL_POLICY.md                # Usage policies by scenario
├── OPTIMIZATION.md                     # Performance optimization details
└── OPTIMIZATION_SUMMARY.md             # Optimization summary
```

## Key Architectural Patterns

### Agent Tools System

The app uses a Tools-based Agent pattern. Located in `lib/agent/agent_tools.dart`:

```dart
// Data tools
get_today_usage()              // Today's screen time stats
get_weekly_trend()             // 7-day usage trend
analyze_time_slot("高数")       // Analyze specific time slot

// Schedule tools
add_schedule()                 // Parse NL like "周一上午8点高数课"
get_today_schedule()           // Get today's events
get_current_context()          // Current scenario (class/study/gym)

// Rule tools
create_rule()                  // Create reminder rules
list_rules()                   // List all active rules
toggle_rule()                  // Enable/disable rules

// Action tools
send_reminder()                // Send notification
suggest_activity()             // Recommend alternative activity
```

### Chinese App Database

`lib/data/services/chinese_app_database.dart` contains a curated database of 50+ Chinese apps:

- **Intents**: entertainment, communication, music, study, tool, shopping
- **Addiction ratings**: `highAddictive` flag for apps like Douyin
- **Usage scenarios**: Some apps encouraged in specific contexts (music during gym)

Example:
```dart
AppInfo {
  name: '抖音',
  intent: UsageIntent.entertainment,
  highAddictive: true,
}
```

### Context-Aware Monitoring

`lib/data/services/context_aware_monitor.dart` implements scenario-based policies:

| Scenario | Douyin | WeChat | Music | Study |
|----------|--------|--------|-------|-------|
| Class    | 3min   | 10min  | 0     | 60min |
| Gym      | 10min  | 20min  | 180min| N/A   |
| Study    | 5min   | 15min  | 30min | 60min |
| Free     | No limit | No limit | No limit | No limit |

### Rule Engine

`lib/data/services/rule_engine.dart` evaluates rules with multiple conditions:
- Time range (e.g., 20:00-23:00)
- Weekday filters (weekdays/weekends)
- Schedule type (class/study/gym)
- App targets (specific apps)
- Usage duration thresholds

Rules support natural language creation like: "晚上8点后刷抖音超30分钟提醒我"

### Event-Driven Tracking

The app uses Android UsageStatsManager instead of custom timers:
- Zero extra battery drain
- Reads pre-recorded system data
- 30-second check intervals during focus mode
- Batch storage to reduce disk writes

## Common Development Tasks

### Adding a New Agent Tool

1. Define tool in `lib/agent/agent_tools.dart`
2. Implement handler in `lib/agent/enhanced_agent_tools.dart`
3. Register in `FocusAgentCore._initializeTools()`
4. Add to agent prompt in `lib/data/services/llm_engine.dart`

### Adding a New Screen

1. Create screen file in `lib/presentation/screens/<feature>/`
2. Add route in `lib/app.dart` routes map
3. Add navigation entry in relevant screen

### Modifying App Database

Edit `lib/data/services/chinese_app_database.dart`:
- Add new apps to `_appDatabase` list
- Set `intent` (entertainment/communication/music/study/tool/shopping)
- Mark `highAddictive: true` for addictive apps
- Add `note` for context-specific recommendations

### Testing Notifications

1. Run `flutter logs` to see output
2. Create a rule with short threshold
3. Trigger condition in emulator/device
4. Check log for rule evaluation results

## Configuration Files

- `pubspec.yaml`: Dependencies and Flutter SDK version (>=3.0.0 <4.0.0)
- `android/app/build.gradle`: Android build configuration, minSdkVersion 21
- `analysis_options.yaml`: Dart analyzer rules
- `.github/workflows/build.yml`: GitHub Actions CI/CD for APK builds

## Dependencies of Note

- `usage_stats: ^1.2.0`: Android UsageStatsManager access
- `flutter_local_notifications: ^16.3.0`: Local notifications
- `shared_preferences: ^2.2.2`: Local storage
- `workmanager: ^0.5.2`: Background task scheduling
- `permission_handler: ^11.1.0`: Runtime permission handling

## Build Outputs

- Debug APK: `build/app/outputs/flutter-apk/app-debug.apk`
- Release APK: `build/app/outputs/flutter-apk/app-release.apk`
- App Bundle: `build/app/outputs/bundle/release/app-release.aab`
