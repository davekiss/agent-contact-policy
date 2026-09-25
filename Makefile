# Render the draft: needs kramdown-rfc (gem install kramdown-rfc) and xml2rfc (pipx install xml2rfc).
DRAFT := draft-kiss-agent-contact-policy

all: $(DRAFT).txt $(DRAFT).html

$(DRAFT).xml: $(DRAFT).md
	kramdown-rfc $< > $@

$(DRAFT).txt $(DRAFT).html: $(DRAFT).xml
	xml2rfc --v3 $< --text --html

clean:
	rm -f $(DRAFT).xml $(DRAFT).txt $(DRAFT).html

.PHONY: all clean
