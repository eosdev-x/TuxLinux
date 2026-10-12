#!/bin/bash

set -ouex pipefail

### Add Repositories

# VS Code (Microsoft repo)
cat > /etc/yum.repos.d/vscode.repo << 'EOF'
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF
rpm --import https://packages.microsoft.com/keys/microsoft.asc

# WezTerm COPR
dnf5 -y copr enable wezfurlong/wezterm-nightly

# Cloudflare tunnel client
rpm --import https://pkg.cloudflare.com/cloudflare-ascii-pubkey.gpg
cat > /etc/yum.repos.d/cloudflared.repo << 'EOF'
[cloudflared]
name=Cloudflare Tunnel Client
baseurl=https://pkg.cloudflare.com/cloudflared/rpm
enabled=1
gpgcheck=1
gpgkey=https://pkg.cloudflare.com/cloudflare-ascii-pubkey.gpg
EOF

### Install packages

# Development groups
dnf5 install -y @c-development @development-tools

# Terminal & shell
dnf5 install -y tmux vim zsh fd-find zoxide wezterm

# Browsers (Chromium required for OpenClaw browser automation / CDP)
dnf5 install -y chromium

# Editor
dnf5 install -y code

# Version control & dev essentials
dnf5 install -y git git-lfs gh

# Languages & runtimes
dnf5 install -y golang rust cargo nodejs nodejs-full-i18n npm python3-pip java-devel qt6-qtbase-devel cmake

# Build tools & native deps (Tauri, Flutter, Rust bindings, Protobuf, Qt6)
dnf5 install -y \
  webkit2gtk4.1-devel openssl-devel gtk3-devel \
  libappindicator-gtk3-devel librsvg2-devel pango-devel \
  lld pkg-config \
  protobuf-compiler protobuf-devel \
  sqlite-devel ninja-build \
  qt6-qtdeclarative-devel qt6-qtsvg-devel qt6-qtshadertools-devel libgit2-devel qtkeychain-qt6-devel

# Bazzite ships an epoch-bumped/custom Mesa stack. Fedora development RPMs
# require a different runtime. Keep these headers in Containerfile.devel rather
# than extracting RPMs over the host or replacing gaming drivers.

# Containers & virtualization
dnf5 install -y distrobox podman-compose

# Utilities
dnf5 install -y htop btop ripgrep jq yq fzf bat eza curl tar gzip unzip zstd shellcheck

# Lazygit (needs COPR)
dnf5 -y copr enable atim/lazygit
dnf5 install -y lazygit
dnf5 -y copr disable atim/lazygit

# CLI tools (benchmarking, code stats, git diffs)
dnf5 install -y git-delta hyperfine yt-dlp

# Theming
dnf5 install -y kvantum

# The vendor RPM's post-install creates a compatibility link in /usr/local/bin.
# /usr/local points into /var on Atomic systems; create it for the scriptlet.
install -d -m 0755 /var/usrlocal/bin
dnf5 install -y cloudflared
test -x /usr/bin/cloudflared

# Keep a verified SDK seed in the image. The launcher extracts a writable copy
# for each user/version; Flutter must not write into the immutable image.
FLUTTER_VERSION="3.29.3"
FLUTTER_SHA256="8a908a5add53c1dfc2031da29e58daefd59a6d1d52fb5cb61f5ee52c73e36e15"
install -d /usr/share/tuxlinux
curl -fSL --retry 3 "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" -o /usr/share/tuxlinux/flutter.tar.xz
printf '%s  %s\n' "$FLUTTER_SHA256" /usr/share/tuxlinux/flutter.tar.xz | sha256sum --check --strict
printf '%s\n' "$FLUTTER_VERSION" > /usr/share/tuxlinux/flutter-version
install -m 0755 /ctx/flutter-launcher.sh /usr/bin/flutter
ln -sf flutter /usr/bin/dart

# Disable COPRs & cleanup repos
dnf5 -y copr disable wezfurlong/wezterm-nightly
rm -f /etc/yum.repos.d/cloudflared.repo

# Pin and verify the executable instead of executing a mutable installer.
STARSHIP_VERSION="1.26.0"
STARSHIP_SHA256="b7c232b0e8249d8e55a40beb79c5c43a7d370f3f9408bd215deb0170daeaadf3"
curl -fSL --retry 3 "https://github.com/starship/starship/releases/download/v${STARSHIP_VERSION}/starship-x86_64-unknown-linux-musl.tar.gz" -o /tmp/starship.tar.gz
printf '%s  %s\n' "$STARSHIP_SHA256" /tmp/starship.tar.gz | sha256sum --check --strict
tar -xzf /tmp/starship.tar.gz -C /usr/bin starship
rm /tmp/starship.tar.gz

# Preserve upstream registry policies and add our repository's verification key.
python3 /ctx/configure-trust.py --key /ctx/cosign.pub

### Enable services
systemctl enable podman.socket

# Fail the build if a promised tool or development interface is absent.
/ctx/smoke-test.sh --build
