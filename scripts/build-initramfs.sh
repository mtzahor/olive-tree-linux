#!/bin/sh

set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"

echo "Building initramfs..."

mkdir -p "$ROOT/build"

cd "$ROOT/rootfs"

find . -print0 \
    | cpio --null -o --format=newc \
    | gzip -9 \
    > "$ROOT/build/initramfs.cpio.gz"

echo "Created:"
ls -lh "$ROOT/build/initramfs.cpio.gz"
