#!/bin/sh

set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"

BUSYBOX_VERSION="$(cat "$ROOT/busybox/version")"

SOURCE_DIR="$ROOT/build/busybox-$BUSYBOX_VERSION"
BUSYBOX_ARCHIVE="$ROOT/build/busybox-$BUSYBOX_VERSION.tar.bz2"

mkdir -p "$ROOT/build"

echo "Building BusyBox $BUSYBOX_VERSION..."

if [ ! -s "$BUSYBOX_ARCHIVE" ]; then
    echo "Downloading BusyBox $BUSYBOX_VERSION..."

    wget \
        "https://busybox.net/downloads/busybox-$BUSYBOX_VERSION.tar.bz2" \
        -O "$BUSYBOX_ARCHIVE"
else
    echo "Using existing BusyBox archive."
fi

if [ ! -d "$SOURCE_DIR" ]; then
    echo "Extracting BusyBox $BUSYBOX_VERSION..."

    tar -xf "$BUSYBOX_ARCHIVE" -C "$ROOT/build"
else
    echo "Using existing BusyBox source tree."
fi

echo "Applying Olive Tree BusyBox configuration..."

cp "$ROOT/busybox/config" "$SOURCE_DIR/.config"

echo "Compiling BusyBox..."

make -C "$SOURCE_DIR" -j"$(nproc)"

cp "$SOURCE_DIR/busybox" "$ROOT/build/busybox"

if ! file "$ROOT/build/busybox" | grep -q "statically linked"; then
    echo "Error: BusyBox is not statically linked." >&2
    exit 1
fi

echo "BusyBox built successfully:"
file "$ROOT/build/busybox"
