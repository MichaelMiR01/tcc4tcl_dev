@echo off
set topdir=..
set tccdir=..
set tcc4tcldir=..\tcc4tcl
set win32=..\win32

mkdir %tcc4tcldir%
copy .\*.tcl %tcc4tcldir%
copy .\*.h   %tcc4tcldir%
copy .\*.c   %tcc4tcldir%

mkdir %tcc4tcldir%\lib
copy .\lib\* %tcc4tcldir%\lib
copy .\lib\* %tccdir%\lib

copy .\modify\*.bat %win32%
copy .\modify\*.h %win32%
copy .\modify\replace_bat_for_wine.tcl %win32%
rem copy .\modify\VERSION %tccdir%

set /p VERSION= <%tccdir%\VERSION

FOR %%? IN ("..\README") DO (
    echo %VERSION% mob %%~t?>%tccdir%\VERSION
)

copy .\modify\mod_tcc.tcl %tccdir%

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

