.PHONY: pdf pdf-short clean help all check-deps test

help:
	@echo "Resume Build Targets:"
	@echo "  make check-deps - Verify pandoc, xelatex, fonts are installed"
	@echo "  make pdf        - Generate full resume (runs test first)"
	@echo "  make pdf-short  - Generate short resume (runs test first)"
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

clean:
	rm -f resume.pdf resume-short.pdf

all: pdf pdf-short

check-deps:
	@command -v pandoc >/dev/null || { echo "ERROR: pandoc not installed"; exit 1; }
	@command -v xelatex >/dev/null || { echo "ERROR: xelatex not installed (apt install texlive-xetex)"; exit 1; }
	@command -v pdftotext >/dev/null || { echo "ERROR: pdftotext not installed (apt install poppler-utils)"; exit 1; }
	@fc-list | grep -qi "Playfair Display" || { echo "ERROR: Playfair Display font missing. See README."; exit 1; }
	@fc-list | grep -qi "Source Sans 3" || { echo "ERROR: Source Sans 3 font missing. See README."; exit 1; }
	@echo "All dependencies OK."

test:
	@./tests/filter/run-tests.sh
