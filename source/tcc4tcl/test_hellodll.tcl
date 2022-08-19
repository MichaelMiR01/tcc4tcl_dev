catch {console show}
lappend auto_path .
package require tcc4tcl

set handle [tcc4tcl::new dll dll]
$handle ccode {
	#include "examples/dll.c"
}

puts [$handle code]
puts [$handle go]

puts "Compilation dll.dll ready, building exe"

set handle [tcc4tcl::new hello_dll]
$handle ccode {
	#include "examples/hello_dll.c"
}

$handle add_library_path ./
$handle add_library dll

puts [$handle code]
puts [$handle go]

puts "Compilation ready, loading exe"
set e "ok"
catch {puts [eval exec hello_dll.exe 30]} e
puts "result: $e"

