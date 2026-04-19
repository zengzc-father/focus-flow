# Focus Flow - APK 构建指南

## 📦 项目备份

**备份位置**: `C:\Users\21498\focus-flow-app-backup-20260419\`

备份时间：2026-04-19
备份状态：✅ 完成（111 个文件）

---

## 🚀 快速构建步骤

### 前提条件

构建 APK 需要以下环境：

| 组件 | 必需版本 | 用途 |
|------|---------|------|
| Flutter SDK | 3.19.0+ | Flutter 框架 |
| Android SDK | API 33+ | Android 构建工具 |
| Java JDK | 11+ | Gradle 编译 |

### 方案 A：自动安装（推荐新手）

**步骤 1**: 运行自动下载脚本

```bash
cd C:\Users\21498\focus-flow-app
setup_flutter.bat
```

这将：
- 下载 Flutter SDK (约 200MB)
- 解压到 `C:\src\flutter`
- 自动配置环境变量

**步骤 2**: 等待下载完成（约 5-10 分钟）

**步骤 3**: 重新打开命令提示符，运行：

```bash
cd C:\Users\21498\focus-flow-app
flutter pub get
flutter build apk --release
```

---

### 方案 B：手动安装（更可靠）

**步骤 1**: 手动下载 Flutter

访问：https://docs.flutter.dev/get-started/install/windows

下载 `flutter_windows_3.19.0-stable.zip`

**步骤 2**: 解压到 `C:\src\flutter`

**步骤 3**: 添加环境变量

1. 右键"此电脑" → 属性 → 高级系统设置
2. 点击"环境变量"
3. 在"系统变量"中找到 `Path`，点击"编辑"
4. 新建，添加：`C:\src\flutter\bin`
5. 确定保存

**步骤 4**: 验证安装

```bash
flutter doctor
```

**步骤 5**: 安装 Android Studio（如未安装）

下载地址：https://developer.android.com/studio

安装后打开 Android Studio → SDK Manager → 安装：
- Android SDK Platform 33
- Android SDK Build-Tools
- Android SDK Platform-Tools

**步骤 6**: 接受 Android 许可证

```bash
flutter doctor --android-licenses
# 全部选择 y
```

**步骤 7**: 构建 APK

```bash
cd C:\Users\21498\focus-flow-app
flutter pub get
flutter build apk --release
```

---

## 📱 APK 输出位置

构建成功后，APK 位于：

```
C:\Users\21498\focus-flow-app\build\app\outputs\flutter-apk\app-release.apk
```

---

## 📋 使用一键构建脚本

我已为你创建了两个脚本：

### 1. `setup_flutter.bat` - Flutter 自动安装
- 自动下载并配置 Flutter
- 适合首次使用的用户

### 2. `build_apk_wizard.bat` - APK 构建向导
- 交互式引导
- 自动检测环境
- 一键构建 APK

**使用方法**：
```bash
cd C:\Users\21498\focus-flow-app
build_apk_wizard.bat
```

---

## 🔧 常见问题解决

### 错误：`flutter` 不是内部命令

**解决**：
1. 确认 Flutter 已解压到 `C:\src\flutter`
2. 确认 `C:\src\flutter\bin` 已添加到 PATH
3. 重启命令提示符

### 错误：Android SDK 未找到

**解决**：
1. 安装 Android Studio
2. 运行 `flutter doctor` 查看 Android SDK 路径
3. 设置环境变量：`setx ANDROID_HOME "C:\Users\你的用户名\AppData\Local\Android\Sdk"`

### 错误：许可证未接受

**解决**：
```bash
flutter doctor --android-licenses
```
全部选择 `y` 接受

### 错误：构建失败 - Gradle

**解决**：
```bash
cd android
gradlew clean
cd ..
flutter clean
flutter pub get
flutter build apk --release
```

---

## 📲 安装到手机

### 方法 1：USB 调试安装

1. 手机开启"开发者选项"和"USB 调试"
2. USB 连接电脑
3. 运行：
```bash
flutter install
```

### 方法 2：手动安装

1. 复制 `app-release.apk` 到手机
2. 在手机上点击 APK 安装

---

## ⏱️ 预计时间

| 步骤 | 时间 |
|------|------|
| Flutter 下载 | 5-10 分钟 |
| Flutter 解压 | 1-2 分钟 |
| 依赖安装 | 2-5 分钟 |
| APK 构建 | 5-10 分钟 |
| **总计** | **约 15-30 分钟** |

---

## 📞 需要帮助？

运行以下命令查看环境状态：
```bash
flutter doctor -v
```

如有问题，请提供：
1. `flutter doctor` 输出
2. 构建错误日志
3. Windows 版本

---

**当前状态**: 
- ✅ 项目已备份
- ⏳ Flutter 正在后台下载
- ⏳ 等待环境配置完成
- 📦 准备构建 APK

**下一步**: 等待 Flutter 下载完成后，运行 `build_apk_wizard.bat` 开始构建
