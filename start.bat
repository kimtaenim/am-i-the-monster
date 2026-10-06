@echo off
chcp 65001 > nul
title Am I the Monster?
cd /d "%~dp0"

echo ==========================================
echo   Am I the Monster?
echo ==========================================
echo.

rem 1) 최신 코드 받기
if exist ".git" (
    where git > nul 2> nul
    if not errorlevel 1 (
        echo [1/4] GitHub에서 최신 코드를 받는 중...
        git pull
    )
)

rem 2) rojo 확인 (없으면 이 폴더에 내려받기)
where rojo > nul 2> nul
if errorlevel 1 (
    echo [2/4] rojo 내려받는 중... 처음 한 번만 해요.
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Invoke-WebRequest -Uri 'https://github.com/rojo-rbx/rojo/releases/download/v7.4.4/rojo-7.4.4-windows-x86_64.zip' -OutFile 'rojo.zip'; Expand-Archive -Force 'rojo.zip' '.'; Remove-Item 'rojo.zip'"
    rojo plugin install
)

rem 바탕화면 바로가기 (처음 한 번)
powershell -NoProfile -ExecutionPolicy Bypass -Command "$d=[Environment]::GetFolderPath('Desktop'); $l=Join-Path $d 'Am I the Monster.lnk'; if (-not (Test-Path $l)) { $s=(New-Object -ComObject WScript.Shell).CreateShortcut($l); $s.TargetPath='%~dp0start.bat'; $s.WorkingDirectory='%~dp0'; $s.IconLocation='%SystemRoot%\System32\shell32.dll,137'; $s.Save() }"

rem 3) 최신 코드로 게임 파일 만들기
echo [3/4] 게임 파일 만드는 중...
rojo build default.project.json -o AmITheMonster.rbxlx
if errorlevel 1 (
    echo [X] 게임 파일 만들기에 실패했어요. 이 창의 글씨를 Claude에게 보여 주세요.
    pause
    exit /b 1
)

rem 4) Roblox Studio로 열기
echo [4/4] Roblox Studio 켜는 중...
start "" "%~dp0AmITheMonster.rbxlx"

echo.
echo   Studio가 열리면 바로 Play 를 누르면 돼요.
echo   이 창은 Rojo 서버예요. 테스트하는 동안 켜 두세요.
echo   (게임 중에 코드가 바뀌면 Studio의 Rojo - Connect 로 바로 받아올 수 있어요)
echo.
rojo serve default.project.json
pause
