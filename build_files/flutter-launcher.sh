#!/usr/bin/env bash
set -euo pipefail

seed=/usr/share/tuxlinux
version=$(cat "$seed/flutter-version")
# A versioned directory preserves older SDKs for users who still need them.
sdk_parent="${XDG_DATA_HOME:-$HOME/.local/share}/tuxlinux/flutter"
sdk="$sdk_parent/$version"
mkdir -p "$sdk_parent"
(
    flock -x 9
    if [[ ! -x "$sdk/bin/flutter" ]]; then
        staging=$(mktemp -d "$sdk_parent/.extract.XXXXXXXX")
        trap 'rm -rf -- "$staging"' EXIT
        tar -xf "$seed/flutter.tar.xz" -C "$staging" --no-same-owner
        mv -- "$staging/flutter" "$sdk"
    fi
) 9>"$sdk_parent/.install.lock"

case "$(basename "$0")" in
    dart) exec "$sdk/bin/dart" "$@" ;;
    *) exec "$sdk/bin/flutter" "$@" ;;
esac
