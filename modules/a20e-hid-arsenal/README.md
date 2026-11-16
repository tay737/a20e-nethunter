# a20e USB HID Arsenal

Makes the Galaxy A20e act as a USB HID keyboard (and mouse) once the
[v1.2 kernel](../../../releases/tag/v1.2) is flashed. Without that kernel the bind
succeeds but `/dev/hidg0` never appears — the configfs fix lives in the kernel,
not here.

Install with the KernelSU manager (*Modules → Install from storage*), or in TWRP.

## Why the module

The stock NetHunter `usbarsenal` refuses to run on this device. Its first check is

```sh
[ ! -d /config/usb_gadget -o -f /sys/devices/virtual/android_usb/android0/enable ]
```

Samsung keeps a legacy `android_usb` node next to configfs, so that test always
comes back true and the script exits before touching anything. This module ships
the patched script (check removed, `f1`-style link names forced so this ROM's
`acm.0`-style names cannot confuse the parser) together with the watchdog that
was used to bring HID up safely during development.

## Usage

```sh
su -c hid-arsenal                 # HID keyboard + mouse, adb restored after 60 s
su -c 'hid-arsenal --keep'        # HID stays up until you reset
su -c hid-arsenal reset           # back to adb immediately
su -c 'hid-arsenal --delay 0'     # no automatic restore, no watchdog
```

Turning HID on takes the port away from adb, so:

- run it from a terminal **on the phone** (Termux, NetHunter, TWRP console) and
  you keep control;
- run it over `adb shell` and the connection drops — that is what the 60-second
  watchdog is for. It puts `sys.usb.config=adb` back and restarts adbd, so an
  unlucky bind cannot leave the phone without USB.

`hid-arsenal --keep` also writes `keep` into the module directory, so a watchdog
that is already armed backs off.

## Typing

With the gadget up, `/dev/hidg0` takes an 8-byte boot-keyboard report:

```sh
printf '\0\0\x04\0\0\0\0\0' > /dev/hidg0    # press 'a'
printf '\0\0\0\0\0\0\0\0'   > /dev/hidg0    # release
```

The module chmods the node to 666 after a successful bind.

## Layout

| File | Purpose |
|---|---|
| `bin/hid-arsenal` | front end: arms the watchdog, calls the patched script, reports whether `/dev/hidg0` came up |
| `bin/usbarsenal-patched` | NetHunter's script with the false configfs check removed; runs standalone, but uses NetHunter's `bootkali_*` helpers when present |
| `bin/usb-watchdog.sh` | restores `sys.usb.config=adb` after N seconds unless `keep` exists |
| `system/bin/hid-arsenal` | PATH wrapper, so `hid-arsenal` works from any shell |
| `customize.sh` | sets permissions and patches NetHunter's installed `usbarsenal` in place (`usbarsenal.orig` is kept) |

Logs: `/data/adb/a20e-hid-arsenal.log`.

## Verified

On the A20e with the v1.2 kernel: `hid-arsenal` binds a hid-only configuration,
`/dev/hidg0` appears, macOS prompts "Press the Shift key to verify your keyboard",
typing reaches the host, and the watchdog returns the port to adb afterwards.

If it fails, `hid-arsenal` says so and the watchdog still restores adb. Kernel
`4.4.302-p6` is the version this was tested against (`uname -r`).
