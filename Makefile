.PHONY: pdf pdf-short clean help all

help:
	@echo "Resume Build Targets:"
	@echo "  make pdf       - Generate full resume (resume.pdf)"
	@echo "  make pdf-short - Generate short resume (resume-short.pdf)"
	@echo "  make clean     - Remove generated PDFs"

pdf: resume.md filter.lua
	pandoc -L filter.lua \
		--metadata short_version=false \
		-f markdown \
		-t pdf \
		--pdf-engine=xelatex \
		resume.md -o resume.pdf
	@echo "Generated: resume.pdf"

pdf-short: resume.md filter.lua
	pandoc -L filter.lua \
		--metadata short_version=true \
		-f markdown \
		-t pdf \
		--pdf-engine=xelatex \
		resume.md -o resume-short.pdf
	@echo "Generated: resume-short.pdf"

clean:
	rm -f resume.pdf resume-short.pdf

all: pdf pdf-short

