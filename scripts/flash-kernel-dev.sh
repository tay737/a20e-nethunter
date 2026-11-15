#!/system/bin/sh
# Runs on device. Repacks /data/local/tmp/boot.base with kernel.new, verifies, flashes.
set -e
cd /data/local/tmp
rm -rf work
mkdir -p work
cd work
../mb unpack ../boot.base >/dev/null
cp -f ../kernel.new kernel
../mb repack ../boot.base ../new-boot.img >/dev/null
NEW=$(md5sum ../new-boot.img | awk '{print $1}')
echo "new boot md5: $NEW"
# sanity: new boot must contain the new kernel's version string
if ! grep -q "Linux version 4.4.302" ../new-boot.img; then
	echo "ERROR: kernel string missing from repacked boot"
	exit 1
fi
dd if=../new-boot.img of=/dev/block/by-name/boot bs=1M
sync
dd if=/dev/block/by-name/boot of=../verify.img bs=1M
VER=$(md5sum ../verify.img | awk '{print $1}')
echo "readback md5: $VER"
[ "$NEW" = "$VER" ] || { echo "ERROR: readback mismatch"; exit 1; }
echo "FLASH OK"
