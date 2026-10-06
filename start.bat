@echo off
chcp 65001 > nul
title Am I the Monster? - Rojo
cd /d "%~dp0"

echo ==========================================
echo   Am I the Monster?  개발 서버 켜기
echo ==========================================
echo.

rem 1) 최신 코드 받기 (git으로 받은 폴더일 때만)
if exist ".git" (
    where git > nul 2> nul
    if errorlevel 1 (
        echo [!] git이 없어서 최신 코드를 못 받았어요. 지금 폴더 그대로 켤게요.
    ) else (
        echo [1/3] GitHub에서 최신 코드를 받는 중...
        git pull
    )
) else (
    echo [1/3] git으로 받은 폴더가 아니라서 최신 코드 받기는 건너뛰어요.
)
echo.

rem 2) rojo가 없으면 이 폴더에 내려받고, Studio 플러그인도 설치해요
where rojo > nul 2> nul
if errorlevel 1 (
    echo [2/3] rojo가 없어서 내려받는 중... 처음 한 번만 해요.
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Invoke-WebRequest -Uri 'https://github.com/rojo-rbx/rojo/releases/download/v7.4.4/rojo-7.4.4-windows-x86_64.zip' -OutFile 'rojo.zip'; Expand-Archive -Force 'rojo.zip' '.'; Remove-Item 'rojo.zip'"
    if not exist "rojo.exe" (
        echo [X] rojo 내려받기에 실패했어요. 인터넷 연결을 확인하고 다시 실행해 주세요.
        pause
        exit /b 1
    )
    echo      Roblox Studio에 Rojo 플러그인을 설치하는 중...
    rojo plugin install
    echo      설치 끝! Studio가 켜져 있었다면 껐다가 다시 켜 주세요.
) else (
    echo [2/3] rojo 준비 완료.
)
echo.

echo [3/3] Rojo 서버를 켰어요!
echo.
echo   이제 Roblox Studio에서
echo     1. 새 Baseplate 를 열고
echo     2. 위쪽 [플러그인] 탭의 Rojo 버튼을 누른 뒤
echo     3. [Connect] 를 누르세요.
echo   끝내려면 이 창을 닫으면 돼요.
echo.
rojo serve default.project.json
pause
