TCCDIR=./tcc
if ! [ "$1" = "" ]; then
    TCCDIR=$1
fi
echo $TCCDIR


gcc -Wfatal-errors -fPIC -DHAVE_TCL_H -D_GNU_SOURCE -DTCC_TARGET_X86_64 -DONE_SOURCE -DLIBTCC_AS_DLL -DUSE_TCL_STUBS -I/usr/include/tcl8.6 -I/usr/include/tcl8.6/tcl-private/generic -c $TCCDIR/tcc.c   -L/usr/lib/x86_64-linux-gnu -ltclstub8.6  -o"libtcc.o" -O2 
read -rsp $'Press enter to continue...\n'
gcc -Wfatal-errors -fPIC -DTCC_TARGET_X86_64 -DHAVE_TCL_H -DONE_SOURCE -DLIBTCC_AS_DLL -DUSE_TCL_STUBS -I/usr/include/tcl8.6/tcl-private/generic -I/usr/include/tcl8.6/tcl-private/unix -I/usr/include/tcl8.6 -I$TCCDIR -c tcc4tcl.c  -L/usr/lib/x86_64-linux-gnu -ltclstub8.6 -o"tcc4tcl.o" -O2 
read -rsp $'Press enter to continue...\n'

gcc -shared -s -o tcc4tcl.so libtcc.o tcc4tcl.o  -L/usr/lib/x86_64-linux-gnu -ltclstub8.6
read -rsp $'Press enter to continue...\n'

cp tcc4tcl.so ../tccide.vfs/lib/tcc4tcl-0.30/tcc4tcl.so
read -rsp $'Press enter to continue...\n'
