@echo off
chcp 936 >nul
rem ============================================================
rem  X7Plus 专用遥控控制台（PC 侧）  ctl_x7plus.bat
rem  与 ctl.bat（X6s A / 端口 8000）独立：本脚本用端口 8001、
rem  独立日志 phone_ack_x7plus.log，两机互不抢指令。
rem
rem  ctl_x7plus.bat start                 随机 3~10 秒自动上滑
rem  ctl_x7plus.bat start 10              固定 10 秒自动上滑
rem  ctl_x7plus.bat start 10 172.20.32.20 固定 10 秒 + 先 ping 检查手机在线
rem  ctl_x7plus.bat stop                  停止服务端
rem  ctl_x7plus.bat status                看状态 / PC 地址 / 手机最近连接IP / 最近6条回报
rem
rem  对应手机脚本：remote_ctl_kuaishou_v3_x7plus_20261030.js
rem  手机脚本里 PC 地址须为 http://172.20.36.178:8001
rem ============================================================
setlocal enabledelayedexpansion

set "DIR=%~dp0"
set "SERVER=%DIR%phone_ctl_server.py"
set "PORT=8001"
set "PCS_ACK_LOG=phone_ack_x7plus.log"

if /i "%~1"=="start"  goto start
if /i "%~1"=="stop"   goto stop
if /i "%~1"=="status" goto status

echo 用法: ctl_x7plus.bat [start [间隔秒] [手机IP] ^| stop ^| status]
exit /b 1

:start
call :parseargs %~2 %~3

call :portup
if "%UP%"=="1" (
    echo [server] 已在运行，如需重启请先执行 ctl_x7plus.bat stop
    exit /b 0
)

echo [server] 启动中... 间隔=%MODE% 端口=%PORT%
start "PhoneSwipeServer-X7Plus" /min cmd /c python "%SERVER%" %PORT% %MODE%

for /l %%i in (1,1,6) do (
    ping -n 2 127.0.0.1 >nul
    call :portup
    if "!UP!"=="1" goto srvok
)
echo [server] 启动失败：端口 %PORT% 未监听
echo          检查 python 是否在 PATH，或手动运行: python "%SERVER%" %PORT%
exit /b 1

:srvok
echo [server] 已启动，端口 %PORT%，日志 %PCS_ACK_LOG%
if /i "%MODE%"=="rand" (
    echo [auto]   已开启，随机间隔 3~10 秒
) else (
    echo [auto]   已开启，固定间隔 %MODE% 秒
)

if not "%PHONEIP%"=="" (
    echo [phone]  检查 %PHONEIP% ...
    ping -n 1 -w 1200 %PHONEIP% >nul 2>&1
    if errorlevel 1 (
        echo [phone]  不可达：可能不在同一网络，或手机未连 Wi-Fi
    ) else (
        echo [phone]  在线
    )
)

echo.
curl.exe -s "http://127.0.0.1:%PORT%/info"
echo.
echo 状态: ctl_x7plus.bat status    停止: ctl_x7plus.bat stop
exit /b 0

:stop
set "FOUND=0"
for /f "tokens=5" %%p in ('netstat -ano ^| findstr ":%PORT% " ^| findstr "LISTENING"') do (
    taskkill /f /pid %%p >nul 2>&1
    echo [server] 已停止 PID=%%p
    set "FOUND=1"
)
if "!FOUND!"=="0" echo [server] 未在运行
call :portup
if "!UP!"=="0" echo [server] 端口 %PORT% 已释放
exit /b 0

:status
call :portup
if "!UP!"=="1" (echo [server] 运行中，端口 %PORT%) else (echo [server] 未运行)
if "!UP!"=="1" (
    curl.exe -s "http://127.0.0.1:%PORT%/info"
    echo ---- 自动上滑状态 ----
    curl.exe -s "http://127.0.0.1:%PORT%/auto/status"
    echo.
    echo ---- 最近 6 条手机回报 ----
    curl.exe -s "http://127.0.0.1:%PORT%/tail?n=6"
)
exit /b 0

:parseargs
set "MODE=%~1"
set "PHONEIP=%~2"
if "%MODE%"=="" set "MODE=rand"
if "%MODE%"=="" exit /b 0
echo %MODE%|findstr /r "\." >nul
if errorlevel 1 exit /b 0
set "PHONEIP=%MODE%"
set "MODE=rand"
exit /b 0

:portup
set "UP=0"
for /f "tokens=*" %%l in ('netstat -ano ^| findstr ":%PORT% " ^| findstr "LISTENING"') do set "UP=1"
exit /b 0
