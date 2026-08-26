#!/bin/sh

set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"

KERNEL_VERSION="$(cat "$ROOT/kernel/version")"
SOURCE_VERSION="$(cat "$ROOT/kernel/source-version")"
KERNEL_CONFIG="$ROOT/kernel/config"

SOURCE_DIR="$ROOT/build/linux-$SOURCE_VERSION"
KERNEL_ARCHIVE="$ROOT/build/linux-$SOURCE_VERSION.tar.xz"

echo "Building Linux $KERNEL_VERSION for Olive Tree Linux..."

mkdir -p "$ROOT/build"

if [ ! -s "$KERNEL_ARCHIVE" ]; then
    echo "Downloading Linux $SOURCE_VERSION..."

    wget \
        "https://cdn.kernel.org/pub/linux/kernel/v7.x/linux-$SOURCE_VERSION.tar.xz" \
        -O "$KERNEL_ARCHIVE"
else
    echo "Using existing kernel archive."
fi

if [ ! -d "$SOURCE_DIR" ]; then
    echo "Extracting Linux $SOURCE_VERSION..."

    tar -xf "$KERNEL_ARCHIVE" -C "$ROOT/build"
else
    echo "Using existing kernel source tree."
fi

echo "Applying Olive Tree kernel configuration..."

cp "$KERNEL_CONFIG" "$SOURCE_DIR/.config"

make -C "$SOURCE_DIR" olddefconfig

echo "Compiling kernel..."

make -C "$SOURCE_DIR" -j"$(nproc)"

echo "Installing kernel image..."

cp \
    "$SOURCE_DIR/arch/x86/boot/bzImage" \
    "$ROOT/build/bzImage"

echo "Kernel built successfully:"
ls -lh "$ROOT/build/bzImage"
