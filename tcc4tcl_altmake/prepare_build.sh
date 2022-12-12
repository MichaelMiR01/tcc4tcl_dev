#!/bin/sh
topdir=..
tccdir=..
tcc4tcldir=../tcc4tcl
tcc4tclsrc=tcc4tcl
win32=../win32
win32src=win32


mkdir $tcc4tcldir
cp ./$tcc4tclsrc/*.tcl $tcc4tcldir
cp ./$tcc4tclsrc/*.h   $tcc4tcldir
cp ./$tcc4tclsrc/*.c   $tcc4tcldir

mkdir $tcc4tcldir/lib
cp ./lib/* $tcc4tcldir/lib
cp ./lib/* $tccdir/lib

mkdir $tcc4tcldir/doc
mkdir $tccdir/doc
cp ./$tcc4tclsrc/doc/* $tcc4tcldir/doc
cp ./$tcc4tclsrc/doc/* $tccdir/doc

cp ./$win32src/*.bat $win32
cp ./$win32src/*.h $win32
cp ./$win32src/replace_bat_for_wine.tcl $win32
#cp ./$win32src/VERSION $tccdir
version=`head $tccdir/VERSION`
at=$(stat -c '%.19y' $tccdir/README)
echo>$tccdir/VERSION "$version mob $at"
echo "Version $at"

cp ./$tcc4tclsrc/mod_tcc.tcl $tccdir
rm ./$tcc4tcldir/mod_tcc.tcl
#modify tcc.c
$tccdir/mod_tcc.tcl 

cp -r ./linux/* $tccdir
cp -r ./include/* $tccdir/include/

if ! test -e ${tccdir}/win32/include/winapi/winsock2.h ; then
    echo "Copying missing winsock2 headers"
    cp ./win32winsock/* ${tccdir}/win32/include/winapi/
fi


