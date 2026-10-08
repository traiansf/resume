# Industry-oriented CV — design

Date: 2026-05-31

## Goal

Add a third build target, `resume-industry.pdf`, generated from the same
`resume.md`. It is a *full-length* CV (not the one-page short version) but
re-weighted for an industry audience: publications are reduced to a proof of
record, teaching to a subject summary, and academic minutiae (dissertation
titles, advisors, committees, early-career detail) are dropped.

This sits alongside the two existing targets, which are unchanged:

- `resume.pdf` — full academic CV (`make pdf`).
- `resume-short.pdf` — condensed one-pager (`make pdf-short`).

## Visibility model

Today the build has one axis: `short_version` (true/false), with
`[LONG]…[/LONG]` hiding content in the short version. We add a second axis,
`industry_version`, and two new tag idioms. The three tags are orthogonal,
each gating on exactly one flag:

| Tag                        | Hidden when         | Visible in        |
|----------------------------|---------------------|-------------------|
| `[LONG]…[/LONG]`           | `short_version`     | full, industry    |
| `[ACADEMIC]…[/ACADEMIC]`   | `industry_version`  | full, short       |
| `[INDUSTRY]…[/INDUSTRY]`   | **not** `industry_version` | industry only |

Tags compose by nesting. Content that is academic *and* long-form is wrapped
`[LONG][ACADEMIC]…[/ACADEMIC][/LONG]`, making it visible only in the full
version (LONG hides it in short, ACADEMIC hides it in industry).

### The three modes

| Mode     | Make target        | `short_version` | `industry_version` | LONG | ACADEMIC | INDUSTRY |
|----------|--------------------|-----------------|--------------------|------|----------|----------|
| full     | `make pdf`         | false           | false              | show | show     | hide     |
| short    | `make pdf-short`   | true            | false              | hide | show     | hide     |
| industry | `make pdf-industry`| false           | true               | show | hide     | show     |

`short_version` and `industry_version` are never both true.

## Content changes (industry mode only)

All edits are additive tagging in `resume.md`; the full and short outputs are
unchanged.

1. **Publications.** Keep the stats callout (`55 articles · h-index 22 · 2106
   citations`) — it proves the research record exists. Wrap the "Top 20 by
   citations" intro paragraph and the numbered list in `[ACADEMIC]…[/ACADEMIC]`
   (nested inside the existing `[LONG]`), so the list shows only in the full
   version.

2. **Teaching (Associate Professor entry).** The detailed course list (links
   per course) is wrapped `[ACADEMIC]` inside the existing `[LONG]`. Add an
   `[INDUSTRY]…[/INDUSTRY]` one-line summary that appears only in industry mode,
   e.g.:

   > Designed and taught courses across software modelling, declarative &
   > concurrent programming, programming-language semantics, program
   > verification, and machine learning — all course materials openly
   > published.

3. **Education.** Wrap each entry's dissertation title / advisors / committee
   in `[ACADEMIC]` (nested in the existing `[LONG]`). Industry keeps degree ·
   institution · year only.

4. **Postdoc / early-career roles** (Postdoctoral fellow/associate, Research
   Assistant, Teaching Assistant, interns, early Programmer). These entries are
   currently wrapped whole in `[LONG]`. Restructure each so the `## Title` +
   `**Org, Years**` stay LONG-gated but the one-line detail is additionally
   wrapped in `[ACADEMIC]`. Result: industry keeps the timeline (title/org/years)
   but drops the descriptions; full keeps everything; short still hides the
   whole entry.

5. **Open-source Projects.** Already `[LONG]`, which industry mode shows — so it
   appears in the industry CV unchanged, and remains hidden in the short
   one-pager. No tagging change needed.

6. **Tagline.** Add a `tagline-industry` YAML frontmatter field. The filter
   swaps it in when `industry_version` is set. Proposed value:

   > Formal Methods for Software Correctness · Verification Engineer ·
   > Associate Professor

   (Leads with the value proposition — applying formal methods to software
   correctness / quality — per the requested framing. Final wording confirmed
   on spec review.)

Skills, Programming Languages, Languages, the Pi Squared and Runtime
Verification industry roles, and the ILDS co-founder role are all
industry-relevant and unchanged.

## Filter implementation (`filter.lua`)

Generalize the existing `[LONG]` machinery rather than duplicating it:

- Parameterize `normalize_long_paras` → `normalize_tag_paras(blocks, tag)`,
  splitting orphan-leading/trailing occurrences of any given tag.
- Parameterize `resolve_block_long` → `resolve_block_tag(blocks, tag, hide)`,
  depth-counted resolution that drops wrapped content when `hide` is true and
  drops only the tags otherwise. Emits the same unmatched-tag stderr warning.
- In `Pandoc(doc)`: read `industry_version` from `doc.meta` alongside
  `short_version`. Run normalize for all three tags, then three resolve passes:
  `LONG` (hide = short), `ACADEMIC` (hide = industry), `INDUSTRY`
  (hide = not industry). Nesting is well-formed (no interleaving), so
  sequential passes are correct.
- When `industry_version` and `doc.meta['tagline-industry']` is present, set
  `doc.meta.tagline = doc.meta['tagline-industry']` so the template's
  `$tagline$` renders the industry tagline.

The LONG-only idioms — inline pills (`[LONG]\n- a\n- b\n[/LONG]` in
Skills/Programming Languages) and in-list trim (`trim_lists_with_inline_long`)
— are **not** generalized; they stay LONG-specific. ACADEMIC and INDUSTRY are
only ever used in standalone/orphan block form, which the generalized
normalize+resolve covers.

Pipeline order is preserved: normalize → resolve (×3) → main loop →
citation rewrite. The main loop must never see a standalone tag paragraph for
any of the three tags.

## Build (`Makefile`)

- Add a `pdf-industry` target mirroring `pdf`/`pdf-short`, passing
  `--metadata industry_version=true`, output `resume-industry.pdf`. Depends on
  `test`.
- Add `pdf-industry` to `all`.
- Add `resume-industry.pdf` to `clean`.
- Update `help`.

## Tests (`tests/filter/`)

- New fixtures exercising `[ACADEMIC]` and `[INDUSTRY]` standalone tags, and
  the nested `[LONG][ACADEMIC]` form, with expected output for the relevant
  modes. The runner currently renders full + short per fixture; extend it to
  also render the industry mode (`--metadata industry_version=true`) and
  compare against an optional `expected-industry.tex`.
- Extend the integration check: render the real `resume.md` in industry mode in
  addition to full/short, and fail if any rendered output contains a literal
  `[LONG]`, `[/LONG]`, `[ACADEMIC]`, `[/ACADEMIC]`, `[INDUSTRY]`, or
  `[/INDUSTRY]` token, or if the filter emits any stderr warning.

## Documentation

Update `CLAUDE.md` (project notes) to document the `industry_version` flag, the
two new tags, the `pdf-industry` target, and the `tagline-industry` field.

## Out of scope

- Per-mode section reordering (e.g. Experience before Education). The single
  source has one section order; reordering per mode is not supported by this
  design and is not requested.
- Any change to the full or short outputs.
