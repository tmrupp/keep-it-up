@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0run_loop.ps1" %*
exit /b %ERRORLEVEL%
