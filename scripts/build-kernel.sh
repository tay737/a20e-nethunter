#!/bin/sh
# Build the NetHunter + KernelSU kernel for a20e.
#
# Requirements: Apple-silicon or Linux host with clang/LLVM, KernelSU checked out at
# 109442f8 inside the kernel tree as KernelSU/, and drivers/kernelsu symlinked to it.
# On macOS use Homebrew clang: the Kali NetHunter prebuilts are Linux x86-64 and will
# not run here.
#
# Usage: ./build-kernel.sh <kernel-src> <objtree>
set -e
SRC=${1:?kernel source tree}
OUT=${2:?object tree}

if [ "$(uname)" = "Darwin" ]; then
    export PATH=/opt/homebrew/opt/llvm/bin:/opt/homebrew/bin:$PATH
    SSL=${SSL:-/opt/homebrew/opt/openssl@3}
    HOSTCC="clang -I/tmp/hostinc -I$SSL/include"
    HOSTLDFLAGS="-L$SSL/lib -Wl,-rpath,$SSL/lib"
    CROSS=aarch64-elf-
    CLANG_TRIPLE=aarch64-linux-gnu-
else
    HOSTCC=clang
    HOSTLDFLAGS=
    CROSS=aarch64-linux-android-
    CLANG_TRIPLE=aarch64-linux-gnu-
fi

make -C "$SRC" O="$OUT" ARCH=arm64 CC=clang LD=ld.lld CROSS_COMPILE="$CROSS" \
     CLANG_TRIPLE="$CLANG_TRIPLE" HOSTCC="$HOSTCC" HOSTLDFLAGS="$HOSTLDFLAGS" \
     exynos7885-a20e_defconfig

make -C "$SRC" O="$OUT" -j"$(nproc 2>/dev/null || sysctl -n hw.ncpu)" ARCH=arm64 \
     CC=clang LD=ld.lld CROSS_COMPILE="$CROSS" CLANG_TRIPLE="$CLANG_TRIPLE" \
     HOSTCC="$HOSTCC" HOSTLDFLAGS="$HOSTLDFLAGS" Image 2>&1 | tee /tmp/a20e-kernel-build.log

grep -m1 'KernelSU version' /tmp/a20e-kernel-build.log
ls -l "$OUT/arch/arm64/boot/Image"
