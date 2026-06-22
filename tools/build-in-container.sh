#!/bin/sh
set -eu

root_dir="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
image="${OCTOLINUX_BUILDER_IMAGE:-octolinux-iso-builder}"
platform="${OCTOLINUX_CONTAINER_PLATFORM:-linux/amd64}"
minimum_free_kib=$((15 * 1024 * 1024))

# The output is replaced on every build. Remove only the previous generated ISO
# before checking capacity so it does not count against the build workspace.
output="${OCTOLINUX_OUTPUT:-$root_dir/dist/octolinux-stage0-x86_64.iso}"
rm -f "$output"

available_kib=$(df -Pk "$root_dir" | awk 'NR == 2 { print $4 }')

if [ "$available_kib" -lt "$minimum_free_kib" ]; then
    available_gib=$(awk -v kib="$available_kib" 'BEGIN { printf "%.1f", kib / 1024 / 1024 }')
    echo "OctoLinux ISO builds require at least 15 GiB free." >&2
    echo "Only ${available_gib} GiB is available on the workspace volume." >&2
    exit 1
fi

if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    runtime=docker
    volume="$root_dir:/work"
elif command -v podman >/dev/null 2>&1; then
    runtime=podman
    volume="$root_dir:/work:Z"
else
    echo "Install Docker or Podman, then rerun this script." >&2
    exit 1
fi

if [ "${OCTOLINUX_SKIP_BUILDER_IMAGE:-0}" != 1 ] ||
    ! "$runtime" image inspect "$image" >/dev/null 2>&1; then
    "$runtime" build --platform "$platform" -t "$image" -f "$root_dir/Containerfile" "$root_dir"
fi

# --cpus is omitted intentionally: Docker uses all available CPUs by default.
# Override memory with OCTOLINUX_MEM=8g if needed; omit to use Docker's limit.
"$runtime" run --rm --privileged --platform "$platform" \
    -v "$volume" \
    -w /work \
    -e "OCTOLINUX_REPOSITORY=${OCTOLINUX_REPOSITORY:-https://repo-default.voidlinux.org/current}" \
    -e "OCTOLINUX_BUILD_MODE=${OCTOLINUX_BUILD_MODE:-fast}" \
    ${OCTOLINUX_MEM:+--memory "$OCTOLINUX_MEM"} \
    --shm-size 2g \
    "$image" \
    /work/tools/build-iso.sh
