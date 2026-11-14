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

So this needs a kernel change: let the Exynos/GSI configfs path accept `hid` functions, or
build the gadget without the vendor hooks. The R15 tree is not currently on disk
(`/Volumes/a20e-HFSX` is unmounted), so the patch cannot be built right now.

Until then, USB Arsenal cannot work on this kernel. Bluetooth (HID over BT is a different
path) and KeX are unaffected.

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
