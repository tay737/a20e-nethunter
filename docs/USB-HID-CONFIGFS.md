# Why USB HID never appears on this kernel

`/dev/hidg0` cannot be created from userspace on a stock Eureka/R15 kernel, no
matter how the gadget is configured. The blocker is in
`drivers/usb/gadget/configfs.c`, not in the HID function, the descriptor, or the
NetHunter script.

## The parking problem

With `CONFIG_USB_CONFIGFS_UEVENT=y` (set in every R15 defconfig here),
`config_usb_cfg_link()` parks every function linked through configfs on
`gi->linked_func` instead of `cfg->func_list`:

```c
#ifdef CONFIG_USB_CONFIGFS_UEVENT
	list_add_tail(&f->list, &gi->linked_func);
#else
	list_add_tail(&f->list, &cfg->func_list);
#endif
```

Stock Samsung code only ever drains that list for `adb`:
`get_adb_function_from_linked_func()` returns nothing unless `f->name` is
`"adb"`, and the GSI branch in the link callback moves only `adb` too.

Consequences, all observable on the device:

- a config whose only link is `hid.0` has an empty `func_list`, so
  `configfs_composite_bind()` fails with
  `Config b/1 of g1 needs at least one function.` and
  `failed to start g1: -22`;
- `hidg_bind()` is never called, so `/sys/class/hidg` stays empty and no
  `/dev/hidg0` is created;
- the same happens for any other configfs function (tested with `acm.0` and
  with `ffs.adb` linked by hand), so this is not HID-specific;
- NetHunter's USB Arsenal aborts before any of this with a false negative, it
  treats `/sys/devices/virtual/android_usb/android0/enable` (Samsung's legacy
  driver, present alongside configfs) as proof of GadgetFS.

`/proc/config.gz` on the running kernel claims
`# CONFIG_USB_CONFIGFS_F_HID is not set` while the `hid` function driver is
clearly registered (`mkdir functions/hid.0` succeeds and exposes `protocol`,
`report_desc`, `report_length`, `subclass`). Do not trust that file for feature
questions.

## The fix

There are two separate defects in `config_usb_cfg_link()`, and both have to be
handled. `patches/0006-usb-gadget-attach-hid-function.patch` does that for the
`hid.0` instance and leaves every other function on the stock path.

### 1. The link is swallowed before it is ever allocated

When the configuration's string list holds a mode name that is not `Conf 1`
— `adb` is the only one this ROM uses — the callback takes an early return that
sits before the `usb_get_function()` call:

```c
if (strcmp(cn->configuration, "Conf 1")!= 0) {
	if (strcmp(cn->configuration, "adb") == 0) {
		/* move adb out of linked_func, if it happens to be there */
	}
	gi->gsi_boot=1;
	ret = 0;
	goto out;          /* <- success, nothing was allocated */
}
```

So while the gadget is in `adb` mode, `mkdir functions/hid.0` followed by
`ln -s ../../../../usb_gadget/g1/functions/hid.0 configs/b.1/f1d` reports
success and leaves no trace: no function instance is taken, nothing is parked,
and the bind later binds only adb. This is why the `hidg_bind` probes never
fired even on a kernel that already had the older draining patch — the function
the patch was looking for had never been created. A bind-time diagnostic dump
made this visible:

```
usb: bind parked 'mtp' ... usb: bind parked 'ncm'
usb: bind config already has 'adb'
```

No `hid` in either list, with the link accepted.

The patch lets the `hid.0` instance past that early return
(`strcmp(usb_func_ci->ci_namebuf, "hid.0") != 0` keeps stock behaviour for every
other instance, including `ffs.adb` during boot).

### 2. The function is parked instead of attached

Once it does reach the tail of the callback, stock code parks it on
`linked_func`, and `configfs_composite_bind()` never walks that list, so the
function never reaches `usb_add_function()`. The patch attaches `hid` to the
configuration it was linked into instead:

```c
	if (f->name && strcmp(f->name, "hid") == 0)
		list_add_tail(&f->list, &cfg->func_list);
	else
		list_add_tail(&f->list, &gi->linked_func);
```

Only `hid` is diverted. Every other function keeps the parked behaviour because
boot depends on it: this ROM leaves a dozen init links parked (accessory, acm,
mtp, ptp, rndis, midi, ncm, ...) and attaches adb through the GSI path. An
earlier revision that attached every non-adb function made the device bootloop
(no USB enumeration at all), so the narrow scope is deliberate.

### Result

Boot is unchanged and adb comes up as before. When userspace clears the links
and builds a hid-only configuration, the bind does reach `hidg_bind()`:

```
usb: bind parked 'mtp' ... usb: bind parked 'adb'
usb: bind config already has 'hid'
hidg_bind: eps in=ep1in out=ep1out
hidg_bind: created hidg0
configfs-gadget gadget: high-speed config #1: b
```

`/dev/hidg0` exists for the lifetime of that configuration (the probe script
reported `class=[hidg0] dev=[/dev/hidg0]`), and macOS shows its "Press the Shift
key to verify your keyboard" prompt — an end-to-end confirmation that the host
sees a HID keyboard rather than a vendor-specific interface.

The gadget reverts to adb, and `/dev/hidg0` disappears, whenever the watchdog
or `usbarsenal` restores `sys.usb.config=adb`. That is expected.

## Booting: the panel config trap

A build of this tree with the wrong display config bootloops on an A20e: the
screen flashes white, goes black, and the device never reaches adb. The A40
config (`CONFIG_EXYNOS_DECON_LCD_S6E8FC0_A40=y`, `SENSORS_A96T3X6_A40=y`) is
what a plain `a40_00_stock_defconfig`-style config gives you. An A20e build
needs at least

```
CONFIG_EXYNOS_DECON_LCD_HX83102D_A20E=y
CONFIG_MACH_EXYNOS7885_A20e_OPEN=y
```

Use `exynos7885-a20e_defconfig` as the base (or the config in
`build-configs/a20e-tree302-ksu-hid.config`, which is the A20e config with
KernelSU and HID enabled). `CONFIG_CUSTOM_BACKLIGHT_SYSFS_NODE=y` is mandatory:
the dpu_7885 panel drivers reference
`struct lcd_info::custom_brightness_enable` unconditionally.

## Building it

The kernel also has to keep KernelSU working, so the config needs
`CONFIG_KSU=y` and its dependency `CONFIG_OVERLAY_FS=y`, plus
`CONFIG_USB_CONFIGFS_F_HID=y`, `CONFIG_USB_CONFIGFS_UEVENT=y` and
`CONFIG_LTO_NONE=y`. `build-configs/a20e-tree302-ksu-hid.config` is the exact
config used for the build that includes the fix:

```sh
bash ~/Documents/a20e-nethunter/scripts/build-tree-macos.sh /Volumes/a20e-kernel-cs/tree302
bash ~/Documents/a20e-nethunter/scripts/flash-kernel.sh \
     /Volumes/a20e-kernel-cs/tree302/arch/arm64/boot/Image
```

## Restoring

`scripts/restore-boot.sh` writes the known-good boot image back and verifies
the read-back md5 (`b751ac5b781bab4d28e4c9b16c503807`).
