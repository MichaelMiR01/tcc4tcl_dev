// additional configuration directives for tcc4tcl

#ifndef _USE_32BIT_TIME_T 
#define _USE_32BIT_TIME_T
#endif

//define PE_PRINT_SECTIONS

#ifndef _WIN32
#include <stdint.h>
#endif

#if !(TCC_TARGET_I386 || TCC_TARGET_X86_64 || TCC_TARGET_ARM || TCC_TARGET_ARM64 || TCC_TARGET_RISCV64 || TCC_TARGET_C67)
#define TCC_TARGET_X86_64 1
#define CONFIG_TRIPLET "x86_64-linux-gnu"
#endif

#ifndef _WIN32
#ifdef TCC_TARGET_X86_64
//# define CONFIG_LDDIR "lib"
// this seems oddly to oscillate in deferrent mobs, 
// due to changes in makefile and config
// i don't understand and can't reflect on
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

#define TCC4TCL_DODELETE

#define TCC4TCL_DODELETE
