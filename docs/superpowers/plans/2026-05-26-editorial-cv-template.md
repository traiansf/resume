# Editorial CV Template Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace pandoc's default LaTeX-article styling with a custom "editorial" template (Playfair Display + Source Sans 3, burgundy accent, two-column item rows with right-aligned years, styled publication list) while keeping `resume.md` as the single source of truth and preserving the `make pdf` / `make pdf-short` dual-output workflow.

**Architecture:** Three pieces of work — (1) extend `filter.lua` so it emits semantic LaTeX (`\cvitem`, `\cites`, `callout` env, `\pill`) instead of pandoc's default block conversions for the affected sections; (2) write a new `template.tex` that pandoc consumes via `--template=`, defining typography, colors, the custom macros, and the page furniture; (3) wire it all into the `Makefile`. Source-of-truth content in `resume.md` changes only minimally — one new YAML field (`tagline`) and `[CALLOUT]…[/CALLOUT]` markers around the publication-summary paragraph.

**Tech Stack:** pandoc (Lua filters + custom LaTeX templates), XeLaTeX, `fontspec`, `xcolor`, `titlesec`, `enumitem`, `tcolorbox`, `tikz`. Fonts: Playfair Display + Source Sans 3 (installed from Google Fonts to `~/.local/share/fonts/`).

**Spec reference:** `docs/superpowers/specs/2026-05-26-editorial-cv-template-design.md`

---

## File Map

**Created:**
- `template.tex` — custom pandoc LaTeX template (typography, color, macros, header, footer)
- `tests/filter/run-tests.sh` — fixture-based runner for `filter.lua`
- `tests/filter/cvitem/input.md`, `tests/filter/cvitem/expected.tex`
- `tests/filter/cites/input.md`, `tests/filter/cites/expected.tex`
- `tests/filter/callout/input.md`, `tests/filter/callout/expected.tex`
- `tests/filter/skills/input.md`, `tests/filter/skills/expected.tex`
- `tests/filter/languages/input.md`, `tests/filter/languages/expected.tex`

**Modified:**
- `resume.md` — add `tagline` to front-matter; wrap publication-summary paragraph in `[CALLOUT]…[/CALLOUT]`
- `filter.lua` — extend with `\cvitem`, `\cites`, `callout`, `\pill`, languages-inline transformations
- `Makefile` — pass `--template=template.tex`; add `check-deps`, `test`, `install-fonts` targets

**Untouched:**
- `sources/` (Romanian/Europass legacy)
- All existing `[LONG]`/`[/LONG]` content semantics

---

## Task 1: Install Playfair Display and Source Sans 3 fonts

**Files:** none in the repo — installs to `~/.local/share/fonts/`

`fc-list` confirms neither font is installed, and they are not in Ubuntu Noble apt repos under the expected names. Install from Google Fonts (OFL-licensed). One-time setup.

- [ ] **Step 1: Download and install Playfair Display**

```bash
mkdir -p ~/.local/share/fonts/playfair-display
cd /tmp && curl -L -o playfair.zip \
  "https://fonts.google.com/download?family=Playfair+Display"
unzip -o playfair.zip -d /tmp/playfair-display
find /tmp/playfair-display -name "*.ttf" -exec cp {} ~/.local/share/fonts/playfair-display/ \;
```

- [ ] **Step 2: Download and install Source Sans 3**

```bash
mkdir -p ~/.local/share/fonts/source-sans-3
cd /tmp && curl -L -o source-sans-3.zip \
  "https://fonts.google.com/download?family=Source+Sans+3"
unzip -o source-sans-3.zip -d /tmp/source-sans-3
find /tmp/source-sans-3 -name "*.ttf" -exec cp {} ~/.local/share/fonts/source-sans-3/ \;
```

- [ ] **Step 3: Refresh the font cache and verify**

```bash
fc-cache -f ~/.local/share/fonts/
fc-list | grep -iE "Playfair Display|Source Sans 3" | head
```

Expected: at least one match for each family. If empty, the Google Fonts download may have hit a CAPTCHA — fall back to:

```bash
# Fallback A: clone the Google Fonts repo subset
git clone --depth 1 https://github.com/google/fonts.git /tmp/gfonts
mkdir -p ~/.local/share/fonts/{playfair-display,source-sans-3}
cp /tmp/gfonts/ofl/playfairdisplay/*.ttf ~/.local/share/fonts/playfair-display/
cp /tmp/gfonts/ofl/sourcesans3/*.ttf ~/.local/share/fonts/source-sans-3/
fc-cache -f ~/.local/share/fonts/
```

- [ ] **Step 4: Do not commit anything**

Fonts live in `~/.local/share/fonts/` — outside the repo. The repo's README/Makefile `help` target will document the dependency in a later task.

---

## Task 2: Add `check-deps` Makefile target

**Files:**
- Modify: `Makefile`

Make the missing-font failure mode explicit before any future build is attempted.

- [ ] **Step 1: Add the target**

Append to `Makefile`:

```make
check-deps:
	@command -v pandoc >/dev/null || { echo "ERROR: pandoc not installed"; exit 1; }
	@command -v xelatex >/dev/null || { echo "ERROR: xelatex not installed (apt install texlive-xetex)"; exit 1; }
	@command -v pdftotext >/dev/null || { echo "ERROR: pdftotext not installed (apt install poppler-utils)"; exit 1; }
	@fc-list | grep -qi "Playfair Display" || { echo "ERROR: Playfair Display font missing. See README."; exit 1; }
	@fc-list | grep -qi "Source Sans 3" || { echo "ERROR: Source Sans 3 font missing. See README."; exit 1; }
	@echo "All dependencies OK."
```

