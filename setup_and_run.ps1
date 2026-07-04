$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
# Unique log per run — avoids OneDrive file locks killing the script.
$stamp = Get-Date -Format 'HHmmss'
try {
    Start-Transcript -Path (Join-Path $root "run_log_$stamp.txt") -Force
} catch {
    Write-Host ">> Transcript unavailable: $($_.Exception.Message)"
}

try {
    $dev = 'C:\dev'
    if (-not (Test-Path $dev)) { New-Item -ItemType Directory -Path $dev | Out-Null }

    # ---------- Git (required by Flutter) ----------
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        if (Test-Path 'C:\dev\git\cmd\git.exe') {
            $env:Path = "C:\dev\git\cmd;$env:Path"
        } else {
            Write-Host '>> Git not found. Downloading portable MinGit (no admin needed)...'
            $gitZip = Join-Path $env:TEMP 'mingit.zip'
            Invoke-WebRequest -Uri 'https://github.com/git-for-windows/git/releases/download/v2.47.1.windows.1/MinGit-2.47.1-64-bit.zip' -OutFile $gitZip
            Expand-Archive -Path $gitZip -DestinationPath 'C:\dev\git' -Force
            $env:Path = "C:\dev\git\cmd;$env:Path"
            $up = [Environment]::GetEnvironmentVariable('Path','User')
            if ($up -notlike '*C:\dev\git\cmd*') {
                [Environment]::SetEnvironmentVariable('Path', "$up;C:\dev\git\cmd", 'User')
            }
        }
    }
    Write-Host ">> Git: $(git --version)"

    # ---------- Flutter SDK ----------
    $flutterBin = 'C:\dev\flutter\bin'
    if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
        if (-not (Test-Path (Join-Path $flutterBin 'flutter.bat'))) {
            Write-Host '>> Flutter not found. Fetching latest stable release info...'
            $rel = Invoke-RestMethod 'https://storage.googleapis.com/flutter_infra_release/releases/releases_windows.json'
            $hash = $rel.current_release.stable
            $entry = $rel.releases | Where-Object { $_.hash -eq $hash } | Select-Object -First 1
            $url = "$($rel.base_url)/$($entry.archive)"
            Write-Host ">> Downloading Flutter $($entry.version) (~1 GB). This can take several minutes..."
            $zip = Join-Path $env:TEMP 'flutter_sdk.zip'
            Invoke-WebRequest -Uri $url -OutFile $zip
            Write-Host '>> Download complete. Extracting to C:\dev\flutter (a few minutes)...'
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            [System.IO.Compression.ZipFile]::ExtractToDirectory($zip, $dev)
            Write-Host '>> Extraction complete.'
        }
        $env:Path = "$flutterBin;$env:Path"
        $up = [Environment]::GetEnvironmentVariable('Path','User')
        if ($up -notlike "*$flutterBin*") {
            [Environment]::SetEnvironmentVariable('Path', "$up;$flutterBin", 'User')
        }
    }
    Write-Host '>> Checking Flutter (first run downloads the Dart SDK)...'
    flutter --version
    try { flutter config --no-analytics | Out-Null } catch {}

    # ---------- Run the project ----------
    Set-Location $root
    Write-Host '>> Installing project dependencies (flutter pub get)...'
    flutter pub get
    Write-Host '>> Launching app in Google Chrome (first build takes a few minutes)...'
    Write-Host '>> SUCCESS-MARKER: starting flutter run'
    flutter run -d chrome
}
catch {
    Write-Host ''
    Write-Host ">> ERROR: $($_.Exception.Message)"
    Write-Host '>> See details above. This window will stay open.'
}
finally {
    try { Stop-Transcript } catch {}
}
