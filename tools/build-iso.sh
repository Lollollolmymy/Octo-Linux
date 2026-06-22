#!/bin/sh
set -eu

root_dir="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
arch="${OCTOLINUX_ARCH:-x86_64}"
output="${OCTOLINUX_OUTPUT:-$root_dir/dist/octolinux-stage0-$arch.iso}"
repo="${OCTOLINUX_REPOSITORY:-https://repo-default.voidlinux.org/current}"
mklive="${VOID_MKLIVE:-$root_dir/void-mklive/mklive.sh}"
postsetup="$root_dir/hooks/postsetup.sh"
build_root="${OCTOLINUX_BUILD_ROOT:-/tmp/octolinux-mklive}"

# ── Speed tuning ────────────────────────────────────────────────────────────
# Use every available CPU core for mksquashfs.  On an M4 (10 cores) this
# is passed to mksquashfs via MKSQUASHFS_NPROCS; mklive.sh reads it if
# the variable is set, otherwise we patch the call via MKSQUASHFS_OPTS.
nproc="${OCTOLINUX_NPROC:-$(nproc 2>/dev/null || sysctl -n hw.logicalcpu 2>/dev/null || echo 4)}"

build_mode="${OCTOLINUX_BUILD_MODE:-fast}"
case "$build_mode" in
    fast)
        initramfs_comp="${OCTOLINUX_INITRAMFS_COMP:-lz4}"
        squashfs_comp="${OCTOLINUX_SQUASHFS_COMP:-lzo}"
        squashfs_extra="-no-xattrs -Xalgorithm lzo1x_1"
        ;;
    release)
        initramfs_comp="${OCTOLINUX_INITRAMFS_COMP:-xz}"
        squashfs_comp="${OCTOLINUX_SQUASHFS_COMP:-zstd}"
        squashfs_extra="-Xcompression-level 10"
        ;;
    *)
        echo "Unknown OCTOLINUX_BUILD_MODE: $build_mode" >&2
        exit 1
        ;;
esac

# Memory budget for mksquashfs (half of available RAM keeps the system
# responsive during a container build).
mem_mb="${OCTOLINUX_SQUASHFS_MEM:-$(awk '/MemTotal/{printf "%d", $2/2048}' /proc/meminfo 2>/dev/null || echo 4096)}"

# XBPS parallel fetch workers (speeds up package download phase).
export XBPS_FETCH_TIMEOUT=60
export XBPS_FETCH_RETRIES=3
# ────────────────────────────────────────────────────────────────────────────

if [ "$(uname -s)" != "Linux" ]; then
    echo "ISO building must run on Linux. Use a Linux VM/container or tools/build-in-container.sh." >&2
    exit 1
fi

if [ "$(id -u)" -ne 0 ]; then
    echo "Run this script as root because live ISO construction needs mounts/chroots." >&2
    exit 1
fi

if [ ! -x "$mklive" ]; then
    echo "Missing void-mklive at $mklive" >&2
    echo "Run ./tools/fetch-void-mklive.sh first, or set VOID_MKLIVE=/path/to/mklive.sh" >&2
    exit 1
fi

packages="$(
    awk '
        /^[[:space:]]*#/ { next }
        /^[[:space:]]*$/ { next }
        { print }
    ' "$root_dir"/packages/*.txt | tr '\n' ' '
)"

mkdir -p "$root_dir/dist" "$root_dir/build" "$build_root"
rm -f "$output"
mkdir -p /var/lib/binfmts

chmod +x "$root_dir/overlay/usr/local/bin/octolinux-session"
chmod +x "$root_dir/overlay/usr/local/bin/octolinux-installer"
chmod +x "$root_dir/overlay/usr/local/bin/octofetch"
chmod +x "$root_dir/overlay/usr/local/bin/octolinux-first-login"
chmod +x "$root_dir/overlay/usr/local/sbin/octolinux-install-system"
chmod +x "$postsetup"

echo "Building OctoLinux stage 0 ISO"
echo "  arch:             $arch"
echo "  repo:             $repo"
echo "  build root:       $build_root"
echo "  output:           $output"
echo "  build mode:       $build_mode"
echo "  initramfs comp:   $initramfs_comp"
echo "  squashfs comp:    $squashfs_comp"
echo "  mksquashfs cores: $nproc"
echo "  mksquashfs mem:   ${mem_mb} MiB"

cd "$(dirname -- "$mklive")"
mklive_base="$(basename -- "$mklive")"
# void-mklive uses XBPS_REPOSITORY internally as a list of complete
# --repository flags. Do not leak a raw URL from the caller into that list.
unset XBPS_REPOSITORY
export ROOTDIR="$build_root"
export SPLASH_IMAGE="$root_dir/overlay/usr/share/octolinux/assets/boot-splash.png"
# Pass extra mksquashfs flags via environment so mklive.sh forwards them.
export MKSQUASHFS_OPTS="-processors $nproc -mem ${mem_mb}M $squashfs_extra"

exec "./$mklive_base" \
    -a "$arch" \
    -r "$repo" \
    -p "$packages xf86-video-fbdev xf86-video-vesa" \
    -i "$initramfs_comp" \
    -s "$squashfs_comp" \
    -S "dbus elogind NetworkManager lightdm" \
    -I "$root_dir/overlay" \
    -x "$postsetup" \
    -e /bin/zsh \
    -T "OctoLinux" \
    -o "$output"
