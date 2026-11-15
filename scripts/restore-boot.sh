#!/bin/bash
# Poll for the phone; if it shows up in recovery, restore the known-good boot.
DEV=RF8M608W7NN
DIR=$HOME/Downloads/a20e-flash
BASE=$DIR/boot-stock-ksu.img
GOOD=b751ac5b781bab4d28e4c9b16c503807
[ "$(md5 -q "$BASE" 2>/dev/null)" = "$GOOD" ] || { echo "FATAL: base image missing or wrong md5"; exit 1; }

for i in $(seq 1 60); do
	state=$(adb -s $DEV get-state 2>/dev/null)
	[ -z "$state" ] && { sleep 5; continue; }
	# Tell recovery from Android: recovery has no Android runtime.
	if adb -s $DEV shell 'test -e /system/bin/app_process32 -o -e /system/bin/app_process64' >/dev/null 2>&1; then
		echo "ANDROID_BOOTED"
		adb -s $DEV shell 'uname -r; getprop sys.boot_completed'
		exit 0
	fi
	echo "RECOVERY_DETECTED ($state)"
	adb -s $DEV push "$BASE" /data/local/tmp/b.img >/dev/null 2>&1 || adb -s $DEV push "$BASE" /tmp/b.img >/dev/null 2>&1
	src=/data/local/tmp/b.img
	adb -s $DEV shell "test -e $src" >/dev/null 2>&1 || src=/tmp/b.img
	echo "restoring from $src"
	adb -s $DEV shell "dd if=$src of=/dev/block/by-name/boot bs=1M 2>/dev/null; sync; dd if=/dev/block/by-name/boot of=/tmp/v.img bs=1M 2>/dev/null; md5sum /tmp/v.img; rm -f /tmp/v.img $src"
	adb -s $DEV shell 'sync; reboot'
	exit 0
done
echo "NO_DEVICE_SEEN"
