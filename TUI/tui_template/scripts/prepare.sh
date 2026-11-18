#!/usr/bin/env sh
set -eu
project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
sh "$project_root/scripts/build_tools.sh"
exec "$project_root/bin/tui_tools" prepare "$project_root"
