# Installing the NetHunter module when `ksud module install` fails

KernelSU 0.9.4 keeps modules in an ext4 image at `/data/adb/ksu/modules.img` and mounts
it over `/data/adb/modules` on every boot. `ksud module install` on the NetHunter zip
runs its `customize.sh` (the Kali rootfs unpacks fine) but then dies with:

```
- Error: Transport endpoint is not connected (os error 107)
```

...and no module is registered. The workaround is to let KSU build the image with a
throwaway module, then put the real module inside that image by hand.

```sh
# 1. make KSU create its module image (any tiny module works)
ksud module install tiny-module.zip

# 2. loop-mount the image and drop the module in
M=/data/local/tmp/mimg; mkdir -p $M
mount -o loop,rw /data/adb/ksu/modules_update.img $M
mkdir -p $M/Kali-NetHunter-Ksu
# the module payload is what the zip's customize.sh stages:
#   system/, module.prop, post-fs-data.sh, service.sh, action.sh, uninstall.sh
cp -a /path/to/staged/module/. $M/Kali-NetHunter-Ksu/
chown -R 0:0 $M/Kali-NetHunter-Ksu
sync; umount $M

# 3. ask KSU to apply it
touch /data/adb/ksu/update
reboot
```

After the reboot `ksud module list` shows `Kali-NetHunter-Ksu` and the overlay is live
(`/system/xbin/busybox_nh-1.38.0`, `/system/xbin/hid-keyboard`, `/system/bin/screenres`).

Do not run another `ksud module install` while you are doing this. A failed install
cleans up the image and takes the module with it.
