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
make pdf-publications # full list of publications (publications.md)
make all          # all four PDFs
make web          # tabbed web page + PDFs into docs/ (published)
make test         # filter tests (run automatically before pdf targets)
make clean        # remove generated PDFs (docs/ is tracked; kept)
make check-deps   # verify pandoc, xelatex, fonts
```

## Web build

`make web` renders the same sources through the same filter in **HTML mode**
(`FORMAT` is html: the filter builds pandoc Divs/Spans instead of raw LaTeX)
and assembles `docs/index.html`, one page with four tab panels: Academic
(full), Industry, One page (short), and Publications. Each panel is rendered
by `web/panel.html` with its own `--id-prefix` (`academic-`, `industry-`,
`short-`, `pubs-`) so heading ids stay unique; `web/page.html` stitches them
in with `-B`. `web/style.css` is the theme (light/dark via
`prefers-color-scheme`, WCAG AA contrast, responsive, print styles) and
`web/tabs.js` progressively enhances the nav into a WAI-ARIA tablist driven by
the URL hash (`#academic`, `#industry`, `#short`, `#publications`). Without
JavaScript all four versions show in sequence.

`docs/` is committed and GitHub Pages serves it from `main:/docs` at
<https://traiansf.github.io/resume/> (`docs/.nojekyll` disables Jekyll). To
publish changes: `make web`, then commit `docs/` and push. Keep anything that
should not be public out of `docs/` (design notes live in `notes/`).

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
- `publications.md` — the full publication list (`make pdf-publications`).
- `web/` — web build templates, theme and tabs script; output goes to the
  committed `docs/` (see "Web build").
- `notes/` — design specs and plans.
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

- **`email-academic` frontmatter field** — in the full version (neither
  `short_version` nor `industry_version`) the filter replaces `email` with
  `email-academic` (the institutional address). Short and industry keep
  `email`. `publications.md` sets its `email` to the institutional address
  directly.

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
   Publications section (also entered via a `\sectionwithcallout` block).
6. HTML only — demote all headers by one level (the page `<h1>` is the name).

Every LaTeX construct has an HTML counterpart guarded by `html_output`; when
adding one, add the other and an `expected.html` fixture.

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
- `expected.html` / `expected-short.html` — expected HTML (web build) output
  (optional; rendered with `-t html5`).

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

## Administrative documents (ARACIS lists, Europass)

Not part of the build; notes for recurring paperwork.

### Bibliographic databases via e-nformation (Web of Science, Scopus)

- Access goes through the University of Bucharest's ANELIS Plus subscription at
  e-nformation.ro. The credentials are in `env.toml` (gitignored, never commit
  or echo it). **The user logs in themselves in Chrome**; Claude does not type
  passwords into sign-in forms. Logging in from a script also kicks out the
  user's browser session (single-session account).
- Once logged in, open these in Chrome (claude-in-chrome). The proxy rewrites
  the hostname per session (e.g. `0510qtc5t-y-https-www-webofscience-com.z.e-nformation.ro`),
  so always enter through the link:
  - WoS: `https://z.e-nformation.ro/PlatformaUnivBucsiBCUBuc?action=source&sourceID=ClarivateWoS_AnelisPlus`
  - Scopus: same URL with `sourceID=Scopus_AnelisPlus`. If the landing page
    errors, go to `/search/form.uri?display=authorLookup` on the proxied host.
- Scripted WoS API calls (`/api/wosnx/...`) fail with
  `Server.passiveVerificationRequired`; use the browser UI.
- WoS advanced search (`/wos/woscc/advanced-search`): the query box can be
  pre-filled from history and typing interleaves with it; set the value with
  `form_input` instead. Decline the cookie banner first, because it swallows clicks.
- Author query that catches every record (one FROM 2019 paper is indexed
  without a matching author form):
  `AU=(Serbanuta T*) OR AU=(Serbanuta, Traian*) OR TI=("From Hybrid Modal Logic to Matching Logic")`.
  Add `AND PY=(YYYY-YYYY)` for a period. "Citation Report" on the results page
  gives total publications, h-index and citations.
- The results list is virtualized. Collect `a[data-ta="summary-record-title-link"]`
  while scrolling; the href ends in the `WOS:` accession number.
- Scopus author profile: ID **6507372636** (`/authid/detail.uri?authorId=6507372636`);
  a stray 1-document duplicate profile also exists.
- Snapshot (2026-10-10): WoS CC 37 pubs, h 14, 793 citations; Scopus 43 docs,
  h 16, 1162 citations; Google Scholar 55, h 22, 2178.
