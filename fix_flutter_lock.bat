@echo off
chcp 65001 >nul
title Flutter 锁终结者

echo.
echo 正在强杀残留的 dart / flutter 进程 ...
taskkill /F /IM dart.exe /IM flutter.exe >nul 2>&1

echo.
echo 正在删除所有 Flutter 锁文件 ...
if exist "%LOCALAPPDATA%\FlutterToolState" (
    rd /s /q "%LOCALAPPDATA%\FlutterToolState" 2>nul
    md "%LOCALAPPDATA%\FlutterToolState" 2>nul
)

if defined FLUTTER_ROOT (
    del /F /Q "%FLUTTER_ROOT%\bin\cache\lockfile" >nul 2>&1
    del /F /Q "%FLUTTER_ROOT%\bin\cache\flutter_tools.*" >nul 2>&1
)

del /F /Q "%LOCALAPPDATA%\Pub\Cache\lockfile" >nul 2>&1

echo.
echo ╔══════════════════════════════╗
echo ║      Flutter 锁已彻底解锁！     ║
echo ║   现在可以正常运行 flutter 命令了   ║
echo ╚══════════════════════════════╝
echo.
pause