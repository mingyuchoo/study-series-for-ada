#!/usr/bin/env sh
set -eu
project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
gprbuild -P "$project_root/tools.gpr" "-aP$project_root/packages/tooling" diary_tools.adb -j0
