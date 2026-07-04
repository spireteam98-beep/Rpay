@echo off
title CryptoTrader - Run App
cd /d "%~dp0"

where flutter >nul 2>nul
if errorlevel 1 (
    echo Flutter is not installed or not in PATH.
    echo.
    echo Install it from: https://docs.flutter.dev/get-started/install/windows
    echo Then re-run this script.
    pause
    exit /b 1
)

echo Flutter found. Installing dependencies...
call flutter pub get
if errorlevel 1 (
    echo.
    echo "flutter pub get" failed - check the error above.
    pause
    exit /b 1
)

echo.
echo Starting app in Chrome (no emulator needed)...
echo To run on Windows desktop instead: flutter run -d windows
echo.
call flutter run -d chrome
pause
