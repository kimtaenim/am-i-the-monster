@echo off
title Am I the Monster?
cd /d "%~dp0"

echo ==========================================
echo   Am I the Monster?
echo ==========================================
echo.

rem 1) Get latest code
if exist ".git" (
    echo [1/4] Downloading latest code...
    git pull
)

rem 2) Download rojo if missing (first time only)
where rojo > nul 2> nul
if errorlevel 1 (
    echo [2/4] Installing rojo...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Invoke-WebRequest -Uri 'https://github.com/rojo-rbx/rojo/releases/download/v7.4.4/rojo-7.4.4-windows-x86_64.zip' -OutFile 'rojo.zip'; Expand-Archive -Force 'rojo.zip' '.'; Remove-Item 'rojo.zip'"
    rojo plugin install
)

rem Desktop shortcut (first time only)
powershell -NoProfile -ExecutionPolicy Bypass -Command "$d=[Environment]::GetFolderPath('Desktop'); $l=Join-Path $d 'Am I the Monster.lnk'; if (-not (Test-Path $l)) { $s=(New-Object -ComObject WScript.Shell).CreateShortcut($l); $s.TargetPath='%~dp0start.bat'; $s.WorkingDirectory='%~dp0'; $s.IconLocation='%SystemRoot%\System32\shell32.dll,137'; $s.Save() }"

rem 3) Build the game file
echo [3/4] Building game file...
rojo build default.project.json -o AmITheMonster.rbxlx
if errorlevel 1 (
    echo.
    echo [ERROR] Build failed. Show this window to Claude.
    pause
    exit /b 1
)

rem 4) Open Roblox Studio
echo [4/4] Opening Roblox Studio...
start "" "%~dp0AmITheMonster.rbxlx"

echo.
echo   Studio is opening. Just press Play.
echo   Keep this window open while testing (Rojo server).
echo.
rojo serve default.project.json
pause
