# 冒烟测试：在临时目录中用假 adb 完整跑一遍 安装(-NoReboot) → 卸载 → 诊断。
# 同时验证：目录布局（运行时目录在工具根而非 scripts\ 下）、
# payload 提取回归（设备端脚本生成内容与 payload\ 逐字节一致）。
# 用法：powershell -NoProfile -ExecutionPolicy Bypass -File test\smoke.ps1
$ErrorActionPreference = "Stop"

$testRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $testRoot

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "断言失败：$Message" }
}

$stage = Join-Path ([System.IO.Path]::GetTempPath()) ("mumu-smoke-" + (Get-Date -Format "yyyyMMdd-HHmmss"))
$tree = Join-Path $stage "tree"
New-Item -ItemType Directory -Force -Path $tree | Out-Null

# 复制被测文件，排除运行时目录与 .git
robocopy $repoRoot $tree /E /XD .git work logs backups config .serena /XF *.log | Out-Null
if ($LASTEXITCODE -ge 8) { throw "robocopy 失败：$LASTEXITCODE" }

# 固定设备地址
New-Item -ItemType Directory -Force -Path (Join-Path $tree "config") | Out-Null
[System.IO.File]::WriteAllText((Join-Path $tree "config\last-device.txt"), "127.0.0.1:16384")

# ---- 夹具：最小合法 Magisk APK 与两个模块 ZIP ----
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
$fixtures = Join-Path $stage "fixtures"
New-Item -ItemType Directory -Force -Path $fixtures | Out-Null

function New-Zip {
    param([string]$Path, [hashtable]$Entries)
    $zip = [System.IO.Compression.ZipFile]::Open($Path, "Create")
    try {
        foreach ($name in $Entries.Keys) {
            $entry = $zip.CreateEntry($name)
            $writer = New-Object System.IO.StreamWriter($entry.Open(), (New-Object System.Text.UTF8Encoding($false)))
            try { $writer.Write(($Entries[$name] -replace "`r`n", "`n")) } finally { $writer.Dispose() }
        }
    } finally { $zip.Dispose() }
}

$apk = Join-Path $fixtures "Magisk-fake.apk"
$apkEntries = @{}
foreach ($lib in "libmagisk.so", "libmagiskpolicy.so", "libbusybox.so", "libmagiskboot.so", "libmagiskinit.so") {
    $apkEntries["lib/x86_64/$lib"] = "fake-binary"
}
$apkEntries["lib/x86/libmagisk.so"] = "fake-binary-32"
foreach ($asset in "util_functions.sh", "boot_patch.sh", "addon.d.sh", "app_functions.sh", "uninstaller.sh", "module_installer.sh") {
    $apkEntries["assets/$asset"] = "MAGISK_VER_CODE=31000`n# fake $asset`n"
}
$apkEntries["assets/stub.apk"] = "fake-stub"
New-Zip -Path $apk -Entries $apkEntries

$neo = Join-Path $fixtures "NeoZygisk-fake.zip"
New-Zip -Path $neo -Entries @{ "module.prop" = "id=zygisksu`nname=NeoZygisk fake`nversion=v1`n"; "customize.sh" = "# fake`n" }
$vector = Join-Path $fixtures "Vector-fake.zip"
New-Zip -Path $vector -Entries @{ "module.prop" = "id=zygisk_vector`nname=Vector fake`nversion=v1`n"; "customize.sh" = "# fake`n" }

# ---- 运行被测脚本 ----
$fakeAdb = Join-Path $testRoot "fake-adb.cmd"
$fakeLog = Join-Path $stage "fake-adb-calls.log"
$env:FAKE_ADB_LOG = $fakeLog
# 与 install.cmd 相同的环境隔离：清掉 pwsh 父进程传入的 PSModulePath，
# 避免 5.1 子进程加载 PS7 版 Microsoft.PowerShell.Utility 导致 Get-FileHash 丢失
Remove-Item Env:\PSModulePath -ErrorAction SilentlyContinue
$answerFile = Join-Path $stage "stdin.txt"
Set-Content -LiteralPath $answerFile -Value "" -Encoding Ascii

