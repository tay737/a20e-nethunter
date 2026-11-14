# Building the HID kernel: what works and what does not

The USB HID fix is written and compiles. Getting a **bootable** kernel out of it is
where this stopped, and the reason is a tree mismatch, not the patch.

## What is in the repo

| Patch | What it fixes |
|---|---|
| `0006-usb-gadget-bind-linked-functions.patch` | configfs parks linked functions on `gi->linked_func`; only the adb special case ever moves one, so `hid` never binds and `/dev/hidg0` is never created |
| `0007-f-hid-fix-spinlock-name.patch` | `hidg_disable()` used `hidg->read_spinlock`, a member that does not exist; f_hid had never been compiled because `CONFIG_USB_CONFIGFS_F_HID` was unset everywhere |
| `0008-bluetooth-l2cap-hold-unless-zero.patch` | `l2cap_core.c` calls `l2cap_chan_hold_unless_zero()`, which this tree never defines |

`build-configs/a20e-working.config` is `/proc/config.gz` pulled from the running phone
(5366 lines, `CONFIG_USB_CONFIGFS_UEVENT=y`, no `CONFIG_KSU` symbol — this tree compiles
KernelSU unconditionally).

`.github/workflows/build-kernel.yml` clones Eureka `R15-AOSP`, pins KernelSU to v0.9.4,
applies the three patches, configures and builds `Image` with clang.

## Results

1. **Upstream `exynos7885-a20e_defconfig` build: succeeds.** Image 28,235,136 bytes,
   md5 `de543ad15905ddcfb8ebc861c539fac3`. Written to the boot partition, verified
   byte-for-byte before rebooting — and it does not start: the phone sits on the static
   Samsung splash, before any kernel console output, with no adb.

2. **Device config as the build base: does not compile.** The running kernel's config is
   from a newer tree than `R15-AOSP`:

   ```
   ../include/linux/bpf.h:404:1: error: function definition is not allowed here
   ../include/linux/security.h:1443:1: error: function definition is not allowed here
   ```

   That is the signature of config symbols the checked-out source does not implement the
   same way (BPF and Samsung security bits), so forcing `R15-AOSP` to build with it is not
   viable either.

3. Every flash attempt was recovered from the boot backup taken before any changes
   (`artifacts/boot-backup-r15ksu.img`, md5 `b751ac5b781bab4d28e4c9b16c503807`), restored
   through recovery and verified by reading the partition back.

## Conclusion

The working kernel on the phone was built from a tree that is not on this machine — the
`vip3r` NetHunter tree on the currently unmounted `/Volumes/a20e-HFSX` volume, configured
with BPF and Samsung options that `R15-AOSP` does not carry. Without that tree there is no
combination of available source + config that both compiles and boots on this device.

To finish: mount the volume and run

```sh
./scripts/enable-usb-hid-gadget.sh /Volumes/a20e-HFSX/vip3r
# apply patches 0007 and 0008 to that tree as well, then build Image
```

The HID patch itself is proven to apply cleanly to the vendor `configfs.c` and to compile
(the full kernel built with `CONFIG_USB_CONFIGFS_F_HID=y` for the first time in this tree's
history); what is unproven is the runtime behaviour, which needs a bootable kernel.
