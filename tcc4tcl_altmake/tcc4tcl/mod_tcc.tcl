#! /usr/bin/env tclsh
catch {console show}
cd [file dirname $argv0]
#--------------------------------------------------------
# lookup tcc_list_symbols in libtcc.h
set __has_tcc_list_symbols 0
set fh [open "libtcc.h" r]
while {[gets $fh line] > -1} {
    #
    if {[string first "tcc_list_symbols" [string trim $line]]>0} {
        puts "found tcc_list_symbols"
        set __has_tcc_list_symbols 1
        break;
    }
}
close $fh

#--------------------------------------------------------
if {[file exists "tcc.orig.c"]} {
    # already ran thsi script?
    puts "Please check if tcc.c is already modified"
} else {
set fh [open "tcc.c" r]
set fhout [open "tcc.mod.c" w]
set linenr 0
while {[gets $fh line] > -1} {
     incr linenr
        if {[string eq [string trim $line] "#if ONE_SOURCE"]==1} {
            puts "Modified tcc.c, added #include tcc4tcl/tcl_iomap.c at line $linenr"
            if {$__has_tcc_list_symbols==0} {
                puts $fhout "#define NO_TCC_LIST_SYMBOLS"
            }
            puts $fhout "#include \"tcc4tcl/tcl_iomap.c\""
        }       
        puts $fhout $line
}
close $fh
close $fhout

file rename "tcc.c" "tcc.orig.c"
file rename "tcc.mod.c" "tcc.c"
}
#--------------------------------------------------------
if {[file exists "libtcc.orig.c"]} {
    # already ran thsi script?
    puts "Please check if libtcc.c is already modified"
    
} else {

set fh [open "libtcc.c" r]
set fhout [open "libtcc.mod.c" w]

set oldversion 0
set linenr 0
while {[gets $fh line] > -1} {
        incr linenr
        if {[string eq [string trim $line] "tcc_run_free(s1);"]==1} {
            if {$oldversion==0} {
                puts "Modified libttcc.c, adding #ifndef HAVE_TCL_H at line $linenr"
                puts $fhout "#ifndef HAVE_TCL_H\n  tcc_run_free(s1);\n#endif"
                set line ""
            }
        }   
        if {[string first "tcc_cleanup" [string trim $line]]>-1} {
                if {$oldversion==0} {
                    puts "Aargh, old version, don't use tcc_delete"
                    set oldversion 1
                }
        }   
        puts $fhout $line
}
close $fh
close $fhout

if {$oldversion==0} {
     puts "Modified config_tcc4tcl.h, adding #define TCC4TCL_DODELETE at end"
    set fh_conf [open "tcc4tcl/config_tcc4tcl.h" a]
    puts $fh_conf "\n#define TCC4TCL_DODELETE"
    #puts $fh_conf "#define TCC4TCL_NEWVERSION\n"
    close $fh_conf
}

file rename "libtcc.c" "libtcc.orig.c"
file rename "libtcc.mod.c" "libtcc.c"
}
#--------------------------------------------------------
if {[file exists "win32/include/_mingw.orig.h"]} {
    # already ran thsi script?
    puts "Please check if _mingw.h is already modified"
    
} else {

set fh [open "win32/include/_mingw.h" r]
set fhout [open "win32/include/_mingw.mod.h" w]

set linenr 0
while {[gets $fh line] > -1} {
        incr linenr
        if {[string eq [string trim $line] "#define _USE_32BIT_TIME_T"]==1} {
            puts "Modified _mingw.h, adding #ifndef _USE_32BIT_TIME_T at line $linenr"
            puts $fhout "#ifndef _USE_32BIT_TIME_T\n  #define _USE_32BIT_TIME_T\n#endif"
            set line ""
        }   
        puts $fhout $line
}
close $fh
close $fhout

file rename "win32/include/_mingw.h" "win32/include/_mingw.orig.h"
file rename "win32/include/_mingw.mod.h" "win32/include/_mingw.h"
}
#--------------------------------------------------------


