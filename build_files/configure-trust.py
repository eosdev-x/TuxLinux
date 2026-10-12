#!/usr/bin/env python3
"""Merge TuxLinux trust without replacing upstream registry policies."""
import argparse
import json
import os
from pathlib import Path
import tempfile


def configure(root: Path, key: Path) -> None:
    public_key = key.read_bytes()
    if not public_key.startswith(b"-----BEGIN PUBLIC KEY-----\n"):
        raise ValueError("Expected a PEM public key")
    policy_path = root / "etc/containers/policy.json"
    policy = json.loads(policy_path.read_text())
    policy.setdefault("transports", {}).setdefault("docker", {})[
        "ghcr.io/eosdev-x/tuxlinux"
    ] = [{
        "type": "sigstoreSigned",
        "keyPath": "/etc/pki/containers/tuxlinux.pub",
        "signedIdentity": {"type": "matchRepository"},
    }]
    key_path = root / "etc/pki/containers/tuxlinux.pub"
    key_path.parent.mkdir(parents=True, exist_ok=True)
    key_path.write_bytes(public_key)
    key_path.chmod(0o644)
    registry_path = root / "etc/containers/registries.d/tuxlinux.yaml"
    registry_path.parent.mkdir(parents=True, exist_ok=True)
    registry_path.write_text(
        "docker:\n  ghcr.io/eosdev-x/tuxlinux:\n    use-sigstore-attachments: true\n"
    )
    registry_path.chmod(0o644)
    # Replace atomically so interruption cannot leave a truncated policy.
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", dir=policy_path.parent, delete=False) as stream:
            temporary = Path(stream.name)
            json.dump(policy, stream, indent=2)
            stream.write("\n")
        temporary.chmod(policy_path.stat().st_mode & 0o777)
        os.replace(temporary, policy_path)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path("/"))
    parser.add_argument("--key", type=Path, required=True)
    args = parser.parse_args()
    configure(args.root, args.key)
