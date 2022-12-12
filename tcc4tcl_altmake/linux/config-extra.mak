libtclstub86.a:
	./make_stubs.sh $(CC)

libtcc4tcl.o: tcc.h libtcc.h config.h
	. ./conf_tcc4tcl.sh; \
	$(CC) $(CPPFLAGS) $${TCC4TCL_CFLAGS} -DHAVE_TCL_H -DLIBTCC_AS_DLL -o libtcc4tcl.o -c tcc.c 
	
tcc4tcl.o: tcc4tcl/tcc4tcl.c tcc.h libtcc.h config.h
	. ./conf_tcc4tcl.sh; \
	$(CC) $(CPPFLAGS) $${TCC4TCL_CFLAGS} -DHAVE_TCL_H -DLIBTCC_AS_DLL -I.  -o tcc4tcl.o -c tcc4tcl/tcc4tcl.c

tcc4tcl: tcc4tcl.o libtcc4tcl.o libtclstub86.a
	. ./conf_tcc4tcl.sh; \
	$(CC) -shared -s -o tcc4tcl.so tcc4tcl.o libtcc4tcl.o $${TCC4TCL_LIBS}
	
# create tcl-package tarball from *current* git branch (including tcc-doc.html
# and converting two files to CRLF)
TCC4TCL-VERSION = 0.40.0
TCC4TCL_SRC = tcc4tcl
TCC4TCL_TRG = tcc4tcl-$(TCC4TCL-VERSION)
TCC4TCL_TRGLIB = "$(TCC4TCL_TRG)/lib"
TCC4TCL_TRGINC = "$(TCC4TCL_TRG)/include"
TCC4TCL_TRGWIN = "$(TCC4TCL_TRG)/win32"

INSTALL = install -m755
INSTALLD = install -dm755
INSTALLBIN = install -m755 $(STRIP_$(CONFIG_strip))
STRIP_yes = -s

LIBTCC1_W = $(filter %-win32-libtcc1.a %-wince-libtcc1.a,$(LIBTCC1_CROSS))
LIBTCC1_U = $(filter-out $(LIBTCC1_W),$(LIBTCC1_CROSS))
IB = $(if $1,$(IM) mkdir -p $2 && $(INSTALLBIN) $1 $2)
IBw = $(call IB,$(wildcard $1),$2)
IF = $(if $1,$(IM) mkdir -p $2 && $(INSTALL) $1 $2)
IFd = $(if $1,$(IM) $(INSTALLD) $1 $2)
IFw = $(call IF,$(wildcard $1),$2)
IR = $(IM) mkdir -p $2 && cp -r $1/. $2
IC = $(IM) mkdir -p $2 && cp -r $1 $2
IM = $(info -> $2 : $1)@

B_O = bcheck.o bt-exe.o bt-log.o bt-dll.o

# install progs & libs
#make  tcc4tcl package
pkg: tcc4tcl.so
	@-if [ ! -d $(TCC4TCL_TRG) ]; then mkdir $(TCC4TCL_TRG); fi
	@-cp $(TCC4TCL_SRC)/*.tcl $(TCC4TCL_TRG)
	@-cp *.so $(TCC4TCL_TRG)

	@$(call IBw,$(PROGS) $(PROGS_CROSS),"$(TCC4TCL_TRG)")
	@$(call IFw,$(LIBTCC1) $(B_O) $(LIBTCC1_U),"$(TCC4TCL_TRG)/lib")
	@
	@$(call IC,$(TOPSRC)/include/*, "$(TCC4TCL_TRG)/include")
	@$(call IC,$(TOPSRC)/include/*.h $(TOPSRC)/tcclib.h,"$(TCC4TCL_TRG)/include/stdinc")
	@$(call IC,$(TCC4TCL_SRC)/lib/*, "$(TCC4TCL_TRG)/lib")
	@$(call IC,$(TCC4TCL_SRC)/doc/*, "$(TCC4TCL_TRG)/doc")
	@$(call $(if $(findstring .so,$(LIBTCC)),IBw,IFw),$(LIBTCC),"$(TCC4TCL_TRG)")
	@$(call IF,$(TOPSRC)/libtcc.h,"$(TCC4TCL_TRG)/include/libtcc")
	@$(call IC,$(TOPSRC)/win32/examples/*, "$(TCC4TCL_TRG)/examples")
ifneq "$(wildcard $(LIBTCC1_W))" ""
	@$(call IC,$(TOPSRC)/win32/*, "$(TCC4TCL_TRG)/win32")
	@$(call IFw,$(TOPSRC)/win32/lib/*.def $(LIBTCC1_W),"$(TCC4TCL_TRG)/win32/lib")
	@$(call IR,$(TOPSRC)/win32/include,"$(TCC4TCL_TRG)/win32/include")
	@$(call IF,$(TOPSRC)/include/*.h $(TOPSRC)/tcclib.h,"$(TCC4TCL_TRG)/win32/include")
endif
	#@find $(TCC4TCL_TRG)/include -maxdepth 1 -type f -delete

