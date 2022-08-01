#!/bin/sh
CC64="gcc"
CC32="gcc -m32" 
AR="ar cr"

ACTDIR=$(pwd) 

TCC_LIN32="${ACTDIR}/i386-tcc" 
TCC_LIN64="${ACTDIR}/x86_64-tcc" 
TCC_NATIVE="${ACTDIR}/tcc"

if test -e ${TCC_NATIVE}; then
    CC=${TCC_NATIVE}
    AR="${TCC_NATIVE} -ar "
fi

if test -e ${TCC_LIN32}; then
    CC32=${TCC_LIN32}
    AR="${TCC_LIN32} -ar "
fi

if test -e ${TCC_LIN64}; then
    CC64=${TCC_LIN64}
    AR="${TCC_LIN64} -ar "
fi

echo "compile $CC32 $CC64"

INCLUDES="-Iinclude/generic -Iinclude/generic/unix -Iinclude/generic/win -Iinclude/xlib -Iinclude -Iinclude/stdinc"
FPATH="./include/generic/"

rm *.o
${CC64} -c ${FPATH}tclStubLib.c ${INCLUDES}
${CC64} -c ${FPATH}tclOOStubLib.c ${INCLUDES}
${CC64} -c ${FPATH}tclTomMathStubLib.c ${INCLUDES}
${AR} libtclstub86_64.a tclStubLib.o tclOOStubLib.o tclTomMathStubLib.o

rm *.o
${CC32} -c ${FPATH}tclStubLib.c ${INCLUDES}
${CC32} -c ${FPATH}tclOOStubLib.c ${INCLUDES}
${CC32} -c ${FPATH}tclTomMathStubLib.c ${INCLUDES}
${AR} libtclstub86elf.a tclStubLib.o tclOOStubLib.o tclTomMathStubLib.o

rm *.o
${CC64} -c ${FPATH}tkStubLib.c ${INCLUDES}
${CC64} -c ${FPATH}ttkStubLib.c ${INCLUDES}
${AR} libtkstub86_64.a tkStubLib.o ttkStubLib.o

rm *.o
${CC32} -c ${FPATH}tkStubLib.c ${INCLUDES}
${CC32} -c ${FPATH}ttkStubLib.c ${INCLUDES}
${AR} libtkstub86elf.a tkStubLib.o ttkStubLib.o

rm *.o
