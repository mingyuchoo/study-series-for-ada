from pathlib import Path
import hashlib
import os
import shutil
import subprocess
import tarfile
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


class ReleaseTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="diary release test ")
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)
        self.project = self.directory / "project with spaces"
        shutil.copytree(ROOT / "scripts", self.project / "scripts", ignore=shutil.ignore_patterns("__pycache__"))
        for name in ("alire.toml", "diary.gpr", "Makefile", "README.md", "LICENSE", ".gitattributes"):
            shutil.copy2(ROOT / name, self.project / name)
        for name in ("apps", "packages", "tests"):
            shutil.copytree(ROOT / name, self.project / name, ignore=shutil.ignore_patterns("obj", "alire", "__pycache__"))
        (self.project / "bin").mkdir()
        (self.project / "bin/diary").write_bytes(Path("/bin/true").read_bytes())
        (self.project / "bin/diary").chmod(0o755)
        for name in ("domain_tests", "editor_tests", "codec_tests"):
            (self.project / "bin" / name).symlink_to("diary")
        for name in ("run_storage_tests.py", "tui_smoke.py"):
            (self.project / "tests" / name).write_text("pass\n")
        dependency = self.project / "alire/cache/pins/malef_79b20b6b"
        (dependency / "src").mkdir(parents=True)
        (dependency / "LICENSE").write_text("Malef GPL-3.0-or-later\n")
        (dependency / "src/example.ads").write_text("package Example is end Example;\n")
        (self.project / "scripts/prepare_malef.py").write_text("pass\n")
        self.tools = self.directory / "tools"
        self.tools.mkdir()
        (self.tools / "alr").write_text(
            '#!/usr/bin/env bash\n'
            'printf "%s\\n" "$*" >> "$RELEASE_TEST_LOG"\n'
            'if [[ -n "${RELEASE_TEST_FAIL:-}" && "$*" == *"$RELEASE_TEST_FAIL"* ]]; then exit 42; fi\n'
        )
        (self.tools / "alr").chmod(0o755)
        self.log = self.directory / "commands.log"
        self.environment = {
            **os.environ,
            "PATH": str(self.tools) + os.pathsep + os.environ["PATH"],
            "RELEASE_TEST_LOG": str(self.log),
        }
        self.output = self.directory / "output with spaces"

    def run_release(self, *arguments, environment=None, umask=-1):
        return subprocess.run(
            ["bash", str(self.project / "scripts/release.sh"), *arguments],
            cwd=self.directory,
            env={**self.environment, **(environment or {})},
            text=True,
            capture_output=True,
            timeout=60,
            umask=umask,
        )

    def test_help_does_not_run_toolchain(self):
        result = self.run_release("--help")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("--bundle-only", result.stdout)
        self.assertFalse(self.log.exists())

    def test_invalid_arguments_fail_before_toolchain(self):
        for arguments in (("--version", "../bad"), ("--unknown",), ("--output",), ("--version", "1.0.0\n")):
            with self.subTest(arguments=arguments):
                result = self.run_release(*arguments)
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse(self.log.exists())

    def test_failure_stops_before_bundling(self):
        result = self.run_release(
            "--output", str(self.output), "--bundle-only",
            environment={"RELEASE_TEST_FAIL": "gnatformat -P"},
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("build --release --", self.log.read_text())
        self.assertFalse(list(self.output.glob("*.tar.gz")))

    def test_relative_output_is_resolved_from_the_calling_directory(self):
        result = self.run_release("--output", "relative output", "--bundle-only")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(len(list((self.directory / "relative output").glob("*.tar.gz"))), 2)

    def test_restrictive_umask_does_not_make_installed_directories_private(self):
        result = self.run_release("--output", str(self.output), "--bundle-only", umask=0o077)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        binary_archive = next(path for path in self.output.glob("*.tar.gz") if "source" not in path.name)
        with tarfile.open(binary_archive) as archive:
            directories = [member for member in archive.getmembers() if member.isdir()]
            self.assertTrue(all(member.mode & 0o055 == 0o055 for member in directories))

    def test_bundle_contains_payload_sources_and_valid_checksums(self):
        result = self.run_release("--output", str(self.output), "--bundle-only")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        archives = list(self.output.glob("*.tar.gz"))
        self.assertEqual(len(archives), 2)
        binary_archive = next(path for path in archives if "source" not in path.name)
        with tarfile.open(binary_archive) as archive:
            names = archive.getnames()
            self.assertTrue(any(name.endswith("/bin/diary") for name in names))
            self.assertTrue(any(name.endswith("/LICENSE") for name in names))
            self.assertFalse(any("domain_tests" in name for name in names))
        source_archive = next(path for path in archives if "source" in path.name)
        with tarfile.open(source_archive) as archive:
            names = archive.getnames()
            self.assertTrue(any("dependencies/malef/src/example.ads" in name for name in names))
            self.assertTrue(any(name.endswith("/scripts/prepare_malef.py") for name in names))
            self.assertFalse(any("/obj/" in name or "/bin/" in name for name in names))
            manifest_name = next(name for name in names if name.count("/") == 1 and name.endswith("/alire.toml"))
            self.assertIn('malef = { path = "dependencies/malef" }', archive.extractfile(manifest_name).read().decode())
        manifests = list(self.output.glob("*SHA256SUMS"))
        self.assertEqual(len(manifests), 1)
        for line in manifests[0].read_text().splitlines():
            expected, name = line.split("  ", 1)
            self.assertEqual(hashlib.sha256((self.output / name).read_bytes()).hexdigest(), expected)
        self.assertIn("-O2", self.log.read_text())
        self.assertFalse(list(self.output.glob("*.deb")))

    def test_missing_packager_fails_before_formatting(self):
        (self.tools / "otool").symlink_to("/bin/true")
        (self.tools / "uname").write_text('#!/usr/bin/env bash\nif [[ "$1" == -s ]]; then echo Darwin; else echo arm64; fi\n')
        (self.tools / "uname").chmod(0o755)
        result = self.run_release("--output", str(self.output))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("pkgbuild", result.stderr)
        self.assertFalse(self.log.exists())

    @unittest.skipUnless(shutil.which("dpkg-deb") and shutil.which("rpmbuild"), "Native Linux packagers are required")
    def test_native_packages_accept_prerelease_versions_with_hyphens(self):
        result = self.run_release("--output", str(self.output), "--version", "1.2.3-rc.1-alpha")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        package = next(self.output.glob("*.deb"))
        version = subprocess.check_output(["dpkg-deb", "--field", str(package), "Version"], text=True).strip()
        self.assertEqual(version, "1.2.3~rc.1-alpha")
        self.assertEqual(len(list(self.output.glob("*.rpm"))), 1)

    def test_dependency_patch_uses_host_terminal_constants_and_stdin_symbol(self):
        dependency = self.project / "alire/cache/pins/malef_79b20b6b"
        shutil.rmtree(dependency)
        dependency = self.project / "dependencies/malef"
        fixtures = {
            "drawing/malef-groups.ads": "",
            "widgets/malef-styles.ads": "",
            "widgets/malef-styles-classes.ads": "",
            "widgets/malef-styles-sheets.ads": "",
            "drawing/malef-window.adb": "",
            "drawing/malef-palettes.adb": "",
            "private/malef-groups-composers.adb": "",
            "subsystems/ansi/posix/__malef-platform-terminal-input-implementation.c": "",
            "subsystems/ansi/posix/malef-platform-terminal-input-get_byte_immediate.adb": 'External_Name => "stdin";',
            "subsystems/ansi/malef-platform-terminal-input.adb": "TIOCGWINSZ : constant Interfaces.C.unsigned_long := 16#5413#;",
        }
        for name, text in fixtures.items():
            path = dependency / "src" / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text)
        shutil.copy2(ROOT / "scripts/prepare_malef.py", self.project / "scripts/prepare_malef.py")
        command = [
            "python3", "-c",
            "import runpy,sys,termios; sys.platform='darwin'; termios.TIOCGWINSZ=0x40087468; runpy.run_path(sys.argv[1])",
            str(self.project / "scripts/prepare_malef.py"),
        ]
        for attempt in range(2):
            result = subprocess.run(command, capture_output=True, text=True, timeout=5)
            self.assertEqual(result.returncode, 0, result.stderr)
            terminal = dependency / "src/subsystems/ansi/malef-platform-terminal-input.adb"
            self.assertIn("16#40087468#", terminal.read_text())
            reader = dependency / "src/subsystems/ansi/posix/malef-platform-terminal-input-get_byte_immediate.adb"
            self.assertIn('External_Name => "__stdinp"', reader.read_text())


if __name__ == "__main__":
    unittest.main()
