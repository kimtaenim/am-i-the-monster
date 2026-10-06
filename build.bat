@echo off
chcp 65001 > nul
title Am I the Monster? - 장소 파일 만들기
cd /d "%~dp0"

echo ==========================================
echo   Am I the Monster?  장소 파일 만들기
echo   (Rojo 플러그인 없이 Studio에서 바로 열 수 있는 파일)
echo ==========================================
echo.

where git > nul 2> nul
if not errorlevel 1 (
    echo [1/3] GitHub에서 최신 코드를 받는 중...
    git pull
    echo.
)

where rojo > nul 2> nul
if errorlevel 1 (
    echo [X] rojo를 찾을 수 없어요. start.bat 안내를 보고 rojo.exe 를 이 폴더에 넣어 주세요.
    pause
    exit /b 1
)

echo [2/3] AmITheMonster.rbxlx 만드는 중...
rojo build default.project.json -o AmITheMonster.rbxlx
if errorlevel 1 (
    echo [X] 만들기에 실패했어요. 위의 빨간 글씨를 Claude에게 보여 주세요.
    pause
    exit /b 1
)

echo [3/3] Roblox Studio로 여는 중...
start "" "AmITheMonster.rbxlx"
