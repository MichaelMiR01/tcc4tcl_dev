// additional configuration directives for tcc4tcl

#ifndef _USE_32BIT_TIME_T 
#define _USE_32BIT_TIME_T
#endif

//define PE_PRINT_SECTIONS

#ifndef _WIN32
#include <stdint.h>
#endif

#ifndef _WIN32
#ifdef TCC_TARGET_X86_64
# define CONFIG_LDDIR "lib/x86_64-linux-gnu"
#endif
#endif

/*
#ifdef _WIN32
#include <stdint.h>
typedef int64_t __time64_t;
#endif
*/

#ifdef HAVE_TCL_H
#ifndef USE_TCL_STUBS
#define USE_TCL_STUBS 1
#endif
#include <tcl.h>
#endif

#ifdef HAVE_TCL_H
#ifdef _WIN32  
#define CONFIG_TCC_SYSINCLUDEPATHS "{B}/include;{B}/include/stdinc;{B}/include/winapi;{B}/win32;{B}/win32/winapi;"
#else
#define CONFIG_TCC_SYSINCLUDEPATHS "{B}/include/stdinc/:{B}/include/"
#endif
#define CONFIG_TCCDIR "."
#endif
