#!/usr/bin/env bash
set -euo pipefail

for tool in git gh go rustc cargo node npm python3 pip3 java javac code \
    wezterm chromium cloudflared podman distrobox starship flutter dart \
    protoc cmake ninja pkg-config; do
    command -v "$tool"
done
pkg-config --exists libpipewire-0.3 gbm webkit2gtk-4.1 openssl gtk+-3.0 sqlite3
cloudflared --version
starship --version
javac -version
python3 - <<'PY'
import json
from pathlib import Path
policy = json.loads(Path('/etc/containers/policy.json').read_text())
rule = policy['transports']['docker']['ghcr.io/eosdev-x/tuxlinux'][0]
assert rule['type'] == 'sigstoreSigned'
assert Path(rule['keyPath']).is_file()
PY

if [[ ${1:-} != --build ]]; then
    mkdir -p "$HOME"
    # Run on a read-only root as a non-root user in CI, with disposable HOME.
    flutter --version
    dart --version
    flutter config --no-analytics
    flutter create --platforms=linux --no-pub /tmp/flutter-smoke
    test -f /tmp/flutter-smoke/linux/CMakeLists.txt
    # Compile/link representative headers against the actual image libraries.
    printf '#include <pipewire/pipewire.h>\n#include <gbm.h>\nint main(void) { pw_init(0, 0); return gbm_create_device(-1) != 0; }\n' > /tmp/headers-smoke.c
    # pkg-config deliberately emits separate compiler arguments.
    # shellcheck disable=SC2046
    cc /tmp/headers-smoke.c $(pkg-config --cflags --libs libpipewire-0.3 gbm) -o /tmp/headers-smoke
fi
