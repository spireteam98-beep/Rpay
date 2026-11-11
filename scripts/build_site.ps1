<#
  Builds the full site for Vercel — Windows/PowerShell version of
  scripts/build_site.sh:
    build/web/          landing page (marketing site) at "/"
    build/web/app/      compiled Flutter app at "/app"

  Usage (from anywhere):
    powershell -ExecutionPolicy Bypass -File scripts\build_site.ps1           # build only
    powershell -ExecutionPolicy Bypass -File scripts\build_site.ps1 -Deploy   # build + vercel --prod
    powershell -ExecutionPolicy Bypass -File scripts\build_site.ps1 -Deploy -ApiUrl https://your-backend   # pick the backend
#>
param([switch]$Deploy, [string]$ApiUrl = '')

$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $root

function Step($msg) { Write-Host "==> $msg" -ForegroundColor Red }

Step 'Cleaning previous build output...'
Remove-Item -Recurse -Force 'build\web', 'build\web-app-tmp' -ErrorAction SilentlyContinue

Step 'flutter clean (drops stale plugin registrations, e.g. Firebase on web)...'
flutter clean
if ($LASTEXITCODE -ne 0) { throw 'flutter clean failed - see the error above.' }

Step 'flutter pub get...'
flutter pub get
if ($LASTEXITCODE -ne 0) { throw 'flutter pub get failed - see the error above.' }

Step 'Building Flutter web app (release, base href /app/)...'
$buildArgs = @('build', 'web', '--release', '--base-href=/app/')
if ($ApiUrl) { $buildArgs += "--dart-define=API_BASE_URL=$ApiUrl"; Step "Backend for this build: $ApiUrl" }
flutter @buildArgs
if ($LASTEXITCODE -ne 0) { throw 'flutter build web failed - copy the red error above and send it over.' }
if (-not (Test-Path 'build\web\main.dart.js')) { throw 'Build finished but build\web\main.dart.js is missing.' }

Step 'Moving compiled app into build\web\app...'
Move-Item 'build\web' 'build\web-app-tmp'
New-Item -ItemType Directory 'build\web' | Out-Null
Move-Item 'build\web-app-tmp' 'build\web\app'

Step 'Copying landing page into build\web root...'
Copy-Item 'landing\index.html', 'landing\wayaki.css', 'landing\wayaki.js', 'landing\favicon.png', 'landing\favicon.ico' 'build\web\'
New-Item -ItemType Directory 'build\web\assets' | Out-Null
Copy-Item 'landing\assets\*' 'build\web\assets\'

if (Test-Path 'landing\downloads\fareenn.apk') {
  Step 'Copying the Android APK into build\web (direct download link)...'
  Copy-Item 'landing\downloads\fareenn.apk' 'build\web\fareenn.apk'
}

if (-not (Test-Path 'build\web\app\index.html')) { throw 'build\web\app\index.html is missing - not deploying.' }
Step 'Build OK: build\web\index.html (landing) + build\web\app\ (Flutter app).'

if ($Deploy) {
  Step 'Deploying to Vercel (production)...'
  vercel --prod
  if ($LASTEXITCODE -ne 0) { throw 'vercel --prod failed.' }
}
