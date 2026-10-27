@echo off
chcp 65001 > nul
cls
echo =====================================================================
echo    PROJECT SOLOMON -- НАСТРОЙКА БРАНДМАУЭРА WINDOWS ДЛЯ LAN СЕТИ
echo =====================================================================
echo.
echo Открытие входящих портов UDP 7777 (Игровой сервер) и 7778 (Автопоиск LAN)...
netsh advfirewall firewall delete rule name="Project Solomon - LAN Server" >nul 2>&1
netsh advfirewall firewall add rule name="Project Solomon - LAN Server" dir=in action=allow protocol=UDP localport=7777,7778 >nul 2>&1

if %errorlevel% equ 0 (
    echo.
    echo [УСПЕХ] Сетевые порты 7777 и 7778 (UDP) успешно открыты!
    echo Теперь устройства в локальной сети (ноутбуки/ПК) смогут подключиться.
) else (
    echo.
    echo [ВНИМАНИЕ] Для изменения настроек брандмауэра нужны права администратора!
    echo Пожалуйста, нажмите правой кнопкой мыши по этому файлу и выберите:
    echo "Запуск от имени администратора".
)
echo.
echo =====================================================================
pause
