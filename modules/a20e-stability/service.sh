#!/system/bin/sh
# a20e stability: keep the screen awake and stop Android from entering doze/suspend,
# because resuming from display-off wedges system_server on this kernel.
LOG=/data/adb/a20e-stability.log
i=0
while [ "$(getprop sys.boot_completed)" != "1" ] && [ $i -lt 120 ]; do
    sleep 2
    i=$((i+1))
done
sleep 5
settings put system screen_off_timeout 2147483647
settings put global stay_on_while_plugged_in 7
settings put secure screensaver_enabled 0
settings put system screen_brightness_mode 0
locksettings set-disabled true
svc power stayon true
dumpsys deviceidle disable
echo "screen_off_timeout=$(settings get system screen_off_timeout)" >> "$LOG"
echo "stay_on=$(settings get global stay_on_while_plugged_in)" >> "$LOG"
echo "doze=$(dumpsys deviceidle get deep)" >> "$LOG"
