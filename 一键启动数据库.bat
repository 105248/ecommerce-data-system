@echo off
chcp 65001 >nul
title 电商数据库一键启动 (PostgreSQL + pgAdmin4)
echo ============================================
echo   电商数据中台 - 一键启动
echo   PostgreSQL 16 + pgAdmin 4
echo ============================================
echo.

rem ---------- 1. 启动 PostgreSQL ----------
echo [1/3] 检查 PostgreSQL 是否已运行...
netstat -ano | findstr ":5432 " | findstr "LISTENING" >nul 2>&1
if %errorlevel%==0 (
    echo       PostgreSQL 已在运行 (端口 5432)
) else (
    echo       PostgreSQL 未运行，正在启动...
    start "" "D:\pgsql16_fresh\pgsql\bin\postgres.exe" -D "D:\pgdata_final" -p 5432
    echo       等待数据库就绪...
    set /a count=0
    :wait_pg
    set /a count+=1
    netstat -ano | findstr ":5432 " | findstr "LISTENING" >nul 2>&1
    if errorlevel 1 (
        if %count% LSS 30 (
            timeout /t 1 /nobreak >nul
            goto wait_pg
        )
        echo       [警告] 数据库启动超时，请检查 D:\pgdata_final\server.log
    ) else (
        echo       PostgreSQL 启动成功 (端口 5432)
    )
)

echo.

rem ---------- 2. 启动 pgAdmin ----------
echo [2/3] 检查 pgAdmin 是否已运行...
netstat -ano | findstr ":5050 " | findstr "LISTENING" >nul 2>&1
if %errorlevel%==0 (
    echo       pgAdmin 已在运行 (端口 5050)
) else (
    echo       pgAdmin 未运行，正在启动...
    set "PATH=D:\pgsql16_fresh\pgsql\bin;%PATH%"
    start "" "D:\pgadmin4\python\python.exe" "D:\pgadmin4\web\pgAdmin4.py"
    echo       等待 pgAdmin 就绪...
    set /a count2=0
    :wait_pgadmin
    set /a count2+=1
    netstat -ano | findstr ":5050 " | findstr "LISTENING" >nul 2>&1
    if errorlevel 1 (
        if %count2% LSS 60 (
            timeout /t 1 /nobreak >nul
            goto wait_pgadmin
        )
        echo       [警告] pgAdmin 启动超时
    ) else (
        echo       pgAdmin 启动成功 (端口 5050)
    )
)

echo.

rem ---------- 3. 打开浏览器 ----------
echo [3/3] 打开 pgAdmin 页面...
start "" "http://127.0.0.1:5050"

echo.
echo ============================================
echo   全部完成！
echo   pgAdmin 地址: http://127.0.0.1:5050
echo   PostgreSQL:  127.0.0.1:5432
echo   密码:  见 mcp_server\.env（不在此明文显示）
echo   此窗口可以关闭
echo ============================================
echo.
timeout /t 5 /nobreak >nul
exit
