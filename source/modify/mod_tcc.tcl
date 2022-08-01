#! /usr/bin/env tclsh
catch {console show}
cd [file dirname $argv0]

if {[file exists "tcc.orig.c"]} {
    # already ran thsi script?
    puts "Please check if tcc.c is already modified"
    return
}

set fh [open "tcc.c" r]
set fhout [open "tcc.mod.c" w]
set linenr 0
while {[gets $fh line] > -1} {
     incr linenr
        if {[string eq [string trim $line] "#if ONE_SOURCE"]==1} {
            puts "Modified tcc.c, added #include tcc4tcl/tcl_iomap.c at line $linenr"
            puts $fhout "#include \"tcc4tcl/tcl_iomap.c\""
        }       
        puts $fhout $line
}
close $fh
close $fhout

file rename "tcc.c" "tcc.orig.c"
file rename "tcc.mod.c" "tcc.c"

if {[file exists "libtcc.orig.c"]} {
    # already ran thsi script?
    puts "Please check if libtcc.c is already modified"
    return
}

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
