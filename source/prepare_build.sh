#!/bin/sh
topdir=..
tccdir=..
tcc4tcldir=../tcc4tcl
win32=../win32


mkdir $tcc4tcldir
cp ./*.tcl $tcc4tcldir
cp ./*.h   $tcc4tcldir
cp ./*.c   $tcc4tcldir

mkdir $tcc4tcldir/lib
cp ./lib/* $tcc4tcldir/lib
cp ./lib/* $tccdir/lib

cp ./modify/*.bat $win32
#cp ./modify/VERSION $tccdir
version=`head $tccdir/VERSION`
at=$(stat -c '%.19y' $tccdir/README)
echo>$tccdir/VERSION "$version mob $at"
echo "Version $at"

cp ./modify/*.tcl $tccdir

#modify tcc.c
$tccdir/mod_tcc.tcl 

cp -r ./linux/* $tccdir
cp -r ./include/* $tccdir/include/
cp -r ./win32include/* $tccdir/win32/include/

#cp $tccdir/include/* $tccdir/include/stdinc
