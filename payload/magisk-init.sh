#!/system/bin/sh
export MAGISKTMP=/debug_ramdisk
export PATH=$MAGISKTMP/.magisk/busybox:/sbin:/system/bin:/system_ext/bin:/system/xbin:/vendor/bin:/odm/bin
MAGISKBIN=/data/adb/magisk
LOG=/data/local/tmp/magisk_init.log

log() {
    echo "[$(date '+%F %T')] $*" >> "$LOG"
}

# MuMu keeps the KernelSU kernel interface available even after its Root toggle is off.
# Official NeoZygisk treats KernelSU + Magisk as conflicting root implementations when
# /data/adb/ksud is still present. Preserve the original ksud once, then keep that path
# absent before Magisk runs module post-fs-data scripts.
PERSIST_BACKUP=/data/adb/mumu-magisk-backup
quarantine_ksu_userspace() {
    mkdir -p "$PERSIST_BACKUP" || return 1
    if [ -e /data/adb/ksud ] || [ -L /data/adb/ksud ]; then
        if [ ! -e "$PERSIST_BACKUP/ksud" ] && [ ! -L "$PERSIST_BACKUP/ksud" ]; then
            if ! mv /data/adb/ksud "$PERSIST_BACKUP/ksud" 2>>"$LOG"; then
                cp -af /data/adb/ksud "$PERSIST_BACKUP/ksud" 2>>"$LOG" || return 1
                rm -rf /data/adb/ksud 2>>"$LOG" || return 1
            fi
            chmod 0700 "$PERSIST_BACKUP/ksud" 2>/dev/null || true
            log "Backed up and quarantined KernelSU userspace daemon"
        else
            rm -rf /data/adb/ksud 2>>"$LOG" || return 1
            log "Removed a restored KernelSU userspace daemon; original backup retained"
        fi
    fi
    if [ -e /data/adb/ksud ] || [ -L /data/adb/ksud ]; then
        return 1
    fi
    log "Root implementation boundary ready: Magisk only"
    return 0
}

log "Starting Magisk initialization"
quarantine_ksu_userspace || { log "ERROR: unable to quarantine /data/adb/ksud"; exit 1; }
[ -x "$MAGISKBIN/magisk" ] || { log "Missing $MAGISKBIN/magisk"; exit 1; }

mkdir -p "$MAGISKTMP/.magisk/device" "$MAGISKTMP/.magisk/worker"
mkdir -p /data/adb/modules /data/adb/post-fs-data.d /data/adb/service.d
chmod 0755 "$MAGISKTMP/.magisk"
chmod 0711 "$MAGISKTMP/.magisk/device"

for file in magisk magisk32 magiskpolicy busybox; do
    [ -f "$MAGISKBIN/$file" ] || continue
    cp -af "$MAGISKBIN/$file" "$MAGISKTMP/$file" || exit 1
    chmod 0755 "$MAGISKTMP/$file"
done
if [ -f "$MAGISKBIN/stub.apk" ]; then
    cp -af "$MAGISKBIN/stub.apk" "$MAGISKTMP/stub.apk"
    chmod 0644 "$MAGISKTMP/stub.apk"
fi

ln -sf ./magisk "$MAGISKTMP/su"
ln -sf ./magisk "$MAGISKTMP/resetprop"
ln -sf ./magiskpolicy "$MAGISKTMP/supolicy"

if ! grep -q " $MAGISKTMP/.magisk/worker " /proc/mounts; then
    chmod 0000 "$MAGISKTMP/.magisk/worker"
    "$MAGISKTMP/busybox" mount -t tmpfs -o mode=0755 magisk "$MAGISKTMP/.magisk/worker" || true
fi
"$MAGISKTMP/busybox" mount --make-private "$MAGISKTMP/.magisk/worker" 2>/dev/null || true
chmod 0755 "$MAGISKTMP/.magisk/worker" 2>/dev/null || true

mkdir -p "$MAGISKTMP/.magisk/busybox"
"$MAGISKTMP/busybox" --install -s "$MAGISKTMP/.magisk/busybox"
export PATH=$MAGISKTMP/.magisk/busybox:$PATH

# 与 Magisk 官方 AVD live_setup 保持一致：config 表示运行时配置目录已就绪，
# live 标记当前属于 live/manual setup，而不是 boot image patch 安装。
touch "$MAGISKTMP/.magisk/config" "$MAGISKTMP/.magisk/live"
chmod 0644 "$MAGISKTMP/.magisk/config" "$MAGISKTMP/.magisk/live" 2>/dev/null || true

log "Preinit device: $(MAKEDEV=1 "$MAGISKTMP/magisk" --preinit-device 2>&1)"

RULESCMD=""
rule="$MAGISKTMP/.magisk/preinit/sepolicy.rule"
[ -f "$rule" ] && RULESCMD="--apply $rule"
if [ -d /sys/fs/selinux ]; then
    if [ -f /vendor/etc/selinux/precompiled_sepolicy ]; then
        "$MAGISKTMP/magiskpolicy" --load /vendor/etc/selinux/precompiled_sepolicy --live --magisk $RULESCMD >> "$LOG" 2>&1 || true
    elif [ -f /sepolicy ]; then
        "$MAGISKTMP/magiskpolicy" --load /sepolicy --live --magisk $RULESCMD >> "$LOG" 2>&1 || true
    else
        "$MAGISKTMP/magiskpolicy" --live --magisk $RULESCMD >> "$LOG" 2>&1 || true
    fi
fi

# MUMU_MODULE_SEPOLICY_FIX_BEGIN
# MuMu live setup does not replace Android init with magiskinit. Load enabled
# module sepolicy.rule files before Magisk runs post-fs-data module scripts.
# NeoZygisk needs these rules for its ptrace-based Zygote injection.
for module_dir in /data/adb/modules/* /data/adb/modules_update/*; do
    [ -d "$module_dir" ] || continue
    [ -f "$module_dir/disable" ] && continue
    [ -f "$module_dir/remove" ] && continue
    [ -r "$module_dir/sepolicy.rule" ] || continue
    log "Applying module sepolicy: $module_dir/sepolicy.rule"
    if ! "$MAGISKTMP/magiskpolicy" --live --apply "$module_dir/sepolicy.rule" >> "$LOG" 2>&1; then
        log "WARNING: failed to apply $module_dir/sepolicy.rule"
    fi
done
# MUMU_MODULE_SEPOLICY_FIX_END

log "Magisk initialization complete"
exit 0