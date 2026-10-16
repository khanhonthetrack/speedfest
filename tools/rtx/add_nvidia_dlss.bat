@echo off
rem Adds NVIDIA's DLSS / Streamline runtime next to SpeedFest.exe (see README-RTX.txt).
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0add_nvidia_dlss.ps1" %*
pause
