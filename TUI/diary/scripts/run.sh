#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd -- "$project_root"

if [[ "$(uname -s)" != Linux ]]; then
    printf '%s\n' 'This application requires Linux. On Windows, use scripts/run.ps1 with WSL.' >&2
    exit 1
fi

for tool in alr python3; do
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
projects=(packages/*/*.gpr diary.gpr tests/tests.gpr)
for project in "${projects[@]}"; do
    alr exec -- gnatformat -P "$project" --no-subprojects -U --charset=utf-8
done

printf '\n[2/5] Linting Ada sources\n'
for project in "${projects[@]}"; do
    alr exec -- gprbuild -P "$project" --subdirs=lint -c -f -u \
        -cargs:Ada -gnatc -gnatwa -gnatwe
done

printf '\n[3/5] Building\n'
alr build
alr exec -- gprbuild -P tests/tests.gpr -j0

printf '\n[4/5] Testing\n'
./bin/domain_tests
./bin/editor_tests
./bin/codec_tests
python3 tests/run_storage_tests.py
python3 tests/tui_smoke.py

printf '\n[5/5] Running diary\n'
exec ./bin/diary "$@"
