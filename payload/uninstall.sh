#!/system/bin/sh
[ -x /debug_ramdisk/magisk ] && /debug_ramdisk/magisk --stop 2>/dev/null || true
for root in /data/adb/modules /data/adb/modules_update; do
    for d in "$root"/*; do
        [ -f "$d/module.prop" ] || continue
        if grep -qiE 'NeoZygisk|Vector|LSPosed' "$d/module.prop"; then
            rm -rf "$d"
        fi
    done
done
rm -f /system/etc/init/magisk.rc
rm -f /data/adb/magisk_init.sh
# 前缀匹配识别任意版本安装的兼容启动器，保证旧版安装也能被新版卸载器干净移除
if grep -q 'MUMU_MAGISK_COMPAT_LAUNCHER_v' /system/bin/magisk 2>/dev/null; then
    rm -f /system/bin/magisk
    if [ -e /data/adb/mumu-magisk-backup/system-bin-magisk ]; then
        cp -af /data/adb/mumu-magisk-backup/system-bin-magisk /system/bin/magisk
        chmod 0755 /system/bin/magisk 2>/dev/null || true
        restorecon /system/bin/magisk 2>/dev/null || true
    fi
fi
rm -rf /data/adb/magisk
rm -rf /data/adb/neozygisk /data/adb/neozygisk-mumu-guard
if [ ! -e /data/adb/ksud ] && [ ! -L /data/adb/ksud ] && { [ -e /data/adb/mumu-magisk-backup/ksud ] || [ -L /data/adb/mumu-magisk-backup/ksud ]; }; then
    cp -af /data/adb/mumu-magisk-backup/ksud /data/adb/ksud
    chmod 0700 /data/adb/ksud 2>/dev/null || true
    restorecon /data/adb/ksud 2>/dev/null || true
fi
rm -rf /data/adb/mumu-magisk-backup
sync
