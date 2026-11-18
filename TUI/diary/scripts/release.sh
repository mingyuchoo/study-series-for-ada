#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
output="$project_root/dist"
version=''
bundle_only=false

fail() {
    printf 'Release failed: %s\n' "$*" >&2
    exit 1
}

usage() {
    printf '%s\n' \
        'Usage: scripts/release.sh [--version VERSION] [--output DIRECTORY] [--bundle-only]' \
        'Formats, lints, builds, tests, bundles, and creates native installers.' \
        'Linux: .tar.gz, source .tar.gz, .deb, .rpm, SHA256SUMS.' \
        'macOS: .tar.gz, source .tar.gz, .pkg, SHA256SUMS.' \
        '--bundle-only runs all checks and builds archives without native installers.'
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h) usage; exit 0 ;;
        --version|--output)
            [[ $# -ge 2 && -n "$2" && "$2" != --* ]] || fail "Missing value for $1"
            if [[ "$1" == --version ]]; then version="$2"; else output="$2"; fi
            shift 2
            ;;
        --bundle-only) bundle_only=true; shift ;;
        *) fail "Unknown argument: $1" ;;
    esac
done

if [[ -n "$version" && ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z]+([.-][0-9A-Za-z]+)*)?$ ]]; then
    fail 'Version must be MAJOR.MINOR.PATCH with an optional prerelease suffix.'
fi

system="$(uname -s)"
case "$system" in
    Linux) platform=linux; malef_system=linux; prefix=usr ;;
    Darwin) platform=macos; malef_system=unix; prefix=usr/local ;;
    *) fail "Unsupported host: $system. Use release.ps1 on Windows 11." ;;
esac
case "$(uname -m)" in
    x86_64|amd64) architecture=amd64; rpm_architecture=x86_64 ;;
    aarch64|arm64) architecture=arm64; rpm_architecture=aarch64 ;;
    *) fail 'Only x86-64 and ARM64 hosts are supported.' ;;
esac

required_tools=(alr python3 tar strip)
if [[ "$system" == Linux ]]; then
    required_tools+=(ldd getconf)
    if [[ "$bundle_only" == false ]]; then required_tools+=(dpkg-deb rpmbuild); fi
else
    required_tools+=(otool)
    if [[ "$bundle_only" == false ]]; then required_tools+=(pkgbuild); fi
fi
for tool in "${required_tools[@]}"; do
    command -v "$tool" >/dev/null 2>&1 || fail "Required command not found: $tool"
done

