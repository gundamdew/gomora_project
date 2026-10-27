@echo off
chcp 65001 > nul
cd /d "%~dp0"

cls
echo =====================================================================
echo    PROJECT SOLOMON -- ЗАПУСК СЕРВЕРА (ХОСТ)
echo =====================================================================
echo.
echo  Ваши сетевые IP-адреса на этом ПК:
ipconfig | findstr /i "IPv4"
echo.
echo  Сетевой порт: 7777
echo.
echo  ДЛЯ ПОДКЛЮЧЕНИЯ СО ВТОРОГО УСТРОЙСТВА:
echo  1. Убедитесь, что оба ПК подключены к одному Wi-Fi (или роутеру).
echo  2. Запустите игру на втором ПК через run_client.bat (или run_game.bat).
echo  3. В лобби сервер появится в списке 'СЕРВЕРЫ В СЕТИ'. Нажмите [ПОДКЛЮЧИТЬСЯ].
echo     Либо введите один из ваших IP выше в поле ввода.
echo.
echo  * Если второй ПК не видит сервер, запустите setup_firewall.bat от админа.
echo =====================================================================
echo.
echo Запуск хоста...

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
    start "" "godot.exe" --host
    exit /b 0
)
if exist "Godot_v4.7.2-stable_win64.exe" (
    start "" "Godot_v4.7.2-stable_win64.exe" --host
    exit /b 0
)
where godot.exe >nul 2>&1
if %errorlevel% equ 0 (
    start "" godot --host
    exit /b 0
)
if exist "%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64.exe" (
    start "" "%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64.exe" --host
    exit /b 0
)

echo =====================================================================
echo [ОШИБКА] Не найден файл godot.exe!
echo Пожалуйста, поместите godot.exe в папку с игрой: %~dp0
echo =====================================================================
pause
exit /b 1
