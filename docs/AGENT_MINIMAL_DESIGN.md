# Focus Flow - Agent-Centric 极简设计

## 核心理念

```
传统App: 用户 -> 复杂UI -> 操作 -> 系统
Agent驱动: 用户 -> 自然语言 -> Agent(tools) -> 系统
```

**用户只需要：**
1. 看状态（使用情况、趋势）
2. 发指令（自然语言）
3. 收提醒（Agent主动）

**Agent负责：**
- 所有操作执行
- 规则管理
- 数据分析
- 主动干预

---

## 架构图

```
┌─────────────────────────────────────────────────────────────┐
│                      用户层 (极简)                           │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│  │ 状态看板    │  │ 对话入口    │  │ 通知/提醒          │ │
│  │ (只读数据)  │  │ (一句话)    │  │ (Agent主动)        │ │
│  └─────────────┘  └─────────────┘  └─────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    Focus Agent Core                         │
│                    (本地LLM驱动)                            │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐ │
│  │ 理解意图 │ → │ 选择Tool │ → │ 执行Action│ → │ 生成回复 │ │
│  │          │   │          │   │          │   │          │ │
│  └──────────┘   └──────────┘   └──────────┘   └──────────┘ │
└─────────────────────────────────────────────────────────────┘
                              │
              ┌───────────────┼───────────────┐
              ▼               ▼               ▼
┌─────────────────────────────────────────────────────────────┐
│                    Agent Tools (工具层)                      │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  📊 数据类                    🔧 操作类                     │
│  ─────────                   ─────────                     │
│  • get_today_usage           • create_rule                 │
│  • get_app_timeline          • update_goal                 │
│  • get_weekly_trend          • send_reminder               │
│  • compare_with_yesterday    • suggest_activity            │
│  • detect_usage_pattern      • start_focus_mode            │
│                                                             │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    系统数据源 (Android)                      │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  UsageStatsManager ──→ 系统已记录的应用使用数据              │
│  (不重复计时，直接读取)                                      │
│                                                             │
│  • 各应用使用时长 (精确到秒)                                │
│  • 使用时间段记录                                           │
│  • 解锁次数统计                                             │
│  • 无需后台计时服务                                         │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Agent Tools 详细设计

### 工具定义格式 (JSON Schema)

```json
{
  "name": "get_today_usage",
  "description": "获取今日屏幕使用统计",
  "parameters": {
    "type": "object",
    "properties": {
      "include_apps": {
        "type": "boolean",
        "description": "是否包含各应用详情"
      }
    }
  },
  "returns": {
    "total_minutes": "integer",
    "unlock_count": "integer",
    "top_apps": [{"name": "string", "minutes": "integer"}],
    "compared_to_goal": "string"
  }
}
```

### 完整工具列表

| Tool | 功能 | 使用场景 |
|------|------|---------|
| `get_today_usage` | 获取今日使用统计 | 用户问"今天用了多久" |
| `get_app_timeline` | 获取某应用使用时段 | 分析"什么时候刷抖音最多" |
| `get_weekly_trend` | 获取7天趋势 | 生成周报 |
| `get_usage_pattern` | 获取使用模式分析 | "我什么时候最容易沉迷" |
| `create_rule` | 创建提醒规则 | "晚上8点后刷抖音超过30分钟提醒我" |
| `list_rules` | 列出所有规则 | "我设置了哪些规则" |
| `toggle_rule` | 启用/禁用规则 | "暂停晚上那个规则" |
| `delete_rule` | 删除规则 | "删掉抖音那个规则" |
| `update_daily_goal` | 修改每日目标 | "把目标改成2小时" |
| `send_test_reminder` | 发送测试提醒 | "发个提醒试试" |
| `suggest_activity` | 推荐替代活动 | "推荐个活动" |
| `analyze_concerning_pattern` | 分析 worrisome 模式 | "分析我的使用习惯" |
| `export_weekly_report` | 导出周报 | "给我个周报" |

---

## 极简UI设计

### 主界面 (Single Screen)

```
┌─────────────────────────────────────┐
│  Focus Flow         [设置图标]      │  ← 极简顶部
├─────────────────────────────────────┤
│                                     │
│     ┌─────────────────────────┐    │
│     │                         │    │
│     │    📱 今日使用          │    │  ← 核心数据
│     │                         │    │
│     │    3小时 24分           │    │
│     │    ━━━━━━━━━━━━░░░ 85%  │    │  ← 进度条
│     │    目标: 4小时          │    │
│     │                         │    │
│     └─────────────────────────┘    │
│                                     │
│  ┌──────────┐  ┌──────────┐        │
│  │ 📈 趋势  │  │ 📊 详情  │        │  ← 快捷入口
│  └──────────┘  └──────────┘        │
│                                     │
├─────────────────────────────────────┤
│                                     │
│  🤖 Focus Agent                     │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━   │
│                                     │
│  下午好！今天已经用了3小时多，      │  ← Agent主动消息
│  比昨天同时段少了20分钟，不错~      │
│                                     │
│  检测到你刚才连续用了抖音40分钟，   │
│  要做一组眼保健操吗？               │
│                                     │
│  ┌──────────┐  ┌──────────┐        │
│  │  好     │  │  稍后   │        │
│  └──────────┘  └──────────┘        │
│                                     │
├─────────────────────────────────────┤
│                                     │
│  💬 [和Agent对话...           ]    │  ← 对话输入框
│                                     │
│  快捷: ➕规则 | 📊周报 | 🎯目标     │
│                                     │
└─────────────────────────────────────┘
```

### 对话界面 (Bottom Sheet)

```
┌─────────────────────────────────────┐
│  💬 Focus Agent              [↓]   │
├─────────────────────────────────────┤
│                                     │
│  👤 帮我设置个规则，晚上8点后       │
│     刷抖音超过30分钟提醒我          │
│                                     │
│  🤖 ✅ 已创建规则"晚间抖音提醒"     │
│     我会在条件触发时自动提醒你~     │
│                                     │
│  👤 今天用了多久                    │
│                                     │
│  🤖 今天用了3小时24分钟，           │
│     距离4小时目标还有36分钟空间~    │
│                                     │
│  👤 推荐个活动                      │
│                                     │
│  🤖 你已经坐了40分钟了，            │
│     来做个简单的颈椎操吧：          │
│     1. 缓慢转头向左5秒              │
│     2. 向右5秒                      │
│     3. 低头抬头各5秒                │
│     做完告诉我~                     │
│                                     │
├─────────────────────────────────────┤
│ [语音] [输入消息...          ] [发送]│
└─────────────────────────────────────┘
```

---

## 系统数据对接 (核心优化)

### 为什么选择系统UsageStats？

| 自研计时 | 系统UsageStats |
|---------|---------------|
| 需要后台服务 | ✅ 系统已记录 |
| 耗电 | ✅ 零额外耗电 |
| 可能被系统杀 | ✅ 数据可靠 |
| 需处理休眠/锁屏 | ✅ 自动处理 |
| 精度依赖实现 | ✅ 秒级精度 |

### 数据获取流程

```dart
// 不再自己计时，直接读取系统数据
class SystemUsageProvider {
  // 获取今日精确使用数据
  Future<DailyUsage> getTodayUsage() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    
    // 直接查询系统UsageStats
    final events = await UsageStats.queryEvents(start, now);
    
