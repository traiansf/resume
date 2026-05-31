# Resume — project notes

Three build variants from a single `resume.md`: `resume.pdf` (full academic),
`resume-short.pdf` (condensed, intended to fit one page), and
`resume-industry.pdf` (industry-oriented, full-length). One pandoc Lua filter,
one xelatex template; all three PDFs are produced by toggling metadata flags.

## Build

```
make pdf          # full version
make pdf-short    # short version (condensed, one page)
make pdf-industry # industry-oriented full-length version
make all          # all three
make test         # filter tests (run automatically before pdf targets)
make clean        # remove generated PDFs
make check-deps   # verify pandoc, xelatex, fonts
```

All three `pdf` targets depend on `test`, so a filter regression aborts the
build before generating PDFs. Do not bypass this — the test suite exists
because the `[LONG]` handling has historically been fragile.

## Source layout

- `resume.md` — single source of truth. YAML frontmatter for personal info;
  H1 sections for resume structure; `## Title` + `**Org, Years**` for CV
  entries.
- `filter.lua` — pandoc Lua filter; controls all the special markdown idioms
  below. Read this before changing how content is rendered.
- `template.tex` — xelatex template (fonts, section spacing, colors, the
  `\cvitem`, `\pill`, `\cites`, callout macros).
- `tests/filter/` — fixture-based tests; see "Tests" below.
- `sources/` — older/auxiliary CVs and GitHub-contribution notes used as
  input material when updating `resume.md`. Not consumed by the build.

## Markdown conventions

These are non-standard idioms the filter recognises:

- **`[LONG] ... [/LONG]`** — hide content in the short version. Four valid
  forms (see `filter.lua` for the full pipeline):
  - **standalone tags**: `[LONG]` on its own line (blank lines around),
    arbitrary blocks between, `[/LONG]` on its own line. Can wrap entire
    `# H1` sections or `## H2` entries.
  - **orphan-leading / orphan-trailing**: tag is the first/last line of a
    paragraph that also has content; the filter splits these into standalone
    form before resolving.
  - **inline both**: `[LONG]\n- item\n- item\n[/LONG]` all in one paragraph,
    used in Skills and Programming Languages to render extra pills only in
    the full version.
  - **in-list trim**: place `[LONG]` and `[/LONG]` on their own lines
    *immediately after* bullet-list items (no blank line), to hide a
    contiguous slice of items in the short version while keeping a single
    `BulletList` in the AST. Implemented in `trim_lists_with_inline_long`
    by detecting the trailing `SoftBreak + Str "[LONG]"` (resp. `[/LONG]`)
    appended to the preceding item.

  **Never** use `</LONG>` — that's an HTML-style close, pandoc parses it as
  raw HTML and the filter does not recognise it. The integration test fails
  on the resulting "unmatched [LONG] tag" warning.

- **`[ACADEMIC] ... [/ACADEMIC]`** — hide content in the industry version
  (shown in full and short). Used for the publications Top-20 list, detailed
  course listings, dissertation/advisor/committee detail, and early-career
  role descriptions. Nest inside `[LONG]` to produce full-only content:
  `[LONG][ACADEMIC]...[/ACADEMIC][/LONG]`.

- **`[INDUSTRY] ... [/INDUSTRY]`** — show content only in the industry
  version (hidden in full and short). Used for the industry teaching-subjects
  summary and other industry-targeted additions.

- **`tagline-industry` frontmatter field** — when `industry_version=true` the
  filter replaces the `tagline` metadata value with the value of
  `tagline-industry` before template rendering. Declare both fields in the
  YAML frontmatter of `resume.md`.

- **Blank-line rule for `[ACADEMIC]`/`[INDUSTRY]` (important gotcha):** always
  put each tag on its own line with blank lines separating it from the wrapped
  content (standalone-paragraph form). A single-line construct like
  `[ACADEMIC]\ncontent\n[/ACADEMIC]` with no surrounding blank lines causes
  pandoc to parse all three lines as one paragraph holding *both* tags. The
  generalized `normalize_tag_paras` runs for all three tags and splits the
  orphan-leading/trailing forms (one tag per paragraph), but the *both-tags-in-
  one-paragraph* form is only special-cased for `[LONG]` (the pills idiom) — for
  `[ACADEMIC]`/`[INDUSTRY]` it falls through unresolved, so the content leaks
  unhidden and the tags render as literal text. The safe rule for all three
  tags: blank lines around both the open and close tag.

- **`[CALLOUT] ... [/CALLOUT]`** — wrap content in a soft-background callout
  box. Used for the Publications stats.

