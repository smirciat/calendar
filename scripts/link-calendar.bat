@echo off
REM Link a Google Calendar account - Windows CMD wrapper
REM Usage: link-calendar.bat
REM        set FAMILY_PASSWORD=yourpassword && link-calendar.bat

cd /d "%~dp0.."
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0link-calendar.ps1" %*
pause
