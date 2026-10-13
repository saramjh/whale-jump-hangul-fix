#!/bin/bash
set -euo pipefail
JUMP_REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
JUMP_TEST_TMP="$(mktemp -d)"
trap 'rm -rf "$JUMP_TEST_TMP"' EXIT
swiftc "$JUMP_REPO_ROOT/macos/InputPin.swift" "$JUMP_REPO_ROOT/macos/PinTests.swift" -o "$JUMP_TEST_TMP/pin-tests"
"$JUMP_TEST_TMP/pin-tests"
swiftc "$JUMP_REPO_ROOT/macos/InputPin.swift" "$JUMP_REPO_ROOT/macos/SessionDetector.swift" \
  "$JUMP_REPO_ROOT/macos/RemoteInputController.swift" "$JUMP_REPO_ROOT/macos/SessionTests.swift" \
  -o "$JUMP_TEST_TMP/session-tests"
"$JUMP_TEST_TMP/session-tests"
node --check "$JUMP_REPO_ROOT/extension/fix.js"
node --check "$JUMP_REPO_ROOT/extension/background.js"
python3 - "$JUMP_REPO_ROOT" <<'PY'
import json, sys
from pathlib import Path
r = Path(sys.argv[1]); m = json.loads((r / 'extension/manifest.json').read_text())
assert m['manifest_version'] == 3
assert set(m['permissions']) == {'activeTab', 'scripting'}
for item in m['content_scripts']:
    for f in item['js']: assert (r / 'extension' / f).is_file()
assert (r / 'extension' / m['background']['service_worker']).is_file()
print('PASS: extension syntax, manifest, scoped permissions')
PY
