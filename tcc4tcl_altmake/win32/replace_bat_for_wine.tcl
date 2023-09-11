#! /usr/bin/env tclsh
set fname "build-tcc"
catch {console show}
cd [file dirname $argv0]

if {$argc>0} {
    set fname [lindex $argv 0]
}

puts "Changing to wine compatible usage of () in $fname"

proc change_bat {fname} {
if {[file exists "$fname.orig.bat"]} {
    # already ran thsi script?
    puts "Please check if $fname.bat is already modified"
    return
}

set fh [open "$fname.bat" r]
set fhout [open "$fname.mod.bat" w]
set linenr 0
while {[gets $fh line] > -1} {
     incr linenr
     if {[line_find $line]>0} {
            puts "Modified $fname.bat, change () to __ in $linenr"
            puts $line
            set line [replace_line $line]
            puts $line
     }       
     if {[line_find2 $line]>0} {
            puts "Modified $fname.bat, change () to __ in $linenr"
            puts $line
            set line [replace_line2 $line]
            puts $line
     }       
     puts $fhout $line
}
close $fh
close $fhout
file rename "$fname.bat" "$fname.orig.bat"
file rename "$fname.mod.bat" "$fname.bat"

}

proc replace_line {text} {
    set preg "if (.*?)\\((.*?)\\)(.*?)\\((.*?)\\)(.*?)"
    set repl "if \\1_\\2_\\3_\\4_\\5"
    return [regsub $preg $text $repl]
}
proc line_find {text} {
    set preg "if (.*?)\\((.*?)\\)(.*?)\\((.*?)\\)(.*?)"
    return [regexp $preg $text]
}
proc replace_line2 {text} {
    set preg "if (.*?)echo>>(.*)(.*)"
    set repl "if \\1 (echo>> "
    set r "[regsub $preg $text $repl])"
    return $r
}
proc line_find2 {text} {
    set preg "if (.*?)echo(.*?)"
    return [regexp $preg $text]
}

change_bat $fname

puts "Ready."