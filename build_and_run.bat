@echo off
chcp 65001 >nul
echo ===================================
echo Focus Flow - 快速启动脚本
echo ===================================
echo.

:: 检查 Flutter 环境
flutter --version >nul 2>&1
if errorlevel 1 (
    echo [错误] 未找到 Flutter，请确保 Flutter 已安装并添加到 PATH
    exit /b 1
)

echo [1/4] 获取依赖...
flutter pub get
if errorlevel 1 (
    echo [错误] 获取依赖失败
    exit /b 1
)

echo [2/4] 检查代码...
flutter analyze
if errorlevel 1 (
    echo [警告] 代码检查发现问题，继续构建...
)

echo [3/4] 构建 APK...
flutter build apk --debug
if errorlevel 1 (
    echo [错误] 构建失败
    exit /b 1
)

echo [4/4] 安装到设备...
echo 请确保 Android 设备已连接并开启调试模式
echo.
choice /C YN /M "是否安装到设备"
if errorlevel 2 goto :end

flutter install
if errorlevel 1 (
    echo [错误] 安装失败，请检查设备连接
    exit /b 1
)

echo.
echo ===================================
echo 完成！
echo ===================================
:end
pause
