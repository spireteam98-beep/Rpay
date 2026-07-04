@echo off
title CryptoTrader - Setup and Run
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup_and_run.ps1"
echo.
echo Script finished. Log saved to setup_log.txt
pause
