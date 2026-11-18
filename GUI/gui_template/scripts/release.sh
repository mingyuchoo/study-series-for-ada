#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
platform=$(uname -s)

require_command() {
    command -v "$1" >/dev/null || {
        printf 'Required command missing: %s\n' "$1" >&2
        exit 1
    }
}

case "$platform" in
    Linux)
        for tool in dpkg dpkg-deb dpkg-shlibdeps; do require_command "$tool"; done
        ;;
    Darwin)
        for tool in productbuild plutil lipo; do require_command "$tool"; done
        ;;
    *)
        printf 'Unsupported platform: %s\n' "$platform" >&2
        exit 1
        ;;
esac
require_command alr
require_command gnatformat

version=$(sed -n 's/^version = "\([^"]*\)"$/\1/p' "$root/apps/counter_tk/alire.toml")
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]]; then
    printf 'Invalid application version: %s\n' "$version" >&2
    exit 1
fi

mkdir -p "$root/dist"
work=$(mktemp -d "$root/dist/.release.XXXXXXXX")
trap 'rm -rf -- "$work"' EXIT

app=apps/counter_tk
packages=(packages/counter_domain packages/counter_application)
for crate in "${packages[@]}" "$app"; do
    mkdir -p "$work/$crate"
    cp -R "$root/$crate/src" "$root/$crate/"*.gpr "$root/$crate/alire.toml" "$work/$crate/"
done
for package in "${packages[@]}"; do
    cp -R "$root/$package/tests" "$work/$package/"
done

cd "$work"
printf '\nFormatting Ada sources\n'
find packages apps -type f \( -name '*.adb' -o -name '*.ads' \) -exec gnatformat {} +

printf '\nLinting Ada sources\n'
for package in "${packages[@]}"; do
    (cd "$package" && alr -n exec -- gprbuild -P counter_tests.gpr -c -f -cargs:Ada -gnatwa -gnatwe)
done
(cd "$app" && alr -n exec -- gprbuild -P counter_tk.gpr -c -f -cargs:Ada -gnatwa -gnatwe)

printf '\nBuilding the release executable\n'
(cd "$app" && alr -n build --release)

printf '\nRunning tests\n'
for package in "${packages[@]}"; do
    (cd "$package" && alr -n exec -- gprbuild -P counter_tests.gpr && alr -n exec -- ./bin/test_counter)
done
backend="$work/$app/bin/counter_tk"
response=$(printf 'increment\nreset\n' | "$backend")
[[ "$response" == $'0\n1\n0' ]] || {
    printf 'Unexpected counter backend output: %s\n' "$response" >&2
    exit 1
}

bundle_linux() {
    local architecture dependencies
    architecture=$(dpkg --print-architecture)
    mkdir -p debian bundle/DEBIAN bundle/usr/bin bundle/usr/lib/counter-tk \
        bundle/usr/share/applications bundle/usr/share/doc/counter-tk
    printf 'Source: counter-tk\n\nPackage: counter-tk\nArchitecture: any\n' > debian/control
    install -m 755 "$backend" bundle/usr/lib/counter-tk/counter_tk
    dependencies=$(dpkg-shlibdeps -O -e bundle/usr/lib/counter-tk/counter_tk)
    dependencies=${dependencies#shlibs:Depends=}
    install -m 644 "$root/$app/ui/counter.tcl" bundle/usr/lib/counter-tk/counter.tcl
    install -m 644 "$root/LICENSE" bundle/usr/share/doc/counter-tk/copyright
    cat > bundle/usr/bin/counter-tk <<'LAUNCHER'
#!/bin/sh
exec wish /usr/lib/counter-tk/counter.tcl /usr/lib/counter-tk/counter_tk
LAUNCHER
    chmod 755 bundle/usr/bin/counter-tk
    cat > bundle/usr/share/applications/counter-tk.desktop <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=Counter
Exec=counter-tk
Terminal=false
Categories=Utility;
DESKTOP
    cat > bundle/DEBIAN/control <<CONTROL
Package: counter-tk
Version: ${version/-/\~}
Architecture: $architecture
Maintainer: MINGYUCHOO <mingyuchoo@gmail.com>
Depends: tk${dependencies:+, $dependencies}
Section: utils
Priority: optional
Description: Ada desktop counter with a Tcl/Tk interface
CONTROL
    artifact="counter-tk_${version}_${architecture}.deb"
    dpkg-deb --root-owner-group --build bundle "$artifact"
}

bundle_macos() {
    local contents=bundle/Counter.app/Contents architecture
    architecture=$(lipo -archs "$backend")
    architecture=${architecture// /-}
    mkdir -p "$contents/MacOS" "$contents/Resources"
    install -m 755 "$backend" "$contents/MacOS/counter_tk"
    install -m 644 "$root/$app/ui/counter.tcl" "$contents/Resources/counter.tcl"
    install -m 644 "$root/LICENSE" "$contents/Resources/LICENSE"
    cat > "$contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Counter</string>
    <key>CFBundleIdentifier</key><string>com.mingyuchoo.counter</string>
    <key>CFBundleExecutable</key><string>Counter</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${version%%-*}</string>
    <key>CFBundleVersion</key><string>${version%%-*}</string>
</dict>
</plist>
PLIST
    plutil -lint "$contents/Info.plist"
    cat > "$contents/MacOS/Counter" <<'LAUNCHER'
#!/bin/sh
directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd) || exit 1
for wish in /opt/homebrew/opt/tcl-tk/bin/wish /usr/local/opt/tcl-tk/bin/wish; do
    if [ -x "$wish" ]; then
        exec "$wish" "$directory/../Resources/counter.tcl" "$directory/counter_tk"
    fi
done
exec /usr/bin/wish "$directory/../Resources/counter.tcl" "$directory/counter_tk"
LAUNCHER
    chmod 755 "$contents/MacOS/Counter"
    artifact="counter-tk-${version}-macos-${architecture}.pkg"
    productbuild --component bundle/Counter.app /Applications "$artifact"
}

printf '\nBundling and building the installer\n'
case "$platform" in
    Linux) bundle_linux ;;
    Darwin) bundle_macos ;;
esac
mv -f "$artifact" "$root/dist/$artifact"
printf 'Installer: %s\n' "$root/dist/$artifact"
