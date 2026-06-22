#!/bin/sh
set -eu

iso="${1:-}"

if [ -z "$iso" ]; then
    echo "Usage: $0 path/to/octolinux.iso" >&2
    exit 1
fi

if [ ! -f "$iso" ]; then
    echo "ISO not found: $iso" >&2
    exit 1
fi

if [ "$(uname -s)" != "Darwin" ]; then
    echo "This helper is for macOS. On Linux, use dd or a graphical USB writer." >&2
    exit 1
fi

diskutil list
printf '\nEnter target disk, for example disk4: '
read disk

case "$disk" in
    disk[0-9]*)
        ;;
    *)
        echo "Refusing suspicious disk name: $disk" >&2
        exit 1
        ;;
esac

printf 'This will erase /dev/%s. Type OCTOLINUX to continue: ' "$disk"
read confirm

if [ "$confirm" != "OCTOLINUX" ]; then
    echo "Cancelled."
    exit 1
fi

diskutil unmountDisk "/dev/$disk"
sudo dd if="$iso" of="/dev/r$disk" bs=4m status=progress
sync
diskutil eject "/dev/$disk"

echo "Done. The USB drive can be removed."
