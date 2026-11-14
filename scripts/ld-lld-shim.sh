#!/bin/sh
# ld-lld-shim: use LLD as the kernel linker, but keep 4.4's empty built-in.o
# targets working.
#
# Old kernels run "$(LD) -r -o built-in.o" for directories whose objects are
# all disabled. Those inputs are archives with no members, so LLD refuses with
# "target emulation unknown: -m or at least one .o file required" and the build
# dies. Only for that exact error we emit an empty aarch64 object instead,
# which links the same way an empty built-in.o would. Every other failure is
# passed through untouched.
set -e

LLD=${LLD:-$(command -v ld.lld || echo /opt/homebrew/bin/ld.lld)}
CC=${CC:-clang}

out=
prev=
for arg in "$@"; do
	if [ "$prev" = "-o" ]; then
		out=$arg
	fi
	prev=$arg
done

# CONFIG_RELOCATABLE links vmlinux -pie; old kernels put absolute relocations in
# read-only sections, which GNU ld accepts as DT_TEXTREL but LLD rejects. LLD
# allows them with -z notext, so add it for PIE links only.
case " $* " in
*" -pie "*)
	[ "${*#*-z notext}" = "$*" ] || true
	set -- "$@" -z notext
	;;
esac

set +e
err=$("$LLD" "$@" 2>&1)
rc=$?
set -e

if [ "$rc" -eq 0 ]; then
	exit 0
fi

case "$err" in
*target\ emulation\ unknown*)
	[ -n "$out" ] || { echo "ld-lld-shim: empty link without -o: $*" >&2; exit 1; }
	echo "" | "$CC" --target=aarch64-elf -x c -c - -o "$out"
	exit $?
	;;
esac

printf '%s\n' "$err" >&2
exit "$rc"
