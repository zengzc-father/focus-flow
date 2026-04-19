#!/usr/bin/env python3
"""Batch fix import paths and add missing imports."""
import os

base = 'c:/Users/21498/focus-flow-app/lib'

def read(path):
    with open(os.path.join(base, path), 'r', encoding='utf-8') as f:
        return f.read()

def write(path, content):
    with open(os.path.join(base, path), 'w', encoding='utf-8') as f:
        f.write(content)
    print(f'  Fixed: {path}')

# === 1. Fix wrong import paths ===

# agent_rule_parser.dart
t = read('agent/agent_rule_parser.dart')
t = t.replace("import 'rule_engine.dart';", "import '../data/services/rule_engine.dart';")
write('agent/agent_rule_parser.dart', t)

# agent_tools.dart
t = read('agent/agent_tools.dart')
t = t.replace("import '../models/app_usage.dart';", "import '../data/models/app_usage.dart';")
write('agent/agent_tools.dart', t)

# focus_interruption_detector.dart
t = read('services/focus_interruption_detector.dart')
t = t.replace("import 'notification_service.dart';", "import '../data/services/notification_service.dart';")
write('services/focus_interruption_detector.dart', t)

# minimal_home_screen.dart
t = read('presentation/screens/home/minimal_home_screen.dart')
t = t.replace("import '../../agent/enhanced_focus_agent.dart' as agent;",
            "import '../../../agent/enhanced_focus_agent.dart' as agent;")
t = t.replace("import '../../data/services/system_usage_provider.dart';",
            "import '../../../data/services/system_usage_provider.dart';")
t = t.replace("import '../../data/models/app_usage.dart';",
            "import '../../../data/models/app_usage.dart';")
t = t.replace("import '../../data/services/schedule_repository.dart';",
            "import '../../../data/services/schedule_repository.dart';")
t = t.replace("import '../../data/models/schedule.dart';",
            "import '../../../data/models/schedule.dart';")
write('presentation/screens/home/minimal_home_screen.dart', t)

# schedule_edit_screen.dart
t = read('presentation/screens/schedule/schedule_edit_screen.dart')
t = t.replace("import '../../data/models/schedule.dart';",
            "import '../../../data/models/schedule.dart';")
t = t.replace("import '../../data/services/schedule_repository.dart';",
            "import '../../../data/services/schedule_repository.dart';")
write('presentation/screens/schedule/schedule_edit_screen.dart', t)

# model_manager_screen.dart
t = read('presentation/screens/settings/model_manager_screen.dart')
t = t.replace("import '../../data/services/model_manager_service.dart';",
            "import '../../../data/services/model_manager_service.dart';")
write('presentation/screens/settings/model_manager_screen.dart', t)

# === 2. Add missing imports ===

# system_usage_provider.dart: needs UsageEvent from usage_stats package
t = read('data/services/system_usage_provider.dart')
if 'package:usage_stats/usage_stats.dart' not in t:
    t = "import 'package:usage_stats/usage_stats.dart';\n" + t
    write('data/services/system_usage_provider.dart', t)

# focus_session_monitor.dart: needs UsageIntent, ContextualAppPolicy
t = read('data/services/focus_session_monitor.dart')
if 'import' not in t[:200]:  # check imports area
    pass
imports_to_add = []
if 'UsageIntent' in t and 'import.*app_usage.dart' not in t:
    imports_to_add.append("import '../models/app_usage.dart' show UsageIntent;")
if 'ContextualAppPolicy' in t and 'context_aware_monitor.dart' not in t:
    imports_to_add.append("import 'context_aware_monitor.dart' show ContextualAppPolicy;")

if imports_to_add:
    # Add after existing imports
    lines = t.split('\n')
    insert_idx = 0
    for i, line in enumerate(lines):
        if line.startswith('import '):
            insert_idx = i + 1
    for imp in reversed(imports_to_add):
        lines.insert(insert_idx, imp)
    t = '\n'.join(lines)
    write('data/services/focus_session_monitor.dart', t)

# nl_rule_parser.dart: needs UsageIntent
t = read('agent/nl_rule_parser.dart')
if 'UsageIntent' in t and 'app_usage' not in t:
    lines = t.split('\n')
    insert_idx = 0
    for i, line in enumerate(lines):
        if line.startswith('import '):
            insert_idx = i + 1
    lines.insert(insert_idx, "import '../data/models/app_usage.dart' show UsageIntent;")
    t = '\n'.join(lines)
    write('agent/nl_rule_parser.dart', t)

# user_override_manager.dart: needs UsageIntent, AppIntentClassifier
t = read('agent/user_override_manager.dart')
additions = []
if 'UsageIntent' in t and 'app_usage.dart' not in t:
    additions.append("import '../data/models/app_usage.dart' show UsageIntent;")
if 'AppIntentClassifier' in t and 'time_slot_analyzer.dart' not in t:
    additions.append("import '../data/services/time_slot_analyzer.dart' show AppIntentClassifier;")
