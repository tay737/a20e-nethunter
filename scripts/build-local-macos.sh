#!/bin/bash
# Build the Eureka R15.1.1 kernel for the Galaxy A20e (SM-A202F) on macOS,
# the same way the working 4.4.302-p6 kernel was built: Homebrew clang + LLD.
#
# The kernel tree has files that differ only in case (net/netfilter/xt_TCPMSS.c
# and xt_tcpmss.c), so it cannot live on a case-insensitive filesystem. Build it
# from a case-sensitive volume; this script creates one if needed.
#
#   ./build-local-macos.sh /path/to/eureka-tree
#
set -euo pipefail

TREE=${1:-}
if [ -z "$TREE" ] || [ ! -f "$TREE/Makefile" ]; then
	echo "usage: $0 /path/to/eureka-r15-tree" >&2
	exit 1
fi

REPO=$(cd "$(dirname "$0")/.." && pwd)
CLANG=${CLANG:-/usr/bin/clang}
LLD_BIN=${LLD_BIN:-$(command -v ld.lld || true)}
CROSS=${CROSS_COMPILE:-aarch64-elf-}
JOBS=${JOBS:-$(sysctl -n hw.ncpu)}

[ -n "$LLD_BIN" ] || { echo "ld.lld not found (brew install lld)" >&2; exit 1; }

# 4.4 lacks stpcpy, which clang 23 synthesises. The tree carries lib/stpcpy.c
# (patch 0011); host tools need a real <elf.h>, which macOS does not ship.
HOSTINC=${HOSTINC:-/tmp/hostinc}
if [ ! -f "$HOSTINC/elf.h" ]; then
	mkdir -p "$HOSTINC"
	curl -fsSL https://git.musl-libc.org/cgit/musl/plain/include/elf.h \
		-o "$HOSTINC/elf.h"
fi

# LLD refuses empty built-in.o links and text relocations in the -pie vmlinux.
SHIM=$TREE/scripts/ld-lld-shim.sh
[ -x "$SHIM" ] || { cp "$REPO/scripts/ld-lld-shim.sh" "$SHIM"; chmod +x "$SHIM"; }

export ARCH=arm64
export CROSS_COMPILE=$CROSS
export ANDROID_MAJOR_VERSION=q   # vendor Kconfig sources fs/sdcardfs/$VERSION

cd "$TREE"

make ARCH=arm64 exynos7885-a20e_defconfig
# USB HID gadget: this is what makes USB Arsenal / hidg work.
scripts/config -e USB_CONFIGFS_F_HID
make ARCH=arm64 olddefconfig

make ARCH=arm64 -j"$JOBS" Image \
	CC="$CLANG" \
	LD="$SHIM" \
	LLD="$LLD_BIN" \
	HOSTCFLAGS="-I$HOSTINC" \
	KCFLAGS="-D__ANDROID__ -Wno-error -Wno-strict-prototypes \
-Wno-unused-but-set-variable -Wno-section -Wno-implicit-enum-enum-cast \
-Wno-self-assign"

ls -l arch/arm64/boot/Image
md5 arch/arm64/boot/Image
