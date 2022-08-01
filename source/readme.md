This set of files treis to automate the process of adopting new versions of tcc to tcc4tcl
It consists of some scripts that try to modify tcc.c and hook in the tcl_iomap.c
Furthermore it tries to hook the configure/make process as far as possible without modifying the Makefile

Howto:
1 Download tcc and unpack it into DIR
2 Put tcc4tcl_altmake as a subdir int DIR
3	Prepare build files
 	
	cd DIR/tcc4tcl_altmake
	prepare_build.sh

3a under window run prepare_build_win32.bat
	then you have to manually adopt tcc.c
	or run mod_tcc.tcl from a tclsh/tclkit

4  build under linux:
	
	cd DIR
	./configure
	make

this make the normal tcc and libtcc1.a
	
	make tcc4tcl

now the neccessary files should be compiled, especially tcc4tcl.so

	make pkg

will make a subdir tcc4tcl-0.40.0-pkg

4a build under windows
	
	prepare_build.bat
	cd DIR/win32
	build-tcc4tcl-win32.bat (-t 32 -c PATH/TO/GCC/gcc.exe)

will make a subdir tcc4tcl-0.40.0-pkg

test:
	cd tcc4tcl-0.40.0-pkg
	tclsh test.tcl



