#!/system/bin/sh
# NetHunter Bluetooth bring-up for a20e (KernelSU 0.9.4 + Kali chroot)
# Order matters: Android BT must be OFF, BlueBinder first (creates its vhci
# controller), then bluetoothd, then bring that controller up.
R=/data/local/nhsystem/kali-arm64
CH="env -i PATH=/usr/bin:/bin:/usr/sbin:/sbin HOME=/root chroot $R /bin/bash -c"

echo "[1/5] binderfs into chroot"
mkdir -p "$R/dev/binderfs"
mount | grep -q "kali-arm64/dev/binderfs" || mount -t binder binder "$R/dev/binderfs"

echo "[2/5] dbus"
$CH 'service dbus status >/dev/null 2>&1 || service dbus start; service dbus status'

if [ "$(settings get global bluetooth_on)" = "1" ]; then
  echo "[2b] Android Bluetooth is ON - BlueBinder cannot own the HAL. Turning it off."
  svc bluetooth disable
  sleep 5
fi

echo "[3/5] stopping old bluebinder/bluetoothd"
pkill -f 'usr/sbin/bluebinder' 2>/dev/null
$CH 'service bluetooth stop >/dev/null 2>&1; true'

echo "[4/5] bluebinder + bluetoothd"
$CH 'nohup /usr/sbin/bluebinder >/tmp/bluebinder.log 2>&1 & echo bluebinder-started'
sleep 3
$CH 'service bluetooth start; service bluetooth status'
sleep 3

echo "[5/5] controllers"
$CH 'NEW=$(ls /sys/class/bluetooth/ | sort | tail -1); echo "using $NEW"; hciconfig $NEW up; hciconfig -a | grep -E "^hci|BD Address|UP|DOWN" | head -8'
echo "bluebinder log:"; tail -3 "$R/tmp/bluebinder.log"
