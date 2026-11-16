#!/sbin/sh
MODDIR=${MODDIR:-/data/adb/modules/a20e-hid-arsenal}

chmod 755 "$MODDIR/bin/hid-arsenal" "$MODDIR/bin/usbarsenal-patched" \
          "$MODDIR/bin/usb-watchdog.sh" "$MODDIR/system/bin/hid-arsenal" 2>/dev/null

## NetHunter's own HID Arsenal button calls /data/data/com.offsec.nethunter/scripts/usbarsenal,
## whose first check rejects this device (it tests for Samsung's legacy android_usb
## node and for GadgetFS). Replace it with the patched copy so the app works too.
NH=/data/data/com.offsec.nethunter/scripts
if [ -f "$NH/usbarsenal" ]; then
    [ -f "$NH/usbarsenal.orig" ] || cp "$NH/usbarsenal" "$NH/usbarsenal.orig"
    cp "$MODDIR/bin/usbarsenal-patched" "$NH/usbarsenal"
    chmod 755 "$NH/usbarsenal"
    echo "- NetHunter usbarsenal patched (original kept at usbarsenal.orig)"
else
    echo "- NetHunter app not installed here; skipping its script (module works standalone)"
fi

echo "- a20e-hid-arsenal installed"
echo "  run: su -c hid-arsenal          (HID for 60 s, then adb comes back)"
echo "       su -c 'hid-arsenal --keep'  (HID stays until 'hid-arsenal reset')"
echo "  requires the v1.2 kernel from this repo's releases"
