import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('trust', REPO / 'build_files/configure-trust.py')
trust = importlib.util.module_from_spec(spec)
spec.loader.exec_module(trust)


class HelpersTest(unittest.TestCase):
    def test_trust_preserves_other_registries_and_is_idempotent(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            policy = root / 'etc/containers/policy.json'
            policy.parent.mkdir(parents=True)
            original = {'default': [{'type': 'reject'}], 'transports': {'docker': {
                'example.org': [{'type': 'reject'}]}, 'dir': {'': [{'type': 'reject'}]}}}
            policy.write_text(json.dumps(original))
            for _ in range(2):
                trust.configure(root, REPO / 'cosign.pub')
            actual = json.loads(policy.read_text())
            self.assertEqual(actual['default'], original['default'])
            self.assertEqual(actual['transports']['dir'], original['transports']['dir'])
            self.assertEqual(actual['transports']['docker']['example.org'], [{'type': 'reject'}])
            self.assertEqual(actual['transports']['docker']['ghcr.io/eosdev-x/tuxlinux'][0]['type'], 'sigstoreSigned')
            self.assertEqual((root / 'etc/pki/containers/tuxlinux.pub').read_bytes(), (REPO / 'cosign.pub').read_bytes())

    def test_flutter_extracts_once_and_dispatches_both_commands(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            seed = root / 'seed'
            seed.mkdir()
            (seed / 'flutter-version').write_text('test-version\n')
            payload = root / 'payload/flutter/bin'
            payload.mkdir(parents=True)
            for name in ('flutter', 'dart'):
                executable = payload / name
                executable.write_text(f'#!/bin/sh\nprintf "%s:%s\\n" "{name}" "$1"\n')
                executable.chmod(0o755)
            subprocess.run(['tar', '-cJf', str(seed / 'flutter.tar.xz'), '-C', str(root / 'payload'), 'flutter'], check=True)
            launcher = root / 'flutter'
            launcher.write_text((REPO / 'build_files/flutter-launcher.sh').read_text().replace('seed=/usr/share/tuxlinux', f'seed="{seed}"'))
            launcher.chmod(0o755)
            (root / 'dart').symlink_to('flutter')
            import os
            env = dict(os.environ, HOME=str(root / 'home'), XDG_DATA_HOME=str(root / 'data'))
            for name in ('flutter', 'dart'):
                output = subprocess.check_output([str(root / name), 'hello world'], env=env, text=True)
                self.assertEqual(output, f'{name}:hello world\n')
            # An existing SDK must work without the seed archive and keep changes.
            (seed / 'flutter.tar.xz').unlink()
            subprocess.run([str(launcher), 'again'], env=env, check=True, capture_output=True)


if __name__ == '__main__':
    unittest.main()
