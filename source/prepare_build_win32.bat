@echo off
set topdir=..
set tccdir=..
set tcc4tcldir=..\tcc4tcl
set tcc4tclsrc=tcc4tcl
set win32=..\win32
set win32src=win32

mkdir %tcc4tcldir%
copy %tcc4tclsrc%\*.tcl %tcc4tcldir%
del %tcc4tcldir%\mod_tcc.tcl
copy .\%tcc4tclsrc%\mod_tcc.tcl %tccdir%

copy %tcc4tclsrc%\*.h   %tcc4tcldir%
copy %tcc4tclsrc%\*.c   %tcc4tcldir%

mkdir %tcc4tcldir%\lib
copy .\lib\* %tcc4tcldir%\lib
copy .\lib\* %tccdir%\lib

copy .\%win32src%\*.bat %win32%
copy .\%win32src%\*.h %win32%
copy .\%win32src%\replace_bat_for_wine.tcl %win32%
rem copy .\%win32src%\VERSION %tccdir%

set /p VERSION= <%tccdir%\VERSION

FOR %%? IN ("..\README") DO (
    echo %VERSION% mob %%~t?>%tccdir%\VERSION
)

call ..\mod_tcc.tcl
@if errorlevel 1 echo "Please run mod_tcc.c manually!"

xcopy /s/i/q/y .\linux\* %tccdir%
xcopy /s/i/q/y .\include\* %tccdir%\include\

if not exist %tccdir%\win32\include\winapi\winsock2.h (
    echo "Copying missing winsock2 headers"
    xcopy /s/i/q/y .\win32winsock\* %tccdir%\win32\include\winapi\
)

mkdir %tccdir%\include\stdinc
copy %tccdir%\include\* %tccdir%\include\stdinc\

