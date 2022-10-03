@echo off
set ACTDIR=%cd%

rem if cross tcc is i386, native tcc is x86_64 and vice versa
set XTCC32=%ACTDIR%/i386-win32.exe
set XTCC64=%ACTDIR%/x86_64-win32-tcc.exe
set TCC=%ACTDIR%/tcc.exe

set T=32

rem default is win32
set TCC=%ACTDIR%/tcc.exe
set CC%T%=%TCC%
set AR%T%=%TCC% -ar 

echo %T% %CC32% %CC64%  

if exist ./include/winapi/windows.h (
    echo ok, we are in win32 subdir
    set INCLUDES=-Iinclude -Iinclude/winapi -I../include -I..include/stdinc -I../include/generic -I../include/generic/win -I../include/xlib 
    set FPATH=../include/generic/
    goto :prep_compile
)
if exist ./win32/winapi/windows.h (
    echo ok, we are in package subdir
    set INCLUDES=-Iinclude -Iinclude/stdinc -Iwin32 -Iwin32/winapi -Iinclude/generic -Iinclude/generic/win -Iinclude/xlib 
    set FPATH=./include/generic/
    goto :prep_compile
)

echo failed orienting in directory %cd%?
goto :the_end


:prep_compile
rem if no crosscompiler exists, it's hard to decide :-)
if exist %XTCC64% (
    set NATIVE=32
    set TCC=%ACTDIR%/tcc.exe
    set CC32=%TCC%
    set AR32=%TCC% -ar 
    call :make_stubs32
    set CC64=%XTCC64%
    set AR64=%XTCC64% -ar 
    rem call :make_stubs64
) else (
    if exist %XTCC32% (
        set NATIVE=64
        set CC32=%XTCC32%
        set AR32=%XTCC32% -ar 
        rem call :make_stubs32
        set TCC64=%ACTDIR%/tcc.exe
        set CC64=%TCC64%
        set AR64=%TCC64% -ar 
        call :make_stubs64
    ) else (
        rem no crosscompiler given
        set NATIVE=32
        set CC32=%ACTDIR%/tcc.exe
        set AR32=%ACTDIR%/tcc.exe -ar 
        call :make_stubs32
    )        
)
@if errorlevel 1 goto :the_end
copy /Y *stub*.a .\lib\
@if errorlevel 1 goto :the_end
del *stub*.a
goto :the_end

:make_stubs64
echo compile 64bit %CC64%
del *.o
%CC64% -c %FPATH%tclStubLib.c %INCLUDES%
%CC64% -c %FPATH%tclOOStubLib.c %INCLUDES%
%CC64% -c %FPATH%tclTomMathStubLib.c %INCLUDES%
%AR64% libtclstub86_64.a tclStubLib.o tclOOStubLib.o tclTomMathStubLib.o
del *.o
%CC64% -c %FPATH%tkStubLib.c %INCLUDES%
%CC64% -c %FPATH%ttkStubLib.c %INCLUDES%
%AR64% libtkstub86_64.a tkStubLib.o ttkStubLib.o
del *.o
exit /B

:make_stubs32
echo compile 32bit %CC32%
del *.o
%CC32% -c %FPATH%tclStubLib.c %INCLUDES%
%CC32% -c %FPATH%tclOOStubLib.c %INCLUDES%
%CC32% -c %FPATH%tclTomMathStubLib.c %INCLUDES%
%AR32% libtclstub86elf.a tclStubLib.o tclOOStubLib.o tclTomMathStubLib.o
del *.o
%CC32% -c %FPATH%tkStubLib.c %INCLUDES%
%CC32% -c %FPATH%ttkStubLib.c %INCLUDES%
%AR32% libtkstub86elf.a tkStubLib.o ttkStubLib.o
del *.o
exit /B

:the_end
del *.o
exit /B %ERRORLEVEL% 