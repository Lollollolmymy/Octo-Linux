#!/bin/sh
set -eu

repo_url="${VOID_MKLIVE_REPO:-https://github.com/void-linux/void-mklive.git}"
target="${VOID_MKLIVE_DIR:-void-mklive}"

if [ -x "$target/mklive.sh" ]; then
    echo "void-mklive already exists at $target"
elif [ -e "$target" ]; then
    echo "$target exists but $target/mklive.sh is missing or not executable" >&2
    exit 1
else
    git clone "$repo_url" "$target"
fi

root_dir="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
patch_file="$root_dir/patches/void-mklive-container.patch"

if git -C "$target" apply --reverse --check "$patch_file" >/dev/null 2>&1; then
    echo "OctoLinux container patch is already applied."
elif git -C "$target" apply --check "$patch_file"; then
    git -C "$target" apply "$patch_file"
    echo "Applied OctoLinux container patch."
else
    echo "Unable to apply $patch_file to the current void-mklive checkout." >&2
    exit 1
fi

echo "Fetched void-mklive into $target"
