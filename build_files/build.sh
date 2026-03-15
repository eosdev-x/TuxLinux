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
dnf5 install -y tmux vim zsh fd-find zoxide wezterm --skip-unavailable

# Editor
dnf5 install -y code

# Version control & dev essentials
dnf5 install -y git git-lfs gh --skip-unavailable

# Languages & runtimes (what you can't get via distrobox/toolbox)
dnf5 install -y golang rust cargo nodejs nodejs-full-i18n npm python3-pip java-17-openjdk-devel java-21-openjdk-devel --skip-unavailable

# Tauri build dependencies
dnf5 install -y webkit2gtk4.1-devel openssl-devel gtk3-devel libappindicator-gtk3-devel librsvg2-devel pango-devel --skip-unavailable

# Containers & virtualization
dnf5 install -y distrobox podman-compose --skip-unavailable

# Utilities
dnf5 install -y htop btop ripgrep jq yq fzf bat eza curl tar gzip unzip --skip-unavailable

# Lazygit (needs COPR)
dnf5 -y copr enable atim/lazygit
dnf5 install -y lazygit --skip-unavailable
dnf5 -y copr disable atim/lazygit

# CLI tools (benchmarking, code stats, git diffs)
dnf5 install -y git-delta hyperfine yt-dlp --skip-unavailable

# Theming
dnf5 install -y kvantum --skip-unavailable

# Tauri build dependencies
dnf5 install -y webkit2gtk4.1-devel openssl-devel gtk3-devel libappindicator-gtk3-devel librsvg2-devel pango-devel --skip-unavailable

# Networking tools — cloudflared RPM post-install needs /usr/local/bin for symlink
install -d -m 0755 /usr/local/bin 2>/dev/null || true
dnf5 install -y cloudflared --skip-unavailable || true

# Disable COPRs & cleanup repos
dnf5 -y copr disable wezfurlong/wezterm-nightly
rm -f /etc/yum.repos.d/cloudflared.repo

# Install Starship prompt
curl -fsSL https://starship.rs/install.sh | sh -s -- -y -b /usr/bin

### Enable services
systemctl enable podman.socket
