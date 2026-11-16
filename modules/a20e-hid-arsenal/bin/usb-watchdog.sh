#!/system/bin/sh
# Restores the stock adb gadget after a delay, so a HID bind that loses adb can
# never strand the phone. Cancelled by: touch $MOD/keep   (hid-arsenal --keep)
MOD=${MOD:-/data/adb/modules/a20e-hid-arsenal}
LOG=${LOG:-/data/adb/a20e-hid-arsenal.log}
DELAY=${1:-60}
G=/config/usb_gadget/g1
C=$G/configs/b.1
DWC=${DWC:-$(getprop sys.usb.controller)}

sleep "$DELAY"

if [ -f "$MOD/keep" ]; then
    rm -f "$MOD/keep"
    echo "watchdog: kept HID, no restore requested" >> "$LOG"
    exit 0
fi

echo "" > $G/UDC 2>/dev/null
rm -f $C/f1 2>/dev/null
setprop sys.usb.ffs.ready 0
setprop sys.usb.config adb
sleep 1
setprop sys.usb.ffs.ready 1
start adbd 2>/dev/null
sleep 1
echo "$DWC" > $G/UDC 2>/dev/null
echo "watchdog: restored adb at $(date)" >> "$LOG"
