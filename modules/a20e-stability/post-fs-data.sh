#!/system/bin/sh
# Relax framework timeouts at boot. This 4.4 kernel plus Lineage 19.1 is slow to bring
# up system_server, which trips ANR/watchdog and wedges the UI.
/data/adb/ksu/bin/resetprop -n ro.hw_timeout_multiplier 10
echo "boot=$(date +%s) hw_timeout_multiplier=$(getprop ro.hw_timeout_multiplier)" >> /data/adb/a20e-stability.log
