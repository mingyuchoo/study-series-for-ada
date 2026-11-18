#!/usr/bin/env bash
set -euo pipefail

cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
root=$PWD
platform=$(uname -s)
app=apps/counter_tk
packages=(packages/counter_domain packages/counter_application)

case "$platform" in
    Linux|Darwin) ;;
    *)
        printf 'Run this script on Linux or macOS.\n' >&2
        exit 1
        ;;
esac

for tool in alr gnatformat; do
    if ! command -v "$tool" >/dev/null; then
        printf 'Required command missing: %s\n' "$tool" >&2
        exit 1
    fi
done

wish=$(command -v wish || true)
if [[ "$platform" == Darwin ]]; then
    for candidate in /opt/homebrew/opt/tcl-tk/bin/wish /usr/local/opt/tcl-tk/bin/wish; do
        if [[ -x "$candidate" ]]; then
            wish=$candidate
            break
        fi
    done
fi
if [[ -z "$wish" ]]; then
    printf 'Tcl/Tk is required. Install it and add wish to PATH.\n' >&2
    exit 1
fi

printf '\nFormatting Ada sources\n'
find apps/counter_tk/src apps/counter_windows/src \
    packages/counter_domain/src packages/counter_domain/tests \
    packages/counter_application/src packages/counter_application/tests \
    -type f \( -name '*.adb' -o -name '*.ads' \) -exec gnatformat --no-project {} +

printf '\nLinting Ada sources\n'
for package in "${packages[@]}"; do
    (cd "$package" && alr -n exec -- gprbuild -P counter_tests.gpr -c -f -cargs:Ada -gnatwa -gnatwe)
done
(cd "$app" && alr -n exec -- gprbuild -P counter_tk.gpr -c -f -cargs:Ada -gnatwa -gnatwe)

printf '\nBuilding the application\n'
(cd "$app" && alr -n build)

printf '\nRunning tests\n'
for package in "${packages[@]}"; do
    (cd "$package" && alr -n exec -- gprbuild -P counter_tests.gpr && alr -n exec -- ./bin/test_counter)
done

printf '\nLaunching Counter\n'
exec "$wish" "$root/$app/ui/counter.tcl" "$root/$app/bin/counter_tk"
