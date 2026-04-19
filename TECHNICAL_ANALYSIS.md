# Focus Flow 技术方案选型分析

## 方案对比

### 方案A: Flutter 跨平台方案 (当前设计)

| 维度 | 评价 |
|------|------|
| 开发效率 | ⭐⭐⭐⭐⭐ 单代码库支持Android/iOS |
| 功能完整度 | ⭐⭐⭐⭐ 通过插件访问原生功能 |
| 性能 | ⭐⭐⭐⭐ 接近原生，足够此应用需求 |
| 维护成本 | ⭐⭐⭐⭐⭐ 一套代码，维护简单 |
| 上线速度 | ⭐⭐⭐⭐⭐ 2-3周可完成MVP |
| 包体积 | ⭐⭐⭐ 比原生大5-10MB |

**适用场景**: 快速验证、跨平台需求、团队资源有限

---

### 方案B: Android 原生 (Kotlin + Jetpack Compose)

| 维度 | 评价 |
|------|------|
| 开发效率 | ⭐⭐⭐ 仅Android平台 |
| 功能完整度 | ⭐⭐⭐⭐⭐ 系统级功能访问无限制 |
| 性能 | ⭐⭐⭐⭐⭐ 最优性能 |
| 维护成本 | ⭐⭐⭐ 需单独维护Android代码 |
| 上线速度 | ⭐⭐⭐⭐ 3-4周完成 |
| 包体积 | ⭐⭐⭐⭐⭐ 最精简，~5MB |

**适用场景**: 仅需Android、对性能/包体积极敏感、深度系统集成

---

## 针对您需求的建议

### 推荐: Flutter 方案 (当前实现)

**理由**:
1. **获取应用使用时间**: `usage_stats` 插件稳定可用，完全满足需求
2. **亮屏时间检测**: 可通过 `flutter_foreground_task` + 原生插件实现
3. **通知权限**: `flutter_local_notifications` 成熟稳定
4. **未来扩展**: 如将来需要iOS版本，代码可复用90%
5. **LLM集成**: 可通过 `flutter_rust_bridge` 或平台通道集成本地模型

---

## LLM 集成方案 (Gemma 4E 2bit)

### 架构设计

```
┌─────────────────────────────────────────────────────────┐
│                     Flutter App                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐ │
│  │  自然语言输入 │  │  规则解析器  │  │  智能提醒生成器  │ │
│  └──────┬──────┘  └──────┬──────┘  └────────┬────────┘ │
│         │                │                   │          │
│  ┌──────▼────────────────▼───────────────────▼────────┐ │
│  │               LLM推理引擎 (Gemma 4E 2bit)           │ │
│  │  - 本地运行，无需网络                                │ │
│  │  - 2.6GB模型，4-bit量化                             │ │
│  │  - 支持中文指令理解                                  │ │
│  └─────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

### 功能场景

**1. 自然语言创建规则**
```
用户输入: "工作日晚上8点后如果我刷抖音超过30分钟就提醒我"

LLM解析 → 结构化规则:
{
  "condition": {
    "timeRange": "20:00-23:59",
    "days": ["Mon", "Tue", "Wed", "Thu", "Fri"],
    "appPackage": "com.ss.android.ugc.aweme",
    "duration": 1800
  },
  "action": {
    "type": "notification",
    "message": "已经刷抖音30分钟了，该休息了"
  }
}
```

**2. 智能提醒生成**
```
上下文: 用户已连续使用手机2小时，当前22:00

LLM生成个性化提醒:
"夜深了，你已经专注使用手机2小时。"
"考虑到明天的课程安排，建议现在开始准备休息。"
"试试睡前阅读15分钟？"
```

**3. 动态活动规划**
```
用户输入: "下午有空，推荐个活动"

LLM结合上下文生成建议:
- 查询: 今日已使用3小时，下午时段
- 分析: 学习类活动占比低
- 建议: "下午是高效学习时间，推荐复习今天的课堂笔记 (25分钟) + 眼保健操 (5分钟)"
```

### 技术实现路径

#### 选项1: llama.cpp + FFI (推荐)

```yaml
# pubspec.yaml
dependencies:
  ffi: ^2.1.0
```

```dart
// llm_service.dart
import 'dart:ffi';
import 'dart:io';

class LLMService {
  static DynamicLibrary? _lib;

  static Future<void> initialize() async {
    _lib = Platform.isAndroid
        ? DynamicLibrary.open('libllama.so')
        : DynamicLibrary.process();

    // 加载 Gemma 4E 2bit 模型
    await _loadModel('assets/models/gemma-4e-2bit.gguf');
  }

  static Future<String> generateResponse(String prompt) async {
    // 调用 llama.cpp 推理
    final response = await _inference(prompt);
    return response;
  }
}
```

**优点**:
- 性能最优，C++原生速度
- 社区成熟，llama.cpp支持Gemma

**缺点**:
- 需要编译so文件
- 集成复杂度较高

#### 选项2: mediapipe_genai (Google官方)

```yaml
dependencies:
  mediapipe_genai: ^0.1.0  # 需确认最新版本
```

```dart
import 'package:mediapipe_genai/mediapipe_genai.dart';

class GemmaInference {
  late final LlmInference _llm;

  Future<void> initialize() async {
    _llm = await LlmInference.create(
      modelPath: 'assets/models/gemma-4e.bin',
      maxTokens: 512,
      temperature: 0.7,
    );
  }

  Future<String> generate(String prompt) async {
    return await _llm.generateResponse(prompt);
  }
}
```

**优点**:
- Google官方支持
- 针对移动端优化

**缺点**:
- 功能可能受限
- 需验证是否支持4E 2bit

#### 选项3: 原生端集成 + 平台通道

```kotlin
// Android原生端
class LLMManager(private val context: Context) {
    private var llm: GemmaLLM? = null

    fun initialize(modelPath: String) {
        llm = GemmaLLM.builder()
            .setModelPath(modelPath)
            .setContextSize(2048)
            .build()
    }

    fun generate(prompt: String, callback: (String) -> Unit) {
        llm?.generate(prompt, callback)
    }
}
```

```dart
// Flutter端
class LLMChannel {
  static const platform = MethodChannel('com.focusflow/llm');

  static Future<String> generate(String prompt) async {
    final response = await platform.invokeMethod('generate', {
      'prompt': prompt,
    });
    return response as String;
  }
}
```

**优点**:
- 原生控制力强
- 可精细优化

**缺点**:
- 双端代码维护
- 通信开销

---

## 决策建议

| 您的需求 | 推荐方案 |
|---------|---------|
| 仅Android，追求极致性能 | Kotlin原生 + llama.cpp |
| 快速上线，未来可能跨平台 | Flutter + 平台通道集成LLM |
| 包体积敏感(<20MB) | 原生方案，云端LLM API |
| 完全离线，隐私优先 | Flutter + llama.cpp FFI |

### 推荐组合 (平衡方案)

**Flutter + llama.cpp FFI + Gemma 4E 2bit**

- **开发周期**: 4-5周 (含LLM集成)
- **包体积**: ~35MB (Flutter ~15MB + 模型~20MB)
- **性能**: 中等手机可达 5-10 tokens/秒
- **优势**: 跨平台能力 + 本地AI + 快速迭代

---

## 下一步

请确认您的倾向：
1. **纯Flutter跨平台** (当前代码可继续完善)
2. **转Kotlin原生** (需重写，但性能更好)
3. **Flutter + LLM集成** (在现有方案上增加AI能力)
