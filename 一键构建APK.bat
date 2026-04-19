@echo off
chcp 65001 >nul
title Focus Flow APK 构建工具
echo ===================================
echo Focus Flow - 一键构建APK工具
echo ===================================
echo.

:: 检查 Flutter
where flutter >nul 2>&1
if %errorlevel% neq 0 (
    echo [提示] 未检测到 Flutter，开始自动安装...
    echo.

    if not exist C:\flutter (
        echo [1/3] 下载 Flutter SDK...
        git clone https://github.com/flutter/flutter.git -b stable C:\flutter
        if %errorlevel% neq 0 (
            echo [错误] 下载失败，请手动安装Git或检查网络
            pause
            exit /b 1
        )
    )

    echo [2/3] 配置环境变量...
    setx PATH "C:\flutter\bin;%PATH%" /M
    set "PATH=C:\flutter\bin;%PATH%"

    echo [3/3] 验证安装...
    call flutter --version
    if %errorlevel% neq 0 (
        echo [错误] Flutter安装失败
        pause
        exit /b 1
    )
    echo [成功] Flutter安装完成！
    echo.
    echo [重要] 请关闭此窗口，重新打开后再次运行此脚本
    pause
    exit /b 0
)

echo [✓] Flutter已安装
flutter --version
echo.

:: 检查 Android SDK
echo [检查] Android SDK...
if not exist "%LOCALAPPDATA%\Android\Sdk" (
    echo [!] 未检测到Android SDK
    echo [!] 请下载 Android Studio: https://developer.android.com/studio
    echo [!] 安装后打开 Android Studio，按提示安装SDK
    pause
    exit /b 1
)
echo [✓] Android SDK已安装
echo.

:: 进入项目目录
set PROJECT_DIR=%~dp0
cd /d "%PROJECT_DIR%"

echo [1/4] 获取依赖...
flutter pub get
if %errorlevel% neq 0 (
    echo [错误] 获取依赖失败
    pause
    exit /b 1
)

echo [2/4] 分析代码...
flutter analyze --no-fatal-infos --no-fatal-warnings

echo [3/4] 构建Release APK...
flutter build apk --release
if %errorlevel% neq 0 (
    echo [错误] 构建失败
    pause
    exit /b 1
)

echo [4/4] 复制APK到桌面...
set APK_SOURCE=build\app\outputs\flutter-apk\app-release.apk
set APK_DEST=%USERPROFILE%\Desktop\Focus-Flow-v1.0.apk

copy /Y "%APK_SOURCE%" "%APK_DEST%"
if %errorlevel% equ 0 (
    echo [✓] APK已复制到桌面: %APK_DEST%
)

echo.
echo ===================================
echo 构建成功！
echo ===================================
echo APK位置: %APK_SOURCE%
echo 桌面快捷: %APK_DEST%
echo.
echo 文件大小:
for %%I in ("%APK_SOURCE%") do echo   %%~zI bytes
echo.
pause
