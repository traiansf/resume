# Industry-oriented CV Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a third build target, `resume-industry.pdf`, produced from the same `resume.md` — a full-length CV re-weighted for an industry audience (publications reduced to a stats callout, teaching to a subject summary, academic minutiae dropped).

**Architecture:** Introduce a second visibility axis `industry_version` alongside the existing `short_version`, plus two new orthogonal tag idioms `[ACADEMIC]…[/ACADEMIC]` (hidden in industry) and `[INDUSTRY]…[/INDUSTRY]` (industry-only). Generalize the existing `[LONG]` Lua machinery into tag-parameterized helpers and run three independent resolution passes. Content is tagged additively in `resume.md`; the full and short outputs stay byte-identical.

**Tech Stack:** pandoc Lua filter (`filter.lua`), xelatex template, GNU Make, bash fixture tests.

---

## Background facts (read before starting)

- `filter.lua` currently exposes two relevant functions that this plan generalizes:
  - `normalize_long_paras(blocks)` — splits paragraphs whose first/last inline is an orphan `[LONG]`/`[/LONG]` (followed/preceded by a break) into standalone tag paragraphs.
  - `resolve_block_long(blocks)` — depth-counted resolution of standalone `[LONG]`/`[/LONG]` tag paragraphs; drops wrapped content when hiding, drops only the tags otherwise; warns to stderr on unmatched tags.
- The `Pandoc(doc)` entrypoint currently runs: `trim_lists_with_inline_long(resolve_block_long(normalize_long_paras(doc.blocks)))`, then a main loop, then a citation-rewrite walk.
- Two LONG-specific idioms are **out of scope for generalization** and must keep working unchanged: the inline-pill form (`[LONG]\n- a\n- b\n[/LONG]` in Skills/Programming Languages) handled in the main loop, and the in-list-trim form handled by `trim_lists_with_inline_long`. ACADEMIC/INDUSTRY are only ever used as standalone (or orphan-leading/trailing) block tags.
- The template (`template.tex:142`) renders `$tagline$` from frontmatter. Fixture tests render with `-t latex` and **no** template, so a tagline-swap test needs a minimal template file.
- Visibility truth table the implementation must satisfy:

  | Mode | `short_version` | `industry_version` | LONG | ACADEMIC | INDUSTRY |
  |------|------|------|------|------|------|
  | full | false | false | show | show | hide |
  | short | true | false | hide | show | hide |
  | industry | false | true | show | hide | show |

  So: LONG hidden when `short_version`; ACADEMIC hidden when `industry_version`; INDUSTRY hidden when **not** `industry_version`.

---

## Task 1: Refactor `[LONG]` machinery into tag-parameterized helpers (no behavior change)

**Files:**
- Modify: `filter.lua` (functions `normalize_long_paras`, `resolve_block_long`, and the head of `Pandoc`)

The existing fixture suite is the safety net: this task must leave all current tests green.

- [ ] **Step 1: Replace `normalize_long_paras` with a tag-parameterized version**

In `filter.lua`, replace the entire `normalize_long_paras` function (the `local function normalize_long_paras(blocks) ... end` block) with:

```lua
-- Pre-pass 1: split paragraphs whose leading inline is `[TAG]` (followed by
-- a soft/line break) or whose trailing inline is `[/TAG]` (preceded by one).
-- Paragraphs containing both tags or neither are passed through unchanged.
local function normalize_tag_paras(blocks, tag)
  local open_lit  = "[" .. tag .. "]"
  local close_lit = "[/" .. tag .. "]"
  local open_pat  = "%[" .. tag .. "%]"
  local close_pat = "%[/" .. tag .. "%]"
  local out = {}
  for _, b in ipairs(blocks) do
    local emitted = false
    if b.t == "Para" and #b.content > 0 then
      local inlines = b.content
      local n = #inlines
      local text = pandoc_utils.stringify(b)
      local has_open = text:find(open_pat) ~= nil
      local has_close = text:find(close_pat) ~= nil
      if has_open ~= has_close then
        local is_break = function(x)
          return x.t == "SoftBreak" or x.t == "LineBreak"
        end
        if has_open
            and n >= 2
            and inlines[1].t == "Str" and inlines[1].text == open_lit
            and is_break(inlines[2]) then
          table.insert(out, pandoc.Para({pandoc.Str(open_lit)}))
          local rest = {}
          for i = 3, n do table.insert(rest, inlines[i]) end
          if #rest > 0 then table.insert(out, pandoc.Para(rest)) end
          emitted = true
        elseif has_close
            and n >= 2
            and inlines[n].t == "Str" and inlines[n].text == close_lit
            and is_break(inlines[n-1]) then
          local rest = {}
          for i = 1, n - 2 do table.insert(rest, inlines[i]) end
          if #rest > 0 then table.insert(out, pandoc.Para(rest)) end
          table.insert(out, pandoc.Para({pandoc.Str(close_lit)}))
          emitted = true
        end
      end
    end
    if not emitted then table.insert(out, b) end
  end
  return out
end
```

