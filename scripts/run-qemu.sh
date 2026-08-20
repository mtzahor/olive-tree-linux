#!/bin/sh

set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"

KERNEL="$ROOT/build/bzImage"
INITRAMFS="$ROOT/build/initramfs.cpio.gz"

if [ ! -f "$KERNEL" ]; then
    echo "Error: kernel not found:"
    echo "  $KERNEL"
    exit 1
fi

if [ ! -f "$INITRAMFS" ]; then
    echo "Error: initramfs not found:"
    echo "  $INITRAMFS"
    exit 1
fi

echo "Booting Olive Tree Linux..."

exec qemu-system-x86_64 \
    -kernel "$KERNEL" \
    -initrd "$INITRAMFS" \
    -append "console=ttyS0" \
    -nographic
