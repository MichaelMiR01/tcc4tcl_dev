set TCCDIR=./tcc

if not "%1"=="" (
    set TCCDIR=%1
)

set INCLIBDIR=../tcc_0.9.27-bin

"%INCLIBDIR%/gcc/bin/gcc.exe" -Wfatal-errors -m32 -DHAVE_TCL_H -D_WIN32 -DONE_SOURCE -I%INCLIBDIR%/include/generic  -c %TCCDIR%/tcc.c  -L%INCLIBDIR%/lib -ltclstub86 -o"libtcc.o" -O2 
pause

"%INCLIBDIR%/gcc/bin/gcc.exe" -shared -s -m32 -DUSE_TCL_STUBS -DHAVE_TCL_H -D_WIN32 -static-libgcc -I%INCLIBDIR%/include/generic -I%INCLIBDIR%/include/xlib -I%INCLIBDIR%/include/generic/win -I%TCCDIR%  tcc4tcl.c  -L"%INCLIBDIR%/lib" -ltclstub86 -ltkstub86 -L"%INCLIBDIR%/lib" "libtcc.o" -o"tcc4tcl.dll" 
pause

copy tcc4tcl.dll ..\tccide.vfs\lib\tcc4tcl-0.30\
pause