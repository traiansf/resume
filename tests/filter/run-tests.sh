#!/usr/bin/env bash
# Fixture-based tests for filter.lua.
#
# Each subdirectory under tests/filter/ is one test:
#   input.md            — required, the markdown input
#   expected.tex        — optional, expected LaTeX for the FULL version
#   expected-short.tex  — optional, expected LaTeX for the SHORT version
#
# A directory must provide at least one expected.* file. If both are present,
# both modes are exercised. The test name reported is "<dir>" for the full
# variant and "<dir>:short" for the short variant.

set -euo pipefail
cd "$(dirname "$0")/../.."

pass=0
fail=0
failed_names=()

run_variant() {
  local name="$1" input="$2" expected="$3" short_meta="$4"
  local actual
  actual=$(pandoc -L filter.lua --metadata "short_version=$short_meta" \
             -f markdown -t latex "$input" 2>/dev/null)
  if diff -u "$expected" <(printf '%s\n' "$actual") > /tmp/diff.$$ 2>&1; then
    echo "PASS  $name"
    pass=$((pass+1))
  else
    echo "FAIL  $name"
    cat /tmp/diff.$$
    fail=$((fail+1))
    failed_names+=("$name")
  fi
  rm -f /tmp/diff.$$
}

for d in tests/filter/*/; do
  name=$(basename "$d")
  [[ -f "$d/input.md" ]] || continue
  if [[ -f "$d/expected.tex" ]]; then
    run_variant "$name" "$d/input.md" "$d/expected.tex" "false"
  fi
  if [[ -f "$d/expected-short.tex" ]]; then
    run_variant "$name:short" "$d/input.md" "$d/expected-short.tex" "true"
  fi
done

# Integration check: render the real resume.md in both modes and confirm:
#   1. the output contains no literal [LONG] / [/LONG] tags
#   2. the filter emits no warnings to stderr (catches unbalanced tags,
#      typos like </LONG>, etc. — classes of regression that have bitten us)
if [[ -f resume.md ]]; then
  for mode in false true; do
    label=$([ "$mode" = "true" ] && echo "resume:short" || echo "resume:full")
    err_file=$(mktemp)
    out=$(pandoc -L filter.lua --metadata "short_version=$mode" \
            -f markdown -t latex resume.md 2>"$err_file")
    err=$(cat "$err_file"); rm -f "$err_file"
    problems=""
    if printf '%s' "$out" | grep -qE '\[/?LONG\]'; then
      problems="${problems}literal [LONG]/[/LONG] in output; "
    fi
    if printf '%s' "$err" | grep -qi "filter.lua: warning"; then
      problems="${problems}filter warning on stderr; "
    fi
    if [[ -n "$problems" ]]; then
      echo "FAIL  $label ($problems)"
      [[ -n "$err" ]] && printf '%s\n' "$err" | head -5
      printf '%s' "$out" | grep -nE '\[/?LONG\]' | head -5
      fail=$((fail+1))
      failed_names+=("$label")
    else
      echo "PASS  $label"
      pass=$((pass+1))
    fi
  done
fi

echo
echo "Results: $pass passed, $fail failed"
[[ $fail -eq 0 ]]
