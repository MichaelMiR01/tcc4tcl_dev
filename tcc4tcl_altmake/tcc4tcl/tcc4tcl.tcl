# tcc.tcl - library routines for the tcc wrapper (Mark Janssen)
# heavily modified by MiR to support TK properly and some debug features
# 
# set tcc4tcl::dir to the base dir where includes and libs are living if necessary
# after loading the extension this will be set to the directory where tcc4tcl.tcl and pkgIndex live

namespace eval ::tcc4tcl {
    
	variable dir ""
	variable count 0
	variable loadedfrom "-unknown-"
	variable needInterp 0
    variable needPointers 0

	# lastsyms gets symbols from last compilation
	# symtable can hold reference to all symbols
	# symtable_auto controls  automatc update of symtable after compiling in memory
	
	variable __lastsyms ""
	variable __symtable ""
	variable __symtable_auto 1
	
	set dir [file dirname [info script]]
	set dir [file normalize $dir]
	
	#puts "TCC DIR IS $dir ([file normalize $dir])"
	if {[info command ::tcc4tcl] == ""} {
		catch { 
		    load {} tcc4tcl 
		    set loadedfrom "static"
		}
	}
	if {[info command ::tcc4tcl] == ""} {
		catch {
			load [file join $dir tcc4tcl[info sharedlibextension]] tcc4tcl
		    set loadedfrom  "[file join $dir tcc4tcl[info sharedlibextension]]"
		}
	}
	if {[info command ::tcc4tcl] == ""} {
		catch {
			load [file join ./ tcc4tcl[info sharedlibextension]] tcc4tcl
		    set loadedfrom  "[file join ./ tcc4tcl[info sharedlibextension]]"
		}
	}

	if {[info command ::tcc4tcl] == ""} {
	    puts "ERROR: Failed loading tcc4tcl library"
	    set loadedfrom "-failed-"
	}
	set count 0

	proc lookupNamespace {name} {
		if {![string match "::*" $name]} {
			set nsfrom [uplevel 2 {namespace current}]    
			if {$nsfrom eq "::"} {
				set nsfrom ""
			}

			set name "${nsfrom}::${name}"
		}

		return $name
	}
	proc update_symtable {symlist} {
	    variable __symtable
	    if {$symlist==""} {
	        set symlist $__symtable
	    }
	    #puts "...Unfiltered: $symlist"
	    set filtered [lsearch -regexp -all -inline $symlist ^((?!_).*)$]
	    set filtered [lsearch -regexp -all -inline $filtered ^((?!IAT.).*)$]
	    set filtered [lsearch -regexp -all -inline $filtered ^((?!@).)*$]
	    #puts "...Filtered: $filtered"

	    set storedsymbols ""
        foreach sym $filtered {
            catch {
                set adr [tcc get_symbol $sym]
                lappend storedsymbols $sym $adr 
            }
        }
	    #
		foreach {sym adr} $storedsymbols {
		    if {$adr ne ""} {
                dict set __symtable $sym $adr
                #puts "...stored $sym in __symtable"
            }
		}
	}
	proc lookup_Symbol {symname} {
	    variable __symtable
	    set adr ""
	    catch {
	        set adr [dict get $__symtable $symname]
	    }
	    return $adr	    
	}
	
	proc new {{output ""} {pkgName ""} {compile_type ""}} {
		variable dir
		variable count

		variable needInterp
		variable needPointers
		variable __lastsyms
		variable __symtable
		
		set __lastsyms ""
		set needInterp 0
		
		set handle ::tcc4tcl::tcc_[incr count]
		if {$output == ""} {
			set type "memory"
		} else {
			if {$pkgName == ""} {
				set type "exe"
			} else {
				set type "package"
			}
		}
		if {$compile_type ne ""} {
		    set type $compile_type
		}
		array set $handle [list procs "" code "" type $type filename $output package $pkgName add_inc_path "" add_lib_path "" add_lib "" add_file "" add_macros "" add_symbol "" loot_interp 0]

		proc $handle {cmd args} [string map [list @@HANDLE@@ $handle] {
			set handle {@@HANDLE@@}

			if {$cmd == "go"} {
				set args [list 0 {*}$args]
			}

			if {$cmd == "code"} {
				set cmd "go"
				set args [list 1 {*}$args]
			}

			set callcmd ::tcc4tcl::_$cmd

			if {[info command $callcmd] == ""} {
				return -code error "unknown or ambiguous subcommand \"$cmd\": must be cwrap, ccode, cproc, ccommand, tclwrap, delete, linktclcommand, code, tk, add_include_path, drop_include_path, add_library_path, add_library, add_file, add_symbol, add_options, process_command_line, or go"
			}

			uplevel 1 [list $callcmd $handle {*}$args]
		}]

		return $handle
	}

	proc _linktclcommand {handle cSymbol args} {
		upvar #0 $handle state
		set argc [llength $args]
		if {$argc != 1 && $argc != 2} {
			return -code error "_linktclcommand handle cSymbol tclCommand ?clientData?"
		}

		lappend state(procs) $cSymbol $args
	}

	proc _ccommand {handle tclCommand argList body} {
		upvar #0 $handle state

		set tclCommand [lookupNamespace $tclCommand]

		set cSymbol [cleanname [namespace tail $tclCommand]]

		lappend state(procs) $tclCommand [list $cSymbol]

		foreach {clientData interp objc objv} $argList {}
		set cArgList "ClientData $clientData, Tcl_Interp *$interp, int $objc, Tcl_Obj *CONST $objv\[\]"

		append state(code) "int $cSymbol\($cArgList) {\n$body\n}\n"

		return
	}

	proc _add_include_path {handle args} {
		upvar #0 $handle state

		lappend state(add_inc_path) {*}$args
	}
	proc _add_options {handle args} {
		upvar #0 $handle state

		lappend state(options) {*}$args
	}
	
	proc _drop_include_path {handle path} {
		upvar #0 $handle state

        # lremove RS oneliner from 
        set ol $state(add_inc_path)
        set ol [lsearch -all -inline -not -exact $ol $path]
        set state(add_inc_path) $ol
        #puts $ol
	}

	proc _add_library_path {handle args} {
		upvar #0 $handle state

		lappend state(add_lib_path) {*}$args
	}

	proc _add_library {handle args} {
		upvar #0 $handle state

		lappend state(add_lib) {*}$args
	}

	proc _add_file {handle args} {
		upvar #0 $handle state

		lappend state(add_file) {*}$args
	}

	proc _add_symbol {handle args} {
		upvar #0 $handle state

		lappend state(add_symbol) {*}$args
	}
	
	proc _cwrap {handle name adefs rtype {withfuncdef 1}} {
		upvar #0 $handle state

		set wrap [uplevel 1 [list ::tcc4tcl::wrap $name $adefs $rtype "#" ""]]

		set wrapped [lindex $wrap 0]
		set wrapper [lindex $wrap 1]
		set tclname [lindex $wrap 2]
		if {$withfuncdef==0} {
		    # comment out the funcdef
		    append state(code) "// "
        }
		append state(code) $wrapped "\n"
		append state(code) $wrapper "\n"

		lappend state(procs) $name [list $tclname]
		set cname "$name"
		lappend state(procdefs) $name [list $cname $rtype $adefs _cwrap]
	}

