#!/usr/bin/env bash
set -euo pipefail

for tool in git gh go rustc cargo node npm python3 pip3 java javac code \
    wezterm chromium-browser cloudflared podman distrobox starship flutter dart \
    protoc cmake ninja pkg-config nvim tree-sitter direnv uv shfmt pre-commit \
    clang clangd shellcheck; do
    command -v "$tool" || { echo "Missing required executable: $tool" >&2; exit 1; }
done
# LazyVim requires Neovim >= 0.11.2 with LuaJIT. Skip user configuration.
nvim --headless -u NONE -i NONE \
    -c 'lua if vim.fn.has("nvim-0.11.2") ~= 1 or not jit then vim.cmd("cquit 1") end' \
    -c 'qa!'
pkg-config --exists webkit2gtk-4.1 openssl gtk+-3.0 sqlite3
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
    flutter create --platforms=linux --no-pub /tmp/flutter_smoke
    test -f /tmp/flutter_smoke/linux/CMakeLists.txt
fi