    // 解析事件计算使用时长
    return _parseUsageEvents(events);
  }
  
  // 获取某应用使用时间段
  Future<List<UsageSession>> getAppTimeline(String packageName) async {
    final events = await UsageStats.queryEvents(start, end);
    return _extractSessions(events, packageName);
  }
}
```

### Agent实时感知 (轮询优化)

```dart
// Agent每5分钟读取一次系统数据
// 无需持续后台服务
class AgentPerception {
  Timer? _perceptionTimer;
  
  void start() {
    _perceptionTimer = Timer.periodic(Duration(minutes: 5), (_) async {
      final usage = await SystemUsageProvider().getTodayUsage();
      final decision = await agent.decide(usage);
      if (decision.shouldAct) {
        await execute(decision.action);
      }
    });
  }
}
```

---

## 典型交互流程

### 场景1: 用户查询今日情况

```
用户输入: "今天用了多久"
         ↓
Agent理解意图 → 调用 get_today_usage
         ↓
读取系统UsageStats
         ↓
生成回复: "今天用了3小时24分钟，距离4小时目标还有36分钟空间~"
```

### 场景2: 创建番茄规则

```
用户输入: "帮我设个规则，晚上8点后刷抖音超过30分钟提醒我休息"
         ↓
Agent理解意图 → 提取参数:
  - 时间: 20:00-23:59
  - 应用: com.ss.android.ugc.aweme (抖音)
  - 阈值: 30分钟
  - 动作: 提醒休息
         ↓