	proc _tclwrap {handle name {adefs {}} {rtype void} {cname ""}} {
		upvar #0 $handle state
		set code [::tcc4tcl::tclwrap $name $adefs $rtype $cname]
		append state(code) $code "\n"
		
		# careful, if we export this, the result might be a dll without tcl procs
		# if {$cname==""} {set cname $name}
		# lappend state(procdefs) $name [list $cname $rtype $adefs _tclwrap] 
	}

	proc _tclwrap_eval {handle name {adefs {}} {rtype void} {cname ""}} {
		upvar #0 $handle state
		set code [::tcc4tcl::tclwrap_eval $name $adefs $rtype $cname]
		append state(code) $code "\n"

		# careful, if we export this, the result might be a dll without tcl procs
		# if {$cname==""} {set cname $name}
		# lappend state(procdefs) $name [list $cname $rtype $adefs _tclwrap_eval] 
	}

	proc _cproc {handle name adefs rtype {body "#"}} {
		upvar #0 $handle state

		set wrap [uplevel 1 [list ::tcc4tcl::wrap $name $adefs $rtype $body]]

		set wrapped [lindex $wrap 0]
		set wrapper [lindex $wrap 1]
		set tclname [lindex $wrap 2]

		append state(code) $wrapped "\n"
		append state(code) $wrapper "\n"

		lappend state(procs) $name [list $tclname]
		set cname "c_$name"
		lappend state(procdefs) $name [list $cname $rtype $adefs _cproc] 
	}

	proc _ccode {handle code} {
		upvar #0 $handle state

		append state(code) $code "\n"
	}

	proc _tk {handle} {
		upvar #0 $handle state

		set state(tk) 1
	}

	proc _process_command_line {handle cmdStr} {
		# XXX:TODO: This needs to handle shell-quoted arguments
		upvar #0 $handle state
		set cmdStr [regsub -all {   *} $cmdStr { }]
		set work [split $cmdStr " "]

		foreach cmd $work {
			switch -glob -- $cmd {
				"-I*" {
					set dir [string range $cmd 2 end]
					_add_include_path $handle $dir
				}
				"-D*" {
					set symbolval [string range $cmd 2 end]
					set symbolval [split $symbolval =]
					set symbol [lindex $symbolval 0]
					set val    [join [lrange $symbolval 1 end] =]

					dict set state(add_macros) $symbol $val
				}
				"-U*" {
					set symbol [string range $cmd 2 end]
					dict unset state(add_macros) $symbol $val
				}
				"-l*" {
					set library [string range $cmd 2 end]
					_add_library $handle $library
				}
				"-L*" {
					set libraryDir [string range $cmd 2 end]
					_add_library_path $handle $libraryDir
				}
				"-g" {
					# Ignored
				}
			}
		}
	}

	proc _delete {handle} {
		rename $handle ""
		unset $handle
	}
	proc _proc {handle tclname adefs rtype body args} {
		# Convert body into a C-style string
		# and make it calable from c
		#puts "creating proc $rtype $tclname $adefs $body"
        set nsl [::tcc4tcl::nsresolvename $tclname]
        lassign $nsl namespacepath procname cname
        #puts "resolved $tclname to $namespacepath $procname $cname"
    
        #    $::tsp::TCC_HANDLE proc c_$name $pargs $returnType $body
        # maybe this will sometime superseed the tcc4tcl proc
        set mycode [::tcc4tcl::procdef $tclname $cname $adefs $rtype $body]
        
        _ccode $handle "//start\n$mycode\n"
        _tclwrap $handle $tclname $adefs $rtype $cname
        set name $cname
        set cbody "int tcl_$name (ClientData clientdata, Tcl_Interp *ip, int objc, Tcl_Obj *const objv\[\]) {\n" 
        append cbody "int rs;\n"
        append cbody "#ifdef [string toupper def_$name]\n"
        #append cbody "    #warning [string toupper def_$name]\n"
        # delete command from interp, this will unlink tcl_$name
        append cbody "    rs = Tcl_DeleteCommand (ip, \"$tclname\");\n"
        append cbody "    if (rs!=TCL_OK) return rs;\n"
        # call tcl definition into interp
        set hasinterp [string first "Tcl_Interp*" $adefs ]
        set interp_name ""
        if {$hasinterp>-1} {
            set interp_name "ip"
        }
        append cbody "    def_$name ($interp_name);\n"
#        append cbody "    def_$name ();\n"
        append cbody "#endif /*_proc [string toupper def_$name]*/\n"
        # if all went well now $name is defined as pure tclproc... calling it now
        append cbody "rs = Tcl_EvalObjv(ip, objc, objv,0);\n"
        append cbody "return rs;\n"
        append cbody "}\n"
        _ccode $handle $cbody
        _linktclcommand $handle $tclname tcl_$name
        _ccode $handle "//end\n"

	}

