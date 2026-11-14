# 假 adb：按参数模式返回固定输出，模拟一台已 root、/system 可写的 MuMu 设备。
# 未匹配到的调用打印 FAKE-ADB UNMATCHED 并以退出码 2 失败，让测试暴露覆盖缺口。
$ErrorActionPreference = "Stop"
$a = ($args | ForEach-Object { [string]$_ }) -join ' '
if ($env:FAKE_ADB_LOG) {
    Add-Content -LiteralPath $env:FAKE_ADB_LOG -Value $a -Encoding UTF8
}

$serial = "127.0.0.1:16384"
$out = $null

if ($a -eq 'devices') {
    $out = "List of devices attached`n$serial`tdevice"
} elseif ($a -match '^connect ') {
    $out = "already connected to $serial"
} elseif ($a -match 'get-state$') {
    $out = "device"
} elseif ($a -match ' ro\.build\.version\.release$') {
    $out = "15"
} elseif ($a -match ' ro\.product\.cpu\.abilist$') {
    $out = "x86_64,arm64-v8a,x86"
} elseif ($a -match ' getenforce$') {
    $out = "Permissive"
} elseif ($a -match ' shell id$') {
    $out = "uid=0(root) context=u:r:shell:s0"
} elseif ($a -match ' cat /proc/sys/kernel/random/boot_id$') {
    $out = "11111111-2222-3333-4444-555555555555"
} elseif ($a -match ' getprop sys\.boot_completed$') {
    $out = "1"
} elseif ($a -match ' root$') {
    $out = "fake: adbd root"
} elseif ($a -match ' reboot$') {
    $out = "fake: reboot requested"
} elseif ($a -match 'system-rw-probe\.sh$') {
    $out = "MUMU_SYSTEM_RW`n-rw-r--r-- 1 root root 0 u:object_r:system_file:s0 /system/etc/init/.mumu_magisk_rw_test"
} elseif ($a -match 'mumu_magisk_probe/magisk -c$') {
    $out = "MAGISK_STUB 31.1:x86_64"
} elseif ($a -match 'grep -E .*MAGISK_VER_CODE') {
    $out = "MAGISK_VER_CODE=31000"
} elseif ($a -match ' sh -n ') {
    $out = $null
} elseif ($a -match 'mumu-magisk-install\.sh$') {
    $out = "[Mumu Installer] Checking root`n[Mumu Installer] Installation staged successfully. Reboot is required."
} elseif ($a -match 'mumu-magisk-uninstall\.sh$') {
    $out = "[fake] uninstall script executed"
} elseif ($a -match ' /debug_ramdisk/magisk -v$') {
    $out = "31.1:MUMU_FAKE"
} elseif ($a -match ' /debug_ramdisk/su -c id$') {
    $out = "uid=0(root)"
} elseif ($a -match ' pm path ') {
    $out = "package:/fake/base.apk"
} elseif ($a -match ' install( -r)? ') {
    $out = "Success"
} elseif ($a -match ' uninstall com\.') {
    $out = "Success"
} elseif ($a -match ' monkey ') {
    $out = $null
} elseif ($a -match '^[-\w:./\\]+ push ' -or $a -match ' push ') {
    $out = "file pushed"
} elseif ($a -match ' pull ') {
    # adb pull 会在本地创建目标目录，假实现照做以免后续读取失败
    $localTarget = $args[$args.Count - 1]
    New-Item -ItemType Directory -Force -Path $localTarget -ErrorAction SilentlyContinue | Out-Null
    $out = "file pulled"
} elseif ($a -match ' chmod ') {
    $out = $null
} elseif ($a -match ' rm -rf ') {
    $out = $null
} elseif ($a -match ' mkdir -p ') {
    $out = $null
} else {
    [Console]::Error.WriteLine("FAKE-ADB UNMATCHED: $a")
    exit 2
}

if ($null -ne $out) { Write-Output $out }
exit 0
