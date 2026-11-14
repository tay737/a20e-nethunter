#!/usr/bin/env bash
# Prepare an Exynos7885 kernel tree so USB HID (and the rest of NetHunter's
# USB Arsenal) works: patch the vendor configfs bind path and make sure f_hid
# is enabled. Run from anywhere; pass the kernel tree as $1 or set KERNEL_DIR.
#
#   ./scripts/enable-usb-hid-gadget.sh ~/a20e-kernel
#
# Nothing is rebuilt here - build and flash the Image afterwards.

set -euo pipefail

KERNEL_DIR="${1:-${KERNEL_DIR:-}}"
if [ -z "$KERNEL_DIR" ] || [ ! -d "$KERNEL_DIR" ]; then
    echo "usage: $0 /path/to/kernel-tree" >&2
    exit 2
fi

HERE="$(cd "$(dirname "$0")" && pwd)"
PATCH="$HERE/../patches/0006-usb-gadget-bind-linked-functions.patch"
CONFIGFS="$KERNEL_DIR/drivers/usb/gadget/configfs.c"
DEFCONFIG="$KERNEL_DIR/arch/arm64/configs/exynos7885-a20e_defconfig"

[ -f "$CONFIGFS" ] || { echo "no drivers/usb/gadget/configfs.c in $KERNEL_DIR" >&2; exit 1; }

if grep -q "Attach whatever configfs linked" "$CONFIGFS"; then
    echo "configfs.c: already patched"
else
    echo "configfs.c: applying $(basename "$PATCH")"
    patch -d "$KERNEL_DIR" -p1 --forward < "$PATCH"
fi

# f_hid has to be compiled in; without it there is no "hid" function type at all
if [ -f "$DEFCONFIG" ]; then
    if grep -q '^CONFIG_USB_CONFIGFS_F_HID=y' "$DEFCONFIG"; then
        echo "defconfig: CONFIG_USB_CONFIGFS_F_HID already enabled"
    else
        sed -i '/^# CONFIG_USB_CONFIGFS_F_HID is not set/d' "$DEFCONFIG"
        echo 'CONFIG_USB_CONFIGFS_F_HID=y' >> "$DEFCONFIG"
        echo "defconfig: enabled CONFIG_USB_CONFIGFS_F_HID"
    fi
else
    echo "warning: $DEFCONFIG not found, enable CONFIG_USB_CONFIGFS_F_HID by hand" >&2
fi

echo
echo "Now build and flash, then on the device:"
echo "  mkdir /config/usb_gadget/g1/functions/hid.usb0"
echo "  cat kbd.bin > /config/usb_gadget/g1/functions/hid.usb0/report_desc"
echo "  ln -s .../functions/hid.usb0 /config/usb_gadget/g1/configs/b.1/hid.usb0"
echo "  ls /dev/hidg0"