	proc _go {handle {outputOnly 0}} {
		variable dir
		variable needInterp
		variable needPointers
		variable __lastsyms
		variable __symtable
		variable __symtable_auto
		
	    proc initModInterp {astate} {
            if {$astate!=""} {
                upvar $astate state
            }
            # init module wide interp to use in external callbacks
            # set module_init "int loot_interp (Tcl_Interp* interp) {\n"
            # this code will only be used, if needInterp is set to 1
            # wether manually after creation or from tcc4tcl::tclwrap
            
            set module_init ""
            append module_init  "   mod_Tcl_interp = interp;\n"
            append module_init  "    return 1;\n"
            #append module_init  "}\n";
            append module_head "/* All TCL needs an interp... */\n"
            append module_head "/* External callbacks won't know about an Tcl_Interp, so ...*/\n"
            append module_head "/* we install a module scope global interp here ...*/\n"
            append module_head "static Tcl_Interp*  mod_Tcl_interp;\n"
            set name "__loot_interp"
            set adefs {Tcl_Interp* interp}
            set rtype int
            set body $module_init
            set wrap [uplevel 0 [list ::tcc4tcl::wrap $name $adefs $rtype $body]]
            set wrapped [lindex $wrap 0]
            set wrapper [lindex $wrap 1]
            set tclname [lindex $wrap 2]
            set module_init ""
            if {$astate!=""} {
                upvar $astate state
                if {[lsearch  -exact $state(procs) $name]==-1} {
                    lappend state(procs) $name [list $tclname]
                }
                set module_init "$wrapped \n$wrapper \n"
            }

            return "$module_head\n$module_init\n"
	    }
	    
	    proc finalizeProclist {handle} {
	        upvar #0 $handle state
	        #
            # lets isolate some sugar funcs
            # all cprocs with leading __ will get removed now
            # __before_tclinit
            # __after_tclinit
            # will be put into the init routine
            set state(__before_tclinit) ""
            set state(__after_tclinit) ""
            set realprocs {}
            if {[info exists state(procs)] && [llength $state(procs)] > 0} {
                # scan for special procs and move them to specialprocs
                foreach {procname cname_obj} $state(procs) {
                    set cname [lindex $cname_obj 0]

                    if {[llength $cname_obj] > 1} {
                        set obj [lindex $cname_obj 1]
                    } else {
                        set obj "NULL"
                    }
                    #puts "$procname :-> $obj ($cname_obj)"
                    if {[string range $procname 0 1]=="__"} {
                        # mark special proc with __
                        #puts "found special proc $procname"
                        lappend state(specialprocs) $procname $cname_obj
                        set cname [lindex $cname_obj 0]
                        if {$procname=="__before_tclinit"} {
                            set state(__before_tclinit) "   c_$procname (interp);//init\n"
                        }
                        if {$procname=="__after_tclinit"} {
                            set state(__after_tclinit) "   c_$procname  (interp);\n"
                        }
                    } else {
                        lappend realprocs $procname $cname_obj
                    }
                }
                # all special "__xxx" cprocs are now removed from the regular proclist
                # so we don't want to TclCreateCommand from these 
                # set state(procs) $realprocs
            }
            
	    }
	    
		upvar #0 $handle state

		set code ""
		set module_head ""
		set module_init ""
		
		variable hasTK 0
		finalizeProclist $handle
        #puts "Plattform $::tcl_platform(os)-$::tcl_platform(pointerSize)"
        
        # if tcc4tcl is loaded from a zip-enabled libtcc.dll
        # have to correct the directory accordingly        
        set mdir $dir
        #if {[string first zip: $dir]==0} {
        #    set mdir "."
        #}
        switch -glob -- $::tcl_platform(os)-$::tcl_platform(pointerSize) {
            "Linux-*" {
                #set dir [file normalize $dir]
                # puts "Linux $dir"
                # could use ::tcl::pkgconfig in future versions
                $handle add_include_path  "${mdir}/include/"
                $handle add_include_path  "${mdir}/include/stdinc/"
                $handle add_include_path  "/usr/include/"
                $handle add_include_path  "/usr/include/x86_64-linux-gnu"
                $handle add_include_path  "${mdir}/include/generic"
                $handle add_include_path  "${mdir}/include/xlib"
                $handle add_include_path  "${mdir}/include/generic/unix"
                set outfileext so
                set tclstub tclstub86_64
                set tkstub tkstub86_64
                set DLLEXPORT "__attribute__ ((visibility(\"default\")))"
                set libdir $dir
                set libdir2 $mdir/lib
            }
            "Windows*" {
                $handle add_include_path  "${mdir}/include/"
                $handle add_include_path  "${mdir}/include/generic"
                $handle add_include_path  "${mdir}/include/xlib"
                $handle add_include_path  "${mdir}/include/generic/win"
                $handle add_include_path  "${mdir}/win32"
                $handle add_include_path  "${mdir}/win32/winapi"
                set outfileext dll
                set tclstub tclstub86elf
                set tkstub tkstub86elf
                set DLLEXPORT "__declspec(dllexport)"
                set libdir $dir
                set libdir2 $mdir/lib_win32
            }
            default {
                puts "Unknow Plattform $::tcl_platform(os)-$::tcl_platform(pointerSize)"
                set libdir $mdir
                set libdir2 $mdir/lib
                return
            }
        }
        
		foreach {macroName macroVal} $state(add_macros) {
			append code "#define [string trim "$macroName $macroVal"]\n"
		}
		#append code $state(code) "\n"
		
		# undef DLLEXPORT, since tcl.h and tk.h may have it defined differntly from what we want
		set code "#undef DLLEXPORT \n#undef DLLIMPORT \n$code"
        append code "#ifndef DLLEXPORT \n"
        append code "#define DLLEXPORT $DLLEXPORT\n"
        append code "#endif\n"
		append code $state(code) "\n"
		if {$state(type) == "exe" || $state(type) == "dll"} {
			if {[info exists state(procs)] && [llength $state(procs)] > 0} {
				set code "int _initProcs(Tcl_Interp *interp);\n\n$code"
			}
		}

		if {[info exists state(tk)]} {
		    if {$hasTK==0&&$state(type) == "memory"&&!$outputOnly} {
                set hasTK 1
                set name "tkstart"
                set adefs {Tcl_Interp* interp}
                set rtype int
                set body {
                    if (Tk_InitStubs(interp, TK_VERSION, 0) == NULL) {
                        return TCL_ERROR;
                    }
                    return 1;
                }
                set wrap [uplevel 0 [list ::tcc4tcl::wrap $name $adefs $rtype $body]]
                set wrapped [lindex $wrap 0]
                set wrapper [lindex $wrap 1]
                set tclname [lindex $wrap 2]
                set code "$code\n\n $wrapped \n $wrapper \n"
                lappend state(procs) $name [list $tclname]
             }
			 set compiletkstubs ""
			 if {$state(type)=="memory"} {
			     set compiletkstubs "#include <tkStubLib.c>\n"
			 }
			 set code "#define USE_TK_STUBS 1\n#include <tk.h>\n$compiletkstubs\n$code"
		}
		set modInitCode ""
		# Append additional generated code to support the output type
		#puts "Type is $state(type)";
		switch -- $state(type) {
			"memory" {
				# No additional code needed
				if {$outputOnly} {
					if {[info exists state(procs)] && [llength $state(procs)] > 0} {
						foreach {procname cname_obj} $state(procs) {
							set cname [lindex $cname_obj 0]
							if {[llength $cname_obj] > 1} {
								set obj [lindex $cname_obj 1]
							} else {
								set obj "NULL"
							}
							append code "/* Immediate: Tcl_CreateObjCommand(interp, \"$procname\", $cname, $obj, Tcc4tclDeleteClientData); */\n"
						}
					}
				}
			}
			"exe" - "dll" {
				if {[info exists state(procs)] && [llength $state(procs)] > 0} {
					append code "int _initProcs(Tcl_Interp *interp) \{\n"
                     append code $state(__before_tclinit)
					
					foreach {procname cname_obj} $state(procs) {
                        set cname [lindex $cname_obj 0]
                        if {[llength $cname_obj] != 1} {
                            error "ClientData not supported in exe / dll mode"
                        }
                        append code "  Tcl_CreateObjCommand(interp, \"$procname\", $cname, NULL, NULL);\n"
					}
                     append code $state(__after_tclinit)
					
                     if {$needInterp!=0} {
                        append code "  mod_Tcl_interp = interp;\n"
                     }
					append code "\}"
				}
			}
			"package" {
				set packageName [lindex $state(package) 0]
				if {$needInterp!=0} {
				    set modInitCode [initModInterp state]
				}
				set packageVersion [lindex $state(package) 1]
				set tclversion [lindex $state(package) 2]
				if {$tclversion eq ""} {
				    set tclversion "TCL_VERSION"
				}
				if {$tclversion ne "TCL_VERSION"} {
				    #quote it out, it's not a macro probably
				    set tclversion "\"$tclversion\""
				}
				if {$packageVersion == ""} {
					set packageVersion "1.0"
				}
#				append code "#ifndef DLLEXPORT \n"
#				append code "#define DLLEXPORT $DLLEXPORT\n"
#				append code "#endif\n"
				append code "DLLEXPORT \n"
				append code "int [string totitle $packageName]_Init(Tcl_Interp *interp) \{\n"
				append code "#ifdef USE_TCL_STUBS\n"
				append code "  if (Tcl_InitStubs(interp, $tclversion, 0) == 0L) \{\n"
				append code "    return TCL_ERROR;\n"
				append code "  \}\n"
				append code "#endif\n"
				append code "#ifdef USE_TK_STUBS\n"
				append code "  if (Tk_InitStubs(interp, $tclversion, 0) == 0L) \{\n"
				append code "    return TCL_ERROR;\n"
				append code "  \}\n"
				append code "#endif\n"
                 append code $state(__before_tclinit)
				if {[info exists state(procs)] && [llength $state(procs)] > 0} {
					foreach {procname cname_obj} $state(procs) {
					    if {[string range $procname 0 1]=="__"} {
					        # don't add special procs
					    } else {
                            set cname [lindex $cname_obj 0]
                            if {[llength $cname_obj] != 1} {
                                error "ClientData not supported in exe / dll mode"
                            }
                            append code "  Tcl_CreateObjCommand(interp, \"$procname\", $cname, NULL, NULL);\n"
                        }
					}
				}
				append code "  Tcl_PkgProvide(interp, \"$packageName\", \"$packageVersion\");\n"
				if {$needInterp!=0} {
                    append code "  mod_Tcl_interp = interp;\n"
                }
				append code $state(__after_tclinit)
				append code "  return(TCL_OK);\n"
				append code "\}"
			}
		}
		
		if {($modInitCode eq "")&&($needInterp!=0)} {
		    set modInitCode [initModInterp state]
		}
		
        #add header late
        set modAddDefs ""
        if {$needPointers>0} {
        		append modAddDefs "#include \"pointerhelper.c\"\n"
        }
        append modAddDefs "static int mod_Tcl_errorCode;\n"

        set code "#include <tcl.h>\n$modAddDefs\n$modInitCode\n\n$code"
		if {$outputOnly} {
			return $code
		}

		# Generate output code
		switch -- $state(type) {
			"package" {
				set tcc_type "dll"
				$handle add_library_path  $libdir2
				$handle add_library $tclstub
				$handle add_library $tkstub
			}
			default {
				set tcc_type $state(type)
			}
		}

		if {[info command ::tcc4tcl] == ""} {
			return -code error "Unable to load tcc4tcl library"
		}

		::tcc4tcl $libdir $tcc_type tcc
		
		foreach path $state(add_inc_path) {
			tcc add_include_path $path
		}

		foreach path $state(add_lib_path) {
			tcc add_library_path $path
		}
		tcc add_library_path  $libdir2
		tcc add_library_path  "${dir}/libtcc"

		set ccoptions ""
		catch {
		    set ccoptions [join $state(options) " "]
		}
        
		tcc set_options $ccoptions
		
		foreach lib $state(add_lib) {
			tcc add_library $lib
		}

		foreach lib $state(add_file) {
			tcc add_file $lib
		}
		
		foreach {sym adr} $state(add_symbol) {
			tcc add_symbol $sym $adr 
		}
		
		switch -- $state(type) {
		    "preprocess" {
                set outfile [file tail $state(filename)]
                if {![info exists packageName]} {set packageName "."}
                        if {$outfile==""} {
                            set outfile $packageName
                        }
                set outfileext "src"
                set outfile $outfile.$outfileext
                if {[file isdir $packageName]} {
                    set outfile [file join $packageName/$outfile]
                }
                set r [tcc compile $code $outfile]
                if {[string trim $r] ne ""} {
                    puts "Compile result:\n$r\n"
                }
                return "TCC_PREPROCESS_OK"
		    }
			"memory" {
                if {[catch {
                    set r [tcc compile $code]
                } e]} {
                    ::tcc4tcl::debugcode $code $e
                    error "Compilation failed"
                }
                if {[string trim $r] ne ""} {
                    puts "Compile result:\n";
                    ::tcc4tcl::debugcode $code $r
                }
                if {[info exists state(procs)] && [llength $state(procs)] > 0} {
                    foreach {procname cname_obj} $state(procs) {
                        tcc command $procname {*}$cname_obj
                    }
                }
                set __lastsyms [tcc list_symbols]
                if {$__symtable_auto>0} {update_symtable $__lastsyms}
			}

			"package" - "dll" - "exe" {
			    puts "Compiling package"
                switch -glob -- $::tcl_platform(os)-$::tcl_platform(pointerSize) {
                    "Linux-8" {
                        tcc add_library_path "/lib64"
                        tcc add_library_path "/usr/lib64"
                        tcc add_library_path "/lib"
                        tcc add_library_path "/usr/lib"
                    }
                    "SunOS-8" {
                        tcc add_library_path "/lib/64"
                        tcc add_library_path "/usr/lib/64"
                        tcc add_library_path "/lib"
                        tcc add_library_path "/usr/lib"
                    }
                    "Linux-*" {
                        tcc add_library_path "/lib32"
                        tcc add_library_path "/usr/lib32"
                        tcc add_library_path "/lib"
                        tcc add_library_path "/usr/lib"
                    }
                    default {
                        if {$::tcl_platform(platform) == "unix"} {
                            tcc add_library_path "/lib"
                            tcc add_library_path "/usr/lib"
                        }
                    }
                }
            
                if {[catch {
                    set r [tcc compile $code]
                } e]} {
                    ::tcc4tcl::debugcode $code $e
                    error "Compilation failed"
                }
                if {[string trim $r] ne ""} {
                    puts "Compile result:\n";
                    ::tcc4tcl::debugcode $code $r
                }
                
                foreach lib $state(add_lib) {
                    # this is necessary, since tcc tries to load lib alacarte, so no symbols will be resolved before smth is compolied
                    tcc add_library $lib
                }
            
                set outfile [file tail $state(filename)]
                if {![info exists packageName]} {set packageName "."}
                        if {$outfile==""} {
                            set outfile $packageName
                        }
                if {$state(type)=="exe"} {
                    set outfileext "exe"
                }
                set outfile $outfile.$outfileext
                if {[file isdir $packageName]} {
                    set outfile [file join $packageName/$outfile]
                }
                tcc output_file $outfile 
                set __lastsyms [tcc list_symbols]
                
                rename $handle ""
                unset $handle
                return "TCC_COMPILE_OK"
			}
		}

		if {$hasTK>0} {
		    puts "Starting TK"
            tkstart
        }
        if {$needInterp!=0} {
            __loot_interp
        }
        if {$state(__before_tclinit)!=""} {
            __before_tclinit
        }
        if {$state(__after_tclinit)!=""} {
            __after_tclinit
        }

		# Cleanup
		rename $handle ""
		unset $handle
		return "TCC_COMPILE_OK"
	}
}

