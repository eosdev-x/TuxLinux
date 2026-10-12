#!/usr/bin/env bash
# Rootful Podman is required by bootc-image-builder.
set -euo pipefail
if [[ $# != 5 || $EUID != 0 ]]; then
    echo 'Usage: sudo build-disk.sh IMAGE TYPE CONFIG OUTPUT BUILDER_IMAGE' >&2
    exit 2
fi
image=$1
type=$2
config=$(realpath "$3")
output=$(realpath -m "$4")
builder_image=$5
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
case "$type" in qcow2|raw|anaconda-iso) ;; *) echo "Unsupported type: $type" >&2; exit 2 ;; esac
test -f "$config"
mkdir -p "$output"
if [[ -n $(find "$output" -mindepth 1 -print -quit) ]]; then
    echo "Output directory must be empty: $output" >&2
    exit 2
fi
podman image exists "$image" || podman pull "$image"
podman pull "$builder_image"
# Each build gets a unique builder tag, avoiding collisions with parallel work.
builder_tag="localhost/tuxlinux-image-builder:$(date +%s)-$$"
trap 'podman image rm "$builder_tag" >/dev/null || true' EXIT
podman build --pull=never --build-arg "SOURCE_IMAGE=$image" \
    --build-arg "BIB_IMAGE=$builder_image" -f "$repo/Containerfile.builder" \
    -t "$builder_tag" "$repo"
podman run --rm --privileged --security-opt label=type:unconfined_t \
    -v /var/lib/containers/storage:/var/lib/containers/storage \
    -v "$config:/config.toml:ro" -v "$output:/output" \
    "$builder_tag" --type "$type" --rootfs=btrfs --use-librepo=True "$image"
(
    cd "$output"
    # SHA256SUMS is explicitly excluded from the input list.
    # shellcheck disable=SC2094
    find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 -r sha256sum > SHA256SUMS
)
chown -R "${SUDO_UID:-0}:${SUDO_GID:-0}" "$output"
