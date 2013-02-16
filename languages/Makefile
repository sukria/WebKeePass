
POFILES=$(wildcard *.po)
MOFILES=$(POFILES:.po=.mo)
PACKAGE=WebKeePass
POFILES_SRC=$(PACKAGE).list
.SUFFIXES: .po .mo

all: $(PACKAGE).pot $(POFILES) $(MOFILES)

$(POFILES_SRC):
	find ../lib -type f -name \*.pm | sort > $(POFILES_SRC)
	find ../views -type f -name \*.tt | sort >> $(POFILES_SRC)

$(PACKAGE).pot: $(POFILES_SRC)
	xgettext.pl -o $(PACKAGE).pot --files-from=$(POFILES_SRC)

clean:
	rm -f $(PACKAGE).pot \
		  $(POFILES_SRC) \
	      $(MOFILES) 
		  
.po.mo: $(PACKAGE).pot
	@echo "Merging $(PACKAGE).pot and $*.po"
	@msgmerge $*.po $(PACKAGE).pot -o $*.po.new
	@mv $*.po.new $*.po
	@msgfmt --statistics $*.po
	@msgfmt --no-hash -o $*.mo $*.po

check:
	@for file in $(POFILES); do \
		lang=`echo $$file | sed 's/\.po//'`; \
		printf "$$lang: "; \
		msgfmt -o /dev/null -c -v --statistics $$lang.po;\
	done
