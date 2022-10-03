#! /usr/bin/env tclsh
catch {console show}
lappend auto_path .
package require tcc4tcl
tcc4tcl::cproc test {} char* {return "test ok";}
puts "test: [test]"