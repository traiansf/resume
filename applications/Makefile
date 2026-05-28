.PHONY: all pdf clean help

# Tailored application résumés are built from the shared filter and template
# one directory up, in short (one-page) mode.
FILTER   := ../filter.lua
TEMPLATE := ../template.tex

all: pdf

pdf: resume-nectry.pdf

resume-nectry.pdf: resume-nectry.md $(FILTER) $(TEMPLATE)
	pandoc -L $(FILTER) \
		--template=$(TEMPLATE) \
		--metadata short_version=true \
		-f markdown \
		-t pdf \
		--pdf-engine=xelatex \
		resume-nectry.md -o resume-nectry.pdf
	@echo "Generated: resume-nectry.pdf"

clean:
	rm -f resume-nectry.pdf

help:
	@echo "Application Résumé Build Targets:"
	@echo "  make        - Build the Nectry one-page résumé (resume-nectry.pdf)"
	@echo "  make clean  - Remove generated application PDFs"
	@echo ""
	@echo "Uses ../filter.lua and ../template.tex; builds in short (one-page) mode."
