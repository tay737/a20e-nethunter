#!/system/bin/sh
# a20e stability, boot stage.
# 1) relax framework timeouts: this 4.4 kernel + Lineage 19.1 is slow to bring up
#    system_server, which trips ANR/watchdog and wedges the UI
# 2) keep the NetHunter chroot's dbus fix alive: reinstalling the NetHunter module
#    rewrites /etc/init.d/dbus, and without --chuid dbus dies on capset

LOG=/data/adb/a20e-stability.log
R=/data/local/nhsystem/kali-arm64

/data/adb/ksu/bin/resetprop -n ro.hw_timeout_multiplier 10
echo "boot=$(date +%s) hw_timeout_multiplier=$(getprop ro.hw_timeout_multiplier)" >> "$LOG"

DBUS_INIT="$R/etc/init.d/dbus"
if [ -f "$DBUS_INIT" ]; then
    if ! grep -q -- '--chuid $DAEMONUSER' "$DBUS_INIT"; then
        [ -f "$DBUS_INIT.orig" ] || cp "$DBUS_INIT" "$DBUS_INIT.orig"
        sed -i 's|--exec $DAEMON -- --system $PARAMS|--chuid $DAEMONUSER --exec $DAEMON -- --system $PARAMS|' "$DBUS_INIT"
        echo "dbus_init=patched $(date +%s)" >> "$LOG"
    else
        echo "dbus_init=already-patched" >> "$LOG"
    fi
fi
