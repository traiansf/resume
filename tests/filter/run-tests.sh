#!/usr/bin/env bash
# Fixture-based tests for filter.lua.
# Each subdirectory under tests/filter/ with input.md + expected.tex is a test.

set -euo pipefail
cd "$(dirname "$0")/../.."

pass=0
fail=0
failed_names=()

for d in tests/filter/*/; do
  name=$(basename "$d")
  [[ -f "$d/input.md" && -f "$d/expected.tex" ]] || continue
  actual=$(pandoc -L filter.lua --metadata short_version=false \
             -f markdown -t latex "$d/input.md")
  if diff -u "$d/expected.tex" <(printf '%s\n' "$actual") > /tmp/diff.$$ 2>&1; then
    echo "PASS  $name"
    pass=$((pass+1))
  else
    echo "FAIL  $name"
    cat /tmp/diff.$$
    fail=$((fail+1))
    failed_names+=("$name")
  fi
  rm -f /tmp/diff.$$
done

echo
echo "Results: $pass passed, $fail failed"
[[ $fail -eq 0 ]]