- [ ] **Step 2: Add `check-deps` to `.PHONY` line at top of Makefile**

Change:
```make
.PHONY: pdf pdf-short clean help all
```
to:
```make
.PHONY: pdf pdf-short clean help all check-deps test
```

(`test` is added now in anticipation of Task 7; saves a later edit.)

- [ ] **Step 3: Run it**

```bash
make check-deps
```

Expected: `All dependencies OK.`

- [ ] **Step 4: Commit**

```bash
git add Makefile
git commit -m "build: add check-deps target for pandoc/xelatex/fonts"
```

---

## Task 3: Add `tagline` to resume.md front-matter

**Files:**
- Modify: `resume.md:1-7`

- [ ] **Step 1: Edit the YAML block**

Replace lines 1-7 of `resume.md`:

```yaml
---
name: Traian Florin Șerbănuță
email: traian.serbanuta@unibuc.ro
phone: "+40 21 314 3508"
address: "Faculty of Mathematics and Informatics, University of Bucharest, Str. Academiei nr.14, Sector 1, Bucharest, Romania"
web: "http://cs.unibuc.ro/~tserbanuta"
tagline: "Associate Professor · Researcher in Formal Methods"
---
```

- [ ] **Step 2: Verify the existing build still works**

```bash
make pdf-short
```

Expected: succeeds (the new YAML key is ignored by the default template; no regression).

- [ ] **Step 3: Commit**

```bash
git add resume.md
git commit -m "content: add tagline metadata for editorial header"
```

---

## Task 4: Bootstrap minimal `template.tex` (smoke test only)

**Files:**
- Create: `template.tex`
- Modify: `Makefile`

Get the custom-template plumbing working end-to-end with the most basic LaTeX possible. No styling yet — we only need pandoc to feed the template and xelatex to produce a PDF.

- [ ] **Step 1: Create the minimal template**

`template.tex`:

```latex
\documentclass[11pt,a4paper]{article}

\usepackage[a4paper,top=20mm,bottom=20mm,left=22mm,right=22mm]{geometry}
\usepackage{fontspec}
\usepackage{xcolor}
\usepackage[hidelinks]{hyperref}

\pagestyle{empty}

\begin{document}

% --- Header (Task 6 will replace this with the styled version) ---
\noindent\textbf{\Huge $name$}\par
$if(tagline)$
\noindent\textit{$tagline$}\par
$endif$
\noindent $email$ \quad $phone$ \quad \url{$web$}\par
\vspace{8pt}\hrule\vspace{8pt}

% --- Body ---
$body$

\end{document}
```

- [ ] **Step 2: Update Makefile recipes**

In `Makefile`, change both `pdf` and `pdf-short` recipes to add `--template=template.tex` and depend on `template.tex`:

```make
pdf: resume.md filter.lua template.tex
	pandoc -L filter.lua \
		--template=template.tex \
		--metadata short_version=false \
		-f markdown \
		-t pdf \
		--pdf-engine=xelatex \
		resume.md -o resume.pdf
	@echo "Generated: resume.pdf"

pdf-short: resume.md filter.lua template.tex
	pandoc -L filter.lua \
		--template=template.tex \
		--metadata short_version=true \
		-f markdown \
		-t pdf \
		--pdf-engine=xelatex \
		resume.md -o resume-short.pdf
	@echo "Generated: resume-short.pdf"
```

- [ ] **Step 3: Build both versions**

```bash
make clean && make pdf pdf-short
```

Expected: both succeed; `resume.pdf` and `resume-short.pdf` exist.

- [ ] **Step 4: Verify content survived**

```bash
pdftotext resume.pdf - | head -5
pdftotext resume-short.pdf - | grep -c "Associate Professor"
```

Expected: first command shows the name and tagline; second prints `>=1`.

- [ ] **Step 5: Commit**

```bash
git add template.tex Makefile
git commit -m "build: wire custom pandoc template (smoke-test stage)"
```

---

## Task 5: Fonts, colors, and section title styling in template.tex

**Files:**
- Modify: `template.tex`

Replace the package block and add `titlesec` redefinition. Body still uses the placeholder header from Task 4.

- [ ] **Step 1: Replace template preamble**

Replace the entire preamble of `template.tex` (the lines from `\documentclass` through `\pagestyle{empty}`) with:

```latex
\documentclass[11pt,a4paper]{article}

\usepackage[a4paper,top=20mm,bottom=20mm,left=22mm,right=22mm]{geometry}

\usepackage{fontspec}
\setmainfont{Source Sans 3}[
  UprightFont = * Light,
  BoldFont    = * SemiBold,
  ItalicFont  = * Light Italic,
  BoldItalicFont = * SemiBold Italic,
]
\newfontfamily\headingfont{Playfair Display}

\usepackage{xcolor}
\definecolor{accent}{HTML}{7A1F1F}
\definecolor{bodytext}{HTML}{1A1A1A}
\definecolor{secondary}{HTML}{555555}
\definecolor{tertiary}{HTML}{444444}
\definecolor{calloutbg}{HTML}{FAF7F4}

\usepackage{titlesec}
\titleformat{\section}
  {\Large\itshape\headingfont\color{accent}}{}{0pt}{}
\titlespacing*{\section}{0pt}{16pt}{6pt}

\usepackage{enumitem}
\setlist{nosep,topsep=2pt,partopsep=0pt,leftmargin=*}

\usepackage[hidelinks]{hyperref}
\hypersetup{urlcolor=accent}

\pagestyle{empty}
```

- [ ] **Step 2: Build and verify**

