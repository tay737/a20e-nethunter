<h1 align="center">a20e-nethunter</h1>

<p align="center">
  <em>Kali NetHunter on a Samsung Galaxy A20e, rooted with KernelSU, on a kernel that actually boots.</em>
</p>

<p align="center">
  <img alt="device" src="https://img.shields.io/badge/device-Galaxy%20A20e%20(SM--A202F)-1f6feb?style=flat-square">
  <img alt="rom" src="https://img.shields.io/badge/ROM-LineageOS%2019.1-167c80?style=flat-square">
  <img alt="kernel" src="https://img.shields.io/badge/kernel-4.4.302--p6-8957e5?style=flat-square">
  <img alt="kernelsu" src="https://img.shields.io/badge/KernelSU-0.9.4%20(11838)-2ea043?style=flat-square">
  <img alt="license" src="https://img.shields.io/badge/license-GPL--2.0-blue?style=flat-square">
</p>

<p align="center">
  <a href="#what-this-is">What this is</a> ·
  <a href="#status">Status</a> ·
  <a href="#install">Install</a> ·
  <a href="#building-the-kernel">Build</a> ·
  <a href="#things-that-bit-me">Gotchas</a> ·
  <a href="#credits">Credits</a>
</p>

---

## What this is

A working NetHunter setup for the Exynos 7885 Galaxy A20e. The kernel is the Eureka
`R15-Nethunter` tree with the Kali NetHunter 4.4 feature patches and KernelSU 0.9.4
ported into it. On top of that sits the NetHunter KernelSU module with a Kali chroot,
plus two small modules I wrote to keep the thing from freezing.

The repo holds the patches, the module sources, the helper scripts, the notes and the
flashable binaries. `docs/ARTIFACTS.md` lists every file with its checksum and where it
came from.

## Status

| Piece | State |
|---|---|
| Boot | works. `4.4.302-p6`, Lineage 19.1, OrangeFox R11.1 |
| Root | KernelSU 0.9.4, `su` → `uid=0 context=u:r:su:s0` |
| USB HID | `/system/xbin/hid-keyboard` present, gadget function compiled in |
| Bluetooth HCI | `/dev/vhci` + `/dev/rfkill`, BlueBinder talking to the Android radio |
| NetHunter chroot | Kali Rolling at `/data/local/nhsystem/kali-arm64` |
| Arsenal | nmap, Metasploit, hydra, aircrack-ng, sqlmap, macchanger, whois installed via apt |
| dbus | running, started as `messagebus` (see gotchas) |
| Screen sleep | disabled on purpose, see gotchas |

## Hardware and software

- Samsung Galaxy A20e, `SM-A202F`, Exynos 7885, 2.7 GB RAM
- `lineage-19.1-20220819-UNOFFICIAL-a20e.zip` (Android 12)
- OrangeFox R11.1 Unofficial for `a20e`
- Eureka kernel, branch `R15-Nethunter`, `4.4.302-p6`
- KernelSU 0.9.4, kernel version `11838` (`tiann/KernelSU` at `109442f8`)
- KernelSU manager APK 0.9.4

## Install

### 1. Recovery

OrangeFox, then wipe. `twrp format data` fails on this build, `twrp wipe data` does not:

```sh
twrp wipe data
twrp wipe system
twrp wipe cache
twrp wipe dalvik
```

### 2. ROM

```sh
twrp install /sdcard/lineage-a20e.zip
```

This puts stock `boot`, `dtb` and `dtbo` back. That is what you want, see gotchas.

### 3. Kernel

```sh
twrp install /sdcard/ak3-nethunter-r15-ksu.zip
```

Image only. Do not flash a `dtb.img` or `dtbo.img` from another build.

### 4. Root

Install `KernelSU_v0.9.4.apk`, open it once so it drops `ksud` into `/data/adb`.
Do not flash Magisk afterwards, it takes over `su` and KernelSU stops being in charge.

### 5. NetHunter module

The module's own installer runs fine but KSU's image step fails on it, so use the
manual route in `docs/ARTIFACTS.md`. Short version: let `ksud` create its module
image with a tiny module, loop-mount it, copy the NetHunter module directory in,
touch `/data/adb/ksu/update`, reboot.

Then install the Arsenal packages inside the chroot:

```sh
R=/data/local/nhsystem/kali-arm64
chroot $R /bin/bash -c 'apt-get update && apt-get install -y --no-install-recommends \
  nmap aircrack-ng hydra sqlmap netcat-traditional macchanger dnsutils whois metasploit-framework'
```

### 6. Quality of life

- `a20e-stability` (in this repo) keeps the screen on, kills doze, relaxes boot timeouts
- `wireless-adb` gives you `adb connect <ip>:5555` after every boot

## Building the kernel

You need the kernel tree, KernelSU checked out inside it, and the NetHunter patches
applied. `scripts/build-kernel.sh` wraps the compile:

