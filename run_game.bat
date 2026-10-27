@echo off
chcp 65001 > nul
cd /d "%~dp0"

if not exist "assets" mkdir "assets"

if exist "C:\Users\Alienware\Downloads\classes (3).dmi" (
    copy /Y "C:\Users\Alienware\Downloads\classes (3).dmi" "assets\classes.dmi" >nul
    copy /Y "C:\Users\Alienware\Downloads\classes (3).dmi" "assets\classes.png" >nul
)
if exist "%USERPROFILE%\Downloads\classes (3).dmi" (
    copy /Y "%USERPROFILE%\Downloads\classes (3).dmi" "assets\classes.dmi" >nul
    copy /Y "%USERPROFILE%\Downloads\classes (3).dmi" "assets\classes.png" >nul
)
if exist "%USERPROFILE%\Downloads\classes*.dmi" (
    copy /Y "%USERPROFILE%\Downloads\classes*.dmi" "assets\classes.dmi" >nul
    copy /Y "%USERPROFILE%\Downloads\classes*.dmi" "assets\classes.png" >nul
)
if exist "assets\classes.dmi" (
    copy /Y "assets\classes.dmi" "assets\classes.png" >nul
)

if exist "godot.exe" (
    start "" "godot.exe"
    exit /b 0
)
if exist "Godot_v4.7.2-stable_win64.exe" (
    start "" "Godot_v4.7.2-stable_win64.exe"
    exit /b 0
)
where godot.exe >nul 2>&1
if %errorlevel% equ 0 (
    start "" godot
    exit /b 0
)
if exist "%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64.exe" (
    start "" "%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64.exe"
    exit /b 0
)

echo =====================================================================
echo [ОШИБКА] Не найден файл godot.exe!
echo Пожалуйста, поместите godot.exe в папку с игрой: %~dp0
echo =====================================================================
pause
exit /b 1
