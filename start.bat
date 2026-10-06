@echo off
chcp 65001 > nul
title Am I the Monster? - Rojo
cd /d "%~dp0"

echo ==========================================
echo   Am I the Monster?  개발 서버 켜기
echo ==========================================
echo.

rem 1) 최신 코드 받기
where git > nul 2> nul
if errorlevel 1 (
    echo [!] git이 없어서 최신 코드를 못 받았어요. 지금 폴더 그대로 켤게요.
) else (
    echo [1/2] GitHub에서 최신 코드를 받는 중...
    git pull
    if errorlevel 1 echo [!] 최신 코드 받기에 실패했어요. 지금 폴더 그대로 켤게요.
)
echo.

rem 2) Rojo 찾기 (없으면 rokit으로 설치 시도)
where rojo > nul 2> nul
if errorlevel 1 (
    where rokit > nul 2> nul
    if not errorlevel 1 (
        echo rojo가 없어서 rokit으로 설치할게요...
        rokit install
    )
)
where rojo > nul 2> nul
if errorlevel 1 (
    echo [X] rojo를 찾을 수 없어요.
    echo     https://github.com/rojo-rbx/rojo/releases 에서 rojo-7.4.4-windows-x86_64.zip 을 받아
    echo     압축을 풀고 rojo.exe 를 이 폴더에 넣은 다음 다시 실행해 주세요.
    pause
    exit /b 1
)

echo [2/2] Rojo 서버를 켰어요!
echo.
echo   이제 Roblox Studio에서 Rojo 플러그인의 [Connect] 를 누르세요.
echo   끝내려면 이 창을 닫으면 돼요.
echo.
rojo serve default.project.json
pause
