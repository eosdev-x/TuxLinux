from pathlib import Path
import shlex
import unittest

REPO = Path(__file__).resolve().parents[1]


class Libgit2Test(unittest.TestCase):
    def test_fedora45_development_package_is_installed(self):
        build = (REPO / 'build_files/build.sh').read_text()
        commands = [shlex.split(line) for line in build.replace('\\\n', ' ').splitlines()
                    if line.startswith('dnf5 install ')]
        packages = [token for command in commands for token in command[2:]]
        self.assertIn('libgit2_1.9-devel', packages)
        self.assertNotIn('libgit2-devel', packages)
        self.assertNotIn('--skip-unavailable', build)

    def test_smoke_checks_libgit2_development_interface(self):
        smoke = (REPO / 'build_files/smoke-test.sh').read_text()
        checks = [shlex.split(line) for line in smoke.replace('\\\n', ' ').splitlines()
                  if line.startswith('pkg-config --exists ')]
        self.assertTrue(any('libgit2' in command[2:] for command in checks),
                        'smoke test must require pkg-config libgit2')


if __name__ == '__main__':
    unittest.main()
