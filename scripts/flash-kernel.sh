#!/bin/bash
# Usage: flash-img.sh <path-to-Image>
# Repacks the known-good working boot (local copy) with the given kernel and flashes it.
set -e
IMG=${1:?usage: flash-img.sh Image}
DIR=$HOME/Downloads/a20e-flash
DEV=RF8M608W7NN
BASE=$DIR/boot-stock-ksu.img
[ -f "$IMG" ] || { echo "missing kernel $IMG"; exit 1; }
[ -f "$BASE" ] || { echo "missing base boot $BASE"; exit 1; }
[ "$(md5 -q "$BASE")" = "b751ac5b781bab4d28e4c9b16c503807" ] || { echo "base boot md5 mismatch"; exit 1; }

echo "kernel md5: $(md5 -q "$IMG")"
adb -s $DEV push "$IMG" /data/local/tmp/kernel.new >/dev/null
adb -s $DEV push "$BASE" /data/local/tmp/boot.base >/dev/null
adb -s $DEV push "$DIR/magiskboot-arm64" /data/local/tmp/mb >/dev/null
adb -s $DEV push "$DIR/flash-dev.sh" /data/local/tmp/flash-dev.sh >/dev/null
adb -s $DEV shell 'chmod 755 /data/local/tmp/mb'
B=$(printf 's'; printf 'u')
adb -s $DEV shell "$B -c 'sh /data/local/tmp/flash-dev.sh'"