umask 022
if [[ "$output" != /* ]]; then output="$PWD/$output"; fi
cd -- "$project_root"
if [[ -z "$version" ]]; then
    version="$(python3 -c 'import re; from pathlib import Path; print(re.search(r"(?m)^version\s*=\s*\"([^\"]+)\"", Path("alire.toml").read_text())[1])')"
fi
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z]+([.-][0-9A-Za-z]+)*)?$ ]] || fail 'Invalid version in alire.toml.'
mkdir -p -- "$output"
output="$(cd -- "$output" && pwd)"
workspace="$(mktemp -d "${TMPDIR:-/tmp}/diary-release.XXXXXXXX")"
trap 'rm -rf -- "$workspace"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
artifact_name="diary-$version-$platform-$architecture"
source_name="$artifact_name-source"
artifacts="$workspace/artifacts"
mkdir -p "$artifacts"

printf '\n[1/7] Preparing toolchain and dependencies\n'
alr -n exec -- sh -c 'command -v gnatformat >/dev/null 2>&1' || \
    fail 'Install GNATformat with alr install gnatformat_bin and add its bin directory to PATH.'
alr -n exec -- python3 scripts/prepare_malef.py
projects=(packages/*/*.gpr diary.gpr tests/tests.gpr)
scenario=("-XMALEF_SYSTEM=$malef_system" -XMALEF_SUBSYSTEM=ansi -XMALEF_LIBRARY_TYPE=static)

printf '\n[2/7] Formatting Ada sources\n'
for project in "${projects[@]}"; do
    alr -n exec -- gnatformat -P "$project" --no-subprojects -U --charset=utf-8 "${scenario[@]}"
done

printf '\n[3/7] Linting Ada sources\n'
for project in "${projects[@]}"; do
    alr -n exec -- gprbuild -P "$project" "${scenario[@]}" --subdirs=lint -c -f -u \
        -cargs:Ada -gnatc -gnatwa -gnatwe
done

printf '\n[4/7] Building optimized application and tests\n'
alr -n build --release -- "${scenario[@]}" -f -j0 \
    -cargs:Ada -O2 -gnatn -bargs -static -largs -static-libgcc
alr -n exec -- gprbuild -P tests/tests.gpr "${scenario[@]}" -f -j0

printf '\n[5/7] Running unit, storage, and terminal tests\n'
./bin/domain_tests
./bin/editor_tests
./bin/codec_tests
python3 tests/run_storage_tests.py
python3 tests/tui_smoke.py

printf '\n[6/7] Staging portable and corresponding source bundles\n'
stage="$workspace/stage"
documentation="$stage/$prefix/share/doc/ada-diary"
mkdir -p "$stage/$prefix/bin" "$documentation" "$workspace/$artifact_name" "$workspace/$source_name"
cp bin/diary "$stage/$prefix/bin/diary"
chmod 755 "$stage/$prefix/bin/diary"
if [[ "$system" == Linux ]]; then
    strip "$stage/$prefix/bin/diary"
    ldd "$stage/$prefix/bin/diary" > "$workspace/dependencies.txt"
    python3 - "$workspace/dependencies.txt" <<'PY'
from pathlib import Path
import re
import sys

for line in Path(sys.argv[1]).read_text().splitlines():
    name = line.strip().split()[0]
    if not re.fullmatch(r"linux-vdso\.so\.\d+|lib(c|m|pthread|dl|rt)\.so\.\d+|/\S*/ld-linux[^/\s]*\.so\.[\d.]+", name):
        raise SystemExit(f"Unbundled runtime dependency: {line.strip()}")
    if "not found" in line:
        raise SystemExit(f"Missing runtime dependency: {line.strip()}")
PY
else
    strip -x "$stage/$prefix/bin/diary"
    otool -L "$stage/$prefix/bin/diary" > "$workspace/dependencies.txt"
    python3 - "$workspace/dependencies.txt" <<'PY'
from pathlib import Path
import sys

for line in Path(sys.argv[1]).read_text().splitlines()[1:]:
    if not line.strip().startswith(("/usr/lib/", "/System/Library/")):
        raise SystemExit(f"Unbundled runtime dependency: {line.strip()}")
PY
fi
"$stage/$prefix/bin/diary" --help
cp README.md LICENSE "$documentation/"
cp "$workspace/dependencies.txt" "$documentation/runtime-dependencies.txt"
dependency=alire/cache/pins/malef_79b20b6b
if [[ -d dependencies/malef/src ]]; then dependency=dependencies/malef; fi
[[ -d "$dependency/src" ]] || fail 'Pinned Malef sources are missing.'
dependency_license="$(python3 - "$dependency" <<'PY'
from pathlib import Path
import sys

root = Path(sys.argv[1])
for name in ("LICENSE", "LICENSE.txt", "COPYING", "LICENSE.md"):
    if (root / name).is_file():
        print(root / name)
        break
else:
    raise SystemExit("Malef license file is missing")
PY
)"
cp "$dependency_license" "$documentation/MALEF-LICENSE"
chmod 644 "$documentation/"*
cp -R "$stage/$prefix/." "$workspace/$artifact_name/"
tar -czf "$artifacts/$artifact_name.tar.gz" -C "$workspace" "$artifact_name"
tar -c --exclude=obj --exclude=bin --exclude=alire --exclude=__pycache__ \
    apps packages scripts tests alire.toml diary.gpr Makefile README.md LICENSE .gitattributes | \
    tar -x -C "$workspace/$source_name"
