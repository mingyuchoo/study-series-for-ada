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

required_tools=(alr tar strip)
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
alr -n exec -- sh scripts/build_tools.sh
if [[ -z "$version" ]]; then
    version="$(./bin/tui_tools version alire.toml)"
fi
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z]+([.-][0-9A-Za-z]+)*)?$ ]] || fail 'Invalid version in alire.toml.'
mkdir -p -- "$output"
output="$(cd -- "$output" && pwd)"
workspace="$(mktemp -d "${TMPDIR:-/tmp}/tui_template-release.XXXXXXXX")"
trap 'rm -rf -- "$workspace"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
artifact_name="tui_template-$version-$platform-$architecture"
source_name="$artifact_name-source"
artifacts="$workspace/artifacts"
mkdir -p "$artifacts"

printf '\n[1/7] Preparing toolchain and dependencies\n'
alr -n exec -- sh -c 'command -v gnatformat >/dev/null 2>&1' || \
    fail 'Install GNATformat with alr install gnatformat_bin and add its bin directory to PATH.'
./bin/tui_tools prepare "$project_root" "$platform"
projects=(packages/*/*.gpr tui_template.gpr tools.gpr tests/tooling.gpr tests/patches.gpr tests/integration.gpr tests/release.gpr)
scenario=("-XMALEF_SYSTEM=$malef_system" -XMALEF_SUBSYSTEM=ansi -XMALEF_LIBRARY_TYPE=static)
alr -n build --release --stop-after=generation -- "${scenario[@]}"

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
for project in tools.gpr tests/tooling.gpr tests/patches.gpr tests/integration.gpr tests/release.gpr; do
    alr -n exec -- gprbuild -P "$project" "${scenario[@]}" -f -j0
done

printf '\n[5/7] Running unit and terminal tests\n'
./bin/tui_model_tests
./bin/tooling_tests
./bin/tooling_file_tests
./bin/patch_tests
if [[ "$system" == Linux ]]; then ./bin/release_tests; fi
./bin/tui_smoke

printf '\n[6/7] Staging portable and corresponding source bundles\n'
stage="$workspace/stage"
documentation="$stage/$prefix/share/doc/ada-tui-template"
mkdir -p "$stage/$prefix/bin" "$documentation" "$workspace/$artifact_name" "$workspace/$source_name"
cp bin/tui_template "$stage/$prefix/bin/tui_template"
chmod 755 "$stage/$prefix/bin/tui_template"
if [[ "$system" == Linux ]]; then
    strip "$stage/$prefix/bin/tui_template"
    ldd "$stage/$prefix/bin/tui_template" > "$workspace/dependencies.txt"
else
    strip -x "$stage/$prefix/bin/tui_template"
    otool -L "$stage/$prefix/bin/tui_template" > "$workspace/dependencies.txt"
fi
./bin/tui_tools validate-dependencies "$platform" "$workspace/dependencies.txt"
"$stage/$prefix/bin/tui_template" --help
cp README.md LICENSE "$documentation/"
cp "$workspace/dependencies.txt" "$documentation/runtime-dependencies.txt"
dependency=alire/cache/pins/malef_79b20b6b
if [[ -d dependencies/malef/src ]]; then dependency=dependencies/malef; fi
[[ -d "$dependency/src" ]] || fail 'Pinned Malef sources are missing.'
dependency_license="$(./bin/tui_tools license "$dependency")"
cp "$dependency_license" "$documentation/MALEF-LICENSE"
chmod 644 "$documentation/"*
cp -R "$stage/$prefix/." "$workspace/$artifact_name/"
tar -czf "$artifacts/$artifact_name.tar.gz" -C "$workspace" "$artifact_name"
tar -c --exclude=obj --exclude=bin --exclude=alire --exclude=config \
    apps packages scripts tests alire.toml tui_template.gpr tools.gpr Makefile README.md LICENSE .gitattributes | \
    tar -x -C "$workspace/$source_name"
mkdir -p "$workspace/$source_name/dependencies/malef"
tar -c --exclude=.git --exclude=obj --exclude=lib --exclude=alire -C "$dependency" . | \
    tar -x -C "$workspace/$source_name/dependencies/malef"
./bin/tui_tools pin-manifest "$workspace/$source_name/alire.toml"
tar -czf "$artifacts/$source_name.tar.gz" -C "$workspace" "$source_name"

printf '\n[7/7] Creating installers and SHA-256 manifest\n'
if [[ "$bundle_only" == false && "$system" == Linux ]]; then
    package_version="${version/-/\~}"
    libc_version="$(getconf GNU_LIBC_VERSION)"
    libc_version="${libc_version#glibc }"
    mkdir -p "$stage/DEBIAN"
    cat > "$stage/DEBIAN/control" <<EOF
Package: ada-tui-template
Version: $package_version
Section: utils
Priority: optional
Architecture: $architecture
Maintainer: Mingyu Choo <mingyuchoo@gmail.com>
Depends: libc6 (>= $libc_version)
Description: Ada terminal application template with Malef
 A starter workspace for UTF-8 terminal applications in Ada 2022.
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
    cat > "$rpm_root/SPECS/tui_template.spec" <<EOF
Name: ada-tui-template
Version: $rpm_version
Release: $rpm_release
Summary: Ada terminal application template with Malef
License: GPL-3.0-or-later
BuildArch: $rpm_architecture
%description
A starter workspace for UTF-8 terminal applications in Ada 2022.
%install
mkdir -p "%{buildroot}/usr"
cp -a "$stage/usr/." "%{buildroot}/usr/"
%files
%attr(0755,root,root) /usr/bin/tui_template
%dir /usr/share/doc/ada-tui-template
%attr(0644,root,root) /usr/share/doc/ada-tui-template/*
EOF
    rpmbuild -bb --define "_topdir $rpm_root" --define '_build_id_links none' \
        --define '_buildhost localhost' --define '__os_install_post %{nil}' "$rpm_root/SPECS/tui_template.spec"
    cp "$rpm_root/RPMS/$rpm_architecture/ada-tui-template-$rpm_version-$rpm_release.$rpm_architecture.rpm" \
        "$artifacts/$artifact_name.rpm"
elif [[ "$bundle_only" == false ]]; then
    pkgbuild --root "$stage" --identifier io.github.mingyuchoo.ada-tui-template \
        --version "${version%%-*}" --install-location / --ownership recommended \
        "$artifacts/$artifact_name.pkg"
fi
./bin/tui_tools checksums "$artifacts" "$artifact_name-SHA256SUMS"
cp "$artifacts/"* "$output/"
printf '\nRelease artifacts: %s\n' "$output"
