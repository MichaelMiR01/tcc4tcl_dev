now=$(date +"%y%m%d")
actdir=$( pwd )

tccpkgdir=$1
tccpkg=$1.tar.gz

if ! test -e tcc-mobs/${tccpkg} ; then
    echo "${tccpkg} not found"
    echo "Usage: make_src_bin_package.sh tcc_srcpackage_name [-s] [-w wincompiler]"
    echo "-s:                           make source package only"
    echo "-w path/to/win/gcc.exe:       use gcc.exe as windows compiler"
    exit 0
fi
echo "Using Package tcc-mobs/${tccpkg}"


if ! test $2 = "-w" ; then 
    wincc="z:\\host\\data\\tcl\\tcc_0.9.27-bin\\gcc\\bin\\gcc.exe"
else
    wincc="$3"
fi
    
echo "using wincompiler $wincc"

tcc4tclsrc=tcc4tcl_$1.tar.gz
tcc4tclbin=tcc4tcl_bin_$1.tar.gz

altmakepkg="tcc4tcl_altmake*.tar.gz"
altmakefiles=( $altmakepkg )
altmakepkg=$altmakefiles
echo "Using AltMake Package $altmakepkg"

tccmakedir=$( pwd )/tcc4tcl_makepackages/
echo "Using Dir $tccmakedir"
rm -r $tccmakedir
mkdir $tccmakedir

echo "Loading Package $tccpkg"

tar -zxvf tcc-mobs/$tccpkg -C $tccmakedir
tar -zxvf $altmakepkg -C $tccmakedir/$tccpkgdir

echo "Starting Preparation $actdir"
cd $tccmakedir/$tccpkgdir/tcc4tcl_altmake/
./prepare_build.sh
cd $tccmakedir/$tccpkgdir/win32/
./replace_bat_for_wine.tcl

cd $actdir
rm -r $tccmakedir/$tccpkgdir/tcc4tcl_altmake/

echo "Writing SRC Package $tcc4tclsrc"
cd $tccmakedir/$tccpkgdir/
tar -zcf $actdir/$tcc4tclsrc * --exclude=depr --exclude=cvs --exclude=backup_n.tcl
cd $actdir


if test $2 = "-s" ; then 
    echo "Source package only ... exit"
    exit 0 
fi

echo "Building BIN package win32 $wincc"
cd $tccmakedir/$tccpkgdir/
cd win32
wine start .\\build-tcc4tcl-win32.bat -t 32 -c z:\\host\\data\\tcl\\tcc_0.9.27-bin\\gcc\\bin\\gcc.exe
wineserver -w
cd ..
echo "Building BIN package linux $wincc"
./configure
make 
make tcc4tcl
make pkg

cd $actdir

tccbindir=tcc4tcl-0.40.0
cp $tccmakedir/$tccpkgdir/VERSION $tccmakedir/$tccpkgdir/$tccbindir/VERSION
echo "Writing BIN Package $tcc4tclbin"
cd $tccmakedir/$tccpkgdir/$tccbindir
tar -zcf $actdir/$tcc4tclbin * --exclude=depr --exclude=cvs --exclude=backup_n.tcl
cd $actdir