```bash
make clean && make pdf
pdftotext resume.pdf - | head -20
```

Expected: build succeeds; text content still present. (Visual change — sections now in burgundy Playfair italic — will be confirmed by you visually in the final task.)

- [ ] **Step 3: Commit**

```bash
git add template.tex
git commit -m "style: load Playfair Display + Source Sans 3, define accent palette, style section titles"
```

---

## Task 6: Implement the styled header block

**Files:**
- Modify: `template.tex`

Replace the placeholder header (currently inside `\begin{document}`) with the editorial header: large Playfair name, italic burgundy tagline, secondary contact line, 2 pt burgundy rule.

- [ ] **Step 1: Replace the header block**

In `template.tex`, replace the lines from `% --- Header` through `\vspace{8pt}\hrule\vspace{8pt}` with:

```latex
% --- Header ---
\begingroup
  \setlength{\parindent}{0pt}
  {\headingfont\color{bodytext}\fontsize{30}{32}\selectfont $name$\par}
  \vspace{2pt}
  $if(tagline)$
    {\headingfont\itshape\color{accent}\fontsize{12}{14}\selectfont $tagline$\par}
    \vspace{4pt}
  $endif$
  {\color{secondary}\fontsize{9}{11}\selectfont
    $email$ \enspace$\cdot$\enspace $phone$ \enspace$\cdot$\enspace \url{$web$}\par}
  \vspace{8pt}
  {\color{accent}\rule{\linewidth}{2pt}\par}
  \vspace{8pt}
\endgroup
```

- [ ] **Step 2: Build and verify**

```bash
make clean && make pdf
pdftotext resume.pdf - | sed -n '1,5p'
```

Expected: line 1 is `Traian Florin Șerbănuță`; line 2 is `Associate Professor · Researcher in Formal Methods`; line 3 contains the email/phone/web.

- [ ] **Step 3: Commit**

```bash
git add template.tex
git commit -m "style: implement editorial header block (Playfair name, burgundy rule, tagline)"
```

---

## Task 7: Set up the filter test harness

**Files:**
- Create: `tests/filter/run-tests.sh`
- Modify: `Makefile`

Fixture-based regression tests for `filter.lua`. Each fixture is a directory under `tests/filter/` containing `input.md` and `expected.tex`. The runner feeds the markdown through pandoc with the filter and diffs the resulting LaTeX against the expected output. Cheap to write, prevents future regressions in the filter when Tasks 8–13 extend it.

- [ ] **Step 1: Create the runner**

`tests/filter/run-tests.sh`:

```bash
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
  if diff -u "$d/expected.tex" <(printf '%s\n' "$actual") > /tmp/diff.$$  2>&1; then
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
```

- [ ] **Step 2: Make it executable**

```bash
chmod +x tests/filter/run-tests.sh
```

- [ ] **Step 3: Add the `test` target to Makefile**

Append to `Makefile`:

```make
test:
	@./tests/filter/run-tests.sh
```

(The `test` entry in `.PHONY` was already added in Task 2.)

- [ ] **Step 4: Verify the runner works with zero fixtures**

```bash
make test
```

Expected: `Results: 0 passed, 0 failed`, exit 0.

- [ ] **Step 5: Commit**

```bash
git add tests/filter/run-tests.sh Makefile
git commit -m "test: add fixture-based filter test harness"
```

---

## Task 8: Extend filter.lua to emit `\cvitem` for Education and Experience

**Files:**
- Create: `tests/filter/cvitem/input.md`, `tests/filter/cvitem/expected.tex`
- Modify: `filter.lua`

Inside `# Education` and `# Experience` sections, the existing pattern is:

```markdown
## <Title>
**<Org>, <Years>**

<optional detail paragraphs and [LONG] blocks>
```

After this task, the filter consumes the H2 + the immediately-following `**Org, Years**` paragraph and emits one `\cvitem{Title}{Org}{Years}{Detail}` raw-LaTeX block. Detail is the concatenation of all subsequent body paragraphs up to the next H2 or H1, with `[LONG]` handling unchanged.

- [ ] **Step 1: Write the fixture**

`tests/filter/cvitem/input.md`:

```markdown
# Experience

## Associate Professor of Computer Science
**University of Bucharest, Faculty of Mathematics and Informatics, 2013–Present**

Supervise graduate students and serve on departmental committees.

## Consultant and Researcher
**Pi Squared, Inc., 2024–2026**
```

`tests/filter/cvitem/expected.tex`:

```latex
\section{Experience}\label{experience}

\cvitem{Associate Professor of Computer Science}{University of Bucharest,
Faculty of Mathematics and Informatics}{2013--Present}{Supervise graduate
students and serve on departmental committees.}

\cvitem{Consultant and Researcher}{Pi Squared, Inc.}{2024--2026}{}
```

(Pandoc's LaTeX writer collapses internal whitespace; the exact line wrapping above may differ. The runner does a literal diff — adjust the fixture to match pandoc's actual output after Step 4.)

- [ ] **Step 2: Run the test, watch it fail**

```bash
make test
```

Expected: `FAIL  cvitem` with a diff showing the current pandoc-default `\subsection{}` + `\textbf{}` output.

- [ ] **Step 3: Extend filter.lua**

Replace the contents of `filter.lua` with the version below. This rewrites the filter to use Pandoc's `Pandoc` walker for two purposes: section-aware `\cvitem` emission and the existing `[LONG]/[/LONG]` stripping.

