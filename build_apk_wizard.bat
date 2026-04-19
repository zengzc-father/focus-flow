@echo off
chcp 65001 >nul
echo ========================================
echo   Focus Flow - APK 构建向导
echo ========================================
echo.

:: 检查 Flutter 是否存在
where flutter >nul 2>&1
if %errorlevel% equ 0 (
    echo [✓] Flutter 已安装
    goto :install_deps
)

echo [!] Flutter 未检测到
echo.
echo 请选择安装方式：
echo.
echo   1. 手动下载 Flutter (推荐 - 更可靠)
echo      下载地址：https://docs.flutter.dev/get-started/install/windows
echo.
echo   2. 使用自动下载脚本 (setup_flutter.bat)
echo.
echo   3. 我已有 Flutter，需要配置 PATH
echo.
set /p choice="请输入选择 (1/2/3): "

if "%choice%"=="1" goto :manual_download
if "%choice%"=="2" goto :auto_download
if "%choice%"=="3" goto :config_path

echo 无效选择
pause
exit /b 1

:manual_download
echo.
echo 正在打开 Flutter 下载页面...
start https://docs.flutter.dev/get-started/install/windows
echo.
echo 请按照以下步骤操作：
echo 1. 下载 Windows 版 Flutter SDK
echo 2. 解压到 C:\src\flutter
echo 3. 将 C:\src\flutter\bin 添加到系统 PATH 环境变量
echo 4. 重新运行此脚本
echo.
pause
exit /b 0

:auto_download
echo 正在运行自动下载脚本...
call setup_flutter.bat
exit /b 0

:config_path
set /p flutter_path="请输入 Flutter bin 目录路径 (如 C:\src\flutter\bin): "
setx PATH "%PATH%;%flutter_path%"
echo 环境变量已添加，请重新运行此脚本
pause
exit /b 0

:install_deps
echo.
echo ========================================
echo   开始构建 APK
echo ========================================
echo.

:: 进入项目目录
cd /d "%~dp0"

:: 安装依赖
echo [1/4] 安装 Flutter 依赖...
call flutter pub get
if errorlevel 1 (
    echo [错误] 依赖安装失败
    pause
    exit /b 1
)

:: 清理之前的构建
echo [2/4] 清理旧构建...
call flutter clean

:: 重新获取依赖
call flutter pub get

:: 构建 APK
echo [3/4] 构建 Release APK (这可能需要 5-10 分钟)...
call flutter build apk --release

if errorlevel 1 (
    echo [错误] APK 构建失败
    echo.
    echo 常见错误及解决方案：
    echo 1. Android SDK 未安装 - 请安装 Android Studio
    echo 2. 许可证未接受 - 运行：flutter doctor --android-licenses
    echo 3. 网络问题 - 检查网络连接
    pause
    exit /b 1
)

:: 验证输出
echo [4/4] 验证 APK 文件...
if exist "build\app\outputs\flutter-apk\app-release.apk" (
    echo.
    echo ========================================
    echo   ✓ APK 构建成功！
    echo ========================================
    echo.
    echo APK 位置：build\app\outputs\flutter-apk\app-release.apk
    echo APK 大小：
    dir /s build\app\outputs\flutter-apk\app-release.apk | find "app-release.apk"
    echo.
    echo 下一步：
    echo 1. 通过 USB 连接 Android 手机
    echo 2. 运行：flutter install
    echo    或手动复制 APK 到手机安装
    echo.
    
    :: 询问是否直接安装
    set /p install_now="是否现在安装到手机？(需要连接 USB) (y/n): "
    if /i "%install_now%"=="y" (
        call flutter install
    )
) else (
    echo [错误] 未找到 APK 文件
)

pause
