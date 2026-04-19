# Focus Flow GitHub 上传操作指南

## 概述

本文档详细说明如何将本地 Focus Flow 项目上传到 GitHub 仓库，触发 GitHub Actions 自动构建 APK。

---

## 前置条件

### 1. 本地环境要求

- Git 已安装（验证：`git --version`）
- 项目路径：`C:\Users\21498\focus-flow-app`
- 已初始化 Git 仓库（包含 96 个文件，2 个提交）

### 2. GitHub 仓库信息

- 仓库地址：https://github.com/zengzc-father/focus-flow.git
- 已配置 GitHub Actions 工作流（`.github/workflows/build.yml`）

---

## 上传步骤

### 步骤 1：进入项目目录

```bash
cd C:\Users\21498\focus-flow-app
```

### 步骤 2：验证 Git 状态

```bash
git status
```

预期输出：
```
On branch main
Your branch is ahead of 'origin/main' by 2 commits.
```

### 步骤 3：配置远程仓库

如果尚未配置远程仓库：

```bash
git remote add origin https://github.com/zengzc-father/focus-flow.git
```

验证配置：
```bash
git remote -v
```

预期输出：
```
origin  https://github.com/zengzc-father/focus-flow.git (fetch)
origin  https://github.com/zengzc-father/focus-flow.git (push)
```

### 步骤 4：推送代码

```bash
git push -u origin main
```

---

## 认证方式

### 方式一：Personal Access Token（推荐）

#### 1. 创建 Token

1. 访问 https://github.com/settings/tokens/new
2. 填写信息：
   - **Note**: Focus Flow Push
   - **Expiration**: 30 days（或选择 No expiration）
   - **Scopes**: 勾选 `repo`（完整仓库访问）
3. 点击 **Generate token**
4. **立即复制 Token**（关闭页面后无法再次查看）

#### 2. 使用 Token 推送

执行推送命令后：
- **Username**: `zengzc-father`（GitHub 用户名）
- **Password**: `ghp_xxxxxxxxxxxx`（粘贴 Token）

```bash
git push -u origin main
# 提示 Username: zengzc-father
# 提示 Password: [粘贴 Token]
```

#### 3. 缓存凭证（可选）

Windows：
```bash
git config --global credential.helper manager
```

macOS/Linux：
```bash
git config --global credential.helper cache
```

---

### 方式二：SSH 密钥认证

#### 1. 生成 SSH 密钥

```bash
ssh-keygen -t ed25519 -C "your@email.com"
# 按 Enter 接受默认路径
# 按 Enter 不设置密码（或设置密码）
```

#### 2. 添加密钥到 SSH Agent

Windows（Git Bash）：
```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
```

macOS：
```bash
eval "$(ssh-agent -s)"
ssh-add --apple-use-keychain ~/.ssh/id_ed25519
```

Linux：
```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
```

#### 3. 添加公钥到 GitHub

1. 复制公钥内容：
```bash
cat ~/.ssh/id_ed25519.pub
```

2. 访问 https://github.com/settings/keys
3. 点击 **New SSH key**
4. 填写：
   - **Title**: Focus Flow PC
   - **Key type**: Authentication Key
   - **Key**: 粘贴公钥内容
5. 点击 **Add SSH key**

#### 4. 验证 SSH 连接

```bash
ssh -T git@github.com
# 预期输出: Hi zengzc-father! You've successfully authenticated...
```

#### 5. 切换远程 URL 为 SSH

```bash
git remote set-url origin git@github.com:zengzc-father/focus-flow.git
```

#### 6. 推送

```bash
git push -u origin main
```

---

## 验证上传成功

### 1. 本地验证

```bash
git log --oneline
# 预期输出：
# 3c4d9f2 Add CLAUDE.md for AI assistant guidance
# 9d741dd Initial commit: Focus Flow 学生自律助手
```

### 2. GitHub 验证

访问 https://github.com/zengzc-father/focus-flow

确认：
- 文件列表显示完整项目结构
- 提交历史显示 2 个提交
- Actions 标签页显示 "Build APK" 工作流

---

## 触发自动构建

### 方式一：推送触发（自动）

代码推送到 main 分支后，GitHub Actions 自动触发：
1. 访问 https://github.com/zengzc-father/focus-flow/actions
2. 查看 "Build APK" 工作流运行状态
3. 等待 5-8 分钟

### 方式二：手动触发

1. 进入 Actions 页面
2. 点击左侧 "Build APK"
3. 点击右侧 "Run workflow" → "Run workflow"

---

## 下载 APK

### 方式一：Artifacts 下载

1. Actions 页面点击完成的运行记录
2. 页面底部 "Artifacts" 部分
3. 点击 "focus-flow-apk" 下载

### 方式二：Releases 下载

1. 进入 https://github.com/zengzc-father/focus-flow/releases
2. 找到最新 Release（如 v1.0.1）
3. 下载 `app-release.apk`

---

## 常见问题

### Q: 推送失败 "Authentication failed"

**原因**: 凭证错误

**解决**:
```bash
# 清除缓存凭证
git credential reject https://github.com/zengzc-father/focus-flow.git
# 重新推送，使用正确的 Token 或 SSH
```

### Q: 推送失败 "Permission denied"

**原因**: 无仓库写入权限

**解决**: 确认 GitHub 账号 `zengzc-father` 有该仓库的写权限

### Q: "fatal: repository not found"

**原因**: 仓库不存在或 URL 错误

**解决**:
```bash
# 检查远程地址
git remote -v
# 更正地址
git remote set-url origin https://github.com/zengzc-father/focus-flow.git
```

### Q: "Updates were rejected"

**原因**: 远程仓库有本地没有的内容

**解决**:
```bash
git pull origin main --rebase
git push origin main
```

---

## 文件清单

项目包含以下主要文件：

```
focus-flow-app/
├── .github/workflows/build.yml    # GitHub Actions 配置
├── CLAUDE.md                       # AI 助手指南
├── README.md                       # 项目说明
├── pubspec.yaml                    # Flutter 配置
├── lib/                            # 源代码 (49 个 Dart 文件)
│   ├── agent/                      # Agent 核心
│   ├── data/services/              # 业务逻辑
│   └── presentation/screens/       # UI 界面
├── android/                        # Android 配置
├── docs/                           # 设计文档
└── test/                           # 测试文件
```

---

## 快速命令参考

```bash
# 一次性执行

cd C:\Users\21498\focus-flow-app

git remote add origin https://github.com/zengzc-father/focus-flow.git 2>/dev/null || true

git push -u origin main

# 或使用 SSH
git remote set-url origin git@github.com:zengzc-father/focus-flow.git
git push -u origin main
```

---

## 后续操作

上传成功后：

1. **访问 Actions**: https://github.com/zengzc-father/focus-flow/actions
2. **等待构建**: 5-8 分钟
3. **下载 APK**: Artifacts → focus-flow-apk
4. **安装测试**: 传输到 Android 设备安装

---

## 技术支持

- GitHub Actions 文档: https://docs.github.com/en/actions
- Git 认证文档: https://docs.github.com/en/authentication
- Flutter 构建文档: https://docs.flutter.dev/deployment/android
