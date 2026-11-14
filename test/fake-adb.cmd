@echo off
rem Fake adb shim: forwards to fake-adb.ps1 for the smoke test (ASCII only: cmd.exe reads batch files in the system codepage)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0fake-adb.ps1" %*