- [ ] **Step 2: Replace `resolve_block_long` with a tag-parameterized version**

Replace the entire `resolve_block_long` function with:

```lua
-- Pre-pass 2: resolve standalone [TAG] / [/TAG] tag paragraphs.
-- Drops the wrapped blocks when `hide` is true; drops only the tag paragraphs
-- otherwise. Supports nesting via depth counting. Emits a stderr warning on
-- any unmatched tag (the integration test fails on these).
local function resolve_block_tag(blocks, tag, hide)
  local open_pat  = "%[" .. tag .. "%]"
  local close_pat = "%[/" .. tag .. "%]"
  local function is_tag(b, pat)
    if b.t ~= "Para" then return false end
    return pandoc_utils.stringify(b):match("^%s*" .. pat .. "%s*$") ~= nil
  end
  local out = {}
  local i = 1
  while i <= #blocks do
    local b = blocks[i]
    if is_tag(b, open_pat) then
      local depth = 1
      local j = i + 1
      while j <= #blocks do
        if is_tag(blocks[j], open_pat) then depth = depth + 1
        elseif is_tag(blocks[j], close_pat) then
          depth = depth - 1
          if depth == 0 then break end
        end
        j = j + 1
      end
      if j > #blocks then
        io.stderr:write("filter.lua: warning: unmatched [" .. tag .. "] tag\n")
      end
      if not hide then
        for k = i + 1, math.min(j - 1, #blocks) do
          table.insert(out, blocks[k])
        end
      end
      i = j + 1
    elseif is_tag(b, close_pat) then
      io.stderr:write("filter.lua: warning: orphan [/" .. tag .. "] tag (dropped)\n")
      i = i + 1
    else
      table.insert(out, b)
      i = i + 1
    end
  end
  return out
end
```

- [ ] **Step 3: Update the `Pandoc` entrypoint to call the renamed helpers (LONG only, for now)**

In `filter.lua`, find these lines near the top of `function Pandoc(doc)`:

```lua
  local blocks = trim_lists_with_inline_long(
                   resolve_block_long(normalize_long_paras(doc.blocks)))
```

Replace with:

```lua
  local blocks = normalize_tag_paras(doc.blocks, "LONG")
  blocks = resolve_block_tag(blocks, "LONG", short_version)
  blocks = trim_lists_with_inline_long(blocks)
```

- [ ] **Step 4: Run the full test suite to confirm no behavior change**

Run: `make test`
Expected: all fixtures PASS, including `resume:full` and `resume:short` integration checks. `Results: N passed, 0 failed`.

- [ ] **Step 5: Commit**

