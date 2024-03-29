#! /usr/bin/env tclsh

catch {console show}

lappend auto_path [lindex $argv 0]
package require tcc4tcl
package require critcl

tcc4tcl::cproc test {int i} int { return(i+42); }
tcc4tcl::cproc test1 {int i} int { return(i+42); }
tcc4tcl::cproc ::bob::test1 {int i} int { return(i+42); }

# This will fail
catch {
	tcc4tcl::cproc test2 {int i} int { badcode; }
}

# This should work
tcc4tcl::cproc test3 {int i} int { return(i+42); }

# Multiple arguments
tcc4tcl::cproc add {int a int b} int { return(a+b); }

# Add external functions
# this fails under windows
catch {
tcc4tcl::cproc mkdir {Tcl_Interp* interp char* dir} ok {
	int mkdir_ret;
	mkdir_ret = mkdir(dir);

	if (mkdir_ret != 0) {
		Tcl_SetObjResult(interp, Tcl_NewStringObj("failed", -1));
		return(TCL_ERROR);
	};
	return(TCL_OK);
}
}

# Return error on NULL
tcc4tcl::cproc test4 {int v} char* {
	if (v == 1) {
		return("ok");
	}

	return(NULL);
}

puts [test 1]
puts [test1 1]
puts [test3 1]
puts [::bob::test1 1]
puts [add [test 1] 1]
puts [test4 1]

catch {
	puts [mkdir "/"]
} err
if {$err != "failed"} {
	puts "\[mkdir\] did not return the expected error"
}

catch {
	set v 0
	puts [test4 0]
	set v 1
} err
if {$err != "" || $v == 1} {
	error "\[test4\] did not return the expected error"
}

# New API
## Test processing the commandline
set handle [tcc4tcl::new]
$handle process_command_line -Dx=1234
$handle cproc test13 {int i} int {
	return(i+x);
}
$handle go
puts "[test13 1] = 1235"

## Simple test
set handle [tcc4tcl::new]
$handle cproc test5 {int i} int { return(i + 42); }
if {[$handle code] == ""} {
	error "[list $handle code] did not give code output"
}
$handle cproc test6 {int i} int { return(i + 42); }
$handle go
puts [test5 1]
puts [test6 1]

## Delete without performing
set handle [tcc4tcl::new]
$handle delete

# External functions
if {[info exists ::env(TCC4TCL_TEST_RUN_NATIVE)]} {
	set handle [tcc4tcl::new]
	$handle cwrap curl_version {} vstring
	$handle add_library_path [::tcl::pkgconfig get libdir,runtime]
	$handle add_library_path /usr/lib/x86_64-linux-gnu
	$handle add_library_path /usr/lib64
	$handle add_library_path /usr/lib
	$handle add_library_path /usr/lib32
	$handle add_library curl
	$handle go
	puts [curl_version]
}

# wide values
set handle [tcc4tcl::new]
$handle cproc wideTest {Tcl_WideInt x} Tcl_WideInt {
	return(x);
}
$handle go
puts [wideTest 30]

# Produce a loadable object
## Currently doesn't work on Darwin
if {false && [info exists ::env(TCC4TCL_TEST_RUN_NATIVE)] && $::tcl_platform(os) != "Darwin"} {
	set tmpfile "/tmp/DELETEME_tcc4tcl_test_exec[expr rand()].so"
	file delete $tmpfile
	set handle [tcc4tcl::new $tmpfile "myPkg 0.1"]
	$handle cproc ext_add {int a int b} long { return(a+b); }
	$handle add_include_path [::tcl::pkgconfig get includedir,runtime]
	$handle add_library_path [::tcl::pkgconfig get libdir,runtime]
	$handle add_library_path /usr/lib/x86_64-linux-gnu
	$handle add_library_path /usr/lib64
	$handle add_library_path /usr/lib
	$handle add_library_path /usr/lib32
	$handle add_library tclstub${::tcl_version}
	$handle go
	load $tmpfile myPkg
	puts [ext_add 1 42]
	file delete $tmpfile
}

# More involved test
if {[info exists ::env(TCC4TCL_TEST_RUN_NATIVE)]} {
	set handle [tcc4tcl::new]
	$handle ccode {
#include <stdint.h>
#include <curl/curl.h>
}
	$handle cwrap curl_version {} vstring
	$handle cproc curl_fetch {char* url} ok {
		void *handle;

		handle = curl_easy_init();
		if (!handle) {
			return(TCL_ERROR);
		}

		curl_easy_setopt(handle, CURLOPT_URL, url);
		curl_easy_perform(handle);

		return(TCL_OK);
	}
	$handle add_include_path /usr/include
	$handle add_library_path [::tcl::pkgconfig get libdir,runtime]
	$handle add_library_path /usr/lib/x86_64-linux-gnu
	$handle add_library_path /usr/lib64
	$handle add_library_path /usr/lib
	$handle add_library_path /usr/lib32
	$handle add_library curl
	$handle go
    
	curl_fetch http://rkeene.org/
}

