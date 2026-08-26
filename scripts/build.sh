#!/bin/sh

set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"

echo "================================"
echo "  Building Olive Tree Linux"
echo "================================"

"$ROOT/scripts/build-kernel.sh"
"$ROOT/scripts/build-busybox.sh"
"$ROOT/scripts/build-init.sh"
"$ROOT/scripts/build-initramfs.sh"

echo
echo "Olive Tree Linux build complete."
echo "Kernel:    $ROOT/build/bzImage"
echo "Initramfs: $ROOT/build/initramfs.cpio.gz"
