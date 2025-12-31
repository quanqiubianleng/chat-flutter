@echo off
REM ===============================
REM Windows 批处理：生成 Flutter Dart pb 文件
REM ===============================

REM 设置 Proto 文件目录
set PROTO_DIR=protos

REM 设置输出目录
set OUT_DIR=lib/pb

REM 创建输出目录，如果不存在
if not exist %OUT_DIR% (
    mkdir %OUT_DIR%
)

REM 生成 Dart 文件
protoc --dart_out=%OUT_DIR% %PROTO_DIR%\chat.proto

REM 完成提示
echo.
echo ======= Dart Protobuf 文件生成完成 =======
echo 输出目录: %cd%\%OUT_DIR%
pause