- DBLP (and its XML API) sits behind an Anubis bot check, even in Chrome. Don't
  try to get around it; rely on `publications.md` / `sources/vitae.bib`.

### ARACIS publication list (`Lista_lucrari_format_ARACIS_*.doc`)

- Blank template: `Lista_lucrari_format_ARACIS_Nume_Prenume.doc`; filled:
  `Lista_lucrari_format_ARACIS_Serbanuta_Traian_Florin.{doc,docx}`.
- Conventions agreed with the user: "ultimii 10 ani" = the current year minus
  10 (2016 items kept for 2026); "BDI" = any international database, so
  everything refereed goes in C (journals and conferences as separate sublists)
  and D (unindexed) is "—". Mark each C entry `[ISI – WOS:…]` or `[BDI]`.
  Exclude arXiv preprints.
- Workflow: `soffice --headless --convert-to docx` the template, unzip, replace
  the dotted placeholders / `1.` stub paragraphs in `word/document.xml`, zip,
  validate, convert back with `--convert-to doc:"MS Word 97"`.
- Tool quirks on this machine: Python 3.10 (no `tomllib`, no `requests`; use
  urllib); local `pdftoppm` has no `-jpeg` (use `-png`); `soffice` hangs if it
  isn't given an input file (kill it with `Stop-Process`); pass absolute
  Windows paths plus `--outdir`.

### Europass CV (`CV-Europass-YYYY-MM-DD-Șerbănuță-RO.pdf`)

- Latest: `CV-Europass-2026-10-10-Șerbănuță-RO.pdf` (Romanian, first/
  single-column template, Medium text, page numbers on). The user rejected the
  left-labels ("tabular") template: its PDF hyphenates long headings like
  "EXPERIENȚA PROFESIO-NALĂ" even at Small size (the on-screen preview doesn't
  show this; check the downloaded PDF). It is also saved in the Europass
  library under the same name, so future updates should start from that CV
  (My Library → edit) rather than from scratch. Older versions are in
  `sources/`. Europass PDFs embed their data as `attachment.xml`
  (`pdfdetach -list`).
- The user logs in to Europass in Chrome; then drive it with claude-in-chrome.
  URLs: profile `https://europa.eu/europass/eportfolio/screen/profile?lang=en`,
  library `.../screen/my-library?lang=en`.
- **Use the CV editor, not the profile, for dates.** The profile editor
  (`profile`) stores full DD-MM-YYYY dates, shows them shifted by a day
  (timezone), and turns month-precision entries into day-precision ones as
  soon as you edit them. The CV editor ("Create a CV based on this profile"
  → *standard* builder → Edit step) has separate DD/MM/YYYY selects; leave
  DD empty for "10/2013"-style dates, or leave DD and MM empty for a year
  only. The profile itself is now partly stale (day-level dates; the newer
  entries and the skills/projects sections exist only in the CV).
- CV editor mechanics (Angular + Quill):
  - Rich-text fields are Quill: `Quill.find(container).clipboard.dangerouslyPasteHTML(0, html, 'user')`
    after `setContents([], 'user')`. Typing with the keyboard doesn't reach them.
  - Plain inputs (employer, city): native value setter plus `input`/`change`
    events. The job-title field is an ESCO autocomplete. Type it with the
    keyboard, click elsewhere, press Escape, then Save, otherwise the value
    reverts or a suggestion replaces it.
  - Country is a custom dropdown: click it, type the name, click the option.
  - Work experience is ordered by **end date** (newest first; ongoing roles
    first, in their existing order). Same rule in `resume.md`. Reorder with
    the per-entry "Move the record up" buttons.
  - Deleting a whole line in Quill: delete from the line start through its
    own trailing `
`. Deleting the *preceding* `
` merges it into the line
    above and takes over that line's formatting (e.g. a bullet is lost); fix
    with `q.formatLine(i, 1, 'list', 'bullet', 'user')`.
  - Each entry's "Edit" opens a menu ("Edit work experience"). The department
    field sits under the collapsed "Address details" section and is rendered
    as "Unitatea sau departamentul", so don't also put it in the employer name.
  - Custom-section descriptions are capped at **4000 characters** (the top-20
    publications list uses compact APA style with initials to fit).
  - Skills section: add each skill with the search box + Add, then create
    categories and assign skills via "Add skills to this category" (checkbox
    ids are `select-<skill name>`).
  - Avoid `setTimeout`-based scripts: the tab gets throttled and
    `javascript_tool` times out (45 s), although the script keeps running.
    Prefer synchronous snippets, or start the async work, then poll a
    `window.__last` result between screenshots.
  - Matching DOM text: use XPath `normalize-space(text())`; scanning
    `innerText` over all elements freezes the page.
