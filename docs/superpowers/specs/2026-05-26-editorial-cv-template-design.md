---
name: editorial-cv-template-design
date: 2026-05-26
status: approved-pending-implementation
---

# Editorial CV Template — Design Spec

## Goal

Replace pandoc's default LaTeX-article styling for `resume.md` with a custom
"editorial" template that gives the CV a distinctive, professional look while
preserving the existing single-source / dual-output (full + short) workflow.

## Context

Today:

- `resume.md` is the single source of truth (YAML metadata + Markdown body).
- `filter.lua` strips `[LONG]…[/LONG]` blocks when `short_version=true`.
- `make pdf` / `make pdf-short` invoke pandoc → xelatex with default article
  styling. Output looks generic.

The user picked the **editorial** direction (mockup C) over classical-academic
and two-column-sidebar alternatives. The current source structure stays; only
the rendering pipeline gains a custom template and a richer filter.

## Visual design

### Typography

- **Display / section titles:** Playfair Display, weight 500, italic for
  section titles, roman for the name. Letter-spacing slightly tightened
  (`-0.01em`-equivalent).
- **Body:** Source Sans 3 (formerly Source Sans Pro), regular for prose,
  semibold for item titles. Both are free OFL fonts available via Google Fonts
  / `texlive-fonts-extra`.
- Tabular numerals for years and citation counts.

### Color

Single accent: deep burgundy `#7a1f1f`. Used for:

- Header rule under the name block (3 pt)
- Section titles (Playfair italic, ~16 pt)
- Right-aligned year column
- Publication numbers and citation counts
- Skill-tag borders

Body text `#1a1a1a` (titles) / `#444`–`#555` (secondary). No other colors.

### Page geometry

- A4, margins ~22 mm side, 20 mm top/bottom.
- Single column. Generous leading (~1.45).
- No page numbers on a 1-page short version; show `i / N` on full version
  starting at page 2 (small, burgundy, bottom-outer corner).

### Header block

```
Traian Florin Șerbănuță            ← Playfair, ~30pt
Associate Professor · Researcher in Formal Methods   ← Playfair italic, burgundy
traian.serbanuta@unibuc.ro · +40 21 314 3508 · cs.unibuc.ro/~tserbanuta
─────────────────────────────────────────────────────  ← 3pt burgundy rule
```

The tagline ("Associate Professor · Researcher in Formal Methods") is a new
metadata field. The mailing address moves out of the header into a small grey
footer line on every page of the **full** version; it is omitted from the
**short** version (where space is at a premium and the email/web/phone are
sufficient).

### Section title

Playfair Display, italic, ~16 pt, burgundy. No underline, no rule below — the
title carries the section break visually. Spaced ~18 pt above, ~8 pt below.

### Item rows (Education, Experience)

Two-column row with right-aligned year column:

```
PhD in Computer Science                                          2010
University of Illinois, Urbana-Champaign                        (burgundy,
Dissertation: A Rewriting Approach…  Advisor: Grigore Roșu.      tabular)
```

- Item title: Source Sans semibold, ~11 pt
- Organization: Source Sans italic, ~10 pt, grey `#555`
- Detail/description: Source Sans regular, ~9.5 pt, `#444`
- Year: Source Sans semibold, ~10 pt, burgundy, tabular numerals, right-aligned

### Publications

- Lead with a callout box: pale `#faf7f4` background, 3 pt burgundy left rule,
  summarising aggregate metrics (40 articles WoS / h-index 22 GScholar / 2 105
  citations).
- Numbered list with hanging indent. Numbers are burgundy, semibold, tabular,
  right-aligned in an 18 pt gutter.
- Author list inline; **bold** Șerbănuță's own name; *italic* venue; citation
  count in burgundy brackets at the end: `[639]`.
- Tight leading (~1.4).

### Skills

Outlined "pill" tags: burgundy 0.5 pt border, burgundy text, no fill,
~10 pt rounded corners. Flowing inline.

### Languages

Single inline line: `Romanian (native) · English (fluent) · French (basic)`.
Native/fluent/basic in grey.

## Source-file changes

### `resume.md`

Add to the YAML front-matter:

```yaml
tagline: "Associate Professor · Researcher in Formal Methods"
```

No other changes to the body — section names, `[LONG]` markers, and item
structure (`## Title` followed by `**Org, YYYY–YYYY**`) stay as-is.