- **`## Title` + `**Org, Years**`** in `# Education` and `# Experience`
  sections — the filter folds these (plus the following blocks, up to the
  next H1/H2) into a single `\cvitem{title}{org}{years}{detail}` LaTeX
  macro. Years pattern: `YYYY`, `YYYY–YYYY`, or `YYYY–Present`.

- **`# Skills` / `# Programming Languages`** — bullet lists are rendered as
  outlined burgundy pills (`\pill{...}`). The `[LONG]` block within these
  sections lists more items as additional pills, parsed dash-separated.

- **`# Languages`** — bullet list is rendered inline, `·`-joined, with
  parenthetical level qualifiers (e.g. `(native)`) greyed.

- **`(cited by N)` at the end of a publication entry** — rewritten to a
  burgundy semibold `\cites{N}` badge.

## Filter pipeline (`filter.lua`)

When changing the filter, preserve this order — later passes assume earlier
ones have run:

1. `normalize_tag_paras(blocks, tag)` — generalized pre-pass, run once per
   tag in order: LONG, ACADEMIC, INDUSTRY. Splits paragraphs with orphan
   leading/trailing tag into standalone tag paragraphs.
2. `resolve_block_tag(blocks, tag, hide)` — generalized depth-counted
   resolution of standalone tag pairs, run once per tag:
   - LONG: `hide = short_version` (hidden in short, shown in full + industry).
   - ACADEMIC: `hide = industry_version` (hidden in industry, shown in full + short).
   - INDUSTRY: `hide = not industry_version` (shown only in industry).
   Drops wrapped content when `hide` is true; drops only the tag paragraphs
   otherwise. Emits a stderr warning on any unmatched tag (the integration
   test fails on these). Tags compose by nesting, e.g.
   `[LONG][ACADEMIC]...[/ACADEMIC][/LONG]` = full-only content.
3. `trim_lists_with_inline_long` — handles the in-list trim idiom (`[LONG]`/
   `[/LONG]` attached inline to bullet items). This idiom is LONG-specific
   and is not generalized to `[ACADEMIC]`/`[INDUSTRY]`.
4. Main loop — section tracking; CV-fold for `## H2` entries inside CV
   sections; CALLOUT markers; pills for Skills/Programming Languages;
   inline `·` for Languages; inline `[LONG]...[/LONG]` for the pills idiom
   (also LONG-specific, not generalized).
5. Citation rewrite — `(cited by N)` → `\cites{N}` walk in the
   Publications section.

The main loop should never see a standalone `[LONG]`, `[ACADEMIC]`, or
`[INDUSTRY]` paragraph — if you find yourself adding handling for that there,
the pre-pass is broken and that's where to fix it.

## Tests

Each subdirectory under `tests/filter/` is a fixture:

- `input.md` — markdown input (required).
- `expected.tex` — expected LaTeX for the **full** version (optional).
- `expected-short.tex` — expected LaTeX for the **short** version (optional).
- `expected-industry.tex` — expected LaTeX for the **industry** version
  (optional; rendered with `industry_version=true short_version=false`).

At least one expected file must exist. All present variants are exercised.

Plus an **integration check**: the runner renders the real `resume.md` in
**three modes** (full, short, industry) and fails if the output contains a
literal `[LONG]`, `[ACADEMIC]`, or `[INDUSTRY]` token or the filter emits
any stderr warning. Before scanning, the runner strips `{}` from the output
with `tr -d '{}'` so that LaTeX-escaped brackets (`{[}TAG{]}`) are caught by
the same regex as bare brackets. This is what catches typos and tag-balance
regressions.

A dedicated **`tagline-swap`** check verifies that the `tagline-industry`
frontmatter swap works: it renders the minimal fixture at
`tests/filter/tagline/` in full and industry modes against a minimal template
and confirms the correct tagline appears (and the wrong one does not) in each.

When adding a new markdown idiom or special-casing a section in
`filter.lua`, add a fixture covering all relevant modes. Regenerate expected
files by running pandoc directly:

```
pandoc -L filter.lua --metadata short_version=false -f markdown -t latex \
  tests/filter/<name>/input.md > tests/filter/<name>/expected.tex
pandoc -L filter.lua --metadata short_version=true -f markdown -t latex \
  tests/filter/<name>/input.md > tests/filter/<name>/expected-short.tex
pandoc -L filter.lua --metadata short_version=false --metadata industry_version=true \
  -f markdown -t latex \
  tests/filter/<name>/input.md > tests/filter/<name>/expected-industry.tex
```

## Dependencies

- pandoc, xelatex (`texlive-xetex`), pdftotext (`poppler-utils`).
- Fonts: **Playfair Display** (headings) and **Source Sans 3** (body).
  Install into `~/.local/share/fonts/` from Google Fonts, then `fc-cache -f`.
- `make check-deps` verifies all of the above.
