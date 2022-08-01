@rem ------------------------------------------------------
@rem batch file to build tcc using mingw, msvc or tcc itself
@rem ------------------------------------------------------
rem build-tcc4tcl-win32.bat -t 32 -c ../tcc_0.9.27-bin/gcc/bin/gcc.exe
rem  .\build-tcc4tcl-win32.bat -t 32 -c ..\..\tcc_0.9.27-bin\gcc\bin\gcc.exe -i C:\D\Toolbox\tcl\tcc4tclinst
@echo off
setlocal
if "%1"=="-clean" goto :cleanup
set CC=gcc
set INST=
set DOC=no
set EXES_ONLY=no
set HAS_WIN32_DIR=yes
set topdir=..
set tccdir=..
set tcc4tcldir=..\tcc4tcl
set win32=.
set BIN=
set /p VERSION= <%tccdir%\VERSION

goto :a0
:a2
shift
:a3
shift
:a0
if not "%1"=="-c" goto :a1
set CC=%~2
if "%2"=="cl" set CC=@call :cl
goto :a2
:a1
if "%1"=="-t" set T=%2&& goto :a2
if "%1"=="-v" set VERSION=%~2&& goto :a2
if "%1"=="-i" set INST=%2&& goto :a2
if "%1"=="-b" set BIN=%2&& goto :a2
if "%1"=="-d" set DOC=yes&& goto :a3
if "%1"=="-x" set EXES_ONLY=yes&& goto :a3
if "%1"=="-u" set HAS_WIN32_DIR=no&& goto :a3
if "%1"=="" goto :p1
:usage
echo usage: build-tcc.bat [ options ... ]
echo options:
echo   -c prog              use prog (gcc/tcc/cl) to compile tcc
echo   -c "prog options"    use prog with options to compile tcc
echo   -t 32/64             force 32/64 bit default target
echo   -v "version"         set tcc version
echo   -i tccdir            install tcc into tccdir
echo   -b bindir            optionally install binaries into bindir elsewhere
echo   -d                   create tcc-doc.html too (needs makeinfo)
echo   -x                   just create the executables
echo   -u                   use unified include dir (else will install two include paths include and win32
echo   -clean               delete all previously produced files and directories
exit /B 1

@rem ------------------------------------------------------
@rem sub-routines

:cleanup
echo Cleanup 
set LOG=echo
%LOG% removing files (partially outcommented MiR):
rem for %%f in (*tcc.exe libtcc.dll lib\*.a) do call :del_file %%f
for %%f in (%tccdir%\config.h %tccdir%\config.texi) do call :del_file %%f
rem for %%f in (include\*.h) do @if exist ..\%%f call :del_file %%f
rem for %%f in (include\tcclib.h examples\libtcc_test.c) do call :del_file %%f
for %%f in (*.o *.obj *.def *.pdb *.lib *.exp *.ilk) do call :del_file %%f
goto :the_end
%LOG% removing directories:
for %%f in (doc libtcc) do call :del_dir %%f
%LOG% done.
exit /B 0
:del_file
if exist %1 del %1 && %LOG%   %1
exit /B 0
:del_dir
if exist %1 rmdir /Q/S %1 && %LOG%   %1
exit /B 0

:cl
@echo off
set CMD=cl
:c0
set ARG=%1
set ARG=%ARG:.dll=.lib%
if "%1"=="-shared" set ARG=-LD
if "%1"=="-o" shift && set ARG=-Fe%2
set CMD=%CMD% %ARG%
shift
if not "%1"=="" goto :c0
echo on
%CMD% -O1 -W2 -Zi -MT -GS- -nologo -link -opt:ref,icf
@exit /B %ERRORLEVEL%

@rem ------------------------------------------------------
@rem main program

:p1
if not %T%_==_ goto :p2
set T=32
if %PROCESSOR_ARCHITECTURE%_==AMD64_ set T=64
if %PROCESSOR_ARCHITEW6432%_==AMD64_ set T=64
:p2
if "%CC:~-3%"=="gcc" set CC=%CC% -Os -s -static
set D32=-DTCC_TARGET_PE -DTCC_TARGET_I386 -D_WIN%T% -m%T%
set D64=-DTCC_TARGET_PE -DTCC_TARGET_X86_64 -D_WIN%T% -m%T%
set P32=i386-win32
set P64=x86_64-win32
if %T%==64 goto :t64
set D=%D32%
set DX=%D64%
set PX=%P64%
set TX=64
goto :p3
:t64
set D=%D64%
set DX=%D32%
set PX=%P32%
set TX=32
goto :p3

:p3
rem @echo off
echo starting
echo Version %VERSION%
echo T %T%
echo HAS_WIN32_DIR %HAS_WIN32_DIR%

:config.h
echo building config
echo>%tccdir%\config.h #define TCC_VERSION "%VERSION%"
echo>> %tccdir%\config.h #ifdef TCC_TARGET_X86_64
echo>> %tccdir%\config.h #define TCC_LIBTCC1 "libtcc1-64.a"
echo>> %tccdir%\config.h #else
echo>> %tccdir%\config.h #define TCC_LIBTCC1 "libtcc1-32.a"
echo>> %tccdir%\config.h #endif
echo>>%tccdir%\config.h #ifdef _WIN32
echo>>%tccdir%\config.h #define CONFIG_WIN32 1
echo>>%tccdir%\config.h #define TCC_TARGET_PE 1
echo>>%tccdir%\config.h #endif
echo>>%tccdir%\config.h #define HOST_I386 1
echo>>%tccdir%\config.h #ifndef TCC_TARGET_X86_64
echo>>%tccdir%\config.h #define TCC_TARGET_I386 1
echo>>%tccdir%\config.h #endif
echo>>%tccdir%\config.h #ifdef _WIN32
echo>>%tccdir%\config.h #define _USE_32BIT_TIME_T 1
echo>>%tccdir%\config.h #include ^<stdint.h^>
echo>>%tccdir%\config.h typedef __int64 __time64_t;
echo>>%tccdir%\config.h #endif

for %%f in (*tcc.exe *tcc.dll) do @del %%f

:compiler
echo start compiling %D% 
rem @echo off

rem %CC% -DC2STR %tccdir%/conftest.c -o %tccdir%/c2str.exe %D% 
rem %tccdir%\c2str.exe %tccdir%\include\tccdefs.h %tccdir%\tccdefs_.h

%CC% -o libtcc.dll -shared -s %tccdir%\libtcc.c %D% -DLIBTCC_AS_DLL -O2
@if errorlevel 1 goto :the_end
%CC% -s -o tcc.exe %tccdir%\tcc.c libtcc.dll %D% -DONE_SOURCE"=0" -O2 -fwhole-program
echo start compiling %PX% %DX% 
%CC% -o %PX%-tcc.exe %tccdir%\tcc.c %DX% -O2

:tcl-stubs
rem echo we need a tclstubs from gcc to build tcc4tcl
set INCLUDES= -I../include/generic -I../include/generic/win -I../include/xlib 
set FPATH=../include/generic/
call :getPath %CC% filename folder
set AR=%folder%\ar -cr
echo %CC% %AR%
%CC% -m%T% -D_WIN%T% -c %FPATH%tclStubLib.c %INCLUDES%
%CC% -m%T% -D_WIN%T% -c %FPATH%tclOOStubLib.c %INCLUDES%
%CC% -m%T% -D_WIN%T% -c %FPATH%tclTomMathStubLib.c %INCLUDES%
%AR% libtclstub86.a tclStubLib.o tclOOStubLib.o tclTomMathStubLib.o
copy libtclstub86.a .\lib\
del *.o
del libtclstub86.a

rem build all other stubs by tcc
call .\make_stubs.bat




:tcc4tcl
echo starting build tcc4tcl
rem %CC% %target% %tccdir%/tcc.c -o tcc.exe -ltcc -Llibtcc
echo %CC% %target% -Wfatal-errors -DHAVE_TCL_H %D% -I%tccdir% -I%topdir%/include/generic -c %tccdir%/tcc.c  -Llib -L%topdir%/lib -ltclstub86 -o"libtcc.o" -O2
%CC% %target% -Wfatal-errors -DHAVE_TCL_H %D% -I%tccdir% -I%topdir%/include/generic -c %tccdir%/tcc.c  -Llib -L%topdir%/lib -ltclstub86 -o"libtcc.o" -O2
echo %CC% %target% -shared -s -DHAVE_TCL_H %D% -static-libgcc -I%tccdir% -I%topdir%/include/generic -I%topdir%/include/generic/win -Itcc  %tcc4tcldir%/tcc4tcl.c  -Llib -L%topdir%/lib -ltclstub86  "libtcc.o" -o"tcc4tcl.dll"
%CC% %target% -shared -s -DHAVE_TCL_H %D% -static-libgcc -I%tccdir% -I%topdir%/include/generic -I%topdir%/include/generic/win -Itcc  %tcc4tcldir%/tcc4tcl.c  -Llib -L%topdir%/lib -ltclstub86  "libtcc.o" -o"tcc4tcl.dll"

@if "%EXES_ONLY%"=="yes" goto :files-done

:copy-libtcc
echo copy libtcc %tccdir% to %win32%\libtcc
if not exist %win32%\libtcc mkdir %win32%\libtcc
rem if not exist doc mkdir doc
copy>nul %tccdir%\include\*.h %win32%\include
copy>nul %tccdir%\tcclib.h %win32%\include
copy>nul %tccdir%\libtcc.h %win32%\libtcc
rem copy>nul ..\tests\libtcc_test.c examples
rem copy>nul tcc-win32.txt doc

.\tcc -impdef libtcc.dll -o %win32%\libtcc\libtcc.def
@if errorlevel 1 goto :the_end

:libtcc1.a
set inc=-Iwin32 -Iwin32/winapi
echo building libtcc1 with includes %inc%
call :makelib %T%
@if errorlevel 1 echo "failed to crosscompile libtcc1.a"
@if exist %PX%-tcc.exe call :makelib %TX%
@if errorlevel 1 echo "failed to crosscompile libtcc1.a"
@set O1=libtcc1.o crt1.o crt1w.o wincrt1.o wincrt1w.o dllcrt1.o dllmain.o chkstk.o bcheck.o
rem .\tcc %inc% -m32 -w -c %tccdir%/lib/bcheck.c
.\tcc -m%T% -c %tccdir%/lib/bcheck.c -o lib/bcheck.o -g
.\tcc -m%T% -c %tccdir%/lib/bt-exe.c -o lib/bt-exe.o
.\tcc -m%T% -c %tccdir%/lib/bt-log.c -o lib/bt-log.o
.\tcc -m%T% -c %tccdir%/lib/bt-dll.c -o lib/bt-dll.o

rem @if errorlevel 1 goto :the_end
echo ready...

:tcc-doc.html
@if not "%DOC%"=="yes" goto :doc-done
echo>..\config.texi @set VERSION %VERSION%
cmd /c makeinfo --html --no-split ../tcc-doc.texi -o doc/tcc-doc.html
:doc-done

:files-done
for %%f in (*.o *.def) do @del %%f

:copy-install
@if "%INST%"=="" set INST=%topdir%\tcc4tcl-pkg-0.40.0
echo copy files to %INST%
if not exist %INST% mkdir %INST%
@if "%BIN%"=="" set BIN=%INST%
if not exist %BIN% mkdir %BIN%
for %%f in (*tcc.exe *tcc.dll *.dll) do @copy>nul %%~ff %BIN%\%%~nf%%~xf
copy %tccdir%\tcc4tcl\*.tcl %BIN%\
copy %topdir%\tcc4tcl\*.tcl %BIN%\
copy .\*.tcl %BIN%\

@if not exist %INST%\lib mkdir %INST%\lib

copy %tcc4tcldir%\lib\*.a %INST%\lib\
copy %topdir%\lib\*.a %INST%\lib\
copy %win32%\lib\*.a %INST%\lib\
copy .\lib\lib\*.a %INST%\lib\

copy %tcc4tcldir%\lib\*.def %INST%\lib\
copy %topdir%\lib\*.def %INST%\lib\
copy %win32%\lib\*.def %INST%\lib\
copy .\lib\lib\*.def %INST%\lib\


for %%f in (examples libtcc doc) do xcopy /s/i/q/y %win32%\%%f\ %INST%\%%f\
echo copying %topdir%\include %INST%\include
if not exist %INST%\include mkdir %INST%\include
xcopy /s/i/q/y %topdir%\include %INST%\include
echo deleting surplus files
del %INST%\include\*.*

set INSTWIN32=%INST%\include
if "%HAS_WIN32_DIR%"=="yes" set INSTWIN32=%INST%\win32

echo copying %win32%\include %INSTWIN32%
if not exist %INSTWIN32% mkdir %INSTWIN32%
xcopy /s/i/q/y %win32%\include %INSTWIN32%

:the_end
exit /B %ERRORLEVEL%

:makelib
.\tcc -m%1 -c %tccdir%/%win32%/lib/libtcc1.c
.\tcc -m%1 -c %win32%/lib/crt1.c
.\tcc -m%1 -c %win32%/lib/crt1w.c
.\tcc -m%1 -c %win32%/lib/wincrt1.c
.\tcc -m%1 -c %win32%/lib/wincrt1w.c
.\tcc -m%1 -c %win32%/lib/dllcrt1.c
.\tcc -m%1 -c %win32%/lib/dllmain.c
.\tcc -m%1 -c %win32%/lib/chkstk.S
.\tcc -m%1 -c %tccdir%/%win32%/lib/alloca.S
.\tcc -m%1 -c %tccdir%/%win32%/lib/alloca-bt.S
.\tcc -m%1 -c %tccdir%/%win32%/lib/stdatomic.c
.\tcc -m%1 -ar %win32%/lib/libtcc1-%1.a libtcc1.o crt1.o crt1w.o wincrt1.o wincrt1w.o dllcrt1.o dllmain.o chkstk.o alloca.o alloca-bt.o stdatomic.o
exit /B %ERRORLEVEL%

:getPath
rem call :getPath %Fullpath% filename folder
set "%2=%~nx1"
set "%3=%~dp1"
exit /b
