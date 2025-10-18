@echo off
setlocal enabledelayedexpansion

:: Define the ports you want to kill
set "PORTS_TO_KILL=3100 3101"
set "MAX_RETRIES=3"
set "RETRY_DELAY=2"

echo.
echo === Starting Automated Port Cleanup ===
echo Target Ports: %PORTS_TO_KILL%
echo -------------------------------------

FOR %%A IN (%PORTS_TO_KILL%) DO (
    echo.
    call :KillPort %%A
)

echo.
echo === Cleanup Complete ===
echo.
pause
goto :eof

:KillPort
setlocal enabledelayedexpansion
set "portNumber=%~1"
set "attempt=1"

echo Searching for process on port !portNumber!...

:retry
set "PID="
FOR /F "tokens=5" %%P IN ('netstat -ano ^| findstr :!portNumber! ^| findstr LISTENING') DO (
    SET "PID=%%P"
)

IF NOT DEFINED PID (
    echo INFO: No process found listening on port !portNumber!.
    goto done
)

echo Found PID !PID! on port !portNumber!. Attempting forceful kill (attempt !attempt!/%MAX_RETRIES%)...
taskkill /F /T /PID !PID! >nul 2>&1

:: Wait briefly and re-check the port
timeout /t %RETRY_DELAY% /nobreak >nul

set "CHECK_PID="
FOR /F "tokens=5" %%P IN ('netstat -ano ^| findstr :!portNumber! ^| findstr LISTENING') DO (
    SET "CHECK_PID=%%P"
)

IF DEFINED CHECK_PID (
    IF !attempt! LSS %MAX_RETRIES% (
        set /a attempt+=1
        goto retry
    ) ELSE (
        echo ERROR: Port !portNumber! still in use by PID !CHECK_PID! after %MAX_RETRIES% attempts.
        goto done
    )
) ELSE (
    echo SUCCESS: Port !portNumber! is now free.
)

:done
endlocal
exit /b