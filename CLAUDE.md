# Resume — project notes

A two-target academic resume: `resume.pdf` (full) and `resume-short.pdf`
(condensed, intended to fit one page). One markdown source, one pandoc Lua
filter, one xelatex template; both PDFs are produced from the same `resume.md`
by toggling a metadata flag.

## Build

```
make pdf        # full version
make pdf-short  # short version
make all        # both
make test       # filter tests (run automatically before pdf/pdf-short)
make clean      # remove generated PDFs
make check-deps # verify pandoc, xelatex, fonts
```

Both `pdf` targets depend on `test`, so a filter regression aborts the build
before generating PDFs. Do not bypass this — the test suite exists because
the `[LONG]` handling has historically been fragile.

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

1. `normalize_long_paras` — splits paragraphs with orphan leading/trailing
   `[LONG]`/`[/LONG]` into standalone tag paragraphs.
2. `resolve_block_long` — depth-counted resolution of standalone tag pairs.
   Drops wrapped content in short mode, drops only the tags in full mode.
   Emits a stderr warning on any unmatched tag (the integration test fails
   on these).
3. Main loop — section tracking; CV-fold for `## H2` entries inside CV
   sections; CALLOUT markers; pills for Skills/Programming Languages;
   inline `·` for Languages; inline `[LONG]...[/LONG]` for the pills idiom.
4. Citation rewrite — `(cited by N)` → `\cites{N}` walk in the
   Publications section.

The main loop should never see a standalone `[LONG]` or `[/LONG]` paragraph
— if you find yourself adding handling for that there, the pre-pass is
broken and that's where to fix it.

## Tests

Each subdirectory under `tests/filter/` is a fixture:

- `input.md` — markdown input (required).
- `expected.tex` — expected LaTeX for the **full** version (optional).
- `expected-short.tex` — expected LaTeX for the **short** version (optional).

At least one expected file must exist. If both are present, both modes run.

Plus an **integration check**: the runner renders the real `resume.md` in
both modes and fails if the output contains a literal `[LONG]`/`[/LONG]`
token or the filter emits any stderr warning. This is what catches typos
and tag-balance regressions.

When adding a new markdown idiom or special-casing a section in
`filter.lua`, add a fixture covering both modes. Regenerate expected files
by running pandoc directly:

```
pandoc -L filter.lua --metadata short_version=false -f markdown -t latex \
  tests/filter/<name>/input.md > tests/filter/<name>/expected.tex
pandoc -L filter.lua --metadata short_version=true -f markdown -t latex \
  tests/filter/<name>/input.md > tests/filter/<name>/expected-short.tex
```

## Dependencies

- pandoc, xelatex (`texlive-xetex`), pdftotext (`poppler-utils`).
- Fonts: **Playfair Display** (headings) and **Source Sans 3** (body).
  Install into `~/.local/share/fonts/` from Google Fonts, then `fc-cache -f`.
- `make check-deps` verifies all of the above.
