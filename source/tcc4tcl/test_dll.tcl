#! /usr/bin/env tclsh
catch {console show}
lappend auto_path .
package require tcc4tcl
set handle [tcc4tcl::new testpkg testpkg]
$handle ccode {
	
}
$handle cproc testme {} char* {return "testme ok!";}

puts [$handle code]
puts [$handle go]

puts "Compilation ready, loading dll"
load "./testpkg[info sharedlibextension]"
puts "Loading done, testing testme"
puts [testme]