#!/bin/bash
# Minimal pkg-config shim: the kernel's extract-cert/sign-file ask for libcrypto.
OSSL=/opt/homebrew/opt/openssl@3
args="$*"
case "$args" in
	*--cflags*) echo "-I$OSSL/include" ;;
	*--libs*) echo "-L$OSSL/lib -lcrypto" ;;
	*--exists*|*--modversion*) exit 0 ;;
	*) exit 1 ;;
esac