function Invoke-ToolScript {
    param([string]$Script, [string[]]$ExtraArgs, [string]$Name)
    $outLog = Join-Path $stage "$Name-out.log"
    $errLog = Join-Path $stage "$Name-err.log"
    $p = Start-Process -FilePath "powershell.exe" -ArgumentList (@(
        "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $tree "scripts\$Script")
    ) + $ExtraArgs) -WorkingDirectory $tree `
        -RedirectStandardInput $answerFile -RedirectStandardOutput $outLog -RedirectStandardError $errLog `
        -WindowStyle Hidden -Wait -PassThru
    if ($p.ExitCode -ne 0) {
        Get-Content $outLog; Get-Content $errLog
        throw "$Name 退出码 $($p.ExitCode)"
    }
    return $outLog
}

# 1) 安装（跳过确认与重启；模块走本地夹具，不联网）
Invoke-ToolScript -Script "Install-Mumu-Magisk-Vector.ps1" `
    -ExtraArgs @("-Force", "-NoReboot", "-AdbPath", $fakeAdb, "-MagiskApk", $apk, "-NeoZygiskZip", $neo, "-VectorZip", $vector) `
    -Name "install" | Out-Null

# 运行时目录必须落在工具根，而不是 scripts\ 下
Assert-True (Test-Path (Join-Path $tree "work\stage\magisk")) "work\stage 未生成"
Assert-True (Test-Path (Join-Path $tree "logs")) "logs 未生成"
Assert-True (-not (Test-Path (Join-Path $tree "scripts\work"))) "scripts\ 下不应出现 work"

# payload 提取回归：生成的设备端脚本与 payload\ 逐字节一致
foreach ($pair in @(
    @("magisk.rc", "magisk.rc"),
    @("magisk-compat", "magisk-compat"),
    @("magisk_init.sh", "magisk-init.sh"),
    @("mumu-magisk-install.sh", "install.sh"),
    @("mumu-system-rw-probe.sh", "system-rw-probe.sh")
)) {
    $generated = [System.IO.File]::ReadAllBytes((Join-Path $tree ("work\" + $pair[0])))
    $expected = [System.IO.File]::ReadAllBytes((Join-Path $repoRoot ("payload\" + $pair[1])))
    Assert-True ([BitConverter]::ToString($generated) -eq [BitConverter]::ToString($expected)) ("payload 生成内容不一致：" + $pair[0])
}

$calls = Get-Content -LiteralPath $fakeLog
Assert-True (@($calls | Where-Object { $_ -match ' shell /data/local/tmp/mumu-magisk-install\.sh$' }).Count -gt 0) "远端安装脚本未执行"
$hostLog = Get-ChildItem (Join-Path $tree "logs") -Filter "install-*.log" | Sort-Object LastWriteTime | Select-Object -Last 1
Assert-True ((Get-Content $hostLog.FullName -Raw) -match "已按 -NoReboot 跳过重启") "安装未走到 -NoReboot 出口"

# 2) 卸载
Invoke-ToolScript -Script "Uninstall-Mumu-Magisk-Vector.ps1" `
    -ExtraArgs @("-Force", "-AdbPath", $fakeAdb) -Name "uninstall" | Out-Null
$calls += Get-Content -LiteralPath $fakeLog
Assert-True (@($calls | Where-Object { $_ -match ' shell sh /data/local/tmp/mumu-magisk-uninstall\.sh$' }).Count -gt 0) "远端卸载脚本未执行"
Assert-True (@($calls | Where-Object { $_ -match ' reboot$' }).Count -gt 0) "卸载后未 reboot"

# 3) 诊断
$diagLog = Invoke-ToolScript -Script "Diagnose-Mumu-SystemRW.ps1" `
    -ExtraArgs @("-AdbPath", $fakeAdb) -Name "diagnose"
Assert-True ((Get-Content $diagLog -Raw) -match "\[1\] adbd root") "诊断三条通道未执行"

Remove-Item Env:\FAKE_ADB_LOG -ErrorAction SilentlyContinue
Write-Host "SMOKE PASS：安装、卸载、诊断全流程通过；payload 生成内容与源文件逐字节一致。" -ForegroundColor Green
Remove-Item -Recurse -Force -LiteralPath $stage -ErrorAction SilentlyContinue
exit 0