### `filter.lua` — extended

Today the filter only strips `[LONG]…[/LONG]`. Extend it to recognise the
existing item pattern and emit semantic LaTeX, so the template can style each
field independently:

- Inside `# Education` / `# Experience`, recognise:
  ```
  ## <Title>
  **<Org>, <Years>**
  ```
  and emit a `\cvitem{<Title>}{<Org>}{<Years>}{<detail-paragraphs>}` raw-LaTeX
  block instead of `\subsection*{}` plus a paragraph.
- Year-range parsing extracts the trailing `YYYY[–YYYY|–Present]` so the
  template can put it in the right-aligned column. The year string is
  rendered verbatim (e.g. `2013–Present`, `2024–2026`); the filter does not
  reformat it.
- Inside `# Publications`, leave the numbered list intact — the template will
  redefine `enumerate` styling for that section. Recognise the `(cited by N)`
  suffix and rewrap it as `\cites{N}` so the template controls colour and
  spacing.

The `[LONG]/[/LONG]` stripping behaviour is preserved unchanged.

### New: `template.tex`

A custom pandoc LaTeX template (passed via `--template=template.tex`) that
defines:

- xelatex + fontspec for Playfair Display and Source Sans 3.
- `xcolor` with the burgundy accent (`\definecolor{accent}{HTML}{7A1F1F}`).
- A `titling`-style header that renders `$name$`, `$tagline$`, `$email$`,
  `$phone$`, `$web$` with the 3 pt burgundy rule beneath.
- Section command redefined via `titlesec`: Playfair italic, burgundy, no rule.
- `\cvitem{title}{org}{years}{detail}` macro implementing the two-column row
  with right-aligned years.
- `\cites{N}` macro for burgundy bracketed citation counts.
- Enumerate redefinition under Publications (using `enumitem`): burgundy
  numbers, hanging indent, tight leading.
- `tcolorbox` (or `mdframed`) for the publication-summary callout.
- A `pillbox` macro for skill tags (`\tikz` or `\fcolorbox` with rounded
  corners).

### `Makefile`

The `pdf` / `pdf-short` recipes gain `--template=template.tex`:

```make
pdf: resume.md filter.lua template.tex
	pandoc -L filter.lua \
		--template=template.tex \
		--metadata short_version=false \
		-f markdown \
		-t pdf \
		--pdf-engine=xelatex \
		resume.md -o resume.pdf
```

Same change for `pdf-short`.

## Short vs full versions

The short version uses the **same template**. It differs only in content —
`[LONG]` blocks are stripped by `filter.lua` as today. Visually the short
version is a tighter one- or two-page rendering of the same design. No
template branching needed.

## Out of scope

- Romanian Europass / official format. (Future work; the `serbanuta-cv-ro.*`
  sources stay untouched.)
- Bibliography-driven publication list (BibTeX). The publications stay in
  Markdown inside `resume.md` so the source-of-truth model holds.
- Multi-theme support (light/dark, alternative palettes).
- Web/HTML rendering of `resume.md`.

## Risks / unknowns

- **Font availability on TeX Live distributions.** Both fonts are in
  `texlive-fonts-extra` on recent Ubuntu, but may need a manual install on
  older systems. The Makefile should fail with a clear message if either
  font is missing.
- **Filter regex robustness.** The `## Title` + `**Org, YYYY**` pattern must
  match every existing entry. The implementation step will dry-run the filter
  on the current `resume.md` and diff against the expected output before
  wiring the template in.
- **Citation-count regex.** `(cited by N)` is consistent today but easy to
  accidentally break by edits to `resume.md`. The filter should fall back
  gracefully if the suffix is missing — emit the entry without `\cites{}`
  rather than failing.

## Acceptance criteria

- `make pdf` produces `resume.pdf` rendered in the editorial style above.
- `make pdf-short` produces `resume-short.pdf` in the same style, with
  `[LONG]` content stripped.
- Both PDFs build cleanly on the current Ubuntu environment with no manual
  font installation beyond `apt-get install texlive-fonts-extra` (document
  the requirement in the Makefile `help` target if needed).
- The header block, section titles, item rows, publication list, skill pills,
  and languages line match the approved mockup at
  `.superpowers/brainstorm/2320-1779798993/content/editorial-full.html`.
- No content changes other than adding the `tagline` metadata field.
