from pathlib import Path
import re
import subprocess
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[1]


class ShfmtTest(unittest.TestCase):
    def test_pinned_verified_install_replaces_dnf_package(self):
        build = (REPO / 'build_files/build.sh').read_text()
        for line in build.splitlines():
            if line.startswith('dnf5 '):
                self.assertNotIn('shfmt', line.split())
        self.assertNotIn('--skip-unavailable', build)
        self.assertRegex(build, r'SHFMT_VERSION="\d+\.\d+\.\d+"')
        self.assertRegex(build, r'SHFMT_SHA256="[a-f0-9]{64}"')
        self.assertIn('https://github.com/mvdan/sh/releases/download/v${SHFMT_VERSION}/shfmt_v${SHFMT_VERSION}_linux_amd64', build)
        self.assertIn('curl -fSL --retry 3', build)
        self.assertIn('install -m 0755 /tmp/shfmt /usr/bin/shfmt', build)
        self.assertIn('shfmt', (REPO / 'build_files/smoke-test.sh').read_text())

    def run_install(self, corrupt=False, download_failure=False):
        build = (REPO / 'build_files/build.sh').read_text()
        match = re.search(r'^SHFMT_VERSION=.*?^rm /tmp/shfmt$', build, re.M | re.S)
        if match is None:
            self.fail('missing standalone shfmt installation block')
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source, target = root / 'download', root / 'installed'
            # A small fixture exercises the real sha256sum/install path offline.
            import hashlib
            payload = b'shfmt test fixture\n'
            digest = hashlib.sha256(payload).hexdigest()
            block = re.sub(r'SHFMT_SHA256="[a-f0-9]{64}"', f'SHFMT_SHA256="{digest}"', match.group())
            block = block.replace('/tmp/shfmt', str(source)).replace('/usr/bin/shfmt', str(target))
            source.write_bytes(b'corrupt\n' if corrupt else payload)
            # Only the network boundary is stubbed; no host installation occurs.
            script = 'set -euo pipefail\ncurl() { return ' + ('22' if download_failure else '0') + '; }\n' + block
            result = subprocess.run(['bash', '-c', script], capture_output=True, text=True)
            if corrupt or download_failure:
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse(target.exists(), 'unverified binary was installed')
            else:
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(target.read_bytes(), payload)
                self.assertEqual(target.stat().st_mode & 0o777, 0o755)
                self.assertFalse(source.exists())

    def test_verified_binary_installs_and_download_is_removed(self):
        self.run_install()

    def test_checksum_mismatch_prevents_install(self):
        self.run_install(corrupt=True)

    def test_download_failure_prevents_install(self):
        self.run_install(download_failure=True)


if __name__ == '__main__':
    unittest.main()
