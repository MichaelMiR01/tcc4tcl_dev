#! /usr/bin/env tclsh
catch {console show}
lappend auto_path .
package require tcc4tcl
set handle [tcc4tcl::new testexe]
$handle ccode {
	#include "examples/fib.c"
}

puts [$handle code]
puts [$handle go]

puts "Compilation ready, loading exe"
puts [eval exec ./testexe.exe 30]
