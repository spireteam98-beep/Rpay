@echo off
title RoyalPay API
cd /d "%~dp0backend"

if not exist .env (
    echo No .env found - creating one from the template.
    copy .env.example .env >nul
    echo.
    echo   1. A .env file just opened in Notepad.
    echo   2. Paste your Neon DATABASE_URL after DATABASE_URL=.
    echo   3. Leave JWT_SECRET and MASTER_MNEMONIC blank.
    echo      They are generated on first boot and saved automatically.
    echo   4. Save, close Notepad, then run this script again.
    echo.
    start notepad .env
    pause
    exit /b 0
)

where node >nul 2>nul
if errorlevel 1 (
    echo Node.js is not installed. Get it from https://nodejs.org
    pause
    exit /b 1
)

if not exist node_modules (
    echo Installing dependencies...
    call npm install
    if errorlevel 1 (
        echo npm install failed - check the error above.
        pause
        exit /b 1
    )
)

echo Starting RoyalPay API on http://localhost:8080 ...
node src/server.js
pause