mkdir -p "$workspace/$source_name/dependencies/malef"
tar -c --exclude=.git --exclude=obj --exclude=lib --exclude=alire -C "$dependency" . | \
    tar -x -C "$workspace/$source_name/dependencies/malef"
python3 - "$workspace/$source_name/alire.toml" <<'PY'
from pathlib import Path
import re
import sys

manifest = Path(sys.argv[1])
source, count = re.subn(
    r'(?m)^malef = \{ (?:url|path) = .* \}$',
    'malef = { path = "dependencies/malef" }',
    manifest.read_text(),
)
if count != 1:
    raise SystemExit("Expected exactly one Malef pin in the source manifest")
manifest.write_text(source)
PY
tar -czf "$artifacts/$source_name.tar.gz" -C "$workspace" "$source_name"

printf '\n[7/7] Creating installers and SHA-256 manifest\n'
if [[ "$bundle_only" == false && "$system" == Linux ]]; then
    package_version="${version/-/\~}"
    libc_version="$(getconf GNU_LIBC_VERSION)"
    libc_version="${libc_version#glibc }"
    mkdir -p "$stage/DEBIAN"
    cat > "$stage/DEBIAN/control" <<EOF
Package: ada-diary
Version: $package_version
Section: utils
Priority: optional
Architecture: $architecture
Maintainer: Mingyu Choo <mingyuchoo@gmail.com>
Depends: libc6 (>= $libc_version)
Description: Local calendar diary with a Malef terminal interface
 A UTF-8 Ada 2022 terminal diary with Emacs and Helix keymaps.
EOF
    chmod 755 "$stage/DEBIAN"
    chmod 644 "$stage/DEBIAN/control"
    dpkg-deb --root-owner-group --build "$stage" "$artifacts/$artifact_name.deb"
    rpm_root="$workspace/rpm"
    mkdir -p "$rpm_root/BUILD" "$rpm_root/RPMS" "$rpm_root/SOURCES" "$rpm_root/SPECS" "$rpm_root/SRPMS"
    rpm_version="${version%%-*}"
    rpm_release=1
    if [[ "$version" == *-* ]]; then
        rpm_release="0.${version#*-}"
        rpm_release="${rpm_release//-/.}"
    fi
    cat > "$rpm_root/SPECS/diary.spec" <<EOF
Name: ada-diary
Version: $rpm_version
Release: $rpm_release
Summary: Local calendar diary with a Malef terminal interface
License: GPL-3.0-or-later
BuildArch: $rpm_architecture
%description
A UTF-8 Ada 2022 terminal diary with Emacs and Helix keymaps.
%install
mkdir -p "%{buildroot}/usr"
cp -a "$stage/usr/." "%{buildroot}/usr/"
%files
%attr(0755,root,root) /usr/bin/diary
%dir /usr/share/doc/ada-diary
%attr(0644,root,root) /usr/share/doc/ada-diary/*
EOF
    rpmbuild -bb --define "_topdir $rpm_root" --define '_build_id_links none' \
        --define '_buildhost localhost' --define '__os_install_post %{nil}' "$rpm_root/SPECS/diary.spec"
    cp "$rpm_root/RPMS/$rpm_architecture/ada-diary-$rpm_version-$rpm_release.$rpm_architecture.rpm" \
        "$artifacts/$artifact_name.rpm"
elif [[ "$bundle_only" == false ]]; then
    pkgbuild --root "$stage" --identifier io.github.mingyuchoo.ada-diary \
        --version "${version%%-*}" --install-location / --ownership recommended \
        "$artifacts/$artifact_name.pkg"
fi
python3 - "$artifacts" "$artifact_name-SHA256SUMS" <<'PY'
from pathlib import Path
import hashlib
import sys

directory = Path(sys.argv[1])
lines = [f"{hashlib.sha256(path.read_bytes()).hexdigest()}  {path.name}\n" for path in sorted(directory.iterdir())]
(directory / sys.argv[2]).write_text("".join(lines))
PY
cp "$artifacts/"* "$output/"
printf '\nRelease artifacts: %s\n' "$output"
