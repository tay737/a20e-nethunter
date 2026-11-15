#!/bin/bash
# Usage: build-tree.sh <tree-dir>   — builds Image with Homebrew clang + lld shim.
V=/Volumes/a20e-kernel-cs
TREE=${1:?usage: build-tree.sh <tree-dir>}
LOG=$HOME/Downloads/logs/$(basename "$TREE").log
mkdir -p "$HOME/Downloads/logs"
: > "$LOG"

cd "$TREE" || { echo "TREE_MISSING" >> "$LOG"; exit 90; }

export ARCH=arm64
export CROSS_COMPILE=aarch64-elf-
export ANDROID_MAJOR_VERSION=q
export PATH="$V/host/pc:$V/host/bin:/opt/homebrew/opt/llvm/bin:$PATH"
export HOSTLDFLAGS="-L/opt/homebrew/opt/openssl@3/lib"

echo "== build ==" >> "$LOG"
make ARCH=arm64 -j8 Image \
	CC=/opt/homebrew/opt/llvm/bin/clang \
	LD="$V/host/ldshim" \
	HOSTCFLAGS="-I$V/host" \
	KCFLAGS="-Wno-error -Wno-strict-prototypes -Wno-unused-but-set-variable -Wno-section -Wno-implicit-enum-enum-cast -Wno-self-assign" \
	>> "$LOG" 2>&1
rc=$?
echo "MAKE_EXIT=$rc" >> "$LOG"
ls -l arch/arm64/boot/Image >> "$LOG" 2>&1
exit $rc
