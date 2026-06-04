#!/bin/sh
CC64="gcc -m64"
CC32="gcc -m32" 
AR="ar rcs"

ACTDIR=$(pwd) 
HOSTCC="gcc -fPIC"
HOSTAR="ar rcs"

echo "Host ${HOSTCC}"

TCC_LIN32="${ACTDIR}/i386-tcc" 
TCC_LIN64="${ACTDIR}/x86_64-tcc" 
TCC_NATIVE="${ACTDIR}/tcc"

if test -e ${TCC_NATIVE}; then
    CC32="${TCC_NATIVE}  "
    CC64="${TCC_NATIVE}  "
    AR="${TCC_NATIVE} -ar "
fi

if test -e ${TCC_LIN32}; then
    CC32=${TCC_LIN32}
	CC64="${TCC_NATIVE} -m64"
    AR="${TCC_NATIVE} -ar "
fi

if test -e ${TCC_LIN64}; then
    CC64=${TCC_LIN64}
	CC32="${TCC_NATIVE} -m32"
    AR="${TCC_NATIVE} -ar "
fi


#remove old libs
rm tclStubLib.o tclOOStubLib.o tclTomMathStubLib.o tkStubLib.o ttkStubLib.o
rm libtclstub*.a
rm libtkstub*.a

echo "compile $CC32 $CC64"

INCLUDES="-Iinclude/generic -Iinclude/generic/unix -Iinclude/xlib -Iinclude -Iinclude/stdinc"
#INCLUDES="-Iinclude/generic -Iinclude/generic/unix -Iinclude/generic/win -Iinclude/xlib -Iinclude -Iinclude/stdinc"
FPATH="./include/generic/"

${HOSTCC} -c ${FPATH}tclStubLib.c ${INCLUDES}
${HOSTCC} -c ${FPATH}tclOOStubLib.c ${INCLUDES}
${HOSTCC} -c ${FPATH}tclTomMathStubLib.c ${INCLUDES}
${HOSTAR} libtclstub86.a tclStubLib.o tclOOStubLib.o tclTomMathStubLib.o
${HOSTCC} -c ${FPATH}tkStubLib.c ${INCLUDES}
${HOSTCC} -c ${FPATH}ttkStubLib.c ${INCLUDES}
${HOSTAR} libtkstub86.a tkStubLib.o ttkStubLib.o

rm tclStubLib.o tclOOStubLib.o tclTomMathStubLib.o tkStubLib.o ttkStubLib.o

# build with tcc for x86_64

${CC64} -c ${FPATH}tclStubLib.c ${INCLUDES}
${CC64} -c ${FPATH}tclOOStubLib.c ${INCLUDES}
${CC64} -c ${FPATH}tclTomMathStubLib.c ${INCLUDES}
${AR} libtclstub86_64.a tclStubLib.o tclOOStubLib.o tclTomMathStubLib.o
if test -s libtclstub86_64.a; then
    echo "libtclstub86_64.a ok"
else 
    echo "libtclstub86_64.a failed"
    rm libtclstub86_64.a 
fi 

${CC64} -c ${FPATH}tkStubLib.c ${INCLUDES}
${CC64} -c ${FPATH}ttkStubLib.c ${INCLUDES}
${AR} libtkstub86_64.a tkStubLib.o ttkStubLib.o
if test -s libtkstub86_64.a; then
    echo "libtkstub86_64.a ok"
else 
    echo "libtkstub86_64.a failed"
    rm libtkstub86_64.a 
fi 


rm tclStubLib.o tclOOStubLib.o tclTomMathStubLib.o tkStubLib.o ttkStubLib.o

# build with tcc for lin32

${CC32} -c ${FPATH}tclStubLib.c ${INCLUDES}
${CC32} -c ${FPATH}tclOOStubLib.c ${INCLUDES}
${CC32} -c ${FPATH}tclTomMathStubLib.c ${INCLUDES}
${AR} libtclstub86elf.a tclStubLib.o tclOOStubLib.o tclTomMathStubLib.o
if test -s libtclstub86elf.a; then
    echo "libtclstub86elf.a ok"
else 
    echo "libtclstub86elf.a failed"
    rm libtclstub86elf.a 
fi 

${CC32} -c ${FPATH}tkStubLib.c ${INCLUDES}
${CC32} -c ${FPATH}ttkStubLib.c ${INCLUDES}
${AR} libtkstub86elf.a tkStubLib.o ttkStubLib.o
if test -s libtkstub86elf.a; then
    echo "libtkstub86elf.a ok"
else 
    echo "libtkstub86elf.a failed"
    rm libtkstub86elf.a 
fi 

rm tclStubLib.o tclOOStubLib.o tclTomMathStubLib.o tkStubLib.o ttkStubLib.o

echo "Stubsbuilding ready OK"
cp libtcl*.a lib/
cp libtk*.a lib/

#cp libtcl*.a /host/data/tcl/tcc_0.9.27-bin/lib/
#cp libtk*.a /host/data/tcl/tcc_0.9.27-bin/lib/