```lua
-- filter.lua — see docs/superpowers/specs/2026-05-26-editorial-cv-template-design.md
local short_version = false
local section = nil   -- normalized name of the current H1 section
local pandoc_utils = pandoc.utils

local function normalize(s)
  return s:lower():gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
end

-- Split a "**Org, Years**" paragraph into org + years.
-- Returns nil if the paragraph isn't a single Strong containing the pattern.
local function split_org_years(block)
  if block.t ~= "Para" then return nil end
  if #block.content ~= 1 or block.content[1].t ~= "Strong" then return nil end
  local text = pandoc_utils.stringify(block.content[1])
  -- Match trailing ", YYYY[--YYYY|--Present]" or ", YYYY-YYYY"
  local org, years = text:match("^(.-),%s*(%d%d%d%d[%-–][%-–%w]*)$")
  if not org then
    org, years = text:match("^(.-),%s*(%d%d%d%d)$")
  end
  if not org then return nil end
  -- Normalize en-dash variants to LaTeX "--"
  years = years:gsub("[–%-]+", "--")
  return org, years
end

-- Render a list of blocks (the "detail" of a CV entry) as a LaTeX string.
-- Applies short_version stripping to [LONG] blocks inline.
local function render_detail(blocks)
  if #blocks == 0 then return "" end
  local doc = pandoc.Pandoc(blocks)
  -- Re-run the LONG filter on this slice.
  local cleaned = {}
  local in_long = false
  for _, b in ipairs(blocks) do
    if b.t == "Para" then
      local s = pandoc_utils.stringify(b)
      if s:find("%[LONG%]") and s:find("%[/LONG%]") then
        if short_version then
          local stripped = s:gsub("%[LONG%].*%[/LONG%]", "")
          if stripped:gsub("%s",""):len() > 0 then
            table.insert(cleaned, pandoc.Para(stripped))
          end
        else
          local stripped = s:gsub("%[LONG%]",""):gsub("%[/LONG%]","")
          if stripped:gsub("%s",""):len() > 0 then
            table.insert(cleaned, pandoc.Para(stripped))
          end
        end
      elseif s:find("%[LONG%]") then
        in_long = true
        if not short_version then
          local stripped = s:gsub("%[LONG%]","")
          if stripped:gsub("%s",""):len() > 0 then
            table.insert(cleaned, pandoc.Para(stripped))
          end
        end
      elseif s:find("%[/LONG%]") then
        in_long = false
      elseif in_long then
        if not short_version then table.insert(cleaned, b) end
      else
        table.insert(cleaned, b)
      end
    else
      if not in_long or not short_version then
        table.insert(cleaned, b)
      end
    end
  end
  if #cleaned == 0 then return "" end
  return pandoc.write(pandoc.Pandoc(cleaned), "latex")
end

local function is_cv_section()
  return section == "experience" or section == "education"
end

function Pandoc(doc)
  if doc.meta and doc.meta.short_version then
    short_version = pandoc_utils.stringify(doc.meta.short_version) == "true"
  end

  local blocks = doc.blocks
  local out = {}
  local i = 1
  while i <= #blocks do
    local b = blocks[i]

    -- Track current H1 section.
    if b.t == "Header" and b.level == 1 then
      section = normalize(pandoc_utils.stringify(b))
      table.insert(out, b)
      i = i + 1

    -- In CV sections, fold "## Title" + "**Org, Years**" + detail into \cvitem.
    elseif b.t == "Header" and b.level == 2 and is_cv_section() then
      local title = pandoc_utils.stringify(b)
      local next_b = blocks[i + 1]
      local org, years = next_b and split_org_years(next_b)
      if org then
        -- Collect detail blocks up to the next H2 or H1.
        local detail = {}
        local j = i + 2
        while j <= #blocks do
          local bj = blocks[j]
          if bj.t == "Header" and (bj.level == 1 or bj.level == 2) then break end
          table.insert(detail, bj)
          j = j + 1
        end
        local detail_tex = render_detail(detail):gsub("%s+$", "")
        local tex = string.format("\\cvitem{%s}{%s}{%s}{%s}",
          title, org, years, detail_tex)
        table.insert(out, pandoc.RawBlock("latex", tex))
        i = j
      else
        table.insert(out, b)
        i = i + 1
      end

    -- LONG-block stripping for non-CV sections (legacy behaviour).
    elseif b.t == "Para" then
      local text = pandoc_utils.stringify(b)
      if text:find("%[LONG%]") and text:find("%[/LONG%]") then
        if short_version then
          local s = text:gsub("%[LONG%].*%[/LONG%]", "")
          if s:gsub("%s",""):len() > 0 then table.insert(out, pandoc.Para(s)) end
        else
          local s = text:gsub("%[LONG%]",""):gsub("%[/LONG%]","")
          if s:gsub("%s",""):len() > 0 then table.insert(out, pandoc.Para(s)) end
        end
        i = i + 1
      elseif text:find("%[LONG%]") then
        if not short_version then
          local s = text:gsub("%[LONG%]","")
          if s:gsub("%s",""):len() > 0 then table.insert(out, pandoc.Para(s)) end
        end
        -- Consume blocks until [/LONG]
        local j = i + 1
        while j <= #blocks do
          local bj = blocks[j]
          if bj.t == "Para" then
            local sj = pandoc_utils.stringify(bj)
            if sj:find("%[/LONG%]") then
              j = j + 1
              break
            end
          end
          if not short_version then table.insert(out, bj) end
          j = j + 1
        end
        i = j
      else
        table.insert(out, b)
        i = i + 1
      end

    else
      table.insert(out, b)
      i = i + 1
    end
  end

  doc.blocks = out
  return doc
end
```

- [ ] **Step 4: Run the filter once, capture actual output, sync fixture**