调用 create_rule 保存规则
         ↓
生成回复: "✅ 已创建'晚间抖音提醒'规则，我会在晚上8点后检测，
          如果你用抖音超过30分钟就提醒你休息~"
         ↓
(规则触发时)
         ↓
Agent读取系统数据 → 检测到抖音使用35分钟
         ↓
发送通知: "已经刷了很久了，起来活动一下吧~"
```

### 场景3: Agent主动干预

```
Agent轮询 (每5分钟)
         ↓
读取系统UsageStats
         ↓
分析: 用户已连续使用抖音42分钟
         ↓
LLM决策: 需要干预
         ↓
发送通知 + 显示在主界面
         ↓
用户看到Agent消息卡片，可选择"开始休息"或"稍后"
```

---

## 文件结构

```
lib/
├── main.dart                      # 入口
├── app.dart                       # App配置
│
├── agent/                         # Agent核心 (NEW)
│   ├── focus_agent.dart           # Agent主类
│   ├── agent_tools.dart           # 工具定义
│   ├── tool_executor.dart         # 工具执行器
│   ├── intent_parser.dart         # 意图解析
│   └── local_llm.dart             # 本地LLM封装
│
├── data/
│   ├── models/
│   │   ├── app_usage.dart         # 数据模型
│   │   ├── agent_message.dart     # Agent消息模型
│   │   └── smart_rule.dart        # 规则模型
│   │
│   ├── services/
│   │   ├── system_usage_provider.dart   # 系统数据读取 (核心)
│   │   ├── rules_repository.dart        # 规则存储
│   │   └── notification_service.dart    # 通知服务
│   │
│   └── repositories/
│       └── usage_repository.dart
│
├── presentation/
│   ├── screens/
│   │   └── home/
│   │       ├── home_screen.dart         # 极简主界面
│   │       ├── widgets/
│   │       │   ├── status_card.dart     # 状态卡片
│   │       │   ├── agent_chat_card.dart # Agent对话卡片
│   │       │   └── quick_input_bar.dart # 快捷输入
│   │       └── dialogs/
│   │           └── chat_sheet.dart      # 对话浮层
│   │
│   └── shared/
│       └── theme.dart
│
└── core/
    └── utils/
```

---

## 实现优先级

1. **P0 - 核心数据层**
   - SystemUsageProvider (读取系统UsageStats)
   - AgentTools基础框架

2. **P1 - Agent核心**
   - IntentParser (理解用户输入)
   - ToolExecutor (执行工具)
   - 基础对话能力

3. **P2 - 极简UI**
   - StatusCard (状态展示)
   - ChatSheet (对话界面)
   - AgentChatCard (Agent消息)

4. **P3 - 增强功能**
   - 本地LLM集成
   - 规则引擎
   - 趋势分析

---

## 关键设计决策

### 1. 为什么用系统数据而非自研计时？

- **零额外功耗**: 不运行后台服务
- **数据权威**: 系统数据是最准确的
- **免维护**: 不担心被杀、休眠等问题
- **秒级精度**: UsageStats提供精确事件时间戳

### 2. 为什么界面要极简？

- **Agent是主角**: 用户通过对话交互，不需要复杂UI
- **降低开发成本**: 快速MVP
- **减少认知负担**: 用户只需要知道"发生了什么"和"能做什么"

### 3. 为什么用Tools模式？

- **可扩展**: 新增功能=新增Tool
- **可观测**: 每个操作都有明确记录
- **LLM友好**: 标准Function Calling模式
- **可组合**: 复杂操作=多个Tool组合

---

## 下一步行动

1. 实现 `SystemUsageProvider` - 系统数据读取
2. 实现 `AgentTools` 框架 - 工具定义与执行
3. 重构 `HomeScreen` - 极简主界面
4. 实现基础对话能力

