.PHONY: pdf pdf-short pdf-industry pdf-publications web clean help all check-deps test

help:
	@echo "Resume Build Targets:"
	@echo "  make check-deps - Verify pandoc, xelatex, fonts are installed"
	@echo "  make pdf        - Generate full resume (runs test first)"
	@echo "  make pdf-short  - Generate short resume (runs test first)"
	@echo "  make pdf-industry - Generate industry-oriented resume (runs test first)"
	@echo "  make pdf-publications - Generate full publication list (runs test first)"
	@echo "  make web        - Build the tabbed web page (and PDFs) into docs/"
	@echo "  make test       - Run filter fixture and regression tests"
	@echo "  make clean      - Remove generated PDFs"
	@echo ""
	@echo "First-time setup: install Playfair Display and Source Sans 3 fonts"
	@echo "from Google Fonts into ~/.local/share/fonts/ then run 'fc-cache -f'."

pdf: test resume.md filter.lua template.tex
	pandoc -L filter.lua \
		--template=template.tex \
		--metadata full_version=true \
		--metadata short_version=false \
		-f markdown \
		-t pdf \
		--pdf-engine=xelatex \
		resume.md -o resume.pdf
	@echo "Generated: resume.pdf"

pdf-short: test resume.md filter.lua template.tex
	pandoc -L filter.lua \
		--template=template.tex \
		--metadata short_version=true \
		-f markdown \
		-t pdf \
		--pdf-engine=xelatex \
		resume.md -o resume-short.pdf
	@echo "Generated: resume-short.pdf"

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

pdf-publications: test publications.md filter.lua template.tex
	pandoc -L filter.lua \
		--template=template.tex \
		--metadata full_version=true \
		--metadata short_version=false \
		-f markdown \
		-t pdf \
		--pdf-engine=xelatex \
		publications.md -o publications.pdf
	@echo "Generated: publications.pdf"

# ─── Web build ────────────────────────────────────────────────────────────
# docs/index.html holds all four versions as tab panels (web/page.html);
# each panel is rendered by web/panel.html through the same filter, with a
# per-panel --id-prefix so heading ids stay unique on the page. docs/ is
# committed: GitHub Pages serves it (main:/docs) at
# https://traiansf.github.io/resume/.
SITE    := docs
WEB_SRC := web/page.html web/panel.html web/style.css web/tabs.js
PANEL    = pandoc -L filter.lua --template=web/panel.html -f markdown -t html5

web: pdf pdf-short pdf-industry pdf-publications $(WEB_SRC)
	mkdir -p $(SITE)
	touch $(SITE)/.nojekyll
	$(PANEL) --id-prefix=academic- -M panel=academic -M pdf=resume.pdf \
		-M "pdf-label=academic CV" --metadata short_version=false \
		resume.md -o $(SITE)/academic.part.html
	$(PANEL) --id-prefix=industry- -M panel=industry -M pdf=resume-industry.pdf \
		-M "pdf-label=industry CV" --metadata short_version=false \
		--metadata industry_version=true \
		resume.md -o $(SITE)/industry.part.html
	$(PANEL) --id-prefix=short- -M panel=short -M pdf=resume-short.pdf \
		-M "pdf-label=one-page CV" --metadata short_version=true \
		resume.md -o $(SITE)/short.part.html
	$(PANEL) --id-prefix=pubs- -M panel=publications -M pdf=publications.pdf \
		-M "pdf-label=list of publications" --metadata short_version=false \
		publications.md -o $(SITE)/publications.part.html
	pandoc --template=web/page.html -f markdown -t html5 \
		-M pagetitle=CV -M updated="$$(date +%Y-%m-%d)" \
		-B $(SITE)/academic.part.html -B $(SITE)/industry.part.html \
		-B $(SITE)/short.part.html -B $(SITE)/publications.part.html \
		resume.md -o $(SITE)/index.html
	rm -f $(SITE)/*.part.html
	cp web/style.css web/tabs.js $(SITE)/
	cp resume.pdf resume-short.pdf resume-industry.pdf publications.pdf $(SITE)/
	@echo "Generated: $(SITE)/index.html (commit docs/ to publish)"

# docs/ is the published site and is tracked, so clean leaves it alone.
clean:
	rm -f resume.pdf resume-short.pdf resume-industry.pdf publications.pdf

all: pdf pdf-short pdf-industry pdf-publications

check-deps:
	@command -v pandoc >/dev/null || { echo "ERROR: pandoc not installed"; exit 1; }
	@command -v xelatex >/dev/null || { echo "ERROR: xelatex not installed (apt install texlive-xetex)"; exit 1; }
	@command -v pdftotext >/dev/null || { echo "ERROR: pdftotext not installed (apt install poppler-utils)"; exit 1; }
	@fc-list | grep -qi "Playfair Display" || { echo "ERROR: Playfair Display font missing. See README."; exit 1; }
	@fc-list | grep -qi "Source Sans 3" || { echo "ERROR: Source Sans 3 font missing. See README."; exit 1; }
	@echo "All dependencies OK."

test:
	@./tests/filter/run-tests.sh