if additions:
    lines = t.split('\n')
    insert_idx = 0
    for i, line in enumerate(lines):
        if line.startswith('import '):
            insert_idx = i + 1
    for imp in reversed(additions):
        lines.insert(insert_idx, imp)
    t = '\n'.join(lines)
    write('agent/user_override_manager.dart', t)

# rule_engine.dart: needs UsageIntent, AppInfo
t = read('data/services/rule_engine.dart')
additions = []
if 'UsageIntent' in t and 'app_usage.dart' not in t:
    additions.append("import '../models/app_usage.dart' show UsageIntent;")
if 'AppInfo' in t and 'chinese_app_database.dart' not in t and 'packageName' in t:
    # Check if AppInfo is actually used with packageName getter
    pass  # AppInfo comes from chinese_app_database, check if import needed
if additions:
    lines = t.split('\n')
    insert_idx = 0
    for i, line in enumerate(lines):
        if line.startswith('import '):
            insert_idx = i + 1
    for imp in reversed(additions):
        lines.insert(insert_idx, imp)
    t = '\n'.join(lines)
    write('data/services/rule_engine.dart', t)

# focus_agent.dart: needs DailyUsage, WeeklyAnalysis
t = read('data/services/focus_agent.dart')
additions = []
if 'DailyUsage' in t and 'app_usage.dart' not in t:
    additions.append("import '../models/app_usage.dart' show DailyUsage, WeeklyAnalysis;")
write('data/services/focus_agent.dart', t)  # already imports rule_engine
# Actually need to add the import
if additions:
    t = read('data/services/focus_agent.dart')
    lines = t.split('\n')
    insert_idx = 0
    for i, line in enumerate(lines):
        if line.startswith('import '):
            insert_idx = i + 1
    for imp in reversed(additions):
        lines.insert(insert_idx, imp)
    t = '\n'.join(lines)
    write('data/services/focus_agent.dart', t)

# rules_screen.dart: needs SmartRule, RuleConditions, RuleAction, RuleActionType
t = read('presentation/screens/agent/rules_screen.dart')
# Already imports focus_agent.dart but needs rule_engine.dart types
# Remove unused focus_agent import and add rule_engine import
t = t.replace(
    "import 'package:focus_flow/data/services/focus_agent.dart';",
    "import 'package:focus_flow/data/services/rule_engine.dart';"
)
write('presentation/screens/agent/rules_screen.dart', t)

# agent_hub_screen.dart: needs SmartRule
t = read('presentation/screens/agent/agent_hub_screen.dart')
# Already imports focus_agent.dart, need rule_engine for SmartRule
t = t.replace(
    "import 'package:focus_flow/data/services/focus_agent.dart';",
    "import 'package:focus_flow/data/services/focus_agent.dart';\nimport 'package:focus_flow/data/services/rule_engine.dart';"
)
write('presentation/screens/agent/agent_hub_screen.dart', t)

# usage_stats_service.dart: UsageEvent should come from usage_stats package
# Already has import, so it should be fine

# smart_slot_monitor.dart: needs UsageIntent
t = read('data/services/smart_slot_monitor.dart')
if 'UsageIntent' in t and 'app_usage.dart' not in t:
    lines = t.split('\n')
    insert_idx = 0
    for i, line in enumerate(lines):
        if line.startswith('import '):
            insert_idx = i + 1
    lines.insert(insert_idx, "import '../models/app_usage.dart' show UsageIntent;")
    t = '\n'.join(lines)
    write('data/services/smart_slot_monitor.dart', t)

# enhanced_agent_tools.dart: needs ReminderLevel, AppUsageInfo, CurrentContext
t = read('agent/enhanced_agent_tools.dart')
additions = []
# ReminderLevel is in rule_engine.dart - check if already imported
# Already imports rule_engine.dart? Let me check
# enhanced_agent_tools.dart doesn't import rule_engine.dart
if 'ReminderLevel' in t:
    found = False
    for line in t.split('\n'):
        if 'rule_engine' in line and 'import' in line:
            found = True
    if not found:
        additions.append("import '../data/services/rule_engine.dart' show ReminderLevel;")
if additions:
    lines = t.split('\n')
    insert_idx = 0
    for i, line in enumerate(lines):
        if line.startswith('import '):
            insert_idx = i + 1
    for imp in reversed(additions):
        lines.insert(insert_idx, imp)
    t = '\n'.join(lines)
    write('agent/enhanced_agent_tools.dart', t)

# focus_mode_screen.dart: needs FocusSessionStatus disambiguation
t = read('presentation/screens/focus/focus_mode_screen.dart')
# Import with hide to disambiguate
lines = t.split('\n')
new_lines = []
for line in lines:
    if 'import.*focus_session.dart' in line and 'focus_session_monitor' not in line:
        new_lines.append(line.replace("'", "', show FocusSessionStatus, "))
    elif 'import.*focus_session_monitor.dart' in line:
        new_lines.append(line.replace("'", "', hide FocusSessionStatus, "))
    else:
        new_lines.append(line)
t = '\n'.join(new_lines)
write('presentation/screens/focus/focus_mode_screen.dart', t)

print('\nAll import fixes applied!')