```sh
git clone -b R15-Nethunter https://github.com/ViP3R-KERNELs/Eureka-Kernel-Exynos7885-Q-R-S kernel
cd kernel && git clone https://github.com/tiann/KernelSU && git -C KernelSU checkout 109442f8
ln -sfn ../KernelSU/kernel drivers/kernelsu
patch -p1 < ../patches/0001-kernelsu-0.9.4-hooks-r15-nethunter.patch
patch -p1 < ../patches/0002-exynos7885-a20e_defconfig.patch
../scripts/build-kernel.sh . out
```

The build prints `-- KernelSU version: 11838` and gives you `out/arch/arm64/boot/Image`
around 31 MB. AnyKernel3 package it as Image only.

Building on Apple silicon means Homebrew clang. The Kali NetHunter prebuilt toolchains
are Linux x86-64 and will not run on macOS.

## Things that bit me

**The defconfig lied.** `CONFIG_BT`, `CONFIG_RFKILL` and `USB_CONFIGFS_F_HID` were only
ever in the build tree's `.config`. Regenerating the config for KernelSU dropped them
and `/dev/vhci` quietly vanished. They live in the defconfig now.

**Modules are an ext4 image.** KernelSU 0.9.4 keeps modules in
`/data/adb/ksu/modules.img` and mounts it over `/data/adb/modules` at every boot.
Anything you copy into `/data/adb/modules` is wiped on reboot. That is not a bug you
can work around, it is the design.

**dbus dies on capabilities.** `dbus-daemon` starts as root and tries to drop
capabilities. Android's SELinux says no (`Failed to drop capabilities: Operation not
permitted`), so the service never comes up and Bluetooth can't start either. Starting
it straight as `messagebus` with `--chuid` fixes it. Patch `0004`.

**BlueBinder needs three things.** Android Bluetooth must be off so the HAL is free.
`/dev/binderfs` has to be mounted inside the chroot, or the binder symlinks dangle.
And bluebinder has to start before `bluetoothd`, because it creates the vhci controller
that bluetoothd should bind to. `scripts/nh-bt.sh` does all of it.

**The display never comes back.** Turn the screen off and the device may not wake:
black screen, dead power button, `system_server` stuck. That's this kernel/ROM pair,
not KernelSU. The ROM spoofs a Pixel 6 Pro Android 13 fingerprint while the vendor is
`a20e` on Android 12, and the HAL manifest doesn't match. The stability module keeps
the screen awake instead of pretending to fix it.

**No dtb from this tree.** R15-Nethunter has no `arch/arm64/boot/dts`, so there is
nothing to build. R24U builds with their own Image+dtb+dtbo bootlooped on this ROM.
Stock dtb/dtbo plus this Image boots.

## Repo layout

```
patches/    kernel and chroot patches, in the order they were applied
modules/    source of the a20e-stability KernelSU module
scripts/    build-kernel.sh and nh-bt.sh (Bluetooth bring-up)
logs/       verification output from the working device
docs/       artifact checksums and install notes
```

## Artifacts

Kernel zips, the helper modules and the APKs live in `kernel/`, `modules/` and `tools/`.
The 318 MB NetHunter module is attached to the
[v1.0 release](https://github.com/tay737/a20e-nethunter/releases/tag/v1.0).
`docs/ARTIFACTS.md` has sizes, checksums and upstream sources.

## Known limits

- **USB HID / USB Arsenal** - the Exynos gadget never binds configfs-linked functions other
  than adb, so `/dev/hidg0` never appears. Root cause and fix in
  `patches/0006-usb-gadget-bind-linked-functions.patch`; see `docs/HID-NFC-CAR-FINDINGS.md`
  and `docs/HID-KERNEL-BUILD-NOTES.md`. The patch compiles, but a bootable kernel needs
  the original Eureka tree from the unmounted volume.
- **NFC Arsenal** - the SM-A202F has no NFC controller and the ROM has no NFC HAL.
- **CArsenal** - works only with a USB serial CAN adapter attached (`/dev/ttyUSB0`).

## Credits

- [eurekadevelopment / ViP3R-KERNELs](https://github.com/ViP3R-KERNELs/Eureka-Kernel-Exynos7885-Q-R-S) for the kernel tree
- [Kali NetHunter](https://gitlab.com/kalilinux/nethunter/build-scripts/kali-nethunter-kernel) for the 4.4 patches and the kernel builder
- [tiann/KernelSU](https://github.com/tiann/KernelSU) for KernelSU
- [SherlockChiang/Nethunter_for_KernelSU](https://github.com/SherlockChiang/Nethunter_for_KernelSU) for the module and chroot
- [dracediax/wireless-adb](https://github.com/dracediax/wireless-adb) for the fixed-port ADB module

## License

GPL-2.0. The kernel work inherits it, and the scripts here match it.
