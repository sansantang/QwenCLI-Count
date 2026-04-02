@echo off
chcp 65001 >nul
echo.
echo =========================================
echo   Qwen Code Statistics
echo =========================================
echo.

powershell -ExecutionPolicy Bypass -File "%~dp0qwen-stats.ps1" -Tokens %*

echo.
echo Tip: Use -Month 2026-03 for monthly stats
echo.
pause