proc ::tcc4tcl::checkname {n} {expr {[regexp {^[a-zA-Z0-9_]+$} $n] > 0}}
proc ::tcc4tcl::cleanname {n} {regsub -all {[^a-zA-Z0-9_]+} $n _}
proc ::tcc4tcl::debugcode {code result} {
    # check in result for warnings and errors and give according lines of source
    set ccode [split $code \n] 
    foreach rline [split $result \n] {
        puts $rline
        catch {
            set rparts [split $rline :]
            if {[llength $rparts]<3} {
                # invalid result, skip;
            } else {
                # get parts
                lassign $rparts rtype rlinenr rrest
                if {$rtype eq "<string>"} {
                    puts "\t[lindex $ccode [expr $rlinenr-1]]"
                }
            }
        }
    }
}
# proc tcc4tcl::tclwrap takes a tclproc definition
# and constructs the tcl_eval code from it
# usage
# tcc4tcl::tclwrap name {adefs {(Tcl_interp* ip,) int i float f ...}} {rtype void} {cname ""}
# tcc4tcl::tclwrap_eval does the same, but the emitted code will call Tcl_Eval instead
#
# the resulting code has the form
# $rtype tcl_$name // $cname ( $adefs) {...}
#
# and can be used to call into tcl_procs directly from c
# simply call
# $cname // tcl_$name (args);
# or give an Tcl_Interp*
# cname (ip, args)
#
# if (Tcl_interp* ip,) is ommitted
# tcc4tcl will emit some code to get an interp into module scope
# static Tcl_Interp* mod_Tcl_Interp;
#
# Initialisation of global mod_Tcl_Interp is done in the modules initialisation routine, if neccessary
#
proc ::tcc4tcl::tclwrap_eval {name {adefs {}} {rtype void} {cname ""}} {
    # removed old def
    # forwrd to tclwrap
    return [::tcc4tcl::tclwrap $name $adefs $rtype $cname]
}

