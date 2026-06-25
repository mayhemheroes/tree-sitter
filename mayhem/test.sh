#!/usr/bin/env bash
#
# mayhem/test.sh — RUN the functional oracle for tree-sitter (built by mayhem/build.sh).
#
# Known-answer test: /mayhem/ts_selftest parses a fixed JSON document with the vendored
# tree-sitter-json grammar and prints the syntax tree's s-expression. We assert that output equals
# the golden string — so this checks real PARSING BEHAVIOR, not just an exit code. A patch that
# neuters the program to exit(0) (or breaks the parser) produces a different/empty tree and FAILS.
set -uo pipefail
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH
cd "$SRC"

SELFTEST="$SRC/ts_selftest"
GOLDEN='(document (array (number) (true) (string (string_content)) (null)))'

# emit_ctrf <tool> <passed> <failed> [skipped] [pending] [other]
emit_ctrf() {
  local tool="$1" passed="$2" failed="$3" skipped="${4:-0}" pending="${5:-0}" other="${6:-0}"
  local tests=$(( passed + failed + skipped + pending + other ))
  cat > "${CTRF_REPORT:-$SRC/ctrf-report.json}" <<JSON
{
  "results": {
    "tool": { "name": "$tool" },
    "summary": {
      "tests": $tests,
      "passed": $passed,
      "failed": $failed,
      "pending": $pending,
      "skipped": $skipped,
      "other": $other
    }
  }
}
JSON
  printf 'CTRF {"results":{"tool":{"name":"%s"},"summary":{"tests":%d,"passed":%d,"failed":%d,"pending":%d,"skipped":%d,"other":%d}}}\n' \
    "$tool" "$tests" "$passed" "$failed" "$pending" "$skipped" "$other"
  [ "$failed" -eq 0 ]
}

if [ ! -x "$SELFTEST" ]; then
  echo "test.sh: $SELFTEST missing — mayhem/build.sh did not produce the oracle binary" >&2
  emit_ctrf tree-sitter-json-kat 0 1
  exit 1
fi

got="$("$SELFTEST" 2>/dev/null)"
echo "expected: $GOLDEN"
echo "got:      $got"

if [ "$got" = "$GOLDEN" ]; then
  emit_ctrf tree-sitter-json-kat 1 0
else
  emit_ctrf tree-sitter-json-kat 0 1
fi
