# MuMu Android 15：Magisk + LSPosed 一键安装工具

> **版本：1.0.3**
> **上游：** [Bascter-Main/mumu_magisk_lsposed_oneclick](https://github.com/Bascter-Main/mumu_magisk_lsposed_oneclick)（原作者：Main）
>
> 面向 MuMu Android 15 实例的一键 Magisk、NeoZygisk 与 Vector（LSPosed）安装工具。双击 `install.cmd` 即可完成下载、校验、安装与验证。

## 目录

- [工作原理](#工作原理)
- [适用范围](#适用范围)
- [安装前准备](#安装前准备)
- [快速开始](#快速开始)
- [安装过程会发生什么](#安装过程会发生什么)
- [安装完成后的设置](#安装完成后的设置)
- [最终正常状态](#最终正常状态)
- [参数与离线安装](#参数与离线安装)
- [在线下载与缓存](#在线下载与缓存)
- [验证与诊断](#验证与诊断)
- [日志位置](#日志位置)
- [卸载方法](#卸载方法)
- [故障排查](#故障排查)
- [文件校验](#文件校验)
- [风险说明](#风险说明)
- [更新日志](#更新日志)

---

## 工作原理

- **不修改 boot 镜像。** 利用 MuMu 的"可写系统盘"，把官方 Magisk 完整运行时装入 `/data/adb/magisk`，并通过自定义 init 配置（`/system/etc/init/magisk.rc`）在开机时以用户态方式拉起 Magisk 守护进程。
- **模块全部使用官方原包。** NeoZygisk 与 Vector（LSPosed）的 ZIP 原样交给 Magisk 官方模块安装入口，安装器不修改模块内容。
- **处理 MuMu 自带 KernelSU 冲突。** 关闭 MuMu 的 Root 开关后内核接口仍在，NeoZygisk 会报 `Invalid root implementation: Multiple`。安装器把 `/data/adb/ksud` 备份并隔离（卸载时可恢复），使系统只检测到 Magisk。
- **系统级兼容启动器。** 在 `/system/bin/magisk` 放置带 `MUMU_MAGISK_COMPAT_LAUNCHER_v` 标记的启动器，让 Magisk 在 Android 标准 PATH 中可被发现，并防止模块被两个根实现重复执行。

## 适用范围

本工具仅适用于：

```text
MuMu Android 15
```

不适用于：

- MuMu Android 12
- MuMu Android 9
- 其他安卓模拟器
- Android 15 以外的系统版本

安装器会自动读取设备的 Android 版本。如果检测结果不是 Android 15，脚本会立即停止，不会继续修改系统文件。

运行环境：Windows 10/11，PowerShell 5.1（`.cmd` 启动器已做环境隔离），需要 `adb`（platform-tools）与网络连接。

---

## 安装前准备

请启动需要安装的 MuMu Android 15 实例，并逐项完成：

1. **确认系统版本**为 Android 15。
2. **创建实例快照**，以便设备无法启动时快速恢复。
3. **开启 Root 权限**：设备设置 → 开发者选项 → Root 权限。
4. **开启系统盘读写**：设备设置 → 开发者选项 → 磁盘共享 → 可写系统盘。
5. **开启网络桥接模式**：设备设置 → 网络 → 网络桥接模式。
6. **开启 ADB**，确保电脑可以连接 MuMu 的 ADB 服务。

> [!IMPORTANT]
> 如果刚刚修改了 Root 权限、可写系统盘或网络桥接模式，请先在 MuMu 窗口中点击一次"重启设备"，等待 Android 完整启动后再运行安装器。
>
> 不要只关闭模拟器窗口，也不要只重新连接 ADB。

---

## 快速开始

1. 完整解压工具包（不要在压缩软件中直接运行）。
2. 双击：

   ```text
   install.cmd
   ```

3. 按提示确认安装前 6 项准备已完成，输入 `YES`。
4. 选择 MuMu 设备地址，支持：

   | 输入方式 | 示例 |
   |---|---|
   | 列表编号 | `1` |
   | IP 地址（默认端口 5555） | `192.168.1.42` |
   | IP 和端口 | `192.168.1.42:5555` |
   | 本机默认实例 | `127.0.0.1:16384` |

   桥接模式下可在 Mumu 中查看局域网 IP；本机直连时 MuMu 12 默认实例的 ADB 端口为 `16384`（多实例端口不同）。

   最后一次选择的地址保存在 `config\last-device.txt`，下次运行直接回车即可复用。设备地址不通过 `install.cmd` 命令行参数传入。

5. 安装器自动下载并校验 Magisk、NeoZygisk、Vector（需联网），完成写入后会提示重启。
6. 在 MuMu 中点击"重启设备"，回到命令窗口输入 `RESTART`，安装器等待设备完成启动并做最终验证。

---

## 安装过程会发生什么

安装器会自动检查：

- Android 版本是否为 15；
- `adbd root` 是否真正生效；
- `/system` 是否可以实际写入；
- 设备 ABI 是否受支持；
- Magisk 核心运行时是否完整；
- NeoZygisk 模块包是否有效；
- Vector 模块包是否有效；
- 设备端 Shell 脚本是否通过语法检查；
- Magisk 与 MuMu 内置 Root 框架是否存在执行冲突。

所有持久化写入开始之前，`/system` 写入探测和脚本语法检查必须通过，失败时不会留下半成品。

完成安装文件写入后，脚本会要求在 MuMu 中点击"重启设备"，然后输入：

```text
RESTART
```

脚本通过以下状态确认设备已经完成真正的重启：

- `boot_id` 变化
- `sys.boot_completed` 为 1

> [!WARNING]
> 关闭 MuMu 窗口、重新连接 ADB 或重新启动安装脚本，都不会被视为完整设备重启。

---

## 安装完成后的设置

设备重启完成后，安装器会自动打开 Magisk App。

### 请在 Magisk 中完成

1. 打开"模块"页面，开启 **NeoZygisk**。
2. 开启 **Vector**。
3. 本方案使用 NeoZygisk，请勿同时开启 Magisk 设置页面中的内置 Zygisk。
4. 保持 `Enforce DenyList` 关闭。

### 请在 MuMu 中完成

1. 返回当前设备窗口。
2. 确认 NeoZygisk 和 Vector 均处于启用状态。
3. 关闭 MuMu 自带 Root 权限：设备设置 → 开发者选项 → Root 权限。
4. 在 MuMu 窗口中点击"重启设备"，不要从 Magisk 中重启。
5. 重启完成后打开 NeoZygisk 检查状态。

> [!CAUTION]
> NeoZygisk 与 Magisk 内置 Zygisk 不应同时启用，否则可能导致模块冲突、注入异常或设备启动问题。

---

## 最终正常状态

NeoZygisk 页面应显示：

```text
monitor: tracing
zygote64: injected
daemon64: running
```

同时应满足：

- 系统中只有一个 `zygisk-ptrace64 monitor`；
- `/proc/1/status` 中的 `TracerPid` 指向该 monitor；
- `zygiskd64` 正常运行；
- `lspd` 正常运行；
- 不再出现：

  ```text
  Invalid root implementation: Multiple
  ```

---

## 参数与离线安装

### 安装参数

| 参数 | 用途 |
|---|---|
| `-MagiskApk <路径>` | 使用本地 Magisk APK，跳过在线下载 |
| `-NeoZygiskZip <路径>` | 使用本地 NeoZygisk 模块 ZIP |
| `-VectorZip <路径>` | 使用本地 Vector 模块 ZIP |
| `-AdbPath <路径>` | 指定 adb.exe 位置，默认从 PATH 查找 `adb` |
| `-NoReboot` | 安装完成后不提示重启（模块需手动重启后才加载） |
| `-AutoReboot` | 尝试通过 ADB 自动重启设备，失败时回退为人工重启 |
| `-BootTimeoutSeconds <秒>` | 等待设备重启完成的超时，默认 480 |
| `-ReplaceManager` | 管理器 APK 签名不兼容时，先卸载旧管理器再安装 |
| `-Force` | 跳过安装前的 YES 确认 |

### 卸载参数

| 参数 | 用途 |
|---|---|
| `-UninstallManager` | 同时卸载 Magisk 管理器 APK |
| `-Force` | 跳过卸载前的 YES 确认 |
| `-AdbPath <路径>` | 指定 adb.exe 位置 |

### 方式一：使用 packages 目录

本工具包不内置 NeoZygisk。将官方 NeoZygisk ZIP 命名为 `NeoZygisk.zip` 放入 `packages` 目录，安装器会优先使用该文件。

### 方式二：通过 PowerShell 参数指定

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Install-Mumu-Magisk-Vector.ps1 `
  -MagiskApk .\Magisk.apk `
  -NeoZygiskZip .\NeoZygisk.zip `
  -VectorZip .\Vector.zip
```

本地模块 ZIP 必须是标准模块包，根目录应包含 `module.prop` 与 `customize.sh`；模块 ID 应为：

- NeoZygisk：`zygisksu`
- Vector：`zygisk_vector`

安装器只会校验和安装这些 ZIP，不会修改其内容。

### 覆盖安装

已安装旧版本时，直接运行本版 `install.cmd` 即可。安装器会完整更新 Magisk、NeoZygisk、Vector 和启动环境；旧版中曾经内置或修改过的 NeoZygisk，会被在线下载的官方模块完整替换。

---

## 在线下载与缓存

默认情况下，安装器会查询并下载：

- Magisk 最新稳定版
- NeoZygisk 最新稳定版
- Vector 最新稳定版

下载文件保存在 `work\downloads`。安装失败后重新运行时，可以复用已经完成校验的缓存。

如果 GitHub API 返回资产 SHA-256 digest，安装器会进行完整哈希校验；否则会至少检查下载文件大小和模块结构。实际使用的模块 ZIP SHA-256 会写入主机端安装日志。

---

## 验证与诊断

### 系统写入诊断工具

双击：

```text
diagnose-system-rw.cmd
```

它会通过 `adbd root`、`su -c`、`su 0` 三条通道逐一测试 `/system` 写入并输出详细诊断。安装器报"/system 写入探测失败"时，先运行它定位是哪个通道的问题。

### 常用验证命令

先查看保存的设备地址（假设为 `192.168.1.42:5555`）：

```text
config\last-device.txt
```

检查 Magisk 版本：

```bash
adb -s 192.168.1.42:5555 shell "/debug_ramdisk/magisk -v"
```

检查 Magisk Root（正常输出应包含 `uid=0(root)`）：

```bash
adb -s 192.168.1.42:5555 shell "/debug_ramdisk/su -c id"
```

检查模块状态（没有输出通常表示不存在处于 `unloaded` 状态的模块）：

```bash
adb -s 192.168.1.42:5555 shell "/debug_ramdisk/su -c 'find /data/adb/modules -name unloaded -print'"
```

检查 NeoZygisk monitor（正常情况下只应存在一个）：

```bash
adb -s 192.168.1.42:5555 shell "ps -A | grep zygisk-ptrace"
```

检查 init 的 TracerPid：

```bash
adb -s 192.168.1.42:5555 shell "grep TracerPid /proc/1/status"
```

检查 LSPosed 数据目录：

```bash
adb -s 192.168.1.42:5555 shell "/debug_ramdisk/su -c 'ls -la /data/adb/lspd 2>/dev/null'"
```

以上命令在 CMD 与 PowerShell 中均可直接使用。

---

## 日志位置

### 主机端日志

```text
logs\install-日期时间.log
```

例如 `logs\install-20260801-231500.log`。

### 设备端日志

```text
/data/local/tmp/mumu-magisk-oneclick.log
/data/local/tmp/magisk_init.log
```

安装失败、模块异常或设备重启异常时，请优先检查这些日志。

---

## 卸载方法

双击：

```text
uninstall.cmd
```

卸载器会：

1. 读取上次保存的 MuMu 设备地址（可在卸载前修改）；
2. 移除 Magisk 启动项；
3. 移除 NeoZygisk 和 Vector；
4. 移除 Magisk 运行时；
5. 移除本工具安装的系统级 Magisk 兼容启动器；
6. 恢复安装前备份的同名系统文件和 Root userspace 文件。

是否同时卸载 Magisk 管理器 APK，通过 `-UninstallManager` 参数选择。

卸载完成后，请在 MuMu 窗口中手动点击"重启设备"。

---

## 故障排查

| 现象 | 处理 |
|---|---|
| `找不到 adb` | 把 platform-tools 加入 PATH，或用 `-AdbPath` 指定 adb.exe |
| `无法连接 <IP>` | 确认 MuMu 已开启 ADB 和网络桥接模式、IP 正确、防火墙放行 ADB；本机实例可改用 `127.0.0.1:16384` |
| `adbd 没有获得 root` | 确认 Root 权限已开启，然后在 MuMu 中点击"重启设备"后重跑 |
| `/system 写入探测...均失败` | 确认已开"可写系统盘"，且修改后重启过设备；运行 `diagnose-system-rw.cmd` 定位通道 |
| `APK 内的 Magisk 二进制都无法...执行` | 用 `-MagiskApk` 指定与当前实例 ABI 匹配的 Magisk APK |
| 管理器安装报 `INSTALL_FAILED_UPDATE_INCOMPATIBLE` | 重跑并加 `-ReplaceManager`（会卸载旧管理器），或手动卸载旧管理器后安装 |
| `没有检测到完整的设备重启` | 必须在 MuMu 窗口点击"重启设备"；关窗口、重连 ADB、重跑脚本都不算。卡启动时用快照恢复 |
| 直接运行 `.ps1` 时 `Get-FileHash 无法识别` | 从 PowerShell 7 终端启动 5.1 会继承被污染的模块路径；请用 `install.cmd` 启动（1.0.2 已在启动器内隔离） |
| NeoZygisk 显示 `Invalid root implementation: Multiple` | 完成"安装完成后的设置"中的 MuMu 侧步骤：关闭 MuMu Root 权限并第二次重启 |

---

## 项目结构与测试

```text
├─ install.cmd / uninstall.cmd / diagnose-system-rw.cmd   入口（双击运行）
├─ scripts\      PowerShell 主脚本
├─ payload\      设备端 shell 脚本（安装/卸载/诊断共用，仓库强制 LF）
├─ packages\     离线安装包放置处（可选）
├─ test\         冒烟测试（假 adb，无需真机）
└─ logs\ work\ backups\ config\   运行时目录（自动生成，已 gitignore）
```

修改后可在无真机环境下跑全流程回归：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File test\smoke.ps1
```

冒烟测试用假 adb 模拟一台已 root、/system 可写的设备，完整执行安装（-NoReboot）、卸载、诊断三条链路，并逐字节比对生成的设备端脚本与 `payload\` 源文件。

---

## 文件校验

下载工具包后可校验完整性：

```bash
sha256sum -c SHA256SUMS.txt
```

---

## 风险说明

> [!WARNING]
> 本工具属于针对 MuMu Android 15 的非官方 live/manual Magisk 注入方案。
>
> 修改系统文件可能导致：
>
> - 实例无法正常启动；
> - Magisk 或模块加载失败；
> - 模拟器更新后功能失效；
> - 系统文件与 MuMu 原始状态不一致；
> - 需要通过快照恢复实例。

---

## 更新日志

### 1.0.3

- 目录重构：入口 `.cmd` 保留在根目录，主脚本移入 `scripts\`，设备端 shell 脚本提取为 `payload\` 独立文件（仓库强制 LF），可本地 `sh -n` 检查。
- 修复 payload 为无 BOM UTF-8 时，Windows PowerShell 5.1 按 ANSI 读取导致换行丢失与乱码的问题（该问题会损坏设备端脚本）。
- 新增 `test\smoke.ps1` 冒烟测试：假 adb 模拟已 root 设备，无需真机跑完安装/卸载/诊断全流程。
- 诊断工具与安装器共用同一份 `/system` 探测脚本，口径一致。
- 兼容启动器标记随版本升级为 `v1.0.3`（跨版本前缀识别不受影响）。

### 1.0.2

- 修复从 PowerShell 7 终端运行 `.cmd` 时，Windows PowerShell 5.1 继承 PS7 模块路径导致 `Get-FileHash` 丢失、下载校验失败的问题。
- 兼容启动器标记改为前缀识别：旧版安装的 `/system/bin/magisk` 能被新版安装器正确备份、被新版卸载器干净移除，不会再覆盖原始备份。
- 修正 `packages/README.txt` 文案。
- 重新生成 `SHA256SUMS.txt`，移除指向不存在文件的条目。
- 重构 README：补充诊断工具、完整参数表、故障排查与文件校验说明。

### 1.0.1

- NeoZygisk 不再内置于工具包中，安装时下载官方最新稳定版。
- 下载的 NeoZygisk ZIP 会原样交给 Magisk 安装，不修改模块脚本或二进制。
- 支持复用已经校验的下载缓存。
- 支持通过 `packages\NeoZygisk.zip` 或 PowerShell 参数进行离线安装。
- 增加系统级 Magisk 兼容启动器，避免 MuMu 内置 Root 框架重复执行模块。
- 增加 KernelSU userspace 冲突处理，避免 NeoZygisk 报告 `Invalid root implementation: Multiple`。
- 保留模块 `sepolicy.rule` 动态加载逻辑。
- 增加 NeoZygisk monitor 数量、`TracerPid`、进程状态和模块运行状态检查。
- 修复 Windows PowerShell 5.1 中文编码及多层命令引号问题。
