# tcc4tcl_dev
Develop Repo for tcc4tcl (Next generation tcc4tcl)

This repo holds the neccessary files to prepare the next generation patch for tcc >= 0.9.27 (development branch from mob, upcoming release 0.9.28 etc)
and regulary updated tars of the latest tcc mob branch.

tcc4tcl traditionally is a heavily patched version of tcc, since tcl brings it's own vfs. To handle files, that are covered by tcl-vfs only (tclkits) the file i/o routines of tcc had to be patched. That's the (only) reason, why using the standard libtcc is not possible.

The new patch tries to reduce the need to patch the file IO from tcc in every single sourcecode, 
but overwrite them by #define and thus linking to TCL IO Versions where needed.

Also contains some small patches/bugfixes to tcc4tcl to work properly with latest versions of tcc.

Make/Build process is using original makefiles and modifies/adds the necessary stuff to build and package tcc4tcl

Source packages to compile and pre-compiled binary packages of tcc4tcl are in the [tcc4tcl-packages/](tcc4tcl-packages/) dir.

For details on implementation and build process goto [tcc4tcl_altmake/readme.md](./tcc4tcl_altmake/readme.md)
