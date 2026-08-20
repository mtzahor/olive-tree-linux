Olive Tree Linux v0.0.2

Minimalist Linux distro with Rust init.

Version history:

- v0.0.2  Rust PID 1 + mounts + process/session/console setup
- v0.0.1  Linux + BusyBox shell

Building and running:

1. Compile the latest Linux kernel with the configuration found in kernel/config and add it to build directory inside the repo so that you have build/bzImage.
2. Build the Rust init: ./scripts/build-init.sh
3. Build initramfs: ./scripts/build-initramfs.sh
4. Boot the distro in  QEMU: ./scripts/run-qemu.sh
