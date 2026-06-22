#!/bin/sh
set -eu

profile="${OCTOLINUX_COLIMA_PROFILE:-octolinux-fast}"
cpus="${OCTOLINUX_VM_CPUS:-10}"
memory="${OCTOLINUX_VM_MEMORY:-12}"
disk="${OCTOLINUX_VM_DISK:-60}"

if [ "$(uname -s)" != Darwin ] || [ "$(uname -m)" != arm64 ]; then
    echo "This helper is for Apple Silicon macOS hosts." >&2
    exit 1
fi

if [ ! -x /Library/Apple/usr/libexec/oah/runtime ]; then
    echo "Rosetta 2 is required. Install it once with:" >&2
    echo "  softwareupdate --install-rosetta --agree-to-license" >&2
    exit 1
fi

if colima status --profile "$profile" >/dev/null 2>&1; then
    docker context use "colima-$profile" >/dev/null
    echo "Fast builder is already running."
    exit 0
fi

colima start --profile "$profile" \
    --arch aarch64 \
    --vm-type vz \
    --vz-rosetta \
    --mount-type virtiofs \
    --runtime docker \
    --cpus "$cpus" \
    --memory "$memory" \
    --disk "$disk"

docker context use "colima-$profile" >/dev/null
echo "Fast OctoLinux builder ready: $profile"
