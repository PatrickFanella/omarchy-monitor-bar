#!/usr/bin/env bash
# SPDX-License-Identifier: MIT

set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"
readonly OMARCHY_SHELL_DIR="/usr/share/omarchy/shell"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'validate.sh: required command not found: %s\n' "$1" >&2
    exit 127
  fi
}

for command_name in git node python3 qmllint omarchy; do
  require_command "$command_name"
done

if [[ ! -d "$OMARCHY_SHELL_DIR" ]]; then
  printf 'validate.sh: Omarchy shell directory not found: %s\n' "$OMARCHY_SHELL_DIR" >&2
  printf 'Run this check on the supported Omarchy system with package 4.0.1-1 installed.\n' >&2
  exit 1
fi

readonly PYCACHE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/monitor-bar-pycache.XXXXXX")"
trap 'rm -rf -- "$PYCACHE_DIR"' EXIT
export PYTHONPYCACHEPREFIX="$PYCACHE_DIR"

cd -- "$REPO_ROOT"

node tests/test_model.mjs
node tests/test_bar_model.mjs
python3 -m unittest discover -s tests -p 'test_*.py'
python3 -m py_compile tools/*.py tests/*.py
python3 tools/sync_stock_bar.py --check
python3 tools/sync_stock_bar.py --upstream-dir vendor/omarchy-4.0.1-1/bar --check
qmllint -I "$OMARCHY_SHELL_DIR" ./*.qml
omarchy plugin validate .
python3 -c 'import json, pathlib; json.loads(pathlib.Path("manifest.json").read_text(encoding="utf-8"))'
git diff --check

printf 'All release checks passed.\n'
