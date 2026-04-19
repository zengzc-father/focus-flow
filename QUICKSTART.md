# Focus Flow 快速启动指南

## 环境准备

### 1. 安装 Flutter SDK

```bash
# 下载 Flutter 3.16+ (推荐 3.19)
https://docs.flutter.dev/get-started/install

# 验证安装
flutter doctor
```

### 2. 安装 IDE

- **Android Studio**: 推荐，Android开发调试最方便
- **VS Code**: 轻量，Flutter插件完善

### 3. 配置Android环境

```bash
# 安装Android SDK
# 配置 ANDROID_HOME 环境变量

# 验证
flutter doctor --android-licenses
```

---

## 项目启动

### 步骤1: 获取依赖

```bash
cd focus-flow-app

# 安装Flutter依赖
flutter pub get

# 生成代码（数据类、Provider等）
flutter pub run build_runner build --delete-conflicting-outputs
```

### 步骤2: 连接设备

```bash
# 查看可用设备
flutter devices

# 示例输出:
# • SM G9910 (mobile) • ... • android-arm64 • Android 14
# • Windows (desktop) • ... • windows-x64   • Windows 11
```

### 步骤3: 运行应用

```bash
# 调试模式运行
flutter run

# 或指定设备
flutter run -d <device-id>

# 热重载 (按 r)
# 热重启 (按 R)
# 退出 (按 q)
```

---

## 首次配置

### 1. 授予权限

首次启动后，应用会请求 **"使用记录访问权限"**：

1. 点击"授予权限"按钮
2. 系统跳转到设置页面
3. 找到 Focus Flow 并启用权限
4. 返回应用

### 2. 测试通知

```bash
# 查看日志
flutter logs

# 连续使用手机30分钟后应收到提醒
```

---

## 构建发布版本

### Android APK

```bash
# 构建发布版
flutter build apk --release

# 输出位置: build/app/outputs/flutter-apk/app-release.apk

# 构建 App Bundle (Google Play用)
flutter build appbundle --release
```

### 性能优化

```bash
# 分析构建体积
flutter build apk --analyze-size

# 启用Obfuscation
flutter build apk --obfuscate --split-debug-info=symbols/
```

---

## 常见问题

### Q: 权限请求失败
```
确保 AndroidManifest.xml 包含:
<uses-permission android:name="android.permission.PACKAGE_USAGE_STATS" />
```

### Q: 通知不显示
```
1. 检查通知权限已开启
2. Android 13+ 需要 POST_NOTIFICATIONS 权限
3. 查看 logcat 日志: adb logcat -s Flutter
```

### Q: 后台任务不执行
```
国内ROM可能限制后台:
- 小米: 设置 > 省电策略 > 无限制
- 华为: 设置 > 应用启动管理 > 手动管理
- OPPO/vivo: 类似设置路径
```

### Q: LLM模型集成
```
Gemma 4E 2bit 模型需:
1. 下载模型文件 (~2.6GB)
2. 放入 assets/models/
3. 更新 pubspec.yaml assets 配置
4. 首次启动自动解压到缓存目录
```

---

## 开发命令速查

```bash
# 运行
flutter run

# 测试
flutter test

# 代码检查
flutter analyze

# 格式化
flutter format .

# 生成代码
flutter pub run build_runner build

# 持续生成（开发时）
flutter pub run build_runner watch

# 清理
flutter clean && flutter pub get

# 查看依赖树
flutter pub deps

# 升级依赖
flutter pub upgrade
```

---

## 下一步

1. ✅ 环境配置完成
2. ✅ 项目运行成功
3. ⏭️ 自定义功能开发
4. ⏭️ LLM集成 (可选)
5. ⏭️ 发布上线

遇到问题？查看:
- [Flutter官方文档](https://docs.flutter.dev)
- [项目技术分析](./TECHNICAL_ANALYSIS.md)
