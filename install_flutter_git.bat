@echo off
chcp 65001 >nul
echo ========================================
echo   Flutter Git 克隆安装脚本
echo ========================================
echo.

:: 设置安装目录
set FLUTTER_ROOT=C:\src\flutter
set FLUTTER_BIN=%FLUTTER_ROOT%\bin

:: 创建目录
echo [1/5] 创建安装目录...
if not exist "C:\src" mkdir "C:\src"

:: 检查是否已存在
if exist "%FLUTTER_ROOT%\.git" (
    echo [提示] Flutter 已存在，跳过克隆
    goto :config_env
)

:: 使用国内镜像克隆
echo [2/5] 通过 Git 克隆 Flutter (约 300MB，需 5-15 分钟)...
echo 镜像源：清华大学开源软件镜像站
echo.

git clone -b stable https://mirrors.tuna.tsinghua.edu.cn/git/flutter/flutter.git "%FLUTTER_ROOT%"

if errorlevel 1 (
    echo [错误] 克隆失败！尝试备用镜像...
    rmdir /s /q "%FLUTTER_ROOT%" 2>nul
    git clone -b stable https://mirror.sjtu.edu.cn/git/flutter.git "%FLUTTER_ROOT%"
)

if errorlevel 1 (
    echo [错误] 所有镜像源失败！
    pause
    exit /b 1
)

:: 配置环境变量
:config_env
echo [3/5] 配置环境变量...
setx /M PATH "%PATH%;%FLUTTER_BIN%"
echo 环境变量已添加（重启终端生效）

:: 配置国内镜像
echo [4/5] 配置 Flutter 国内镜像...
call "%FLUTTER_BIN%\flutter" config --set PUB_HOSTED_URL=https://pub.flutter-io.cn
call "%FLUTTER_BIN%\flutter" config --set FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn

:: 预下载
echo [5/5] 预下载 Dart SDK 和工具...
call "%FLUTTER_BIN%\flutter" precache

echo.
echo ========================================
echo   Flutter 安装完成！
echo ========================================
echo.
echo 已配置：
echo - 清华大学 Git 镜像源
echo - 国内 Pub 镜像源
echo - 环境变量 PATH
echo.
echo 下一步操作：
echo 1. 关闭此窗口，重新打开命令提示符
echo 2. 运行：flutter doctor
echo 3. 运行：flutter doctor --android-licenses
echo 4. 运行：cd C:\Users\21498\focus-flow-app
echo 5. 运行：flutter pub get
echo 6. 运行：flutter build apk --release
echo.
echo APK 输出位置：build\app\outputs\flutter-apk\app-release.apk
echo.
pause