proc ::tcc4tcl::tclwrap {name {adefs {}} {rtype void} {cname ""}} {
    # #uses Tcl_EvalObjv
    # #can use the standard cproc args
    # $handle tclwrap ::ClOClass::_notifytop {char* cmd char* text} char* notify_arg
    #
    # #or even variadic form (up to 10 args, we have to hardcode the array length for now)
    # $handle tclwrap ::ClOClass::_notifytop {char* cmd "" ...} char* notify_va
    # #but the last arg has to be a NULL value
    # notify_va ("test1", "test from c va_arg",NULL);
    
    set hasInterp 0
    variable needInterp
    variable needPointers
    set hasInterp 0
	if {$name == ""} {
		return "No TCL Proc name given"
	}

    set nsl [::tcc4tcl::nsresolvename $name]
    lassign $nsl namespacepath procname _cname
    if {$cname==""} {
        set cname c_$_cname
    }
    set cprocname $cname

	set wname tcl_[::tcc4tcl::cleanname $name]
	if {$cname != ""} {
		set wname $cname
	}

	# Fully qualified proc name
	# set name [lookupNamespace $name]
	if {[info commands ::$name] != "::$name"} {
	    #puts "Warning: proc ::$name undefined"
	}
	
	array set types {}
	set varnames {}
	set cargs {}
	set cnames {}  
	set cbody {}
	set code {}
	# if first arg is "Tcl_Interp*", pass it without counting it as a cmd arg
    set hasinterp [string first "Tcl_Interp*" $adefs ]
    set interp_name ""
    if {$hasinterp>-1} {
        set interp_name [dict get $adefs "Tcl_Interp*"]
    }
	while {1} {
		if {[lindex $adefs 0] eq "Tcl_Interp*"} {
			lappend cnames [lindex $adefs 1]
			lappend cargs [lrange $adefs 0 1]
			set adefs [lrange $adefs 2 end]
			set hasInterp 1;# else we have to find a module wide instance
			continue
		}

		break
	}

	array set tags {}
	foreach {t n} $adefs {
	    if {[string range $t 0 2] eq "ptr"} {
	        set tag [string range $t 4 end]
            set types($n) "ptr"
            set tags($n) $tag
            lappend varnames $n
            lappend cnames "_$n"
            lappend cargs "$tag* $n"
	    } else {
            set types($n) $t
            lappend varnames $n
            lappend cnames _$n
            lappend cargs "$t $n"
        }
	}

	# Handle return type
	set rtag ""
	if {[string range $rtype 0 2] eq "ptr"} {
        set rtag [string range $rtype 4 end]
        set rtype "ptr"
    }
	switch -- $rtype {
		ok      {
			set rtype2 "int"
		}
		ptr     {
		    set rtype2 "void*"
		    if {$rtag ne ""} {
		        set rtype2 "${rtag}*"
		    }
		}
		float    {
		    set rtype2 "double"
		}
		string - dstring - vstring {
			set rtype2 "char*"
		}
		""      {
		    set rtype2 "void"
		}
		default {
			set rtype2 $rtype
		}
	}

	# Write wrapper
	if {$hasInterp} {
	    # the function get it's own interp from caller
    } else {
        # no interp in context, try finding a module wide instance
        # nameing convention:
        # mod_Tcl_interp
        set needInterp 1
    }
    append cbody "$rtype2 $wname\("

	# Create wrapped function
	if {[llength $cargs] != 0} {
		set cargs_str [join $cargs {, }]
	} else {
		set cargs_str "void"
	}
    append cbody "$cargs_str"
	append cbody ") {" "\n"
	append cbody "#ifdef [string toupper def_$cprocname]\n"
	#append cbody "    #warning [string toupper def_$cprocname]\n"
	append cbody "    def_$cprocname ($interp_name);\n"
	append cbody "#endif /*tclwrap [string toupper def_$cprocname]*/\n"
	append cbody "int va_count;\n"
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
	set cobjstring "    Tcl_Obj*  argObjvArray \[[expr [llength $varnames]+10]\];\n\n"
	set cleanupstring "// cleanup argObjvArray\n"
	append cleanupstring "    for (int i=0;i<va_count;i++) {if(argObjvArray!=NULL) {Tcl_DecrRefCount(argObjvArray\[i\]);}};\n" 
    append cobjstring "    Tcl_Obj* funcname = Tcl_NewStringObj(\"$name\",-1);\n"
    append cobjstring "    Tcl_IncrRefCount(funcname);\n"
    append cobjstring "    argObjvArray\[$n\] = funcname;\n\n"
	
	foreach x $varnames {
	    set isVariadic 0
	    set varname $x
        incr n
        set acttype $types($x)
        append cobjstring "    va_count =[expr $n];\n"
        if {$acttype== "..."} {
            #puts "got variadic args"
            set acttype ""
            ##set types($x) ""
            set x ...
            set isVariadic 1
        }
        if {$acttype== ""} {
            # empty type, could be ... variadic va_arg
            if {$x eq "..."} {
                #puts "got variadic args"
                set isVariadic 1
            }
        }
        if {$isVariadic==1} {
            set acttype $lasttype
            append cobjstring "    va_list vargs;\n"
            append cobjstring "    Tcl_Obj* target_$n;\n"
            
            append cobjstring "    va_start (vargs, $lastvar);\n"
            append cobjstring "    $lasttype argvar;\n"
            append cobjstring "    while(1) \{\n"
            append cobjstring "    argvar=va_arg(vargs,$lasttype);\n"
            append cobjstring "    if(argvar==NULL) break;\n"
            set varname "argvar"
        }
        switch -- $acttype {
            int {
                append fmtstr " %d"
                append cobjstring "    Tcl_Obj* target_$n = Tcl_NewWideIntObj((Tcl_WideInt) $varname);\n"
            }
            long {
                append fmtstr " %d"
                append cobjstring "    Tcl_Obj* target_$n = Tcl_NewWideIntObj((Tcl_WideInt) $varname);\n"
            }
            Tcl_WideInt {
                append fmtstr " %d"
                append cobjstring "    Tcl_Obj* target_$n = Tcl_NewWideIntObj((Tcl_WideInt) $varname);\n"
            }
            float {
                append fmtstr " %f"
                append cobjstring "    Tcl_Obj* target_$n = Tcl_NewDoubleObj((double) $varname);\n"
            }
            double {
                append fmtstr " %f"
                append cobjstring "    Tcl_Obj* target_$n = Tcl_NewDoubleObj((double) $varname);\n"
            }
            char* {
                append fmtstr " \\\"%s\\\""
                append cobjstring "    Tcl_Obj* target_$n = Tcl_NewStringObj($varname, -1);\n"
                
            }
            default {
                if {$acttype=="ptr"} {
                    set tag ""
                    catch {set tag $tags($x)}
                    #Cinv_GetPointerFromObj
                    set ::tcc4tcl::needPointers 1
                    append fmtstr " \\\"%s\\\""
                    append cobjstring "    Tcl_Obj* target_$n = Cinv_NewPointerObj((void*)$varname, \"$tag\");\n"
                } else {
                    append fmtstr " \\\"%s\\\""
                    append cobjstring "    Tcl_Obj* target_$n = Tcl_NewStringObj($varname,-1);\n"
                }
                # replace by cinv
            }
        }
        append cobjstring "    Tcl_IncrRefCount(target_$n);\n"
        append cobjstring "    argObjvArray\[va_count\] = target_$n;\n"
        append cobjstring "    va_count++;\n"
        if {$isVariadic>0} {
            append cobjstring "    \};//end while\n"
            append cobjstring "    va_end(vargs);\n"
            append cobjstring "    argObjvArray\[va_count\] = NULL;\n"
            append cobjstring "    ;\n"
        } else {
            # store for later use
            set lasttype $types($x)
            set lastvar $x
        }
        append cobjstring "    \n"
        append varstr ",$x"
	}
	incr n
	if {!$hasInterp} {
        # no interp in context, try finding a module wide instance
        # nameing convention:
        # mod_Tcl_interp
        set needInterp 1
        set interp_name "ip"
        append cbody "    Tcl_Interp* ip = mod_Tcl_interp;\n"
        append cbody "    if (ip==NULL) Tcl_Panic(\"No interp found to call tcl routine!\");\n"
        append cbody "    mod_Tcl_errorCode=0;\n"
    }
	append cbody "    char buf \[2048\];\n"
	append cbody $cobjstring
    #append cbody "    sprintf (buf, \"$fmtstr\", \"$name\"$varstr);\n"
	append cbody "    int rs = Tcl_EvalObjv($interp_name, va_count, argObjvArray, 0);//$n\n"
	# check eval for erros and try reporting
    append cbody $cleanupstring;
    append cbody "    if(rs !=TCL_OK) {\n"
	if {!$hasInterp} {
        append cbody "        mod_Tcl_errorCode=rs;\n"
    }
    append cbody "        const char* err = Tcl_GetStringResult($interp_name);\n"
    append cbody "        snprintf (buf, 2048, \"puts {error evaluating tcl-proc $name\\n%s}\",err);\n"
    append cbody "        Tcl_Eval ($interp_name, buf);\n"
    append cbody "        Tcl_Eval ($interp_name, \"puts {STACK TRACE:}; puts \$errorInfo; flush stdout;\");\n"

    if {$rtype2!="void"} {
        append cbody "        return ($rtype2) NULL ;\n"
    } else {
        append cbody "        return ;\n"
    }
    append cbody "    }\n"
	append cbody "    \n\n"

	# Call wrapped function
	if {$rtype2 != "void"} {
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
	switch -- $rtype2 {
		void           { append cbody "    return; \n" }
		int            { append cbody "    rs=Tcl_GetIntFromObj($interp_name,Tcl_GetObjResult($interp_name),&rv);" "\n" }
		long           { append cbody "    rs=Tcl_GetLongFromObj($interp_name,Tcl_GetObjResult($interp_name),&rv);" "\n" }
		Tcl_WideInt    { append cbody "    rs=Tcl_GetWideIntFromObj($interp_name,Tcl_GetObjResult($interp_name),&rv);" "\n" }
		float          -
		double         { append cbody "    rs=Tcl_GetDoubleFromObj($interp_name,Tcl_GetObjResult($interp_name),&rv);" "\n" }
		char*          { append cbody "    rv=Tcl_GetStringFromObj(Tcl_GetObjResult($interp_name),NULL);" "\n" }
		default        {
		    if {$rtype=="ptr"} {
		        #Cinv_GetPointerFromObj
		        set ::tcc4tcl::needPointers 1
		        append cbody "    if(Cinv_GetPointerFromObj($interp_name, Tcl_GetObjResult($interp_name), (void*)&rv,\"$rtag\")!=TCL_OK) return ($rtype2) NULL;" "\n"
		        #append cbody "    if(cv!=TCL_OK) return ($rtype2) NULL;" "\n" 
		    } else {
                append cbody "    rv=NULL;\n"
            }
		}
	}
	# check result for errors and try reporting
    append cbody "    if(rs !=TCL_OK) {\n"
	if {!$hasInterp} {
        append cbody "        mod_Tcl_errorCode=rs;\n"
    }
    append cbody "        const char* err = Tcl_GetStringResult($interp_name);\n"
    append cbody "        sprintf (buf, \"puts {error in result of tcl-proc $name\\n%s}\",err);\n"
    append cbody "        Tcl_Eval ($interp_name, buf);\n"
    if {$rtype2!="void"} {
        append cbody "        return ($rtype2) NULL ;\n"
    } else {
        append cbody "        return ;\n"
    }
    append cbody "    }\n"
	if {$rtype2 != "void"} {
		append cbody "    return rv;\n"
	}

	append cbody "}" "\n"

	return $cbody
}

proc ::tcc4tcl::nsresolvename {nstclname} {
    #return a list with {path name cname}
    set namespacepath ""
    if {[string first :: $nstclname]>-1} {
        # we must resolve a namespace
        #split
        set _cname [namespace tail $nstclname]
        set namespacepath [string range $nstclname 0 end-[expr [string length $_cname]+2]]
        set cpath [::tcc4tcl::cleanname $namespacepath] 
        set cprocname [string trimleft "${cpath}_${_cname}" _ ]		    
        set procname "$_cname"
        if {[string first "c_" $_cname]==0} {
            set procname [string range $_cname 2 end]
        }
        set procname ${namespacepath}::${procname}
    } else {
        set cprocname $nstclname
        set procname $nstclname
        if {[string first "c_" $nstclname]==0} {
            set procname [string range $nstclname 2 end]
        }
    }	
    return [list $namespacepath $procname $cprocname]
}
    
proc ::tcc4tcl::procdef {tclname cname adefs rtype body args} {
    # make c code to define a proc in tcl userspace 
    # return 0 if ok, else 1 if error
    # can be used for _proc and for tclwrap
    # must be called befor using the proc
    # proc will be a normal tcl-proc
    # tclname can have namespace qualifiers
    # cname will be the name to gibe to the c funtion, if empty tclname will be mangled
    # ns::tclname gets ns_tclname etc. leading _ will be removed
    
    # Convert body into a C-style string
    variable needInterp
    set nsl [::tcc4tcl::nsresolvename $tclname]
    lassign $nsl namespacepath procname _cname
    #puts "resolved $tclname to $namespacepath $procname $_cname"
    if {$cname==""} {
        set cname $_cname
    }
    set cprocname $cname
    #puts "cprocname is $cprocname"
    binary scan $body H* cbody
    set cbody [regsub -all {..} $cbody {\\x&}]
    # reformat for better readability in source
    set newbody "\\\n"
    set w 0
    for {set i 0} {$i<[string length $body]} {incr i} {
        append newbody [string range $cbody [expr $i*4] [expr $i*4+3]]
        incr w 4                             
        if {$w>=80} {
            set w 0
            append newbody \\\n
        }
    }
    set cbody $newbody
    # Parse optional arguments
    foreach {argname argval} $args {
        switch -- $argname {
            "-error" {
                set returnErrorValue $argval
            }
        }
    }

    # Argument definitions (in C style) initialization
    set adefs_c [list]

    # Names of all arguments initialization
    set args [list]

    # Determine if one of the arguments is a Tcl_Interp*, if not
    # then we will need to create our own Tcl interpreter for
    # local use
    set newInterp 1
    foreach {type var} $adefs {
        if {$type in "Tcl_Interp*"} {
            set newInterp 0
            set interp_name $var
            set adefs_c [list [list Tcl_Interp* $var]]
            break
        }
    }

    # Create the C-style argument definition
    ## Create a list of all arguments
    foreach {type var} $adefs {
        # The Tcl interpreter is not added to the list of Tcl arguments
        if {$type in "Tcl_Interp*"} {
            continue
        }

        # Update the list of arguments to pass to Tcl
        lappend args $var
    }

    ## Convert that list into something we can use in a C prototype
    if {[llength $adefs_c] == 0} {
        set adefs_c "void"
    } else {
        set adefs_c [join $adefs_c {, }]
    }


    set return_failure "return TCL_ERROR"
    # Define the C function
    set _ccode "#define [string toupper def_$cprocname] def_$cprocname\n"
    append _ccode "int def_$cprocname\($adefs_c) \{ \n"
    ## reset mod_Tcl_errorCode
    append _ccode "    mod_Tcl_errorCode=0; \n"
    
    ## If we need to create a new interpreter, do so
    if {$newInterp} {
        set needInterp 1
        set interp_name "ip"
        append _ccode "    Tcl_Interp *${interp_name}; \n"
    }

    # Create a new interp if needed, otherwise create a temporary procedure
    if {$newInterp} {
        append _ccode "    ${interp_name}  = mod_Tcl_interp; \n"
        append _ccode "    if (!${interp_name})  {\n    mod_Tcl_errorCode=TCL_ERROR; \n    printf(\"No interpreter found!\");\n     $return_failure;\n     }\n"
        append _ccode " \n"

        set cbody "proc ${procname} {$args} { $cbody } "
    } else {
        #set procname "::_tcc4tcl::tmp::proc[clock clicks]"
        #set cbody "namespace eval ::_tcc4tcl {}; namespace eval ::_tcc4tcl::tmp {}; proc ${procname} {$args} { $cbody }"
        set cbody "proc ${procname} {$args} { $cbody } "
    }
    set return_failure "{\n    mod_Tcl_errorCode=TCL_ERROR;\n    $return_failure;}"

    # Evaluate script
    if {$procname != ""} {
        append _ccode "    static int proc_defined = 0; \n"
        append _ccode "    if (proc_defined == 0) \{ \n"
        append _ccode "        proc_defined = 1; \n"
        set extra_space "    "
    } else {
        set extra_space ""
    }

    append _ccode "${extra_space}    int tclrv = Tcl_Eval($interp_name, \"$cbody\");\n"
    append _ccode "${extra_space}    if (tclrv != TCL_OK && tclrv != TCL_RETURN) $return_failure; \n"
    append _ccode "${extra_space} \}\n";
    #append _ccode "${extra_space}    printf(\"defined $cname TCL_OK \\n\"); \n"
    append _ccode "${extra_space}    return TCL_OK; \n"
    append _ccode "\}\n";
    return $_ccode
}

proc ::tcc4tcl::cproc {name adefs rtype {body "#"}} {
	set handle [::tcc4tcl::new]
	$handle cproc $name $adefs $rtype $body
	return [$handle go]
}

proc ::tcc4tcl::wrap {name adefs rtype {body "#"} {cname ""}} {
	variable needPointers
	if {$cname == ""} {
		set cname c_[::tcc4tcl::cleanname $name]
	}

	set wname tcl_[::tcc4tcl::cleanname $name]

	# Fully qualified proc name
	set name [lookupNamespace $name]

	array set types {}
	set varnames {}
	set cargs {}
	set cnames {}  
	set cbody {}
	set code {}

	# Write wrapper
	append cbody "int $wname\(ClientData clientdata, Tcl_Interp *ip, int objc, Tcl_Obj *CONST objv\[\]) {" "\n"

	# if first arg is "Tcl_Interp*", pass it without counting it as a cmd arg
	while {1} {
		if {[lindex $adefs 0] eq "Tcl_Interp*"} {
			lappend cnames ip
			lappend cargs [lrange $adefs 0 1]
			set adefs [lrange $adefs 2 end]

			continue
		}

		if {[lindex $adefs 0] eq "ClientData"} {
			lappend cnames clientdata
			lappend cargs [lrange $adefs 0 1]
			set adefs [lrange $adefs 2 end]

			continue
		}

		break
	}

	array set tags {}
	foreach {t n} $adefs {
	    if {$n!=""} {
            if {[string range $t 0 2] eq "ptr"} {
                set tag [string range $t 4 end]
                set types($n) "ptr"
                set tags($n) $tag
                lappend varnames $n
                lappend cnames "_$n"
                lappend cargs "$tag* $n"
            } else {
                set types($n) $t
                lappend varnames $n
                lappend cnames _$n
                lappend cargs "$t $n"
            }
        }
	}

	# Handle return type
	set rtag ""
	if {[string range $rtype 0 2] eq "ptr"} {
        set rtag [string range $rtype 4 end]
        set rtype "ptr"
    }
	switch -- $rtype {
		ok      {
			set rtype2 "int"
		}
		ptr     {
		    set rtype2 "void*"
		    if {$rtag ne ""} {
		        set rtype2 "${rtag}*"
		    }
		}
		string - dstring - vstring - fstring {
			set rtype2 "char*"
		}
		default {
			set rtype2 $rtype
		}
	}

	# Create wrapped function
	if {[llength $cargs] != 0} {
		set cargs_str [join $cargs {, }]
	} else {
		set cargs_str "void"
	}

	if {$body ne "#"} {
		append code "static $rtype2 ${cname}($cargs_str) \{\n"
		append code $body
		append code "\}\n"
	} else {
		set cname [namespace tail $name]
        append code "$rtype2 ${cname}($cargs_str);\n"
	}

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
	foreach x $varnames {
		set t $types($x)

		switch -- $t {
			int - long - float - double - char* - Tcl_WideInt - Tcl_Obj* {
				append cbody "  $types($x) _$x;" "\n"
			}
			default {
				append cbody "  void *_$x;" "\n"
			}
		}
	}

	if {$rtype ne "void"} {
		append cbody  "  $rtype2 rv;" "\n"
	}  

	append cbody "  if (objc != [expr {[llength $varnames] + 1}]) {" "\n"
	append cbody "    Tcl_WrongNumArgs(ip, 1, objv, \"[join $varnames { }]\");\n"
	append cbody "    return TCL_ERROR;" "\n"
	append cbody "  }" "\n"

	set n 0
	foreach x $varnames {
		incr n
		switch -- $types($x) {
			int {
				append cbody "  if (Tcl_GetIntFromObj(ip, objv\[$n], &_$x) != TCL_OK)"
				append cbody "    return TCL_ERROR;" "\n"
			}
			long {
				append cbody "  if (Tcl_GetLongFromObj(ip, objv\[$n], &_$x) != TCL_OK)"
				append cbody "    return TCL_ERROR;" "\n"
			}
			Tcl_WideInt {
				append cbody "  if (Tcl_GetWideIntFromObj(ip, objv\[$n], &_$x) != TCL_OK)"
				append cbody "    return TCL_ERROR;" "\n"
			}
			float {
				append cbody "  {" "\n"
				append cbody "    double t;" "\n"
				append cbody "    if (Tcl_GetDoubleFromObj(ip, objv\[$n], &t) != TCL_OK)"
				append cbody "      return TCL_ERROR;" "\n"
				append cbody "    _$x = (float) t;" "\n"
				append cbody "  }" "\n"
			}
			double {
				append cbody "  if (Tcl_GetDoubleFromObj(ip, objv\[$n], &_$x) != TCL_OK)"
				append cbody "    return TCL_ERROR;" "\n"
			}
			char* {
				append cbody "  _$x = Tcl_GetString(objv\[$n]);" "\n"
			}
			ptr {
			    set tag ""
			    catch {set tag $tags($x)}
			    if {$tag eq ""} {
			        set tag NULL
			    } else {
			        set tag \"$tag\"
                };#"
			    #Cinv_GetPointerFromObj(Tcl_Interp *interp, Tcl_Obj *obj, PTR_TYPE **ptr,char* tag)
			    set ::tcc4tcl::needPointers 1
			    append cbody " if(Cinv_GetPointerFromObj(ip, objv\[$n],(void*) &_$x,$tag)!=TCL_OK) return TCL_ERROR;" "\n"
			    #append cbody " if(cv!=TCL_OK) return TCL_ERROR; " "\n"
			    
			}
			default {
				append cbody "  _$x = objv\[$n];" "\n"
			}
		}
	}
	append cbody "\n"
    append cbody "  mod_Tcl_errorCode=0;//reset error\n"

	# Call wrapped function
	if {$rtype != "void"} {
        if {$rtype == "ptr"} {
            append cbody "  rv = "
        } else {
            append cbody "  rv = "
        }
    }
	append cbody "${cname}([join $cnames {, }]);" "\n"
	append cbody "  if(mod_Tcl_errorCode>0) {return TCL_ERROR;}\n"
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
	#
	# Added to allow memory of return value of type char* to be freed
	#   fstring   (char* freed by call to free() after interp is done with it)
	switch -- $rtype {
		void - ok - int - long - float - double - Tcl_WideInt {}
		default {
			append cbody "  if (rv == NULL) {\n"
			append cbody "    return(TCL_ERROR);\n"
			append cbody "  }\n"
		}
	}

	set tcl_setstringresult "Tcl_SetObjResult(ip,Tcl_NewStringObj( rv, -1 ));\n"
	switch -- $rtype {
		void           { }
		ok             { append cbody "  return rv;" "\n" }

		int            { append cbody "  Tcl_SetObjResult(ip, Tcl_NewIntObj(rv));" "\n" }
		long           { append cbody "  Tcl_SetObjResult(ip, Tcl_NewLongObj(rv));" "\n" }
		Tcl_WideInt    { append cbody "  Tcl_SetObjResult(ip, Tcl_NewWideIntObj(rv));" "\n" }
		float          -
		double         { append cbody "  Tcl_SetObjResult(ip, Tcl_NewDoubleObj(rv));" "\n" }

		char*          { append cbody "  $tcl_setstringresult" "\n" }
		string         -
		dstring        { append cbody "  $tcl_setstringresult" "\n" }
		vstring        { append cbody "  Tcl_SetResult(ip, rv, TCL_VOLATILE);" "\n" }
		fstring        { append cbody "  Tcl_SetResult(ip, rv, ((Tcl_FreeProc *) free));" "\n" }
		ptr            { append cbody "  Tcl_SetObjResult(ip,Cinv_NewPointerObj((void*)rv, \"$rtag\"));" "\n"; set ::tcc4tcl::needPointers 1  }

		default        { append cbody "  Tcl_SetObjResult(ip, rv); /*Tcl_DecrRefCount(rv);*/" "\n" }
	}

	if {$rtype != "ok"} {
		append cbody "  return TCL_OK;\n"
	}

	append cbody "}" "\n"

	return [list $code $cbody $wname]
}

namespace eval ::tcc4tcl {namespace export cproc}
package provide tcc4tcl "0.41"


