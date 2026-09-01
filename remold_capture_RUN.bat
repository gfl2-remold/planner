@echo off
REM GFL2 remolding capture - double-click launcher.
REM Runs remold_capture.ps1 sitting in the SAME folder. ASCII-only on purpose.
cd /d "%~dp0"
if not exist "%~dp0remold_capture.ps1" (
  echo.
  echo  [!] remold_capture.ps1 was not found next to this file.
  echo      Download BOTH files into the SAME folder, then double-click this again.
  echo.
  pause
  exit /b
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0remold_capture.ps1"
