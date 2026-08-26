#!/bin/sh

set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"

INIT_BINARY="$ROOT/init/target/x86_64-unknown-linux-musl/release/olive-init"
BUILD_BINARY="$ROOT/build/olive-init"

echo "Building olive-init..."

cd "$ROOT/init"

cargo build \
    --release \
    --target x86_64-unknown-linux-musl

echo "Installing olive-init into build directory..."

mkdir -p "$ROOT/build"

cp "$INIT_BINARY" "$BUILD_BINARY"

chmod +x "$BUILD_BINARY"

echo "olive-init built successfully."
