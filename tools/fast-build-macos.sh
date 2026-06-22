#!/bin/sh
set -eu

root_dir="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"

"$root_dir/tools/start-fast-builder-macos.sh"

docker_config="$root_dir/build/docker-public-config"
mkdir -p "$docker_config"
if [ ! -f "$docker_config/config.json" ]; then
    printf '%s\n' '{"auths":{}}' > "$docker_config/config.json"
fi

export DOCKER_CONFIG="$docker_config"
export DOCKER_HOST="unix://$HOME/.colima/${OCTOLINUX_COLIMA_PROFILE:-octolinux-fast}/docker.sock"
export OCTOLINUX_BUILD_MODE=fast
export OCTOLINUX_SKIP_BUILDER_IMAGE="${OCTOLINUX_SKIP_BUILDER_IMAGE:-1}"
export OCTOLINUX_CONTAINER_PLATFORM=linux/arm64
export OCTOLINUX_REPOSITORY="${OCTOLINUX_REPOSITORY:-https://mirrors.summithq.com/voidlinux/current}"

# Failed ISO builds can leave containers and sparse VM blocks consuming host
# storage. Keep the tagged builder image and package cache, but reclaim the
# disposable pieces before the 15 GiB build-space check runs.
docker container prune -f >/dev/null 2>&1 || true
docker image prune -f >/dev/null 2>&1 || true
colima ssh --profile "${OCTOLINUX_COLIMA_PROFILE:-octolinux-fast}" \
    -- sudo fstrim -av >/dev/null 2>&1 || true

exec "$root_dir/tools/build-in-container.sh"
