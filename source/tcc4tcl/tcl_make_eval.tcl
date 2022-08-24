# takes a tclproc definition
# and constrcuts the tcl_eval code from it
# usage
# tcc4tcl::tclwrap name {adefs {int i float f ...}} {rtype void} 
#
# the resulting code has the form
# $rtype tcl_$name (Tcl_interp* ip, $adefs) {...}
#
# and can be used to call into tcl_procs directly from c
#
# but... you need a valid interp to do that!

proc tcc4tcl::tclwrap {name {adefs {}} {rtype void}} {
	if {$name == ""} {
		return "No TCL Proc name given"
	}

	set wname tcl_[tcc4tcl::cleanname $name]

	# Fully qualified proc name
	set name [lookupNamespace $name]

	array set types {}
	set varnames {}
	set cargs {}
	set cnames {}  
	set cbody {}
	set code {}

	# if first arg is "Tcl_Interp*", pass it without counting it as a cmd arg
	while {1} {
		if {[lindex $adefs 0] eq "Tcl_Interp*"} {
			lappend cnames ip
			lappend cargs [lrange $adefs 0 1]
			set adefs [lrange $adefs 2 end]

			continue
		}

		break
	}

	foreach {t n} $adefs {
		set types($n) $t
		lappend varnames $n
		lappend cnames _$n
		lappend cargs "$t $n"
	}

	# Handle return type
	switch -- $rtype {
		ok      {
			set rtype2 "int"
		}
		string - dstring - vstring {
			set rtype2 "char*"
		}
		default {
			set rtype2 $rtype
		}
	}

	# Write wrapper
	append cbody "$rtype2 $wname\(Tcl_Interp *ip, "

	# Create wrapped function
	if {[llength $cargs] != 0} {
		set cargs_str [join $cargs {, }]
	} else {
		set cargs_str "void"
	}
    append cbody "$cargs_str"
	append cbody ") {" "\n"

    set cname [namespace tail $name]

	# Create wrapper function
	## Supported input types
	##   Tcl_Interp*
	##   ClientData
	##   int
	##   long
	##   float
	##   double
	##   char*
	##   Tcl_Obj*
	##   void*
	##   Tcl_WideInt

	set n 0
	set fmtstr "%s"
	set varstr ""
	foreach x $varnames {
		incr n
		switch -- $types($x) {
			int {
				append fmtstr " %d"
			}
			long {
				append fmtstr " %d"
			}
			Tcl_WideInt {
				append fmtstr " %d"
			}
			float {
				append fmtstr " %f"
			}
			double {
				append fmtstr " %f"
			}
			char* {
				append fmtstr " \\\"%s\\\""
			}
			default {
				append fmtstr " \\\"%s\\\""
			}
		}
		append varstr ",$x"
	}
	append cbody "    char buf \[2048\];\n"
    append cbody "    sprintf(buf,\"$fmtstr\",\"$name\"$varstr);\n"
	append cbody "    Tcl_Eval (ip, buf);\n"
	append cbody "\n"

	# Call wrapped function
	if {$rtype != "void"} {
		append cbody "    $rtype2 rv;\n"
	}

	# Return types supported by critcl
	#   void
	#   ok
	#   int
	#   long
	#   float
	#   double
	#   char*     (TCL_STATIC char*)
	#   string    (TCL_DYNAMIC char*)
	#   dstring   (TCL_DYNAMIC char*)
	#   vstring   (TCL_VOLATILE char*)
	#   default   (Tcl_Obj*)
	#   Tcl_WideInt

	switch -- $rtype {
		void           { append cbody "    return; \n" }
		int            { append cbody "    rv=Tcl_GetIntFromObj(Tcl_GetObjResult(ip));" "\n" }
		long           { append cbody "    rv=Tcl_GetLongFromObj(Tcl_GetObjResult(ip));" "\n" }
		Tcl_WideInt    { append cbody "    rv=Tcl_GetWideIntFromObj(Tcl_GetObjResult(ip));" "\n" }
		float          -
		double         { append cbody "    rv=Tcl_GetDoubleFromObj(Tcl_GetObjResult(ip));" "\n" }
		char*          { append cbody "    rv=Tcl_GetStringFromObj(Tcl_GetObjResult(ip),NULL);" "\n" }
		default        { append cbody "    rv=NULL;\n" }
	}

	if {$rtype != "void"} {
		append cbody "    return rv;\n"
	}

	append cbody "}" "\n"

	return $cbody
}

