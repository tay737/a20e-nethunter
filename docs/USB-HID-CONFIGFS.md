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

`patches/0006-usb-gadget-bind-linked-functions.patch` drains `linked_func` into
the configuration being bound, just before the empty-config check, but only
when that configuration is still empty:

```c
if (!list_empty(&gi->linked_func)) {
	cfg_c = list_first_entry_or_null(&gi->cdev.configs,
					 struct usb_configuration, list);
	if (cfg_c) {
		cf = container_of(cfg_c, struct config_usb_cfg, c);
		if (list_empty(&cf->func_list)) {
			list_for_each_entry_safe(sf, stmp, &gi->linked_func, list)
				list_move_tail(&sf->list, &cf->func_list);
		}
	}
}
```

The `list_empty(&cf->func_list)` guard matters. At boot this ROM leaves a
dozen init links parked (accessory, acm, mtp, ptp, rndis, midi, ...) while
stock code attaches adb. Draining unconditionally drags all of them into the
bound composite; guarding on an empty configuration leaves the boot path
exactly as stock and only kicks in for the "nothing but the function I linked"
case, which is what a HID-only gadget is.

A kernel carrying this patch binds that linked function, so a hid-only
configuration reaches `usb_add_function()` and `hidg_bind()` runs.

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

`CONFIG_CUSTOM_BACKLIGHT_SYSFS_NODE=y` is mandatory here: the dpu_7885 A40
panel driver references `struct lcd_info::custom_brightness_enable`
unconditionally, so the build fails without it.

## Restoring

`scripts/restore-boot.sh` writes the known-good boot image back and verifies
the read-back md5 (`b751ac5b781bab4d28e4c9b16c503807`).