```bash
git add filter.lua
git commit -m "refactor(filter): generalize [LONG] machinery into tag-parameterized helpers

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: Extend the test runner to support an industry mode

**Files:**
- Modify: `tests/filter/run-tests.sh`

This adds industry-mode rendering and new-tag token scanning to the runner. No filter changes yet, so the integration check renders industry mode identically to full (resume.md has no industry tags yet) and stays green.

- [ ] **Step 1: Generalize `run_variant` to accept arbitrary pandoc metadata flags**

In `tests/filter/run-tests.sh`, replace the `run_variant` function:

```bash
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
```

with a version that takes the metadata flags as trailing arguments:

```bash
run_variant() {
  local name="$1" input="$2" expected="$3"; shift 3
  local actual
  actual=$(pandoc -L filter.lua "$@" -f markdown -t latex "$input" 2>/dev/null)
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
```

- [ ] **Step 2: Update the fixture loop to pass metadata flags and add an industry variant**

Replace the fixture loop:

```bash
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
```

with:

```bash
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
done
```

- [ ] **Step 3: Extend the integration check to cover industry mode and the new tag tokens**

Replace the entire integration-check block (from `if [[ -f resume.md ]]; then` through its closing `fi`):

```bash
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
```

with a three-mode version that also scans for ACADEMIC/INDUSTRY tokens:

```bash
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
    if printf '%s' "$out" | grep -qE "$tag_re"; then
      problems="${problems}literal [LONG]/[ACADEMIC]/[INDUSTRY] tag in output; "
    fi
    if printf '%s' "$err" | grep -qi "filter.lua: warning"; then
      problems="${problems}filter warning on stderr; "
    fi
    if [[ -n "$problems" ]]; then
      echo "FAIL  $label ($problems)"
      [[ -n "$err" ]] && printf '%s\n' "$err" | head -5
      printf '%s' "$out" | grep -nE "$tag_re" | head -5
      fail=$((fail+1))
      failed_names+=("$label")
    else
      echo "PASS  $label"
      pass=$((pass+1))
    fi
  done
fi
```

- [ ] **Step 4: Run the suite — confirm the new `resume:industry` integration line passes**

Run: `make test`
Expected: existing fixtures still PASS; a new `PASS  resume:industry` line appears; `Results: N passed, 0 failed`.

- [ ] **Step 5: Commit**

```bash
git add tests/filter/run-tests.sh
git commit -m "test(filter): add industry-mode rendering and tag scanning to runner

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: Implement the `[ACADEMIC]` tag (hidden in industry)

**Files:**
- Modify: `filter.lua` (head of `Pandoc`: add `industry_version`, ACADEMIC normalize+resolve passes)
- Create: `tests/filter/academic-standalone/input.md`
- Create: `tests/filter/academic-standalone/expected.tex`
- Create: `tests/filter/academic-standalone/expected-short.tex`
- Create: `tests/filter/academic-standalone/expected-industry.tex`

- [ ] **Step 1: Write the failing fixture**

Create `tests/filter/academic-standalone/input.md`:

```markdown
# Notes

Always visible.

[ACADEMIC]

Only in full and short.

[/ACADEMIC]

[LONG]
[ACADEMIC]

Full only (long and academic).

[/ACADEMIC]
[/LONG]

Always visible again.
```

Create `tests/filter/academic-standalone/expected.tex` (full: both academic blocks shown):

```latex
\hypertarget{notes}{%
\section{Notes}\label{notes}}

Always visible.

Only in full and short.

Full only (long and academic).

Always visible again.
```

Create `tests/filter/academic-standalone/expected-short.tex` (short: LONG-wrapped block gone, standalone ACADEMIC shown):

```latex
\hypertarget{notes}{%
\section{Notes}\label{notes}}

Always visible.

Only in full and short.

Always visible again.
```

Create `tests/filter/academic-standalone/expected-industry.tex` (industry: both ACADEMIC blocks gone):

```latex
\hypertarget{notes}{%
\section{Notes}\label{notes}}

Always visible.

Always visible again.
```

- [ ] **Step 2: Run the suite to verify the new fixture fails**

Run: `make test`
Expected: `FAIL academic-standalone:industry` (industry output still contains the academic text because the filter does not yet read `industry_version` or resolve `[ACADEMIC]`). The full/short variants may also fail because `[ACADEMIC]` tags are not yet stripped.

- [ ] **Step 3: Add `industry_version` and the ACADEMIC passes in `filter.lua`**

In `filter.lua`, add a module-level flag near the top, next to `local short_version = false`:

```lua
local short_version = false
local industry_version = false
```

Then in `function Pandoc(doc)`, find:

```lua
  if doc.meta and doc.meta.short_version then
    short_version = pandoc_utils.stringify(doc.meta.short_version) == "true"
  end
```

and add immediately after it:

```lua
  if doc.meta and doc.meta.industry_version then
    industry_version = pandoc_utils.stringify(doc.meta.industry_version) == "true"
  end
```

Then change the block-prep lines (added in Task 1):

```lua
  local blocks = normalize_tag_paras(doc.blocks, "LONG")
  blocks = resolve_block_tag(blocks, "LONG", short_version)
  blocks = trim_lists_with_inline_long(blocks)
```

to normalize all tags first, then resolve LONG and ACADEMIC:

```lua
  local blocks = normalize_tag_paras(doc.blocks, "LONG")
  blocks = normalize_tag_paras(blocks, "ACADEMIC")
  blocks = resolve_block_tag(blocks, "LONG", short_version)
  blocks = resolve_block_tag(blocks, "ACADEMIC", industry_version)
  blocks = trim_lists_with_inline_long(blocks)
```

- [ ] **Step 4: Run the suite to verify all variants pass**

Run: `make test`
Expected: `PASS academic-standalone`, `PASS academic-standalone:short`, `PASS academic-standalone:industry`, and all pre-existing tests still PASS. `Results: N passed, 0 failed`.

- [ ] **Step 5: Commit**

```bash
git add filter.lua tests/filter/academic-standalone
git commit -m "feat(filter): add [ACADEMIC] tag hidden in industry mode

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: Implement the `[INDUSTRY]` tag (industry-only)

**Files:**
- Modify: `filter.lua` (head of `Pandoc`: add INDUSTRY normalize+resolve passes)
- Create: `tests/filter/industry-standalone/input.md`
- Create: `tests/filter/industry-standalone/expected.tex`
- Create: `tests/filter/industry-standalone/expected-short.tex`
- Create: `tests/filter/industry-standalone/expected-industry.tex`

- [ ] **Step 1: Write the failing fixture**

Create `tests/filter/industry-standalone/input.md`:

```markdown
# Notes

Always visible.

[INDUSTRY]

Industry only.

[/INDUSTRY]

Always visible again.
```

Create `tests/filter/industry-standalone/expected.tex` (full: industry block hidden):

```latex
\hypertarget{notes}{%
\section{Notes}\label{notes}}

Always visible.

Always visible again.
```

Create `tests/filter/industry-standalone/expected-short.tex` (short: industry block hidden):

```latex
\hypertarget{notes}{%
\section{Notes}\label{notes}}

Always visible.

Always visible again.
```

Create `tests/filter/industry-standalone/expected-industry.tex` (industry: block shown):

```latex
\hypertarget{notes}{%
\section{Notes}\label{notes}}

Always visible.

Industry only.

Always visible again.
```

- [ ] **Step 2: Run the suite to verify the new fixture fails**

Run: `make test`
Expected: `FAIL industry-standalone` and `FAIL industry-standalone:short` (the `[INDUSTRY]` tags are not yet stripped, so the text leaks into full/short), and `FAIL industry-standalone:industry` (tags not stripped).

- [ ] **Step 3: Add the INDUSTRY passes in `filter.lua`**

In `function Pandoc(doc)`, update the block-prep section to also normalize and resolve INDUSTRY (hidden when **not** industry):

```lua
  local blocks = normalize_tag_paras(doc.blocks, "LONG")
  blocks = normalize_tag_paras(blocks, "ACADEMIC")
  blocks = normalize_tag_paras(blocks, "INDUSTRY")
  blocks = resolve_block_tag(blocks, "LONG", short_version)
  blocks = resolve_block_tag(blocks, "ACADEMIC", industry_version)
  blocks = resolve_block_tag(blocks, "INDUSTRY", not industry_version)
  blocks = trim_lists_with_inline_long(blocks)
```

- [ ] **Step 4: Run the suite to verify all variants pass**

Run: `make test`
Expected: `PASS industry-standalone`, `PASS industry-standalone:short`, `PASS industry-standalone:industry`, and all earlier tests still PASS. `Results: N passed, 0 failed`.

- [ ] **Step 5: Commit**

```bash
git add filter.lua tests/filter/industry-standalone
git commit -m "feat(filter): add [INDUSTRY] tag shown only in industry mode

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: Industry tagline swap

**Files:**
- Modify: `filter.lua` (head of `Pandoc`: swap `tagline` when industry)
- Create: `tests/filter/tagline/input.md`
- Create: `tests/filter/tagline/template.tex`
- Modify: `tests/filter/run-tests.sh` (dedicated tagline assertion)

Fixtures render without a template, so this is tested with a minimal `$tagline$`-only template via a dedicated runner block rather than a normal `expected*.tex` diff.

- [ ] **Step 1: Create the tagline test fixture inputs**

Create `tests/filter/tagline/input.md`:

```markdown
---
tagline: "ACAD-TAGLINE"
tagline-industry: "IND-TAGLINE"
---

# Heading

Body text.
```

Create `tests/filter/tagline/template.tex` (a one-variable standalone template):

```latex
$tagline$
```

- [ ] **Step 2: Add a failing tagline assertion to the runner**

In `tests/filter/run-tests.sh`, immediately **before** the final `echo` / `echo "Results: ..."` lines at the bottom, insert:

```bash
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
  printf '%s' "$full_tl" | grep -q "ACAD-TAGLINE" || \
    tl_problems="${tl_problems}full mode lost academic tagline; "
  printf '%s' "$ind_tl" | grep -q "IND-TAGLINE" || \
    tl_problems="${tl_problems}industry mode did not swap tagline; "
  printf '%s' "$ind_tl" | grep -q "ACAD-TAGLINE" && \
    tl_problems="${tl_problems}industry mode still shows academic tagline; "
  if [[ -n "$tl_problems" ]]; then
    echo "FAIL  tagline-swap ($tl_problems)"
    fail=$((fail+1))
    failed_names+=("tagline-swap")
  else
    echo "PASS  tagline-swap"
    pass=$((pass+1))
  fi
fi
```

- [ ] **Step 3: Run the suite to verify the tagline assertion fails**

Run: `make test`
Expected: `FAIL tagline-swap (industry mode did not swap tagline; industry mode still shows academic tagline; )` — the filter does not yet swap the tagline.

- [ ] **Step 4: Implement the tagline swap in `filter.lua`**

In `function Pandoc(doc)`, immediately after the `industry_version` detection added in Task 3, insert:

```lua
  if industry_version and doc.meta and doc.meta["tagline-industry"] then
    doc.meta.tagline = doc.meta["tagline-industry"]
  end
```

- [ ] **Step 5: Run the suite to verify the tagline assertion passes**

Run: `make test`
Expected: `PASS tagline-swap`, all other tests still PASS. `Results: N passed, 0 failed`.

- [ ] **Step 6: Commit**

```bash
git add filter.lua tests/filter/tagline tests/filter/run-tests.sh
git commit -m "feat(filter): swap in tagline-industry frontmatter for industry mode

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: Tag `resume.md` content for the industry version

**Files:**
- Modify: `resume.md`

All edits are additive tagging. After this task the integration check (Task 2) guarantees no tag leaks and no filter warnings in any of the three modes.

- [ ] **Step 1: Add the `tagline-industry` frontmatter field**

In `resume.md`, in the YAML frontmatter, after the `tagline:` line, add:

```yaml
tagline-industry: "Formal Methods for Software Correctness · Verification Engineer · Associate Professor"
```

(Final wording is the user's call; this is the spec's proposed value.)

- [ ] **Step 2: Add an industry-only teaching summary and wrap the course list in `[ACADEMIC]`**

In the `## Associate Professor of Computer Science` entry, replace the current detail block:

```markdown
[LONG]

Courses developed and taught, with all materials openly published:

- [Software Systems Modelling](https://traiansf.github.io/class/amss2025) — requirements analysis and modelling (UML, design patterns)
- [Declarative Programming](https://github.com/unibuc-cs/progdecl) — functional and declarative programming in Haskell
- [Concurrency in Programming Languages](https://github.com/unibuc-cs/iclp) — concurrency hands-on across Java, C++, Erlang/Elixir, JavaScript, and Python
- [Programming Languages Semantics](https://github.com/unibuc-cs/slp/tree/v2017) — operational semantics, interpreters, and type systems
- [Foundations of Programming Languages](https://github.com/unibuc-cs/flp) — theoretical incursion into semantics, lambda calculus, type systems, and logic programming
- [Program Verification](https://github.com/unibuc-cs/pv) — Hoare logic, weakest preconditions, separation logic, SAT/SMT solvers, symbolic execution, and model checking
- [Introduction to Machine Learning](https://github.com/unibuc-cs/dh-ml) — hands-on machine learning for non-computer-scientists (Master in Digital Humanities)

Supervise graduate students and serve on departmental committees.

[/LONG]
```

with:

```markdown
[INDUSTRY]

Designed and taught courses across software modelling, declarative & concurrent programming, programming-language semantics, program verification, and machine learning — all course materials openly published.

[/INDUSTRY]

[LONG]

[ACADEMIC]

Courses developed and taught, with all materials openly published:

- [Software Systems Modelling](https://traiansf.github.io/class/amss2025) — requirements analysis and modelling (UML, design patterns)
- [Declarative Programming](https://github.com/unibuc-cs/progdecl) — functional and declarative programming in Haskell
- [Concurrency in Programming Languages](https://github.com/unibuc-cs/iclp) — concurrency hands-on across Java, C++, Erlang/Elixir, JavaScript, and Python
- [Programming Languages Semantics](https://github.com/unibuc-cs/slp/tree/v2017) — operational semantics, interpreters, and type systems
- [Foundations of Programming Languages](https://github.com/unibuc-cs/flp) — theoretical incursion into semantics, lambda calculus, type systems, and logic programming
- [Program Verification](https://github.com/unibuc-cs/pv) — Hoare logic, weakest preconditions, separation logic, SAT/SMT solvers, symbolic execution, and model checking
- [Introduction to Machine Learning](https://github.com/unibuc-cs/dh-ml) — hands-on machine learning for non-computer-scientists (Master in Digital Humanities)

[/ACADEMIC]

Supervise graduate students and serve on departmental committees.

[/LONG]
```

- [ ] **Step 3: Wrap each Education entry's dissertation/advisor/committee detail in `[ACADEMIC]`**

For each of the three Education entries, nest an `[ACADEMIC]` pair just inside the existing `[LONG]` pair. PhD entry becomes:

```markdown
[LONG]
[ACADEMIC]
Dissertation: *A Rewriting Approach to Concurrent Programming Language Design and Semantics*

Advisor: Grigore Roșu

Committee: Thomas Ball, Darko Marinov, José Meseguer, Madhusudan Parthasarathy
[/ACADEMIC]
[/LONG]
```

Master entry becomes:

```markdown
[LONG]
[ACADEMIC]
Dissertation: *Institutional Concepts in First-Order Logic, Parameterized Specification Theory, and Logic Programming*

Advisors: Răzvan Diaconescu, Virgil Emil Căzănescu
[/ACADEMIC]
[/LONG]
```

Bachelor entry becomes:

```markdown
[LONG]
[ACADEMIC]
Dissertation: *Information Hiding in Text Using LR(k) Grammars*

Advisor: Adrian Atanasiu
[/ACADEMIC]
[/LONG]
```

- [ ] **Step 4: Wrap each early-career entry's detail in `[ACADEMIC]` (keep title/org/years)**

For each of these `[LONG]`-wrapped entries, move the `## Title` + `**Org, Years**` lines to sit between `[LONG]` and a new inner `[ACADEMIC]`, leaving only the descriptive paragraph(s) inside `[ACADEMIC]`. The seven entries are: *Postdoctoral Research Fellow* (Alexandru Ioan Cuza), *Postdoctoral Research Associate* (UIUC ITI), *Research Assistant* (UIUC FSL), *Teaching Assistant* (UBucharest), *Summer Intern* (Google), *Summer Intern* (Microsoft Research), and *Programmer* (Popnet-Agentscape).

Example — the Postdoctoral Research Fellow entry becomes:

```markdown
[LONG]

## Postdoctoral Research Fellow
**Alexandru Ioan Cuza University, Iași (FMSE Laboratory), 2011–2013**

[ACADEMIC]
Formal methods research in software engineering. Coordinated the team developing the K Framework.
[/ACADEMIC]

[/LONG]
```

Apply the identical pattern (move heading + org out of `[ACADEMIC]` but keep them inside `[LONG]`; wrap only the detail paragraph in `[ACADEMIC]`) to the other six entries:

- *Postdoctoral Research Associate* — detail: `Formal systems and verification research.`
- *Research Assistant* — detail: `Assisted in research on formal semantics, rewriting logic, and programming language design. Designed and prototyped (in Maude) the K semantic framework.`
- *Teaching Assistant* — detail: `Supported undergraduate courses in programming, discrete mathematics, and computer science theory.`
- *Summer Intern* (Google) — detail: `Co-authored a patent application on web traffic analysis methods (with Bogdan Căpriță).`
- *Summer Intern* (Microsoft Research) — detail: `Contributed an equality theory propagation core for the Zap automated theorem prover.`
- *Programmer* (Popnet-Agentscape) — detail: `Implemented classification algorithms for one of the first AI agents.`

Do **not** touch the Pi Squared, Runtime Verification, or ILDS co-founder entries — those stay full-detail in industry mode.

- [ ] **Step 5: Wrap the Top-20 publications list in `[ACADEMIC]`, keep the callout**

In the `# Publications` section, leave the `[CALLOUT] … [/CALLOUT]` stats block untouched. Inside the existing `[LONG] … [/LONG]` block that holds the "Top 20 by citations" intro and the numbered list, add an inner `[ACADEMIC]` pair so the structure is:

```markdown
[LONG]
[ACADEMIC]
Top 20 by citations (Google Scholar, May 2026). Full record: [Google Scholar](https://scholar.google.com/citations?user=QVLcUrcAAAAJ&hl=en) · [DBLP](https://dblp.org/pid/s/TFSerbanuta.html).

1. Roșu, Grigore and Traian Florin Șerbănuță. ...
...
20. Lucanu, Dorel, Traian Florin Șerbănuță, and Grigore Roșu. "K Framework Distilled." ... (cited by 25)

[/ACADEMIC]
[/LONG]
```

(Only the two new tag lines are added; the intro paragraph and all 20 entries are unchanged.)

- [ ] **Step 6: Run the suite to confirm no tag leaks or warnings in any mode**

Run: `make test`
Expected: all fixtures PASS, and `PASS resume:full`, `PASS resume:short`, `PASS resume:industry`. `Results: N passed, 0 failed`.

- [ ] **Step 7: Sanity-check the rendered industry body without building a PDF**

Run:
```bash
pandoc -L filter.lua --metadata industry_version=true -f markdown -t plain resume.md | grep -c "cited by"
```
Expected: `0` (the Top-20 list with its "cited by" badges is absent from industry mode).

Run:
```bash
pandoc -L filter.lua --metadata industry_version=true -f markdown -t plain resume.md | grep -i "Designed and taught courses across"
```
Expected: the industry teaching summary line is printed.

- [ ] **Step 8: Commit**

```bash
git add resume.md
git commit -m "content: tag resume.md for the industry-oriented CV variant

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: Add the `pdf-industry` build target

**Files:**
- Modify: `Makefile`

- [ ] **Step 1: Add `pdf-industry` to the `.PHONY` line and `help` text**

In `Makefile`, change the first line:

```makefile
.PHONY: pdf pdf-short clean help all check-deps test
```

to:

```makefile
.PHONY: pdf pdf-short pdf-industry clean help all check-deps test
```

In the `help` target, after the `make pdf-short` echo line, add:

```makefile
	@echo "  make pdf-industry - Generate industry-oriented resume (runs test first)"
```

- [ ] **Step 2: Add the `pdf-industry` target**

After the `pdf-short` target block (after its `@echo "Generated: resume-short.pdf"` line), add:

```makefile
pdf-industry: test resume.md filter.lua template.tex
	pandoc -L filter.lua \
		--template=template.tex \
		--metadata industry_version=true \
		--metadata short_version=false \
		-f markdown \
		-t pdf \
		--pdf-engine=xelatex \
		resume.md -o resume-industry.pdf
	@echo "Generated: resume-industry.pdf"
```

- [ ] **Step 3: Add the industry PDF to `all` and `clean`**

Change:

```makefile
clean:
	rm -f resume.pdf resume-short.pdf
```

to:

```makefile
clean:
	rm -f resume.pdf resume-short.pdf resume-industry.pdf
```

Change:

```makefile
all: pdf pdf-short
```

to:

```makefile
all: pdf pdf-short pdf-industry
```

- [ ] **Step 4: Build the industry PDF and confirm it is produced**

Run: `make pdf-industry`
Expected: tests run and pass, then `Generated: resume-industry.pdf`, and `resume-industry.pdf` exists.

- [ ] **Step 5: Verify the rendered PDF content with `pdftotext`**

Run:
```bash
pdftotext resume-industry.pdf - | grep -i "Formal Methods for Software Correctness"
```
Expected: the industry tagline is present.

Run:
```bash
pdftotext resume-industry.pdf - | grep -ic "An Overview of the K Semantic Framework"
```
Expected: `0` (the Top-20 publication titles are absent).

Run:
```bash
pdftotext resume-industry.pdf - | grep -i "articles"
```
Expected: the `55 articles · h-index 22 · 2106 citations` callout line is present.

- [ ] **Step 6: Confirm the full and short PDFs are unchanged in content**

Run: `make pdf pdf-short`
Expected: both build successfully. Spot-check that `pdftotext resume.pdf -` still contains "An Overview of the K Semantic Framework" (full version keeps the publication list).

- [ ] **Step 7: Commit**

```bash
git add Makefile
git commit -m "build: add pdf-industry target for the industry-oriented CV

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 8: Document the new mode in `CLAUDE.md`

**Files:**
- Modify: `CLAUDE.md` (project notes at repo root: `/home/traian/resume/CLAUDE.md`)

- [ ] **Step 1: Document the `pdf-industry` target in the Build section**

In `CLAUDE.md`, in the `## Build` code block, add after the `make pdf-short` line:

```
make pdf-industry  # industry-oriented full-length version
```

- [ ] **Step 2: Document the two new tags and the tagline field**

In the `## Markdown conventions` section, after the `[LONG] ... [/LONG]` bullet, add:

```markdown
- **`[ACADEMIC] ... [/ACADEMIC]`** — hide content in the *industry* version
  (`make pdf-industry`). Used for the publications list, detailed course list,
  and dissertation/advisor/committee detail. Same four source forms as
  `[LONG]`; nest inside `[LONG]` (`[LONG][ACADEMIC]…[/ACADEMIC][/LONG]`) for
  content that should appear only in the full version.

- **`[INDUSTRY] ... [/INDUSTRY]`** — show content *only* in the industry
  version (hidden in full and short). Used for the industry teaching summary.

- **`tagline-industry`** frontmatter field — replaces `tagline` when building
  the industry version.
```

- [ ] **Step 3: Update the filter-pipeline and visibility notes**

In the `## Filter pipeline (filter.lua)` section, update the description of passes 1–2 to note they are now tag-parameterized (`normalize_tag_paras`, `resolve_block_tag`) and run once per tag (`LONG`, `ACADEMIC`, `INDUSTRY`), with hide conditions: LONG hidden when `short_version`, ACADEMIC hidden when `industry_version`, INDUSTRY hidden when not `industry_version`.

- [ ] **Step 4: Note the industry mode in the Tests section**

In the `## Tests` section, update the integration-check description to state that `resume.md` is rendered in **three** modes (full, short, industry) and the check fails on any leftover `[LONG]`/`[ACADEMIC]`/`[INDUSTRY]` token or stderr warning. Mention that fixtures may include an optional `expected-industry.tex`.

- [ ] **Step 5: Verify the build still works and commit**

Run: `make test`
Expected: `Results: N passed, 0 failed`.

```bash
git add CLAUDE.md
git commit -m "docs: document industry CV mode, [ACADEMIC]/[INDUSTRY] tags

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Self-review notes

- **Spec coverage:** visibility model (Tasks 1,3,4), industry tagline (Task 5), publications stats-only (Task 6 step 5), teaching summary (Task 6 step 2), education trim (step 3), early-career trim (step 4), open-source unchanged (no task needed — already `[LONG]`, shown in industry), Makefile target (Task 7), tests + integration check (Tasks 2–5), docs (Task 8). All covered.
- **Type/name consistency:** `normalize_tag_paras(blocks, tag)` and `resolve_block_tag(blocks, tag, hide)` used identically across Tasks 1,3,4. `trim_lists_with_inline_long` retained verbatim. Metadata keys `short_version`, `industry_version`, `tagline-industry` consistent across filter, Makefile, tests, and resume.md.
- **Ordering:** all three `normalize_tag_paras` passes run before any `resolve_block_tag` pass; resolves run LONG → ACADEMIC → INDUSTRY; `trim_lists_with_inline_long` runs last — matching the existing pipeline contract that the main loop never sees a standalone tag paragraph.
```
