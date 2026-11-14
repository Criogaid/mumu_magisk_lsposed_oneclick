#!/system/bin/sh

echo "===== module metadata ====="
for f in /data/adb/modules/*/module.prop; do
    [ -f "$f" ] || continue
    echo "====$f"
    cat "$f"
done

echo "===== unloaded markers ====="
find /data/adb/modules -path '*/zygisk/unloaded' -print 2>/dev/null || true

echo "===== root implementation boundary ====="
if [ -e /data/adb/ksud ] || [ -L /data/adb/ksud ]; then
    echo "ERROR: /data/adb/ksud still exists"
    ls -lZ /data/adb/ksud 2>/dev/null || ls -l /data/adb/ksud 2>/dev/null || true
else
    echo "KernelSU userspace: quarantined"
fi
if [ -e /data/adb/mumu-magisk-backup/ksud ] || [ -L /data/adb/mumu-magisk-backup/ksud ]; then
    echo "KernelSU backup: present"
    ls -lZ /data/adb/mumu-magisk-backup/ksud 2>/dev/null || ls -l /data/adb/mumu-magisk-backup/ksud 2>/dev/null || true
fi

echo "===== Magisk compatibility launcher ====="
ls -lZ /system/bin/magisk 2>/dev/null || ls -l /system/bin/magisk 2>/dev/null || true
grep 'MUMU_MAGISK_COMPAT_LAUNCHER_v1.0.3' /system/bin/magisk 2>/dev/null || true
/system/bin/magisk -v 2>/dev/null || true
/system/bin/magisk -V 2>/dev/null || true

echo "===== NeoZygisk runtime status ====="
cat /data/adb/neozygisk/module.prop 2>/dev/null || true

echo "===== init tracer and monitor count ====="
grep '^TracerPid:' /proc/1/status 2>/dev/null || true
ps -A -o NAME,ARGS 2>/dev/null | grep -c '[z]ygisk-ptrace.*monitor' 2>/dev/null || true

echo "===== process topology ====="
ps -A -o USER,PID,PPID,NAME,ARGS 2>/dev/null || ps -A -o USER,PID,PPID,NAME,CMD 2>/dev/null || ps -A

echo "===== Vector LSPosed data ====="
ls -la /data/adb/lspd 2>/dev/null || true