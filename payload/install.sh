#!/system/bin/sh
LOG=/data/local/tmp/mumu-magisk-oneclick.log
: > "$LOG"

log() {
    echo "[Mumu Installer] $*"
    echo "[$(date '+%F %T')] $*" >> "$LOG"
}

fail() {
    log "ERROR: $*"
    exit 1
}

log "Checking root"
id | grep -q 'uid=0' || fail "adbd is not root"

BACKUP=/data/local/tmp/mumu_magisk_backup
PERSIST_BACKUP=/data/adb/mumu-magisk-backup
rm -rf "$BACKUP"
mkdir -p "$BACKUP" "$PERSIST_BACKUP"
[ -f /system/etc/init/magisk.rc ] && cp -af /system/etc/init/magisk.rc "$BACKUP/magisk.rc.old"
[ -f /data/adb/magisk_init.sh ] && cp -af /data/adb/magisk_init.sh "$BACKUP/magisk_init.sh.old"
[ -f /data/adb/magisk.db ] && cp -af /data/adb/magisk.db "$BACKUP/magisk.db.old"
# 前缀匹配识别任意版本安装的兼容启动器，避免新版重跑时把旧启动器覆盖进原始备份槽
if [ -e /system/bin/magisk ] && ! grep -q 'MUMU_MAGISK_COMPAT_LAUNCHER_v' /system/bin/magisk 2>/dev/null; then
    rm -rf "$PERSIST_BACKUP/system-bin-magisk"
    cp -af /system/bin/magisk "$PERSIST_BACKUP/system-bin-magisk" || fail "backup existing /system/bin/magisk"
    log "Backed up existing /system/bin/magisk"
fi

# Closing MuMu's Root switch does not remove the KernelSU kernel interface. NeoZygisk
# also requires /data/adb/ksud for KernelSU detection, so make that path absent while
# preserving the original executable for uninstall/rollback.
if [ -e /data/adb/ksud ] || [ -L /data/adb/ksud ]; then
    if [ ! -e "$PERSIST_BACKUP/ksud" ] && [ ! -L "$PERSIST_BACKUP/ksud" ]; then
        mv /data/adb/ksud "$PERSIST_BACKUP/ksud" || fail "backup and quarantine /data/adb/ksud"
        chmod 0700 "$PERSIST_BACKUP/ksud" 2>/dev/null || true
        log "Backed up and quarantined KernelSU userspace daemon"
    else
        rm -rf /data/adb/ksud || fail "remove restored /data/adb/ksud"
        log "Removed restored KernelSU userspace daemon; original backup retained"
    fi
fi
[ ! -e /data/adb/ksud ] && [ ! -L /data/adb/ksud ] || fail "KernelSU userspace path still exists"

mkdir -p /data/adb/magisk || fail "cannot create /data/adb/magisk"

# 安装完整 Magisk 运行时，而不是只放 magisk/magiskpolicy/busybox。
# magisk --install-module 会硬性检查 util_functions.sh；官方 live_setup 也会
# 把 assets/*.sh、magiskboot、magiskinit 一并放入 MAGISKBIN。
for file in magisk magisk32 magiskpolicy busybox magiskboot magiskinit util_functions.sh boot_patch.sh addon.d.sh app_functions.sh uninstaller.sh module_installer.sh stub.apk; do
    [ -f "/data/local/tmp/mumu_magisk_stage/$file" ] || continue
    cp -af "/data/local/tmp/mumu_magisk_stage/$file" "/data/adb/magisk/$file" || fail "copy $file"
done

for file in magisk magiskpolicy busybox magiskboot magiskinit util_functions.sh; do
    [ -s "/data/adb/magisk/$file" ] || fail "incomplete Magisk runtime: missing $file"
