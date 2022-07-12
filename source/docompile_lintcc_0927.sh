TCCDIR=./tcc
if ! [ "$1" = "" ]; then
    TCCDIR=$1
fi
echo $TCCDIR

gcc -Wfatal-errors -pthread -D_GNU_SOURCE -DTCC_TARGET_X86_64 -DONE_SOURCE -I../tcc_0.9.27-bin/include/generic $TCCDIR/tcc.c -o"./xtcc"  -L../tcc_0.9.27-bin/lib -ldl -O2 
read -rsp $'Press enter to continue...\n'
