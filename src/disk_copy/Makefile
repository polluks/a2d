HEADERS = $(COMMON_HEADERS) \
	$(SYS_FONTS) \
	../mgtk/mgtk.inc ../toolkits/btk.inc ../toolkits/lbtk.inc

include ../common/Makefile.common

TARGETS = $(OUTDIR)/disk_copy.built

.PHONY: clean all
all: $(OUTDIR) $(TARGETS)

$(OUTDIR):
	mkdir -p $(OUTDIR)

clean:
	rm -f $(OUTDIR)/*.o
	rm -f $(OUTDIR)/*.list
	rm -f $(OUTDIR)/*.font
	rm -f $(TARGETS)

$(OUTDIR)/disk_copy.o: disk_copy.s $(HEADERS) loader.s auxlc.s main.s ../toolkits/btk.s ../toolkits/lbtk.s
	../../bin/colorize ca65 $(CAFLAGS) --listing $(basename $@).list -o $@ $<

$(OUTDIR)/%.built: $(OUTDIR)/%.o ../common/asm.cfg
	../../bin/colorize ld65 $(LDFLAGS) -o '$@' $<