done
chmod 0755 /data/adb/magisk/magisk /data/adb/magisk/magiskpolicy /data/adb/magisk/busybox /data/adb/magisk/magiskboot /data/adb/magisk/magiskinit /data/adb/magisk/*.sh
[ -f /data/adb/magisk/magisk32 ] && chmod 0755 /data/adb/magisk/magisk32
[ -f /data/adb/magisk/stub.apk ] && chmod 0644 /data/adb/magisk/stub.apk

# 在产生持久化改动之前检查脚本与版本占位符，避免把半成品写入模块目录。
/data/adb/magisk/busybox sh -n /data/adb/magisk/util_functions.sh || fail "util_functions.sh syntax"
grep -q '^MAGISK_VER_CODE=' /data/adb/magisk/util_functions.sh || fail "util_functions.sh has no version metadata"

cp -af /data/local/tmp/magisk.rc /system/etc/init/magisk.rc || fail "install magisk.rc"
cp -af /data/local/tmp/magisk_init.sh /data/adb/magisk_init.sh || fail "install magisk_init.sh"
cp -af /data/local/tmp/magisk-compat /system/bin/magisk || fail "install /system/bin/magisk compatibility launcher"
chmod 0644 /system/etc/init/magisk.rc
chmod 0755 /data/adb/magisk_init.sh /system/bin/magisk
chown root:root /system/etc/init/magisk.rc /data/adb/magisk_init.sh /system/bin/magisk /data/adb/magisk/* 2>/dev/null || true
restorecon /system/etc/init/magisk.rc /data/adb/magisk_init.sh /system/bin/magisk /data/adb/magisk/* 2>/dev/null || true
grep -q 'MUMU_MAGISK_COMPAT_LAUNCHER_v1.0.3' /system/bin/magisk || fail "compatibility launcher marker missing"
log "Installed Magisk compatibility launcher; KernelSU userspace is quarantined so NeoZygisk detects Magisk only"

[ -x /debug_ramdisk/magisk ] && /debug_ramdisk/magisk --stop 2>/dev/null || true
mkdir -p /debug_ramdisk
if ! grep -q ' /debug_ramdisk ' /proc/mounts; then
    mount -t tmpfs -o mode=0755 tmpfs /debug_ramdisk || fail "mount /debug_ramdisk"
fi

/system/bin/sh /data/adb/magisk_init.sh || fail "magisk_init.sh"
/debug_ramdisk/magisk --daemon || fail "start magisk daemon"
sleep 1
/debug_ramdisk/magisk --post-fs-data || fail "post-fs-data"
/debug_ramdisk/magisk --service || true
[ "$(getprop sys.boot_completed)" = "1" ] && /debug_ramdisk/magisk --boot-complete || true
/debug_ramdisk/magisk --restorecon 2>/dev/null || true

log "Magisk version: $(/debug_ramdisk/magisk -v 2>&1)"
/debug_ramdisk/su -c id || fail "MagiskSU verification"

# NeoZygisk replaces built-in Zygisk in this unsupported emulator setup.
# This installer is already running as uid 0, so call magisk directly. Avoid nested
# su -c quoting: Android mksh would parse SQL parentheses as shell syntax.
/debug_ramdisk/magisk --sqlite "INSERT OR REPLACE INTO settings SELECT 'zygisk',0;" || true

install_module_zip() {
    name="$1"
    zipfile="$2"
    [ -s "$zipfile" ] || fail "$name zip missing"

    modid=$(/data/adb/magisk/busybox unzip -p "$zipfile" module.prop 2>/dev/null | sed -n 's/^id=//p' | head -n 1 | tr -d '\015')
    [ -n "$modid" ] || fail "$name module.prop/id missing"
    log "Installing $name (id=$modid)"

    # 完整重装：清除上一次未完成的更新目录，避免旧文件与新模块混装。
    rm -rf "/data/adb/modules_update/$modid"
    rm -f "/data/adb/modules/$modid/disable" "/data/adb/modules/$modid/remove" 2>/dev/null || true

    # 首选 Magisk 官方入口。若某个版本的 CLI 环境检查仍不兼容手工 live setup，
    # 直接执行同一份官方 util_functions.sh 作为等价回退，并保留完整输出。
    if ! /debug_ramdisk/magisk --install-module "$zipfile"; then
        log "$name: Magisk CLI installer failed; trying official util_functions fallback"
        OUTFD=1 ZIPFILE="$zipfile" ASH_STANDALONE=1 MAGISKTMP=/debug_ramdisk PATH=/debug_ramdisk:/data/adb/magisk:$PATH /data/adb/magisk/busybox sh -c '. /data/adb/magisk/util_functions.sh; install_module' || fail "$name install"
    fi

    if [ ! -s "/data/adb/modules_update/$modid/module.prop" ] && [ ! -s "/data/adb/modules/$modid/module.prop" ]; then
        fail "$name installer returned success but module was not staged"
    fi
    log "$name staged successfully"
}

install_module_zip "NeoZygisk" /data/local/tmp/NeoZygisk.zip
install_module_zip "Vector" /data/local/tmp/Vector.zip

# NeoZygisk ZIP is installed as supplied. Duplicate execution is prevented at the
# root-framework boundary by /system/bin/magisk, not by changing third-party files.
NEODIR=""
[ -d /data/adb/modules_update/zygisksu ] && NEODIR=/data/adb/modules_update/zygisksu
[ -z "$NEODIR" ] && [ -d /data/adb/modules/zygisksu ] && NEODIR=/data/adb/modules/zygisksu
[ -n "$NEODIR" ] || fail "NeoZygisk module directory missing after install"
[ -s "$NEODIR/post-fs-data.sh" ] || fail "NeoZygisk post-fs-data.sh missing after install"
[ -s "$NEODIR/service.sh" ] || fail "NeoZygisk service.sh missing after install"
for d in /data/adb/modules/zygisksu /data/adb/modules_update/zygisksu /data/adb/modules/zygisk_vector /data/adb/modules_update/zygisk_vector; do
    [ -d "$d" ] || continue
    rm -f "$d/disable" "$d/remove"
done
rm -rf /data/adb/neozygisk-mumu-guard 2>/dev/null || true
log "Official NeoZygisk module staged without modifying its scripts"
log "Root conflict prevention: /data/adb/ksud quarantined; /system/bin/magisk remains the only detected userspace root"
log "Duplicate module execution prevention is provided by the system Magisk compatibility launcher"

log "Installation staged successfully. Reboot is required."
exit 0