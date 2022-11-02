This set of files tries to automate the process of adopting new versions of tcc to tcc4tcl

It consists of some scripts that try to modify tcc.c and hook in the tcl_iomap.c

Furthermore it tries to hook the configure/make process as far as possible without modifying the Makefile

Howto:

1 Download tcc and unpack it into DIR

2 Put tcc4tcl_altmake as a subdir into DIR

3       Prepare build files

        cd DIR/tcc4tcl_altmake
        prepare_build.sh

3a under windows run 

        prepare_build_win32.bat

then you have to manually adopt tcc.c
or run mod_tcc.tcl from a tclsh/tclkit
The batch will try to call mod_tcc.tcl directly, 
so if a tclsh is in your system path this may work

4  build under linux:

        cd DIR
        ./configure
        make

this will make the normal tcc and libtcc1.a

        make tcc4tcl

now the neccessary files should be compiled, especially tcc4tcl.so

        make pkg

will make a subdir tcc4tcl-0.40.0-pkg and place all necessary files there to make a tcl package

4a build under windows:

        cd DIR/win32
        build-tcc4tcl-win32.bat (-t 32 -c PATH/TO/GCC/gcc.exe)

will make a subdir tcc4tcl-0.40.0-pkg (or use the existing from the linux-build :-)

test:

        cd tcc4tcl-0.40.0-pkg
        tclsh test.tcl

For wine users:

the normal build-tcc.bat uses if (%1)== ... wich, at least under my version of wine, fail.
to avoid this, use replace_bat_for_wine.tcl wich will replace all () with _ _ in build-tcc.bat
so it will work under wine (and still under windows also)

Modifications to tcc sources

        mod_tcc.tcl tries to find and modify only a few lines

```     
*** tcc.c      
***************
*** 19,25 ****
   */

  #include "tcc.h"
+ #include "tcc4tcl/tcl_iomap.c"
  #if ONE_SOURCE
  # include "libtcc.c"
  #endif

--- 19,24 ----

*** libtcc.c	
***************
*** 854,863 ****
      cstr_free(&s1->cmdline_incl);
  #ifdef TCC_IS_NATIVE
      /* free runtime memory */
+ #ifndef HAVE_TCL_H
    tcc_run_free(s1);
+ #endif
  #endif
      tcc_free(s1->dState);
      tcc_free(s1);
--- 854,860 ----
```

A word on tclstubs // tkstubs

The tcl stubs libraries are simply compiled archives. They get compiled from

        libtclstub86.a tclStubLib.o tclOOStubLib.o tclTomMathStubLib.o
                
        libtkstub86.a tkStubLib.o ttkStubLib.o
        

from the corresponding .c sources.

But I found, that tcc is a bit picky with it's own libraries. So a stub compiled from tcc-win will fail if linked from tcc-lin, when used under the same architecture.

Actually, if you want to run both tcc4tcl side by side, they will have to use seperated stubs. In my case, I run tcc-linux 64bit and tcc-win32, so the stubs are separated into tclstub86elf.a (compiled 32bit under windows) and tclstubs86_64.a (compiled under linux 64bit). GCC needs it's own stubs.

So, if in doubt, recompile the stubs manually from source, all necessary sourcefiles are included in tcc4tcl packages (include/generic), under linux you can additionally install tcl-dev and use the sources from there.