The fixture in Step 1 is an approximation — pandoc's exact LaTeX whitespace is unpredictable. Sync by capturing reality:

```bash
pandoc -L filter.lua --metadata short_version=false \
  -f markdown -t latex tests/filter/cvitem/input.md \
  > tests/filter/cvitem/expected.tex
```

Then read `tests/filter/cvitem/expected.tex` and confirm it contains two `\cvitem{...}{...}{...}{...}` lines with the correct title/org/year fields. If it doesn't (e.g. `\cvitem` is missing or the year wasn't extracted), the lua filter has a bug — fix it before snapshotting.

- [ ] **Step 5: Run the test, confirm it passes**

```bash
make test
```

Expected: `PASS  cvitem`.

- [ ] **Step 6: Verify the full resume still builds**

```bash
make clean && make pdf pdf-short
```

Expected: both succeed. (The PDF currently lacks a `\cvitem` definition, so the macro will appear as raw `\cvitem{...}{...}{...}{...}` text — fine for now; Task 9 defines it.)

If xelatex errors with "Undefined control sequence \cvitem", define a temporary stub in `template.tex` for this commit only:

```latex
% Temporary — replaced by the styled macro in Task 9.
\providecommand{\cvitem}[4]{\textbf{#1} (#2, #3)\par #4\par\vspace{4pt}}
```

- [ ] **Step 7: Commit**

```bash
git add filter.lua tests/filter/cvitem/ template.tex
git commit -m "filter: emit \\cvitem for Education/Experience entries"
```

---

## Task 9: Define the styled `\cvitem` macro in template.tex

**Files:**
- Modify: `template.tex`

Implement the two-column row: item title (semibold), org (italic grey), detail (grey), with a right-aligned burgundy year column.

- [ ] **Step 1: Replace any `\providecommand{\cvitem}` stub with the real definition**

In `template.tex`, after the `\setlist{...}` line (or wherever you placed the stub), insert:

```latex
% \cvitem{title}{org}{years}{detail}
\newcommand{\cvitem}[4]{%
  \par\vspace{6pt}%
  \noindent
  \begin{minipage}[t]{0.82\linewidth}
    \raggedright
    {\fontseries{sb}\selectfont\color{bodytext}#1}\par
    {\itshape\color{secondary}#2}\par
    \ifx\relax#4\relax\else
      \vspace{1pt}{\color{tertiary}\small #4}%
    \fi
  \end{minipage}%
  \hfill
  \begin{minipage}[t]{0.16\linewidth}
    \raggedleft
    {\fontseries{sb}\selectfont\color{accent}#3}%
  \end{minipage}%
  \par
}
```

If you added the temporary `\providecommand` in Task 8, delete it now.

- [ ] **Step 2: Build and verify**

```bash
make clean && make pdf
pdftotext -layout resume.pdf - | sed -n '1,40p'
```

Expected: Education and Experience entries appear with year right-aligned (visible in `-layout` mode as separation between body text and year column).

- [ ] **Step 3: Run filter tests**

```bash
make test
```

Expected: `PASS  cvitem`.

- [ ] **Step 4: Commit**

```bash
git add template.tex
git commit -m "style: implement \\cvitem with right-aligned year column"
```

---

## Task 10: Mark the publication summary with `[CALLOUT]` and add the callout environment

**Files:**
- Create: `tests/filter/callout/input.md`, `tests/filter/callout/expected.tex`
- Modify: `resume.md`, `filter.lua`, `template.tex`

The summary paragraph at the top of `# Publications` (the 40-article / h-index / citation-count stats line and the next paragraph) should render inside a pale background callout box with a burgundy left rule.

- [ ] **Step 1: Add `[CALLOUT]` markers around the publication summary in `resume.md`**

Lines 117-124 of `resume.md` currently read:

```markdown
# Publications

- 40 articles indexed in Web of Science (43 in Scopus; 55 in Google Scholar)
- Hirsch index 13 in Web of Science (17 in Scopus; 22 in Google Scholar)
- 653 citations in Web of Science (1042 in Scopus; 2105 in Google Scholar)

[LONG]
The following are the 22 most-cited publications…
```

Replace with:

```markdown
# Publications

[CALLOUT]
- **40 articles** indexed in Web of Science (43 Scopus, 55 Google Scholar)
- **Hirsch index 13** (WoS) / 17 (Scopus) / **22 (Google Scholar)**
- **653 citations** (WoS) / 1042 (Scopus) / **2105 (Google Scholar)**
[/CALLOUT]

[LONG]
The following are the 22 most-cited publications…
```

- [ ] **Step 2: Write the filter fixture**

`tests/filter/callout/input.md`:

```markdown
# Publications

[CALLOUT]
- **40 articles** indexed in Web of Science
- h-index 22
[/CALLOUT]
```

After the next two steps, snapshot the actual filter output into `tests/filter/callout/expected.tex` the same way as Task 8.

- [ ] **Step 3: Extend `filter.lua` to handle `[CALLOUT]`**

In the `Pandoc(doc)` loop in `filter.lua`, before the `[LONG]` handling branch, add a branch for `[CALLOUT]`/`[/CALLOUT]`. The markers appear as their own paragraphs (single-line text). The simplest implementation: when a `Para` is exactly `[CALLOUT]`, emit `\begin{callout}` as a `RawBlock` and skip the paragraph; when a `Para` is exactly `[/CALLOUT]`, emit `\end{callout}`.

Insert this branch immediately before the existing `[LONG]` branch:

```lua
    elseif b.t == "Para" and pandoc_utils.stringify(b):match("^%s*%[CALLOUT%]%s*$") then
      table.insert(out, pandoc.RawBlock("latex", "\\begin{callout}"))
      i = i + 1
    elseif b.t == "Para" and pandoc_utils.stringify(b):match("^%s*%[/CALLOUT%]%s*$") then
      table.insert(out, pandoc.RawBlock("latex", "\\end{callout}"))
      i = i + 1
```

- [ ] **Step 4: Define the callout environment in `template.tex`**

In the preamble of `template.tex` (after the `\setlist{...}` block), add:

```latex
\usepackage{tcolorbox}
\tcbset{
  calloutbox/.style={
    enhanced, breakable,
    colback=calloutbg, colframe=accent,
    boxrule=0pt, leftrule=2.5pt,
    arc=0pt, outer arc=0pt,
    boxsep=4pt, left=10pt, right=10pt, top=4pt, bottom=4pt,
    before skip=4pt, after skip=8pt,
  }
}
\newenvironment{callout}{\begin{tcolorbox}[calloutbox]}{\end{tcolorbox}}
```

- [ ] **Step 5: Snapshot the fixture**

```bash
pandoc -L filter.lua --metadata short_version=false \
  -f markdown -t latex tests/filter/callout/input.md \
  > tests/filter/callout/expected.tex
```

Read the file and confirm it begins with `\section{Publications}` followed by `\begin{callout}`, the itemize, and `\end{callout}`.

- [ ] **Step 6: Run tests + build**

```bash
make test
make clean && make pdf pdf-short
pdftotext resume.pdf - | grep -c "40 articles"
```

Expected: tests pass; both builds succeed; the `40 articles` line is present.

- [ ] **Step 7: Commit**

```bash
git add resume.md filter.lua template.tex tests/filter/callout/
git commit -m "style: render publication summary in callout box"
```

---

## Task 11: Style the publication list (`\cites` macro + burgundy numbering)

**Files:**
- Create: `tests/filter/cites/input.md`, `tests/filter/cites/expected.tex`
- Modify: `filter.lua`, `template.tex`

The numbered publication list inside `# Publications` should render with burgundy semibold numbers, hanging indent, tight leading, and `(cited by N)` rewrapped as a burgundy `[N]` at the end of each entry.

- [ ] **Step 1: Write the fixture**

`tests/filter/cites/input.md`:

```markdown
# Publications

[LONG]
1. Roșu, G. and Șerbănuță, T.F. "An Overview of the K Semantic Framework." *JLAP* 79(6), 2010. (cited by 639)
2. Chen, F. et al. "jPredictor." *ICSE'08*. (cited by 154)
[/LONG]
```

Snapshot expected output in Step 5 below.

- [ ] **Step 2: Extend `filter.lua` to rewrap `(cited by N)`**

Add an inline-walker function to `filter.lua` that runs over every Para/Plain in a `# Publications` section and converts the trailing `(cited by N)` to a RawInline. The simplest place is a second pass: after the block-level rewrite, walk the result and apply the inline transformation only when `section == "publications"`.

Add this at the end of `filter.lua`, replacing the existing `return doc` at the bottom of `Pandoc(doc)`:

```lua
  -- Second pass: in Publications, rewrap "(cited by N)" as \cites{N}.
  local cur_section = nil
  local function rewrap_cites(el)
    if cur_section ~= "publications" then return nil end
    -- el is a Plain or Para; mutate its inlines list.
    local text = pandoc_utils.stringify(el)
    local n = text:match("%(cited by (%d+)%)%s*$")
    if not n then return nil end
    -- Strip the trailing "(cited by N)" from the last Str-ish inlines,
    -- then append a RawInline.
    -- Cheap approach: rebuild from text via inlines reader.
    local stripped = text:gsub("%s*%(cited by %d+%)%s*$", "")
    local doc_inline = pandoc.read(stripped, "markdown").blocks[1]
    if not doc_inline or not doc_inline.content then return nil end
    local new_inlines = doc_inline.content
    table.insert(new_inlines, pandoc.Space())
    table.insert(new_inlines, pandoc.RawInline("latex", "\\cites{"..n.."}"))
    if el.t == "Para" then return pandoc.Para(new_inlines) end
    return pandoc.Plain(new_inlines)
  end

  local result = pandoc.Pandoc(doc.blocks):walk{
    Header = function(h)
      if h.level == 1 then cur_section = normalize(pandoc_utils.stringify(h)) end
      return nil
    end,
    Para  = rewrap_cites,
    Plain = rewrap_cites,
  }
  doc.blocks = result.blocks
  return doc
```

- [ ] **Step 3: Define `\cites` and style the publication-list enumerate in `template.tex`**

In the preamble of `template.tex`, after the `\usepackage{enumitem}` block, add a `Publications`-scoped enumerate style by redefining the list environment locally. The cleanest LaTeX hook is to define a `publist` environment and let the filter wrap the enumerate; but pandoc emits a generic `enumerate`. Simpler: redefine the enumerate label color globally with low contrast for sections that don't use enumerate elsewhere — and our resume only uses an ordered list inside Publications.

Add to the preamble:

```latex
\setlist[enumerate,1]{
  label={\color{accent}\fontseries{sb}\selectfont\arabic*.},
  labelsep=8pt,
  leftmargin=24pt,
  itemsep=4pt,
  topsep=4pt,
}

\newcommand{\cites}[1]{\,{\color{accent}\fontseries{sb}\selectfont[#1]}}
```

- [ ] **Step 4: Snapshot the fixture**

```bash
pandoc -L filter.lua --metadata short_version=false \
  -f markdown -t latex tests/filter/cites/input.md \
  > tests/filter/cites/expected.tex
```

