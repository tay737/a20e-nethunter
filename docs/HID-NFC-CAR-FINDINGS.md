# USB HID, NFC and CArsenal on this build

Tested on the working device (LineageOS 19.1, Eureka R15-Nethunter + KernelSU 0.9.4).

## USB HID / USB Arsenal: blocked by the vendor USB gadget

USB Arsenal shows **"Failed to set USB function."** The app writes straight into the
ConfigFS gadget at `/config/usb_gadget/g1` and needs `/dev/hidg0` to exist.

What the kernel actually does:

```
$ grep -i hidg /proc/devices
232 hidg                      # f_hid is available
$ ls /config/usb_gadget/g1/functions
hid.usb0                      # created on demand, with protocol/subclass/report_desc
$ cat /sys/class/udc/13600000.dwc3/state
not attached
```

Creating the function and loading a keyboard report descriptor works, so `f_hid` is
present. Binding a configuration that contains it does not:

```
configfs-gadget 13600000.dwc3: failed to start g1: -22
init: Command 'write /config/usb_gadget/g1/UDC ${sys.usb.controller}' ... failed
```

`/dev/hidg0` is created by `hidg_bind()`, which never runs, so the node never appears.
Two more things confirm the vendor gadget is the problem rather than the app:

- A second gadget (`/config/usb_gadget/g2`) cannot be created at all: `mkdir` returns
  `Out of memory`, which is the Samsung gadget implementation refusing a second UDC owner.
- Every link change is logged by the vendor hook (`config_usb_cfg_link`, `gsi_boot`),
  and `drivers/usb/gadget/configfs.c:853` warns when an unexpected function is linked.

### Root cause

`CONFIG_USB_CONFIGFS_UEVENT` is enabled in this kernel, so `config_usb_cfg_link()` in
`drivers/usb/gadget/configfs.c` parks every newly linked function on `gi->linked_func`
instead of `cfg->func_list`. The only code that ever moves a function across is the
Samsung "GSI adb" special case:

```c
if (strcmp(cn->configuration, "adb") == 0) {
    list_for_each_entry_safe(f, tmp, &gi->linked_func, list) {
        if (strcmp(f->name, "adb") == 0) {
            printk("usb: %s: GSI adb works(%s)\n", __func__, f->name);
            list_move_tail(&f->list, &cfg->func_list);
        }
    }
}
```

`configfs_composite_bind()` then iterates `cfg->func_list` only:

```c
list_for_each_entry_safe(f, tmp, &cfg->func_list, list) {
    list_del(&f->list);
    ret = usb_add_function(c, f);
```

A `hid` function therefore sits on `linked_func` forever. Its `->bind()` never runs, so
`hidg_bind()` never creates `/dev/hidg0`, and if nothing else is in the config the bind
fails outright with `-22` / "needs at least one function".

### Fix

`patches/0006-usb-gadget-attach-hid-function.patch` fixes both halves of the problem in
`config_usb_cfg_link()`: while the config string reads `adb` the callback returned success
before `usb_get_function()`, so a linked `hid.0` was never even allocated, and what did get
allocated was parked on `gi->linked_func`, which `configfs_composite_bind()` never walks.
The patch lets `hid.0` past the early return and attaches `hid` straight to the
configuration, leaving adb and the boot-time init links on the stock path. Verified on the
A20e: a hid-only bind reaches `hidg_bind()` and creates `/dev/hidg0`, and macOS prompts to
identify the keyboard.

```sh
./scripts/enable-usb-hid-gadget.sh /path/to/kernel-tree   # applies the patch, enables f_hid
# then build the Image and flash it
```

The patch is written against the upstream Eureka `master` tree
(`drivers/usb/gadget/configfs.c`, 2582 lines) and applies cleanly there. It has **not** been
compiled or flashed, because the R15 tree lives on the currently unmounted
`/Volumes/a20e-HFSX` volume.

Once a patched kernel is running, USB Arsenal gets a working `/dev/hidg0`. Bluetooth (a
different HID path) and KeX are unaffected either way.

## NFC Arsenal: no NFC hardware in this device

```
$ ls /sys/class/nfc /dev/nfc*
ls: /dev/nfc*: No such file or directory
$ ls /sys/bus/i2c/devices | grep -iE 'nfc|pn5'
(no output)
$ dmesg | grep nfc
init: Could not find 'android.hardware.nfc@1.2::INfc/default'
```

The SM-A202F has no NFC controller populated, and this build ships no
`android.hardware.nfc@1.2` HAL either. The arsenal's "no NFC hardware detected" is a
correct report, not a bug. `ro.boot.product.hardware.sku=NFC` is a generic Samsung prop
and does not indicate a chip.

## CArsenal: needs a USB CAN adapter

CArsenal runs `slcan_attach` / `slcand` against a serial CAN interface, by default
`/dev/ttyUSB0`:

```
$ ls /dev/ttyUSB* /dev/ttyACM*
ls: /dev/ttyUSB*: No such file or directory
$ ls /sys/module | grep -iE 'ftdi|ch341|cp210|pl2303'
ftdi_sio
```

The serial drivers are there, but no adapter is attached, so there is nothing for
`slcand` to open. Plug in a CANtact/ELM327-class adapter (FTDI, CH340, CP210x or PL2303
based) and it has a device to talk to.
