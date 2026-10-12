@echo off
rem Double-click: preview the changes, then confirm.
rem With flags, runs them directly, e.g.  Share-Worlds.cmd -Status   or   Share-Worlds.cmd -Undo
setlocal
set "SCRIPT=%~dp0Share-Worlds.ps1"

if not "%~1"=="" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" %*
    goto end
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" -DryRun
if errorlevel 3 goto end
if errorlevel 1 goto end
echo.
choice /C YN /M "Apply these changes"
if errorlevel 2 goto end
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%"

:end
echo.
pause
