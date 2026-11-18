#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd -- "$project_root"

system="$(uname -s)"
case "$system" in
    Linux) malef_system=linux ;;
    Darwin) malef_system=unix ;;
    *)
        printf 'Unsupported host: %s. Use scripts/run.ps1 with WSL on Windows.\n' "$system" >&2
        exit 1
        ;;
esac
scenario=("-XMALEF_SYSTEM=$malef_system" -XMALEF_SUBSYSTEM=ansi)

for tool in alr; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        printf 'Required command not found: %s\n' "$tool" >&2
        exit 1
    fi
done

if ! alr exec -- sh -c 'command -v gnatformat >/dev/null 2>&1'; then
    printf '%s\n' \
        'GNATformat is required. Install it with: alr install gnatformat_bin' \
        'Then add "$HOME/.alire/bin" to PATH.' >&2
    exit 1
fi

printf '\n[1/5] Formatting Ada sources\n'
alr build --stop-after=pre-build -- "${scenario[@]}"
projects=(packages/*/*.gpr diary.gpr tools.gpr tests/tests.gpr tests/presentation.gpr tests/tooling.gpr tests/patches.gpr tests/integration.gpr tests/release.gpr)
for project in "${projects[@]}"; do
    alr exec -- gnatformat -P "$project" --no-subprojects -U --charset=utf-8 "${scenario[@]}"
done

printf '\n[2/5] Linting Ada sources\n'
for project in "${projects[@]}"; do
    alr exec -- gprbuild -P "$project" "${scenario[@]}" --subdirs=lint -c -f -u \
        -cargs:Ada -gnatc -gnatwa -gnatwe
done

printf '\n[3/5] Building\n'
alr build -- "${scenario[@]}"
for project in tools.gpr tests/tests.gpr tests/presentation.gpr tests/tooling.gpr tests/patches.gpr tests/integration.gpr tests/release.gpr; do
    alr exec -- gprbuild -P "$project" "${scenario[@]}" -j0
done

printf '\n[4/5] Testing\n'
./bin/domain_tests
./bin/editor_tests
./bin/calendar_commands_tests
./bin/codec_tests
./bin/tooling_tests
./bin/tooling_file_tests
./bin/patch_tests
./bin/run_storage_tests
./bin/release_tests
./bin/tui_smoke

printf '\n[5/5] Running diary\n'
exec ./bin/diary "$@"
