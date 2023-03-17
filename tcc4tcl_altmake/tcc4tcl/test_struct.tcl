#!/usr/bin/tclsh

#test for struct pointers experimental

catch {console show}

lappend auto_path .
package require tcc4tcl
load ./cinvoke_tclcmd[info sharedlibextension]

set handle [tcc4tcl::new]

$handle ccode {
    #include "pointerhelper.c"
    typedef struct _clientdatax {
        int a;
        int b;
    } clientdatax;
    
}
$handle cproc getstructdirect {ptr.clientdatax mystruct} char* {
    char buf[256];
    sprintf(buf,"got pointer to %p\n",mystruct);
    sprintf(buf,"got value a %d b %d\n",mystruct->a,mystruct->b);
    return buf;
}

$handle cproc getintptr {ptr.int aa} ptr.int {
    *aa=*aa*2;
    return aa;
}

#puts [$handle code]

$handle go

proc PointerUnwrap {optr} {
    if {$optr eq ""} {
        return 0;
    }
    set hasTag [string first ^ $optr]
    set tag ""
    set ptr 0
    if {$hasTag>0} {
        set tag [string range $optr $hasTag end]
        scan [string range $optr 0 $hasTag-1] %x decimalptr
        set ptr $decimalptr
    }
    puts "$optr --> $ptr ($tag)"
    return $ptr
}

CStruct clientdatax {
    int a
    int b
}
typedef struct clientdatax
CType cd1 clientdatax

puts "Setting values"
cd1 set a 10
cd1 set b 20
puts "Ptr is : [cd1 getptr] [PointerUnwrap [cd1 getptr]]"
puts [getstructdirect [cd1 getptr]]

CType myint int 123
CType myintres int 123
set rptr [getintptr [myint getptr]]
puts "Resulting ptr $rptr from [myint getptr]"



myintres setptr $rptr mem_none;# mem_none, because we know that returnvalue and argvalue share ONE pointer and we don't want to free it unwillingly
puts [myint get]
puts [myintres get]

proc ptrreturn {a b} {
    set rname rval[clock microseconds]
    puts $rname
    CType $rname clientdatax
    $rname set a $a
    $rname set b $b
    return [$rname getptr]
}

set handle [tcc4tcl::new]

$handle ccode {
    #include "pointerhelper.c"
    typedef struct _clientdatax {
        int a;
        int b;
    } clientdatax;
}

$handle ccode [tcc4tcl::tclwrap ptrreturn {int a int b} ptr.clientdatax ptrreturn]
$handle ccode [tcc4tcl::tclwrap puts {char* c} "" tputs]

$handle cproc getstructindirect {int a int b} ptr.clientdatax {
    char buf[256];
    
    clientdatax* cdval=ptrreturn(a,b);
    
    sprintf(buf,"got pointer to %p",cdval);
    tputs(buf);
    sprintf(buf,"got value a %d b %d",cdval->a,cdval->b);
    tputs(buf);
    return cdval;
}

#puts [$handle code]
$handle go
puts [getstructindirect 12 34]
puts [getstructindirect 23 45]





