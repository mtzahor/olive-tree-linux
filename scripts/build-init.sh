#!/bin/sh

set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"

echo "Building olive-init..."

cd "$ROOT/init"

cargo build \
    --release \
    --target x86_64-unknown-linux-musl

echo "Installing olive-init into rootfs..."

cp \
    target/x86_64-unknown-linux-musl/release/olive-init \
    "$ROOT/rootfs/init"

chmod +x "$ROOT/rootfs/init"

echo "olive-init built successfully."
