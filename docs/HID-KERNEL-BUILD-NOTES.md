# Building the HID kernel on macOS

The USB HID patch is written, and the kernel it lives in now builds locally on this Mac
with the same toolchain the working phone kernel came from: Homebrew clang 23.1.5 and
Homebrew LLD 23.1.5. This document records where the tree came from, what had to change
to build it, and what is still unproven.

## Where the tree is

`Eureka_Kernel_R15.1.1_A20e.zip` extracted to `~/Downloads/a20e_kernel`, with Eureka's own
history on top (`2744de48 fix mali & mtp`). It is the tree the phone's working
`4.4.302-p6` kernel was built from — its `arch/arm64/configs/exynos7885-a20e_defconfig`
diffs against the phone's `/proc/config.gz` in only a handful of lines.

The full tree is attached to the
[v1.1 release](https://github.com/tay737/a20e-nethunter/releases/tag/v1.1) as
`eureka-r15-tree.tar.xz`, because it cannot be checked out on a normal Mac volume: it
contains files that differ only by case (`net/netfilter/xt_TCPMSS.c` and
`xt_tcpmss.c`), and case-insensitive APFS silently collapses one into the other, which
then breaks the netfilter build. Extract it on a case-sensitive volume.

## Patches that matter for this tree

| Patch | What it fixes |
|---|---|
| `0006-usb-gadget-bind-linked-functions.patch` | configfs parks linked functions on `gi->linked_func`; only the adb special case ever moves one, so `hid` never binds and `/dev/hidg0` is never created |
| `0007-f-hid-fix-spinlock-name.patch` | `hidg_disable()` used `hidg->read_spinlock`, a member that does not exist; f_hid had never been compiled because `CONFIG_USB_CONFIGFS_F_HID` was unset |
| `0009-mach-o-host-devtable-data-section.patch` | the tree's own macOS portability shim puts modpost's `__devtable` in `__TEXT`; arm64 ld refuses text relocations, so it goes in `__DATA` |
| `0010-tzdev-tzar-relative-incbin.patch` | `tz_deploy_tzar.c` builds its `.incbin` path from `KBUILD_SRC`, which is empty for an in-tree build, producing `/drivers/...` |
| `0011-lib-add-stpcpy.patch` | clang 23 turns `strcpy` + `strlen` into `stpcpy()`, which 4.4 does not implement |

`0008-bluetooth-l2cap-hold-unless-zero.patch` is not needed here: this tree has no
`l2cap_chan_hold_unless_zero()` call.

## Build

```sh
./scripts/build-local-macos.sh /Volumes/a20e-kernel-cs/tree
```

What the script does, and why each piece is there:

- `ANDROID_MAJOR_VERSION=q` — the vendor `Kconfig` sources
  `fs/sdcardfs/$ANDROID_MAJOR_VERSION/Kconfig`, and only `m n o p q` exist.
- `CC=clang` (Homebrew 23.1.5), `LD=scripts/ld-lld-shim.sh`, `CROSS_COMPILE=aarch64-elf-`
  for the GNU binutils. The shim wraps LLD and handles two 4.4-era LLD refusals: it emits
  an empty object for the empty `built-in.o` links (`sound/drivers`, `drivers/gpu/drm`),
  and adds `-z notext` to the `-pie` vmlinux link (`CONFIG_RELOCATABLE=y` puts absolute
  relocations in read-only sections).
- `HOSTCFLAGS=-I/tmp/hostinc` with a musl `elf.h`, because macOS ships no `<elf.h>` and
  `scripts/sortextable.c` / `mk_elfconfig.c` need one.
- `KCFLAGS` carries `-D__ANDROID__` (the vendor code gates its ioctl ABI on it, and
  Homebrew clang is not Android clang) plus `-Wno-error` and a few warning relaxations
  for warnings that did not exist when this tree was written.
- Build in-tree rather than `O=out`: the firmware blobs and `init/uh.elf` are `incbin`ed
  by relative path, which breaks in an out-of-tree build.

Each kernel directory under a case-sensitive volume is the safe place to run it; the
result lands in `arch/arm64/boot/Image`.

## Result

```
Image    29,343,992 bytes
md5      9c1c26d9355be5157bcf3806d1f8a5a1
strings  hidg_bind present
config   build-configs/a20e-r15-hid.config (defconfig + CONFIG_USB_CONFIGFS_F_HID=y)
```

The earlier CI attempt from `R15-AOSP` produced an `Image` that did not start at all;
this one comes from the tree the working phone kernel was built from, so it is the first
image worth flashing.

## Still unproven

Runtime HID behaviour: `/dev/hidg0` appearing, writes reaching the host, and USB Arsenal
driving it. That needs the flash-and-test cycle on the device, which is the next step.