set handle [tcc4tcl::new]
$handle proc callToTcl {Tcl_Interp* ip int a int b} int {
	set retval [expr {$a + $b}]

	return $retval
}
$handle cwrap callToTcl {Tcl_Interp* ip int a int b} int
$handle go
if {[callToTcl 3 5] != 8} {
	error "3 + 5 is 8, not [callToTcl 3 5]"
}

set handle [tcc4tcl::new]
$handle proc callToTcl1 {int x} float {
	return 0.1
}
$handle cwrap callToTcl1 {int x} float
$handle go
puts [callToTcl1 3]

set handle [tcc4tcl::new]
$handle proc callToTclBinary {char* blob int blob_Length} ok {
	puts "Blob: $blob ([string length $blob])"
}
$handle cproc callToTclBinaryWrapper {} void {
	callToTclBinary("test\x00test", 9);
}
puts [$handle code]
$handle go

callToTclBinaryWrapper

puts "Testing external symbol insertion"
puts "adr of callToTclBinary [tcc4tcl::lookup_Symbol callToTclBinary]"
set handle [tcc4tcl::new]

foreach {sym adr} $tcc4tcl::__symtable {
    $handle add_symbol $sym $adr
    #puts "Added $sym $adr"
}

if { [tcc4tcl::lookup_Symbol callToTclBinary]==""} {
	puts "Symboltable seems broken... getting symbol directly"
	set adr [tcc get_symbol callToTclBinary]
	if {$adr ne ""} {
		puts "Found Symbol callToTclBinary $adr"
		$handle add_symbol callToTclBinary $adr
	}
}



$handle ccode {
    extern int callToTclBinary(char* blob, int blob_Length);
}
$handle cproc callToTclBinaryWrapper2 {} void {
	callToTclBinary("test\x00test", 9);
}
$handle go

callToTclBinaryWrapper2
puts "Ok"

#testing for tclwrap
proc tcl_test {a b} {# pure tcl proc
    if {$a ne ""} {
        return "$a\nOK, Result of 2* $b = [expr $b*2]"
    }
    return [expr $b*2]
}

set handle [tcc4tcl::new]
$handle tclwrap tcl_test {char* text int i} char* mytest1
$handle cproc c_tcl_test {char* text int i1} char* {
    return mytest1(text,i1); 
}

$handle go
puts [tcl_test "call tcl_test from TCL" 123]
puts [c_tcl_test "call tcl_test from C" 123]


set handle [tcc4tcl::new]
$handle cproc testClientData {int y} {int} [concat "int x = 3;" {
	return(x + y);
}]
$handle go
set testVal [testClientData 1]
if {$testVal != "4"} {
	error "\[ClientData\] Invalid value: $testVal, should have been 4"
}

set handle [tcc4tcl::new]
$handle cproc testClientData {ClientData _x=3 int y} {int} {
	int x

	Tcl_GetIntFromObj(NULL, _x, &x);

	return(x + y);
}
set testVal [testClientData 1]
if {$testVal != "4"} {
	error "\[ClientData\] Invalid value: $testVal, should have been 4"
}

set handle [tcc4tcl::new]
$handle ccommand testCCommand {dummy ip objc objv} {
	Tcl_SetObjResult(ip, Tcl_NewStringObj("OKAY", 4));

	return(TCL_OK);
}
#$handle add_options "-g"
$handle go

if {[testCCommand] ne "OKAY"} {
	error "\[testCCommand\] Invalid result"
}
# Critcl test
#package require -exact critcl 0
critcl::ccode {
#define test 1234
}

critcl::cproc test14 {int x} int {
	return(x + test);
}
puts "Test14: [test14 3]"

puts "Symbols: $tcc4tcl::__lastsyms"

if {[file exists fib.src]} {
puts "Deleting fib.src"
	file delete fib.src
}

if {1} {
puts "Testing preprocessing"
set handle [tcc4tcl::new fib . preprocess]
$handle ccode {
	#include "examples/fib.c";
}
puts [$handle go]
if {[file exists fib.src]} {
	puts "OK, fib.src exists now"
}
}


