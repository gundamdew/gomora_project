@echo off
chcp 65001 > nul

set "TARGET_EXE="
if exist "%~dp0godot.exe" set "TARGET_EXE=%~dp0godot.exe"
if not defined TARGET_EXE if exist "%~dp0Godot_v4.7.2-stable_win64.exe" set "TARGET_EXE=%~dp0Godot_v4.7.2-stable_win64.exe"
if not defined TARGET_EXE if exist "%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64.exe" set "TARGET_EXE=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64.exe"
if not defined TARGET_EXE set "TARGET_EXE=godot"

echo Запуск Окна 1 (Хост)...
start "Project Solomon - Хост" "%TARGET_EXE%" --path "%~dp0." --host

timeout /t 2 /nobreak >nul

echo Запуск Окна 2 (Клиент)...
start "Project Solomon - Клиент" "%TARGET_EXE%" --path "%~dp0."
