#ifdef _WIN32  
#define CONFIG_TCC_SYSINCLUDEPATHS "{B}/include;{B}/include/stdinc;{B}/include/winapi;{B}/win32;{B}/win32/winapi;"
#else
#define CONFIG_TCC_SYSINCLUDEPATHS "{B}/include/stdinc/:{B}/include/"
#endif
# if defined TCC_TARGET_PE || defined _WIN32
#  define CONFIG_TCC_LIBPATHS "{B}/lib_win32"
#endif
