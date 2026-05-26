.PHONY: pdf pdf-short clean help all check-deps test

help:
	@echo "Resume Build Targets:"
	@echo "  make pdf       - Generate full resume (resume.pdf)"
	@echo "  make pdf-short - Generate short resume (resume-short.pdf)"
	@echo "  make clean     - Remove generated PDFs"

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
