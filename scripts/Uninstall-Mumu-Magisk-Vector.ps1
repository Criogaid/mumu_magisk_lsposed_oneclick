[CmdletBinding()]
param(
    [string]$AdbPath = "adb",
    [switch]$UninstallManager,
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$cmd = Get-Command $AdbPath -ErrorAction SilentlyContinue
if ($null -eq $cmd) { throw "找不到 adb。" }
$adb = $cmd.Source
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$ToolRoot = Split-Path -Parent $ScriptRoot
$DeviceConfigPath = Join-Path $ToolRoot "config\last-device.txt"
$Device = ""
if (Test-Path -LiteralPath $DeviceConfigPath) {
    $Device = (Get-Content -LiteralPath $DeviceConfigPath -Raw -ErrorAction SilentlyContinue).Trim()
}
Write-Host ""
& $adb devices | Out-Host
if ([string]::IsNullOrWhiteSpace($Device)) {
    $Device = Read-Host "输入 Mumu IP 或 IP:端口（只输入 IP 默认 5555）"
} else {
    $answerDevice = Read-Host "Mumu 设备地址 [$Device]"
    if (-not [string]::IsNullOrWhiteSpace($answerDevice)) { $Device = $answerDevice.Trim() }
}
if ($Device -match '^[0-9]{1,3}(?:\.[0-9]{1,3}){3}$') { $Device += ":5555" }
if ($Device -notmatch '^[0-9]{1,3}(?:\.[0-9]{1,3}){3}:[0-9]{1,5}$') { throw "设备地址格式无效。" }

if (-not $Force) {
    Write-Host "此操作将移除手工 Magisk 启动项、官方 NeoZygisk/Vector 模块和系统 Magisk 兼容启动器，并恢复安装前备份的 KernelSU userspace。"
    $answer = Read-Host "输入 YES 继续"
    if ($answer -ne "YES") { exit 1 }
}

if ($Device -match ":") { & $adb connect $Device | Out-Host }
& $adb -s $Device root | Out-Host
Start-Sleep -Seconds 2
if ($Device -match ":") { & $adb connect $Device | Out-Null }

# 卸载脚本以独立文件存放在 payload\uninstall.sh，与安装器共用同一份标记约定
$tmp = Join-Path $env:TEMP "mumu-magisk-uninstall.sh"
$enc = New-Object System.Text.UTF8Encoding($false)
[IO.File]::WriteAllText($tmp, ((Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $ToolRoot "payload\uninstall.sh")) -replace "`r`n", "`n"), $enc)
& $adb -s $Device push $tmp /data/local/tmp/mumu-magisk-uninstall.sh | Out-Host
& $adb -s $Device shell chmod 0755 /data/local/tmp/mumu-magisk-uninstall.sh | Out-Host
& $adb -s $Device shell sh /data/local/tmp/mumu-magisk-uninstall.sh | Out-Host
if ($UninstallManager) {
    & $adb -s $Device uninstall com.topjohnwu.magisk | Out-Host
}
& $adb -s $Device reboot | Out-Host
Write-Host "已提交卸载并重启。卸载器会恢复安装前备份的 /system/bin/magisk 与 /data/adb/ksud（如有）。"
