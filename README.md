# Traian Florin Șerbănuță — CV

Source for my curriculum vitae and list of publications.

**Read it online: <https://traiansf.github.io/resume/>**: academic, industry
and one-page versions plus the full publication list, each with a PDF
download:

- [Academic CV](https://traiansf.github.io/resume/resume.pdf)
- [Industry CV](https://traiansf.github.io/resume/resume-industry.pdf)
- [One-page CV](https://traiansf.github.io/resume/resume-short.pdf)
- [List of publications](https://traiansf.github.io/resume/publications.pdf)

## How it is built

Everything is generated from two Markdown files with
[pandoc](https://pandoc.org) and a single Lua filter:

- `resume.md`: the CV. Markers such as `[LONG]…[/LONG]`,
  `[ACADEMIC]…[/ACADEMIC]` and `[INDUSTRY]…[/INDUSTRY]` select what appears
  in each version.
- `publications.md`: the full publication list.
- `filter.lua`: turns those markers and a few section conventions into
  LaTeX (for the PDFs, via `template.tex` and XeLaTeX) or HTML (for the web
  page, via `web/`).

```
make all     # the four PDFs
make web     # the web page and PDFs, into docs/ (served by GitHub Pages)
make test    # filter tests (run before every PDF build)
```

Requirements: pandoc, XeLaTeX, and the Playfair Display and Source Sans 3
fonts. Run `make check-deps` to check them. Contributor notes are in
[`CLAUDE.md`](CLAUDE.md).

## Layout

| Path | Contents |
|---|---|
| `resume.md`, `publications.md` | Content |
| `filter.lua`, `template.tex` | PDF rendering |
| `web/` | Web page templates, theme (`style.css`) and tabs script |
| `docs/` | Generated website (published, do not edit by hand) |
| `tests/filter/` | Filter fixtures |
| `sources/` | Older CVs and notes used as input material |
| `notes/` | Design notes |