Read the file; confirm each enumerate item ends with `\cites{639}` / `\cites{154}` and the `(cited by N)` text is gone.

- [ ] **Step 5: Build and verify**

```bash
make test
make clean && make pdf
pdftotext resume.pdf - | grep -E "\[639\]" | head
```

Expected: `[639]` appears next to the K Framework paper.

- [ ] **Step 6: Commit**

```bash
git add filter.lua template.tex tests/filter/cites/
git commit -m "style: burgundy numbering + \\cites macro for publication list"
```

---

## Task 12: Render the Skills section as outlined pills

**Files:**
- Create: `tests/filter/skills/input.md`, `tests/filter/skills/expected.tex`
- Modify: `filter.lua`, `template.tex`

`# Skills` is currently a `BulletList`. After this task, the filter detects that section and replaces the bullet list with a single raw-LaTeX paragraph of `\pill{item} \pill{item} …`.

- [ ] **Step 1: Write the fixture**

`tests/filter/skills/input.md`:

```markdown
# Skills

- Formal methods and verification
- Programming language semantics
- Rewriting logic
```

- [ ] **Step 2: Extend `filter.lua` to convert Skills bullet lists into `\pill{}` sequences**

Inside the main `Pandoc(doc)` while-loop, add a branch that fires when `section == "skills"` and `b.t == "BulletList"`:

```lua
    elseif b.t == "BulletList" and section == "skills" then
      local parts = {}
      for _, item in ipairs(b.content) do
        local item_text = pandoc_utils.stringify(item):gsub("%s+", " ")
                                                      :gsub("^%s+", "")
                                                      :gsub("%s+$", "")
        if item_text ~= "" then
          table.insert(parts, "\\pill{" .. item_text .. "}")
        end
      end
      local line = table.concat(parts, "\\,\\,")
      table.insert(out, pandoc.RawBlock("latex", line))
      i = i + 1
```

Place this branch above the generic `else` at the end of the while-loop, but below the `[LONG]` handling. Also: a `BulletList` inside `# Skills` may be wrapped in a Para or appear directly — the AST emits `BulletList` directly, so this branch will catch it. The existing `[LONG]/[/LONG]` block-stripping must still skip the inner bullets when `short_version=true`; verify by running `make pdf-short` after Step 4.

- [ ] **Step 3: Define `\pill` in `template.tex`**

Add to the preamble after the `\setlist[enumerate,1]{…}` block:

```latex
\usepackage{tikz}
\newcommand{\pill}[1]{%
  \tikz[baseline=(t.base)]{
    \node[draw=accent, text=accent, line width=0.4pt,
          rounded corners=4pt,
          inner xsep=6pt, inner ysep=1.5pt,
          font=\small](t){#1};
  }%
}
```

- [ ] **Step 4: Snapshot, test, build**

```bash
pandoc -L filter.lua --metadata short_version=false \
  -f markdown -t latex tests/filter/skills/input.md \
  > tests/filter/skills/expected.tex
cat tests/filter/skills/expected.tex
make test
make clean && make pdf pdf-short
```

Expected: fixture contains `\pill{Formal methods and verification}\,\,\pill{...}`; tests pass; both PDFs build.

- [ ] **Step 5: Commit**

```bash
git add filter.lua template.tex tests/filter/skills/
git commit -m "style: render Skills as outlined burgundy pills"
```

---

## Task 13: Render Languages inline

**Files:**
- Create: `tests/filter/languages/input.md`, `tests/filter/languages/expected.tex`
- Modify: `filter.lua`

`# Languages` currently renders as a bullet list. After this task, the filter detects that section and emits one paragraph: `Romanian (native) · English (fluent) · French (basic)`, with the parenthetical level shown in grey.

- [ ] **Step 1: Write the fixture**

`tests/filter/languages/input.md`:

```markdown
# Languages

- Romanian (native)
- English (fluent)
- French (basic)
```

- [ ] **Step 2: Extend `filter.lua`**

Add a branch in the main loop similar to Skills, but emitting inline-joined items:

```lua
    elseif b.t == "BulletList" and section == "languages" then
      local parts = {}
      for _, item in ipairs(b.content) do
        local item_text = pandoc_utils.stringify(item):gsub("%s+"," ")
                                                      :gsub("^%s+",""):gsub("%s+$","")
        -- Grey out parenthetical "(level)"
        item_text = item_text:gsub("%s*%(([^)]+)%)$",
          " {\\color{secondary}\\small (%1)}")
        if item_text ~= "" then table.insert(parts, item_text) end
      end
      local line = table.concat(parts, " \\,$\\cdot$\\, ")
      table.insert(out, pandoc.RawBlock("latex", line))
      i = i + 1
```

- [ ] **Step 3: Snapshot, test, build**

```bash
pandoc -L filter.lua --metadata short_version=false \
  -f markdown -t latex tests/filter/languages/input.md \
  > tests/filter/languages/expected.tex
make test
make clean && make pdf
pdftotext resume.pdf - | grep -E "Romanian.*English.*French"
```

Expected: fixture is one RawBlock with all three languages joined by `\,$\cdot$\,`; tests pass; pdftotext shows them on a single line.

- [ ] **Step 4: Commit**

```bash
git add filter.lua tests/filter/languages/
git commit -m "style: render Languages inline with grey level qualifiers"
```

---

## Task 14: Footer (address on full version) + page numbers from page 2

**Files:**
- Modify: `template.tex`

- [ ] **Step 1: Add `fancyhdr` setup to the preamble**

In `template.tex`, after `\pagestyle{empty}`, add:

