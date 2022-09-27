# tcc4tcl_internal_dev
Internal Develop Repo for tcc4tcl

2022-07-28

Repo holds single files that prepare the next generation patch for tcc > 0.9.27 (development branch from mob, upcoming release 0.9.28 etc)
and regulary updated tars of the latest tcc mob branch.

The new patch tries to reduce the need to patch the file IO from tcc in every single sourcecode, 
but overwrite them by #define and thus linking to TCL IO Versions where needed.

Also contains some small patches/bugfixes to tcc4tcl to work properly with later versions of tcc

Make/Build process is using original makefiles and modifies/adds the necessary stuff to build and package tcc4tcl

Source packages to compile and pre-compile binary packages of tcc4tcl are in the packages dir.

