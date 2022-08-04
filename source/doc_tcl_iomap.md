Explanation of tcl_iomap.c for tcc4tcl

1.	Why this patch is needed?

Usually, libtcc should be sufficient to integrate tinycc into an application; that’s what it was intended to do at least. But with TCL things get complicated and even more so if tclkits are involved. To adress TCLs internal VFS and read files from a starkit libtcc can not resort to standard file IO, but has to use the TCL_ based reoutines. 
In tcc4tcl 0.30.0, based on tcc 0.9.26 this was solved with dedicated patches to the tinycc sourcecode. I also patch 0.9.27 manually, but that was tedious and moreover the patched source won’t compile to a standard executable tcc. 
To be clear: This patch is inteded for use with tcc 0.9.27 and higher, it will fail with 0.9.26!

2.	How does it work?

To solve this, tcl_iomap.c redefines some file IO functions, that tcc/libtcc uses and remaps them to custom functions. These  try to emulate the behaviour of standard file IO as close as possible while rerouting part of the file IO to TCL based operations.
There are #ifdef HAVE_TCL_H directives in place, resulting in the default build process dropping the invokation of tcl_iomap.c completely, yielding a regular tcc executable if compiled without -DHAVE_TCL_H.
To integrate the patch there is still one modification to be made to tcc.c, that is #include tcl_iomap.c after include tcc.h. 

3.	Pitfalls

Redefining functions is an uncommon practice. Someone on Stackoverflow said „Not to use in production code“. Redefining file IO in special can yield unwanted sideeffects, so let’s be careful.
tcl_iomap.c redefines only a part of standard file io, ewich is used by tcc/libtcc. At the time of writing (2022-August) these are

```
#define open t_open
#define close t_close
#define fdopen t_fdopen
#define fclose t_fclose
#define read t_read
#define lseek t_lseek
#define fgets t_fgets
#define dup t_dup
```

Some of these are in use in the official 0.9.27 release and are not used anymore in recent mob branches (dup). But if later maintainers of tcc decide to introduce the usage of further file io functions, this patch will fail.

4.	Tcl_iomap internals

In the first place, open and fdopen scan the opening flags given. Write operations are not rerouted, but fall directly through to their native implementations. Read operations yield a TCL_Channel, wich is put into a lookuptable and mapped to an integer. To make it possible to recognize tcl_channels from native filehandles, the integer is mapped to 10000-10128. Usually, no native filehandle should reach that range, but in case, this can lead to trouble. Debug here if in trouble.
fdopen will try to get a native filehandle from tcl, otherwise it will place the tcl_channel on a stack and fgets gets rerouted to TCL_Read based fgets. This practice can lead to trouble, if multiple channels are fdopened and read from, because fdopen does not retain the original filehandle, but ressorts to it’s stack. In 0.9.27 release, fdopen/fgets is used to read .def files in tccpe.c, one at a time, so no confusion here. Later versions droped this altogether, so fdopen is only used to read COFF files from tcccoff.c

