@echo off
chcp 65001 >nul
echo ========================================
echo   Flutter SDK 自动安装脚本
echo ========================================
echo.

:: 设置安装目录
set FLUTTER_ROOT=C:\src\flutter
set FLUTTER_BIN=%FLUTTER_ROOT%\bin

:: 创建目录
echo [1/5] 创建安装目录...
if not exist "%FLUTTER_ROOT%" mkdir "%FLUTTER_ROOT%"

:: 下载 Flutter SDK
echo [2/5] 下载 Flutter SDK (约 200MB，请耐心等待)...
echo 下载地址：https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.19.0-stable.zip

:: 使用 PowerShell 下载
powershell -Command "& { ^
    $ProgressPreference = 'SilentlyContinue'; ^
    $url = 'https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.19.0-stable.zip'; ^
    $output = 'C:\src\flutter_windows_3.19.0-stable.zip'; ^
    Write-Host '正在下载...'; ^
    Invoke-WebRequest -Uri $url -OutFile $output; ^
    Write-Host '下载完成'; ^
}"

if errorlevel 1 (
    echo [错误] 下载失败！
    exit /b 1
)

:: 解压
echo [3/5] 解压 Flutter SDK...
powershell -Command "& { ^
    Expand-Archive -Path 'C:\src\flutter_windows_3.19.0-stable.zip' -DestinationPath 'C:\src' -Force; ^
    Remove-Item 'C:\src\flutter_windows_3.19.0-stable.zip'; ^
}"

:: 删除压缩包
del C:\src\flutter_windows_3.19.0-stable.zip

:: 配置环境变量
echo [4/5] 配置环境变量...
setx PATH "%PATH%;%FLUTTER_BIN%"
echo 环境变量已添加（需要重启终端生效）

:: 验证安装
echo [5/5] 验证 Flutter 安装...
call "%FLUTTER_BIN%\flutter" --version

echo.
echo ========================================
echo   Flutter 安装完成！
echo ========================================
echo.
echo 下一步操作：
echo 1. 关闭此窗口，重新打开命令提示符
echo 2. 运行：cd C:\Users\21498\focus-flow-app
echo 3. 运行：flutter pub get
echo 4. 运行：flutter build apk --release
echo.
echo APK 输出位置：build\app\outputs\flutter-apk\app-release.apk
echo.
pause
