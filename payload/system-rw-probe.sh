#!/system/bin/sh
PROBE=/system/etc/init/.mumu_magisk_rw_test
ERR=/data/local/tmp/mumu-system-rw-probe.err
rm -f "$PROBE" "$ERR"

if touch "$PROBE" 2>"$ERR"; then
    chmod 0644 "$PROBE" 2>/dev/null || true
    echo MUMU_SYSTEM_RW
    ls -lZ "$PROBE" 2>/dev/null || ls -l "$PROBE" 2>/dev/null || true
    rm -f "$PROBE" "$ERR"
    exit 0
fi

echo MUMU_SYSTEM_RW_FAILED
cat "$ERR" 2>/dev/null || true
id 2>/dev/null || true
id -Z 2>/dev/null || true
grep ' /system ' /proc/mounts 2>/dev/null || true
mount 2>/dev/null | grep -E ' on /system | /system ' || true
exit 1