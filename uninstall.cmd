@echo off
setlocal
rem pwsh 父进程会传入含 PS7 模块目录的 PSModulePath，导致 5.1 加载 Core 版 Utility 而 Get-FileHash 失效；清掉让 5.1 重建默认值
set "PSModulePath="
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Uninstall-Mumu-Magisk-Vector.ps1"
echo.
pause
