# 分级阈值系统示例

## 配置

```dart
AppCategoryConfig {
  // 娱乐类 - 低阈值，严格监控
  entertainmentThresholdMinutes = 3;   // 3分钟即提醒
  entertainmentWarningMinutes = 5;     // 5分钟强烈警告
  
  // 通讯类 - 中等阈值
  communicationThresholdMinutes = 10;  // 10分钟提醒
  communicationWarningMinutes = 20;    // 20分钟警告
  
  // 工具类 - 高阈值，宽松
  toolThresholdMinutes = 15;           // 15分钟提醒
  toolWarningMinutes = 30;             // 30分钟警告
}
```

## 场景演示：高数课监控

### 场景1: 刷抖音（娱乐类）

```
时间线:
14:00 高数课开始
14:03 抖音使用 3分钟
      → 达到娱乐类阈值
      → InterventionLevel.gentle
      → Agent: "已经刷3分钟了，高数课还顺利吗？适度放松就好~"

14:06 抖音继续 6分钟
      → 超过6分钟（2倍阈值）
      → InterventionLevel.strong
      → Agent: "高数课时间已用6分钟刷抖音，有点久了，现在放下，等下课再玩吧！"
```

### 场景2: 回微信消息（通讯类）

```
时间线:
14:00 高数课开始
14:05 微信使用 5分钟
      → 未达通讯类阈值(10分钟)
      → NO_ACTION
      → Agent不打扰

14:12 微信使用 12分钟
      → 超过通讯类阈值(10分钟)
      → InterventionLevel.gentle
      → Agent: "回消息用了12分钟，高数课别落下太多哦~"

14:25 微信使用 25分钟
      → 超过通讯类警告阈值(20分钟)
      → InterventionLevel.strong
      → Agent: "通讯已经25分钟，高数课可能需要专注一下了"
```

### 场景3: 使用计算器（工具类）

```
时间线:
14:00 高数课开始
14:10 计算器使用 10分钟
      → 未达工具类阈值(15分钟)
      → NO_ACTION
      → Agent不打扰

14:20 计算器使用 20分钟
      → 超过工具类阈值(15分钟)
      → InterventionLevel.moderate
      → Agent: "查资料/用工具20分钟了，高数课进展如何？"
```

### 场景4: 混合使用

```
时间线:
14:00 高数课开始
14:02 微信 2分钟 → 允许
14:05 抖音 3分钟 → ⚠️ 提醒: "已经刷3分钟了..."
14:08 放下手机
14:15 相机 5分钟 → 允许（工具类）
14:20 抖音 2分钟 → 允许（刚提醒过）
14:23 抖音 5分钟 → ⚠️ 强烈警告: "时间已用5分钟..."
```

## 干预级别

| 级别 | 触发条件 | 消息风格 |
|------|---------|---------|
| none | 未达阈值 | 不发送 |
| gentle | 首次超阈值 | 温和建议，带~ |
| moderate | 持续使用 | 适度提醒 |
| strong | 严重超标 | 明确要求，带！ |

## 用户自定义

用户可以通过自然语言调整阈值：

```
用户: "我上课时可以刷10分钟抖音"
Agent: 将娱乐类阈值调整为10分钟

用户: "微信我可以聊久一点"
Agent: 将通讯类阈值调整为20分钟

用户: "这节课我想完全专注，任何手机都别让我用"
Agent: 启用严格模式，所有应用阈值设为0
```

## 代码实现

```dart
// 监控循环（每分钟执行）
void _checkCurrentUsage() async {
  final currentApp = await getCurrentApp();
  final intent = classify(currentApp); // entertainment/communication/tool
  
  final session = getSession(currentApp);
  final threshold = CategoryThresholdManager.getThreshold(intent);
  
  if (session.durationMinutes >= threshold) {
    final level = _determineLevel(session, threshold);
    final message = CategoryThresholdManager.getInterventionMessage(
      intent, session.durationMinutes, level, "高数课"
    );
    sendNotification(message);
  }
}
```

