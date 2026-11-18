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

# Let init/framework rebuild the adb gadget: this is the path that has been
# verified on this device. If the port is still unbound afterwards, fall back to
# putting ffs.adb back over configfs directly.
echo "" > $G/UDC 2>/dev/null
setprop sys.usb.ffs.ready 0
setprop sys.usb.config adb
sleep 2
setprop sys.usb.ffs.ready 1
start adbd 2>/dev/null
sleep 2

if [ "$(cat $G/UDC 2>/dev/null)" != "$DWC" ] && [ -d $G/functions/ffs.adb ]; then
    for l in $(find $C -maxdepth 1 -type l 2>/dev/null); do rm -f "$l"; done
    ln -sf $G/functions/ffs.adb $C/f1 2>/dev/null
    echo "$DWC" > $G/UDC 2>/dev/null
    echo "watchdog: configfs fallback bind at $(date)" >> "$LOG"
fi

echo "watchdog: restored adb at $(date)" >> "$LOG"