```latex
\usepackage{fancyhdr}
\fancypagestyle{cvfirst}{%
  \fancyhf{}%
  \renewcommand{\headrulewidth}{0pt}%
  \renewcommand{\footrulewidth}{0pt}%
  $if(short_version)$$else$%
  \fancyfoot[C]{\fontsize{7.5}{9}\selectfont\color{secondary}$address$}%
  $endif$%
}
\fancypagestyle{cvrest}{%
  \fancyhf{}%
  \renewcommand{\headrulewidth}{0pt}%
  $if(short_version)$$else$%
  \fancyfoot[C]{\fontsize{7.5}{9}\selectfont\color{secondary}$address$}%
  \fancyfoot[R]{\fontsize{8}{10}\selectfont\color{accent}\thepage}%
  $endif$%
}
```

- [ ] **Step 2: Replace `\pagestyle{empty}` with the new style**

In the same file, change `\pagestyle{empty}` to:

```latex
\AtBeginDocument{%
  \thispagestyle{cvfirst}%
  \pagestyle{cvrest}%
}
```

- [ ] **Step 3: Pass `short_version` and `address` to the template**

Pandoc forwards top-level metadata automatically. The YAML already has `address`. To make `short_version` available to the template (not only the filter), confirm both the `--metadata short_version=true|false` flags are present in the Makefile recipes — they are, from Task 4. No further change.

- [ ] **Step 4: Build and verify**

```bash
make clean && make pdf pdf-short
pdftotext resume.pdf - | tail -5
pdftotext resume-short.pdf - | tail -5
```

Expected: `resume.pdf` shows the address line at the bottom of each page (and a small burgundy page number from page 2 onward). `resume-short.pdf` does not.

- [ ] **Step 5: Commit**

```bash
git add template.tex
git commit -m "style: address footer (full only) and page numbers from page 2"
```

---

## Task 15: Final integration — visual review and Makefile help

**Files:**
- Modify: `Makefile`

- [ ] **Step 1: Update the Makefile `help` target to document the font dependency**

In `Makefile`, replace the `help` recipe with:

```make
help:
	@echo "Resume Build Targets:"
	@echo "  make check-deps - Verify pandoc, xelatex, fonts are installed"
	@echo "  make pdf        - Generate full resume (resume.pdf)"
	@echo "  make pdf-short  - Generate short resume (resume-short.pdf)"
	@echo "  make test       - Run filter regression tests"
	@echo "  make clean      - Remove generated PDFs"
	@echo ""
	@echo "First-time setup: install Playfair Display and Source Sans 3 fonts"
	@echo "from Google Fonts into ~/.local/share/fonts/ then run 'fc-cache -f'."
```

- [ ] **Step 2: Build clean, run full test suite**

```bash
make clean
make check-deps
make test
make pdf pdf-short
```

Expected: all succeed.

- [ ] **Step 3: Visual review**

Open both PDFs in a viewer:

```bash
xdg-open resume.pdf &
xdg-open resume-short.pdf &
```

Compared to the approved mockup, confirm by visual inspection:

- Name in Playfair Display, ~30 pt, dark grey
- Tagline below in burgundy italic Playfair
- 2 pt burgundy rule under contact line
- Section titles in burgundy italic Playfair, ~16 pt
- Education and Experience entries with right-aligned burgundy year column
- Publication summary inside pale callout box with burgundy left rule
- Publication list with burgundy numbers and `[N]` citation counts
- Skills as outlined burgundy pills
- Languages as a single inline line, levels in grey
- Full PDF: address in small grey at bottom of each page; page numbers in burgundy from page 2
- Short PDF: no address footer, [LONG] content stripped

If any item is off, file a follow-up note in the chat — do not silently re-tune; describe the deviation and ask whether to adjust.

- [ ] **Step 4: Commit Makefile help update**

```bash
git add Makefile
git commit -m "docs: update Makefile help with font setup instructions"
```

- [ ] **Step 5: Report**

Summarise to the user:
- Which tasks ran cleanly, which needed adjustment.
- Any deviation from the spec (and why).
- The two final PDFs ready to inspect.

---

## Self-Review Notes

Coverage of the spec sections:

- Typography (Playfair + Source Sans 3) — Task 1, 5.
- Color palette — Task 5.
- Page geometry — Task 5.
- Header block — Task 6.
- Section title — Task 5.
- `\cvitem` row — Tasks 8, 9.
- Publication callout — Task 10.
- Publication list + `\cites` — Task 11.
- Skill pills — Task 12.
- Languages inline — Task 13.
- Address footer + page numbers — Task 14.
- Filter test harness — Task 7.
- Makefile `check-deps`, `test`, help — Tasks 2, 15.
- Risks: font availability handled in Task 1+2; filter regex via fixture tests in 8/10/11/12/13; citation-count fallback (the inline walker simply returns nil if no `(cited by N)` is found, so missing suffix degrades gracefully — confirmed by the implementation in Task 11 Step 2).

Type / name consistency:

- `\cvitem{title}{org}{years}{detail}` — same 4-arg signature in Tasks 8 and 9.
- `\cites{N}` — defined in Task 11 Step 3, used by filter in Task 11 Step 2.
- `\pill{text}` — defined in Task 12 Step 3, used by filter in Task 12 Step 2.
- `callout` environment — defined in Task 10 Step 4, used by filter in Task 10 Step 3.
- Pandoc template variables `$name$`, `$tagline$`, `$email$`, `$phone$`, `$web$`, `$address$`, `$short_version$` — all present in `resume.md` YAML or passed via `--metadata`.

No placeholders, TODOs, or "implement later" markers in the plan above.
