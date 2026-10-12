# 🐧 TuxLinux

A personal development and gaming image based on **Bazzite NVIDIA-open, KDE,
x86-64**. This is not a generic AMD/Intel image, an ARM image, or a Bazzite Deck
variant. Check [Bazzite's hardware guidance](https://docs.bazzite.gg/Gaming/Hardware_compatibility_for_gaming/)
before switching, especially for older NVIDIA GPUs.

## What's included

- Go, Rust/Cargo, Node.js/npm, Python/pip, and Fedora's current default JDK
- VS Code, Vim, WezTerm, tmux, Zsh, Starship, Git/GitHub CLI, and CLI utilities
- C/C++ build tools, Tauri/GTK/WebKitGTK, Qt6 and Protobuf development dependencies
- Podman, podman-compose, Distrobox, Chromium, cloudflared, and Kvantum
- Steam and the graphics/gaming stack inherited from Bazzite
- Flutter 3.29.3 with its bundled Dart SDK, seeded from a checksum-verified archive

Required packages must resolve during the build; missing dependencies fail CI.
Java 17/21 are not promised by this image: those packages are no longer available
in the current Fedora base. Use a project-specific container or JDK manager when
an older Java version is required.

Flutter and Dart launchers extract an SDK on first use into
`${XDG_DATA_HOME:-$HOME/.local/share}/tuxlinux/flutter/<version>`. This directory
is writable by the user, allowing cache downloads and tooling to function on an
immutable OS. Allow space for the extracted SDK in each user's home. New image
SDK versions use new directories; older SDKs are retained. IDEs should point at
that extracted SDK. Host rollback does not undo changes to the user's SDK.

The system Podman socket is enabled for rootful workloads. Rootless containers
use their own user service; do not expose either socket to untrusted clients.

## PipeWire / GBM development

Bazzite's custom Mesa packages do not satisfy Fedora development RPMs' exact
runtime requirements. Build projects needing these interfaces in the supplied
Fedora SDK container, preserving the host gaming drivers:

```bash
podman build -f Containerfile.devel -t localhost/tuxlinux-native-sdk:latest .
distrobox create --name tuxlinux-native-sdk --image localhost/tuxlinux-native-sdk:latest
distrobox enter tuxlinux-native-sdk
pkg-config --modversion libpipewire-0.3 gbm
```

The SDK includes matching package-managed runtime libraries and headers. It is
for compilation, not validation of host NVIDIA/graphics integration. A binary
built there still needs compatibility testing if deployed outside the container.
Distrobox shares your home by default; it is not an untrusted-code sandbox.

## Installation and signature trust

Back up personal data and retain a working deployment. Use `rpm-ostree status`
and `bootc status` to identify the current deployment and supported backend.
Switching images requires a reboot and does not roll back home or `/var` data.
Do not switch desktop environments or assume mutable Fedora supports rebasing.

Images are signed with the repository's `cosign.pub`. Before the first switch,
obtain this repository at a reviewed commit and verify the public key through a
trusted copy/channel. Review the trust helper, then run it from the checkout:

```bash
sudo python3 build_files/configure-trust.py --key cosign.pub
```

This merges a repository-scoped signature rule into `/etc/containers/policy.json`,
installs `/etc/pki/containers/tuxlinux.pub`, and enables signature discovery.
It preserves other registry rules. The image includes the same policy for future
updates. Existing installations using an unverified origin must explicitly switch
to a verified origin; merely installing the policy does not change that origin.

For a compatible bootc-managed installation:

```bash
sudo bootc switch --enforce-container-sigpolicy ghcr.io/eosdev-x/tuxlinux:latest
```

For an rpm-ostree-managed Fedora Atomic/Bazzite installation:

```bash
rpm-ostree rebase ostree-image-signed:docker://ghcr.io/eosdev-x/tuxlinux:latest
```

Use the command appropriate to your deployment, not both. Check staged status,
then reboot when ready. Secure Boot firmware/module keys are a separate matter
from image signatures; follow Bazzite's Secure Boot guide for your hardware.

## Updates and recovery

The container workflow builds daily and on main-branch changes. Published tags
include `latest`, date tags, and a source SHA tag. Date tags can be replaced by
another build that day; use an image digest to identify an exact artifact.

Use Bazzite's updater for ordinary updates, checking that the source remains
`ghcr.io/eosdev-x/tuxlinux`. Keep the previous deployment for recovery. A boot-menu
selection can boot an older deployment; a persistent rollback must be selected
with the appropriate deployment tool. Rollback restores the OS deployment, not
personal files, application databases, containers, or every mutable setting.

## Building and validation

```bash
just build
# Or:
podman build -t tuxlinux .

python3 -m unittest discover -s tests -v
shellcheck build_files/*.sh scripts/*.sh
```

CI checks required tools/development metadata during the build, runs bootc lint,
and exercises Flutter as an ordinary user in a read-only container. It also
builds a separate native SDK and compiles against its PipeWire/GBM headers. These checks do not replace a booted VM or
real NVIDIA hardware test. Test login, graphics, networking, update, and rollback
on a disposable deployment before relying on a release.

`just build-iso` and the disk workflow use `disk_config/iso-kde.toml`. Only amd64
is supported. The disk workflow consumes the published `latest` image; a PR disk
build checks installer configuration, not an unpublished PR container. Installer
post-install configuration retains the TuxLinux origin with signature enforcement.
QCOW2 and installer artifacts have separate names to prevent matrix overwrites.
Both local and CI builds use `scripts/build-disk.sh`, which copies the source
image's public RPM keys into a temporary builder image for dependency solving.
Repository signature checks remain enabled.

Packages live in `build_files/build.sh`; launchers, trust setup, and smoke checks
live alongside it. Flutter and Starship versions/checksums must be updated
together from their official release metadata. Preserve the existing signing key
unless intentionally planning a key rotation for installed clients.

## License

Apache-2.0. See [LICENSE](LICENSE). Bundled software retains its own licenses.
