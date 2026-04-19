# Flutter 手动安装指南

## 📥 步骤 1：下载 Flutter

**页面已打开**：https://docs.flutter.dev/get-started/install/windows

1. 在打开的页面中找到 "Download Flutter"
2. 点击 **Windows** 版本下载
3. 文件名为：`flutter_windows_3.x.x-stable.zip` (约 200MB)

---

## 📦 步骤 2：解压 Flutter

下载完成后：

1. 在 `C:` 盘创建目录：`C:\src\flutter`
2. 将下载的 zip 文件解压到 `C:\src\flutter`

**解压后目录结构**：
```
C:\src\flutter\
├── bin\
│   ├── flutter.bat
│   ├── dart.bat
│   └── ...
├── packages\
├── examples\
└── ...
```

> ⚠️ **重要**：不要解压到 `C:\Program Files` 或需要管理员权限的目录

---

## 🔧 步骤 3：添加环境变量

### 方法 A：使用脚本（推荐）

以**管理员身份**运行命令提示符，执行：

```bash
setx /M PATH "%PATH%;C:\src\flutter\bin"
```

### 方法 B：手动添加

1. 按 `Win + S`，搜索 "环境变量"
2. 选择 "编辑系统环境变量"
3. 点击 "环境变量" 按钮
4. 在 "系统变量" 区域找到 `Path`
5. 点击 "编辑"
6. 点击 "新建"
7. 输入：`C:\src\flutter\bin`
8. 连续点击 "确定" 保存

---

## ✅ 步骤 4：验证安装

**关闭所有命令提示符窗口，重新打开一个新的**

运行以下命令验证：

```bash
flutter --version
```

如果看到 Flutter 版本信息，说明安装成功！

```
Flutter 3.19.x • channel stable • ...
Tools • Dart 3.3.x
```

---

## 🤖 步骤 5：安装 Android 工具

### 检查 Android 环境

运行：
```bash
flutter doctor
```

你会看到类似输出：
```
[!] Android toolchain - develop for Android devices (Android SDK version xx)
    ✗ Some Android licenses not accepted.
```

### 接受 Android 许可证

```bash
flutter doctor --android-licenses
```

- 出现提示时输入 `y` 并回车
- 可能需要接受多个许可证（全部选 `y`）

---

## 📱 步骤 6：安装 Android Studio（如未安装）

如果你没有 Android Studio：

1. 下载：https://developer.android.com/studio
2. 安装完成后打开 Android Studio
3. 进入 Settings → Appearance & Behavior → System Settings → Android SDK
4. 确保安装：
   - ✅ Android SDK Platform 33 (或更高)
   - ✅ Android SDK Build-Tools
   - ✅ Android SDK Command-line Tools
   - ✅ Android SDK Platform-Tools

---

## 🚀 步骤 7：构建 Focus Flow APK

一切准备就绪后：

```bash
# 进入项目目录
cd C:\Users\21498\focus-flow-app

# 安装依赖
flutter pub get

# 构建 Release APK
flutter build apk --release
```

构建完成后，APK 位于：
```
build\app\outputs\flutter-apk\app-release.apk
```

---

## ⏱️ 预计时间

| 步骤 | 时间 |
|------|------|
| Flutter 下载 | 5-15 分钟（取决于网速） |
| Flutter 解压 | 1-2 分钟 |
| 环境变量配置 | 1 分钟 |
| Android 许可证接受 | 1 分钟 |
| 依赖安装 | 2-5 分钟 |
| APK 构建 | 5-10 分钟 |
| **总计** | **约 15-35 分钟** |

---

## 🔍 快速检查清单

完成后应该满足：

- [ ] Flutter 已解压到 `C:\src\flutter`
- [ ] 环境变量 Path 包含 `C:\src\flutter\bin`
- [ ] 运行 `flutter --version` 显示版本
- [ ] 运行 `flutter doctor` 无严重错误
- [ ] Android licenses 已接受

---

## 🆘 遇到问题？

### 问题 1：flutter 不是内部命令

**解决**：
1. 确认解压到正确位置：`C:\src\flutter\bin\flutter.bat` 应该存在
2. 确认环境变量已添加
3. **必须重新打开命令提示符**（环境变量才生效）

### 问题 2：Android SDK 未找到

**解决**：
```bash
# 设置 Android SDK 路径（如果有 Android Studio）
setx ANDROID_HOME "%LOCALAPPDATA%\Android\Sdk"
```

### 问题 3：许可证无法接受

**解决**：
```bash
# 以管理员身份运行命令提示符
flutter doctor --android-licenses
```

---

## 📞 完成确认

完成以上步骤后，告诉我：

1. `flutter --version` 的输出
2. `flutter doctor` 的输出

我会帮你确认环境是否就绪，然后开始构建 APK！

---

**现在请执行步骤 1-2：下载并解压 Flutter，完成后告诉我** 👍
