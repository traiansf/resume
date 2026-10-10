#!/usr/bin/env bash
# Fixture-based tests for filter.lua.
#
# Each subdirectory under tests/filter/ is one test:
#   input.md            — required, the markdown input
#   expected.tex        — optional, expected LaTeX for the FULL version
#   expected-short.tex  — optional, expected LaTeX for the SHORT version
#   expected-industry.tex — optional, expected LaTeX for the INDUSTRY version
#   expected.html / expected-short.html — optional, expected HTML (web build)
#
# Diffs ignore CR line endings (Windows checkouts) and the
# \hypertarget{id}{% ... } wrapper that older pandoc versions put around
# section headings (newer ones emit the bare \section{...}\label{...}).
#
# A directory must provide at least one expected.* file. If both are present,
# both modes are exercised. The test name reported is "<dir>" for the full
# variant and "<dir>:short" for the short variant.

set -euo pipefail
cd "$(dirname "$0")/../.."

pass=0
fail=0
failed_names=()

normalize() {
  tr -d '\r' | sed '/^\\hypertarget{[^}]*}{%$/{N;s/^\\hypertarget{[^}]*}{%\n\(.*\)}$/\1/;}'
}

run_variant() {
  local name="$1" input="$2" expected="$3"; shift 3
  local actual to=latex
  [[ "$expected" == *.html ]] && to=html5
  actual=$(pandoc -L filter.lua "$@" -f markdown -t "$to" "$input" 2>/dev/null)
  if diff -u <(normalize < "$expected") <(printf '%s\n' "$actual" | normalize) \
       > /tmp/diff.$$ 2>&1; then
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
    run_variant "$name" "$d/input.md" "$d/expected.tex" \
      --metadata short_version=false
  fi
  if [[ -f "$d/expected-short.tex" ]]; then
    run_variant "$name:short" "$d/input.md" "$d/expected-short.tex" \
      --metadata short_version=true
  fi
  if [[ -f "$d/expected-industry.tex" ]]; then
    run_variant "$name:industry" "$d/input.md" "$d/expected-industry.tex" \
      --metadata short_version=false --metadata industry_version=true
  fi
  # HTML (web build) variants.
  if [[ -f "$d/expected.html" ]]; then
    run_variant "$name:html" "$d/input.md" "$d/expected.html" \
      --metadata short_version=false
  fi
  if [[ -f "$d/expected-short.html" ]]; then
    run_variant "$name:html-short" "$d/input.md" "$d/expected-short.html" \
      --metadata short_version=true
  fi
done

# Integration check: render the real resume.md in both modes and confirm:
#   1. the output contains no literal [LONG] / [/LONG] tags
#   2. the filter emits no warnings to stderr (catches unbalanced tags,
#      typos like </LONG>, etc. — classes of regression that have bitten us)
if [[ -f resume.md ]]; then
  declare -a int_modes=(
    "resume:full|--metadata short_version=false"
    "resume:short|--metadata short_version=true"
    "resume:industry|--metadata short_version=false --metadata industry_version=true"
  )
  tag_re='\[/?(LONG|ACADEMIC|INDUSTRY)\]'
  for entry in "${int_modes[@]}"; do
    label="${entry%%|*}"; metaflags="${entry#*|}"
    err_file=$(mktemp)
    out=$(pandoc -L filter.lua $metaflags -f markdown -t latex resume.md 2>"$err_file")
    err=$(cat "$err_file"); rm -f "$err_file"
    problems=""
    # Strip LaTeX brace-escaping ({[} / {]}) before scanning: pandoc escapes
    # [ and ] to {[} and {]} in LaTeX output, so a leaked [TAG] appears as
    # {[}TAG{]}. Removing braces lets the same regex catch both forms.
    if printf '%s' "$out" | tr -d '{}' | grep -qE "$tag_re"; then
      problems="${problems}literal [LONG]/[ACADEMIC]/[INDUSTRY] tag in output; "
    fi
    if printf '%s' "$err" | grep -qi "filter.lua: warning"; then
      problems="${problems}filter warning on stderr; "
    fi
    if [[ -n "$problems" ]]; then
      echo "FAIL  $label ($problems)"
      [[ -n "$err" ]] && printf '%s\n' "$err" | head -5
      printf '%s' "$out" | tr -d '{}' | grep -nE "$tag_re" | head -5
      fail=$((fail+1))
      failed_names+=("$label")
    else
      echo "PASS  $label"
      pass=$((pass+1))
    fi
  done
fi

# Tagline swap check: industry mode substitutes `tagline-industry` for the
# template's $tagline$ variable; full mode keeps the academic tagline.
if [[ -f tests/filter/tagline/input.md ]]; then
  tl_in="tests/filter/tagline/input.md"
  tl_tmpl="tests/filter/tagline/template.tex"
  full_tl=$(pandoc -L filter.lua --metadata short_version=false \
              --template="$tl_tmpl" -t latex "$tl_in" 2>/dev/null)
  ind_tl=$(pandoc -L filter.lua --metadata industry_version=true \
              --template="$tl_tmpl" -t latex "$tl_in" 2>/dev/null)
  tl_problems=""
  if printf '%s' "$full_tl" | grep -q "ACAD-TAGLINE"; then
    :
  else
    tl_problems="${tl_problems}full mode lost academic tagline; "
  fi
  if printf '%s' "$ind_tl" | grep -q "IND-TAGLINE"; then
    :
  else
    tl_problems="${tl_problems}industry mode did not swap tagline; "
  fi
  if printf '%s' "$ind_tl" | grep -q "ACAD-TAGLINE"; then
    tl_problems="${tl_problems}industry mode still shows academic tagline; "
  fi
  if [[ -n "$tl_problems" ]]; then
    echo "FAIL  tagline-swap ($tl_problems)"
    fail=$((fail+1))
    failed_names+=("tagline-swap")
  else
    echo "PASS  tagline-swap"
    pass=$((pass+1))
  fi
fi

echo
echo "Results: $pass passed, $fail failed"
[[ $fail -eq 0 ]]
