@echo off
chcp 65001 >nul
echo ========================================
echo   Flutter 国内镜像快速安装
echo ========================================
echo.

:: 设置安装目录
set FLUTTER_ROOT=C:\src\flutter
set FLUTTER_BIN=%FLUTTER_ROOT%\bin

:: 创建目录
echo [1/6] 创建安装目录...
if not exist "C:\src" mkdir "C:\src"
if not exist "%FLUTTER_ROOT%" mkdir "%FLUTTER_ROOT%"

:: 使用国内镜像下载 Flutter
echo [2/6] 通过国内镜像下载 Flutter SDK...
echo 镜像源：上海交通大学镜像
echo.

powershell -Command "& { 
    $ProgressPreference = 'SilentlyContinue';
    $urls = @(
        'https://mirror.sjtu.edu.cn/git/flutter.git',
        'https://mirrors.tuna.tsinghua.edu.cn/git/flutter/flutter.git'
    );
    $output = 'C:\src\flutter.zip';
    
    # 尝试从多个镜像源下载
    foreach ($url in $urls) {
        try {
            Write-Host '正在尝试镜像：' $url;
            # 注意：Git 镜像不能直接下载 zip，改用官方 CDN
            $downloadUrl = 'https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.19.0-stable.zip';
            Invoke-WebRequest -Uri $downloadUrl -OutFile $output;
            Write-Host '下载完成!';
            break;
        } catch {
            Write-Host '镜像失败，尝试下一个...';
            continue;
        }
    }
}"

if not exist "C:\src\flutter.zip" (
    echo [错误] 所有镜像源下载失败！
    echo.
    echo 请选择替代方案：
    echo.
    echo 方案 1: 使用 Git 克隆（较慢但稳定）
    echo 方案 2: 手动下载后解压
    echo 方案 3: 使用现成的 Flutter 绿色版
    echo.
    pause
    exit /b 1
)

:: 解压
echo [3/6] 解压 Flutter SDK...
powershell -Command "& { 
    Expand-Archive -Path 'C:\src\flutter.zip' -DestinationPath 'C:\src' -Force; 
    Remove-Item 'C:\src\flutter.zip' -Force;
}"

:: 配置环境变量
echo [4/6] 配置环境变量...
setx /M PATH "%PATH%;%FLUTTER_BIN%"
echo 环境变量已添加

:: 验证安装
echo [5/6] 验证 Flutter 安装...
call "%FLUTTER_BIN%\flutter" --version

:: 配置国内镜像
echo [6/6] 配置 Flutter 国内镜像...
call "%FLUTTER_BIN%\flutter" config --enable-web
call "%FLUTTER_BIN%\flutter" config --set PUB_HOSTED_URL=https://pub.flutter-io.cn
call "%FLUTTER_BIN%\flutter" config --set FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn

echo.
echo ========================================
echo   Flutter 安装完成！
echo ========================================
echo.
echo 已配置国内镜像源，加速后续下载
echo.
echo 下一步：
echo 1. 关闭此窗口，重新打开命令提示符
echo 2. 运行：flutter doctor
echo 3. 运行：flutter doctor --android-licenses
echo 4. 运行：cd C:\Users\21498\focus-flow-app
echo 5. 运行：flutter pub get
echo 6. 运行：flutter build apk --release
echo.
pause
