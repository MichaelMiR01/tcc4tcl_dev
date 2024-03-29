/*
 *  TclTCC - Tcl binding to Tiny C Compiler
 * 
 *  Copyright (c) 2007 Mark Janssen
 *  Copyright (c) 2014 Roy Keene
 *  Modified 2022 by Michael Richter
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */
#include <stdlib.h>
#ifndef USE_TCL_STUBS
#define USE_TCL_STUBS
#endif
#include <tcl.h>
#include <tclInt.h>

/*
 * <setjmp.h> is used for the optional error recovery mechanism 
 */

#include <setjmp.h>


// don't include unistd.h since this conflicts with tcl/compat/unistd.h
#define	_UNISTD_H	1

#include "tcc.h"
#include "config_tcc4tcl.h"

/* In tcc 0.9.28 mob b671fc0 from Feb, 9th 2024 an API/ABI break appeared
in tcc_relocate, dropping the second argument
old version tcc_relocate(s, TCC_RELOCATE_AUTO)
new version tcc_relocate(s)
*/

#ifdef TCC_RELOCATE_AUTO
#define _TCC_RELOCATE_ tcc_relocate(s, TCC_RELOCATE_AUTO)
#else
#define _TCC_RELOCATE_ tcc_relocate(s)
#endif




struct TclTCCState {
	TCCState *s;
	int relocated;
	int initok;
};

struct TclTCCObj {
    Tcl_Interp* interp;
    Tcl_Obj* obj;
};
typedef struct TclTCCObj TclTCCObj;

void tcc_delete_run(TCCState *s1);

static int Tcc4tclSetupCompiler(TCCState *s) {
    //
    tcc_set_output_type(s,s->output_type);

    #define TCC_USE_PTR_SIZE
    #ifndef TCC_USE_PTR_SIZE
        tcc_define_symbol(s, "__SIZE_TYPE__", "unsigned long");
        tcc_define_symbol(s, "__PTRDIFF_TYPE__", "long int");
        tcc_define_symbol(s, "__SIZE_TYPE__", "unsigned long int");
        tcc_define_symbol(s, "__PTRDIFF_TYPE__", "long int");
    #endif
    #ifdef USE_TCL_STUBS
        tcc_define_symbol(s, "USE_TCL_STUBS", "1");
        if (s->output_type == TCC_OUTPUT_MEMORY) {
            /* Only add this symbol if we are compiling to memory */
            #ifdef TCC_TARGET_PE
                // define stubsptr as dllimport symbols to satisfy tcc's needs
                tcc_define_symbol(s, "tclStubsPtr", "(*_imp__tclStubsPtr)");
                tcc_define_symbol(s, "tclIntStubsPtr", "(*_imp__tclIntStubsPtr)");
            #endif
            tcc_add_symbol(s, "tclStubsPtr", &tclStubsPtr);
            tcc_add_symbol(s, "tclIntStubsPtr", &tclIntStubsPtr);
            tcc_add_symbol(s, "Tcl_InitStubs", &Tcl_InitStubs);
        }
    #endif

}

void Tcc4tclAppendSymbol (ClientData cdata, const char *name, const void *val) {
    struct TclTCCObj* ts;
    Tcl_Obj *mystring;

    ts = (struct TclTCCObj *) cdata;
    Tcl_Interp* interp= ts->interp;
    Tcl_Obj* listObj=ts->obj;
    mystring=Tcl_NewStringObj(name, -1);
    Tcl_ListObjAppendElement(interp, listObj, mystring);
}

int Tcc4tclListSymbols (Tcl_Interp * interp, TCCState *s) {
    
    static struct TclTCCObj listObj;
    
    Tcl_Obj *my_list = Tcl_NewListObj(0, NULL);
    listObj.interp=interp;
    listObj.obj=my_list;
    tcc_list_symbols (s, &listObj, Tcc4tclAppendSymbol);
    Tcl_SetObjResult(interp, my_list);
    return TCL_OK;    

}

static void Tcc4tclErrorFunc(Tcl_Interp * interp, char * msg) {
	Tcl_AppendResult(interp, msg, "\n", NULL);
}

static void Tcc4tclCCommandDeleteProc(ClientData cdata) {
	struct TclTCCState *ts;
	TCCState *s ;

	ts = (struct TclTCCState *) cdata;
	s = ts->s;
	/* carefull with this */
	/* regular tcc_delete will also kill our compiled code */
	/* so we need to use a modified version that kills all, but runtime_memory */
	/* therefor libtcc.c has to be tuned accordingly */
	/* this should be done by modd_tcc.tcl automatically */
	#ifdef TCC4TCL_DODELETE
	    tcc_delete(s);
	#endif
	
	ts->s = NULL;

	ckfree((void *) ts);
}

static void Tcc4tclDeleteClientData(ClientData cdata) {
	/*
	 * ClientData is a Tcl_Obj*, that was passed in 
	 * at command creation
	 */
	Tcl_Obj *cdata_o = (Tcl_Obj *)cdata;

	if (cdata_o != NULL) {
		Tcl_DecrRefCount(cdata_o);
	}
}

static int Tcc4tclHandleCmd ( ClientData cdata, Tcl_Interp *interp, int objc, Tcl_Obj * CONST objv[]){
	Tcl_WideInt val;
	Tcl_Obj *val_o;
	void *val_p;
	void *val_p2;
	int index;
	int res;
    FILE *ppfp = NULL;
	
	struct TclTCCState *ts;
	TCCState *s;
	Tcl_Obj *sym_addr;
	static CONST char *options[] = {
		"add_include_path", "add_file",  "add_library", 
		"add_library_path", "add_symbol", "command", "nrcommand", "compile",
		"define", "get_symbol", "output_file", "undefine", "set_options", "list_symbols",
		(char *) NULL
	};
	enum options {
		TCC4TCL_ADD_INCLUDE, TCC4TCL_ADD_FILE, TCC4TCL_ADD_LIBRARY, 
		TCC4TCL_ADD_LIBRARY_PATH, TCC4TCL_ADD_SYMBOL, TCC4TCL_COMMAND,
		TCC4TCL_NRCOMMAND, TCC4TCL_COMPILE, TCC4TCL_DEFINE, TCC4TCL_GET_SYMBOL,
		TCC4TCL_OUTPUT_FILE, TCC4TCL_UNDEFINE, TCC4TCL_SET_OPTIONS, TCC4TCL_LIST_SYMBOLS,
	};
	char *str;
	int rv;
	
	ts = (struct TclTCCState *) cdata;
	s = ts->s;

    if (objc < 2) {
        Tcl_WrongNumArgs(interp, 1, objv, "subcommand arg ?arg ...?");
        return TCL_ERROR;
    }

    if (Tcl_GetIndexFromObj(interp, objv[1], options, "option", 0,
                &index) != TCL_OK) {
        return TCL_ERROR;
    }

    switch (index) {
        case TCC4TCL_SET_OPTIONS:
            if (objc != 3) {
                Tcl_WrongNumArgs(interp, 2, objv, "options");
                return TCL_ERROR;
            } else {
                #ifdef TCC_SET_STATE
                    tcc_enter_state(s);
                #endif
                s->error_set_jmp_enabled = 1;
            
                if (setjmp(s->error_jmp_buf) == 0) {
                    s->nb_errors = 0;
                    tcc_set_options(s, Tcl_GetString(objv[2]));
                }
                s->error_set_jmp_enabled = 0;
                #ifdef TCC_SET_STATE
                    tcc_exit_state(s);
                #endif

                return s->nb_errors != 0 ? TCL_ERROR : TCL_OK;
            }
        case TCC4TCL_ADD_INCLUDE:   
            if (objc != 3) {
                Tcl_WrongNumArgs(interp, 2, objv, "path");
                return TCL_ERROR;
            } else {
                tcc_add_include_path(s, Tcl_GetString(objv[2]));
                return TCL_OK;
            }
        case TCC4TCL_ADD_FILE:   
            if (objc != 3) {
                Tcl_WrongNumArgs(interp, 2, objv, "filename");
                return TCL_ERROR;
            } else {
                if (!ts->initok) {
                    Tcc4tclSetupCompiler(s);
                    ts->initok=1;
                }
                if(tcc_add_file(s, Tcl_GetString(objv[2]))!=0) {
                    return TCL_ERROR;
                } else {
                    return TCL_OK;
                }
            }
        case TCC4TCL_ADD_LIBRARY:
            if (objc != 3) {
                Tcl_WrongNumArgs(interp, 2, objv, "lib");
                return TCL_ERROR;
            } else {
                if (!ts->initok) {
                    Tcc4tclSetupCompiler(s);
                    ts->initok=1;
                }
                tcc_add_library(s, Tcl_GetString(objv[2]));
                return TCL_OK;
            }
            
        case TCC4TCL_ADD_LIBRARY_PATH:
            if (objc != 3) {
                Tcl_WrongNumArgs(interp, 2, objv, "path");
                return TCL_ERROR;
            } else {
                tcc_add_library_path(s, Tcl_GetString(objv[2]));
                return TCL_OK;
            }
        case TCC4TCL_ADD_SYMBOL:
            if (objc != 4) {
                Tcl_WrongNumArgs(interp, 2, objv, "symbol value");
                return TCL_ERROR;
            }

            rv = Tcl_ExprObj(interp, Tcl_ObjPrintf("wide(%s)", Tcl_GetString(objv[3])), &val_o);
            if (rv != TCL_OK) {
                return TCL_ERROR;
            }

            rv = Tcl_GetWideIntFromObj(interp, val_o, &val);
            if (rv != TCL_OK) {
                return TCL_ERROR;
            }

            val_p = (void *) (intptr_t) val;

            if (!ts->initok) {
                Tcc4tclSetupCompiler(s);
                ts->initok=1;
            }

            tcc_add_symbol(s,Tcl_GetString(objv[2]), val_p); 
            return TCL_OK; 
        case TCC4TCL_COMMAND:
            if (objc != 4 && objc != 5) {
                Tcl_WrongNumArgs(interp, 2, objv, "tclname cname ?clientData?");
                return TCL_ERROR;
            }

            if (!ts->relocated) {     
                if(_TCC_RELOCATE_!=0) {
                    Tcl_AppendResult(interp, "relocating failed", NULL);
                    return TCL_ERROR;
                } else {
                    ts->relocated=1;
                }
            }

            val_p = tcc_get_symbol(s, Tcl_GetString(objv[3]));
            if (val_p == NULL) {
                Tcl_AppendResult(interp, "symbol '", Tcl_GetString(objv[3]),"' not found", NULL);
                return TCL_ERROR;
            }
    
            /* the ClientData */
            if (objc == 5) {
                val_o = objv[4];
                Tcl_IncrRefCount(val_o);
            } else {
                val_o = NULL;
            }

            /*printf("symbol: %x\n",val); */
            Tcl_CreateObjCommand(interp, Tcl_GetString(objv[2]), val_p, val_o, Tcc4tclDeleteClientData);
            return TCL_OK;
        case TCC4TCL_NRCOMMAND:
	        if (objc != 5 && objc != 6) {
		    Tcl_WrongNumArgs(interp, 3, objv, "tclname cname nrcname ?clientData?");
		    return TCL_ERROR;
	        }
            
	        if (!ts->relocated) {
		    if(_TCC_RELOCATE_!=0) {
		        Tcl_AppendResult(interp, "relocating failed", NULL);
		        return TCL_ERROR;
		    } else {
		        ts->relocated=1;
		    }
	        }
            
	        val_p = tcc_get_symbol(s, Tcl_GetString(objv[3]));
	        if (val_p == NULL) {
                Tcl_AppendResult(interp, "symbol '", Tcl_GetString(objv[3]),"' not found", NULL);
                return TCL_ERROR;
	        }
            
	        val_p2 = tcc_get_symbol(s, Tcl_GetString(objv[4]));
	        if (val_p2 == NULL) {
                Tcl_AppendResult(interp, "symbol '", Tcl_GetString(objv[4]),"' not found", NULL);
                return TCL_ERROR;
            }
    
            /* the ClientData */
            if (objc == 6) {
                val_o = objv[5];
                Tcl_IncrRefCount(val_o);
            } else {
                val_o = NULL;
            }

	        /*printf("symbol: %x\n",val); */
	        Tcl_NRCreateCommand(interp, Tcl_GetString(objv[2]), val_p, val_p2, val_o, Tcc4tclDeleteClientData);
            return TCL_OK;
        case TCC4TCL_COMPILE:
            if(ts->relocated == 1) {
                Tcl_AppendResult(interp, "code already relocated, cannot compile more",NULL);
                return TCL_ERROR;
            }
            if (objc < 3) {
                Tcl_WrongNumArgs(interp, 2, objv, "ccode");
                return TCL_ERROR;
            } else {
                if (!ts->initok) {
                    Tcc4tclSetupCompiler(s);
                    ts->initok=1;
                }
                
if ((s->output_type==TCC_OUTPUT_PREPROCESS)||(s->do_debug>1)) {
    // for preprocessing we need an immediate outfile
    // this can be given as an extra option on tcc compile code outfile
    // or set_options -o outfile
    // else exit this part with error
    if (objc == 4) {
        s->outfile = tcc_strdup(Tcl_GetString(objv[3]));
    } 
    ppfp = fopen(s->outfile, "w");
    if (!ppfp) {
        Tcl_AppendResult(interp, "could not write preprocessed code//debug files, no outfile given or unable to open ",s->outfile, NULL);
        //return TCL_ERROR;
    }
    s->ppfp=ppfp;
}

                int i;
                Tcl_GetString(objv[2]);
                
                i = tcc_compile_string(s,Tcl_GetString(objv[2]));
                
if (ppfp && ppfp != stdout) {
    fclose(ppfp);
    Tcl_AppendResult(interp,"Preprocessing ready... see ",s->outfile,NULL);
}
                
                if (i!=0) {
                    Tcl_AppendResult(interp,"Compilation failed",NULL);
                    return TCL_ERROR;
                } else {
                    return TCL_OK;
                }
            }
        case TCC4TCL_DEFINE:
            if (objc != 4) {
                Tcl_WrongNumArgs(interp, 2, objv, "symbol value");
                return TCL_ERROR;
            }
            tcc_define_symbol(s,Tcl_GetString(objv[2]),Tcl_GetString(objv[3]));
            return TCL_OK;
            
        case TCC4TCL_LIST_SYMBOLS: 
            return Tcc4tclListSymbols(interp, s);
        case TCC4TCL_GET_SYMBOL:
            if (objc != 3) {
                Tcl_WrongNumArgs(interp, 2, objv, "symbol");
                return TCL_ERROR;
            }
            if (!ts->relocated) {     
                if(_TCC_RELOCATE_!=0) {
                    Tcl_AppendResult(interp, "relocating failed", NULL);
                    return TCL_ERROR;
                } else {
                    ts->relocated=1;
                }
            }
            val_p = tcc_get_symbol(s,Tcl_GetString(objv[2]));
            if(val_p == NULL) {
                Tcl_AppendResult(interp, "symbol '", Tcl_GetString(objv[2]),"' not found", NULL);
                return TCL_ERROR;
            }
            sym_addr = Tcl_NewWideIntObj((intptr_t) val_p);
            Tcl_SetObjResult(interp, sym_addr);
            return TCL_OK; 
        case TCC4TCL_OUTPUT_FILE:
            if (objc != 3) {
                Tcl_WrongNumArgs(interp, 2, objv, "filename");
                return TCL_ERROR;
            }
            if (ts->relocated) {     
                Tcl_AppendResult(interp, "code already relocated, cannot output to file", NULL);
                return TCL_ERROR;
            }
            if (s->output_type == TCC_OUTPUT_MEMORY) {     
                Tcl_AppendResult(interp, "output_type memory not valid for output to file", NULL);
                return TCL_ERROR;
            }
            res = tcc_output_file(s,Tcl_GetString(objv[2]));
            ts->relocated=1;
            if (res!=0) {
                Tcl_AppendResult(interp, "output to file failed", NULL);
                return TCL_ERROR;
            } else {
                return TCL_OK;
            }
        case TCC4TCL_UNDEFINE:
            if (objc != 3) {
                Tcl_WrongNumArgs(interp, 2, objv, "symbol");
                return TCL_ERROR;
            }
            tcc_undefine_symbol(s,Tcl_GetString(objv[2]));
            return TCL_OK;
        
        default:
            Tcl_Panic("internal error during option lookup");
    }
    return TCL_OK;
} 

static int Tcc4tclCreateCmd( ClientData cdata, Tcl_Interp *interp, int objc, Tcl_Obj * CONST objv[]){
	struct TclTCCState *ts;
	TCCState *s;
    	int index;
	static CONST char *types[] = {
		//"memory", "exe", "dll", "obj", "preprocess",    (char *) NULL
		// 0.9.26 to 0.9.27 the enum changed
		"","memory", "exe", "dll", "obj", "preprocess",    (char *) NULL
	};
	// since tcc devel keeps changing the order of TCC_OUTPUT_ options we have to map the defined macros back to tcc4tcl textual tpyes, sigh
	static CONST int enumtypes[] = {
		0,
		TCC_OUTPUT_MEMORY,
		TCC_OUTPUT_EXE,
		TCC_OUTPUT_DLL,
		TCC_OUTPUT_OBJ,
		TCC_OUTPUT_PREPROCESS,
		0
	};
	
	if (objc < 3 || objc > 4) {
		Tcl_WrongNumArgs(interp, 1, objv, "tcc_libary_path ?output_type? handle");
		return TCL_ERROR;
	}

	if (objc == 3) {
		index = TCC_OUTPUT_MEMORY;
	} else {
		if (Tcl_GetIndexFromObj(interp, objv[2], types, "type", 0, &index) != TCL_OK) {
			return TCL_ERROR;
		}
		index = enumtypes[index];
	}

	s = tcc_new();
	
	if (s == NULL) {
		return(TCL_ERROR);
	}
	s->output_type = index;
	s->static_link = 0;
	tcc_set_lib_path(s, Tcl_GetString(objv[1]));
	
/*	
	tcc_set_output_type(s,index);

#define TCC_USE_PTR_SIZE
#ifndef TCC_USE_PTR_SIZE
    tcc_define_symbol(s, "__SIZE_TYPE__", "unsigned long");
    tcc_define_symbol(s, "__PTRDIFF_TYPE__", "long int");
    tcc_define_symbol(s, "__SIZE_TYPE__", "unsigned long int");
    tcc_define_symbol(s, "__PTRDIFF_TYPE__", "long int");
#endif
	*/
	ts = (void *) ckalloc(sizeof(*ts));
	ts->s = s;
    ts->relocated = 0;
    ts->initok = 0;


	tcc_set_error_func(s, interp, (void *)&Tcc4tclErrorFunc);
/*
#ifdef USE_TCL_STUBS
	tcc_define_symbol(s, "USE_TCL_STUBS", "1");
	if (index == TCC_OUTPUT_MEMORY) {
		// Only add this symbol if we are compiling to memory 
		#ifdef TCC_TARGET_PE
		    // define stubsptr as dllimport symbols to satisfy tcc's needs
            tcc_define_symbol(s, "tclStubsPtr", "(*_imp__tclStubsPtr)");
            tcc_define_symbol(s, "tclIntStubsPtr", "(*_imp__tclIntStubsPtr)");
        #endif
		tcc_add_symbol(s, "tclStubsPtr", &tclStubsPtr);
		tcc_add_symbol(s, "tclIntStubsPtr", &tclIntStubsPtr);
		tcc_add_symbol(s, "Tcl_InitStubs", &Tcl_InitStubs);
	}
#endif
*/
	/*printf("type: %d\n", index); */
	
	Tcl_CreateObjCommand(interp,Tcl_GetString(objv[objc-1]),Tcc4tclHandleCmd,ts,Tcc4tclCCommandDeleteProc);

	Tcl_SetObjResult(interp, objv[objc-1]);

	return TCL_OK;
}

#if (defined(_WIN32) && (defined(_MSC_VER)|| defined(__TINYC__)  || (defined(__BORLANDC__) && (__BORLANDC__ >= 0x0550)) || defined(__LCC__) || defined(__WATCOMC__) || (defined(__GNUC__) && defined(__declspec))))
#undef DLLIMPORT
#undef DLLEXPORT
#   define DLLIMPORT __declspec(dllimport)
#   define DLLEXPORT __declspec(dllexport)
#else
#undef DLLIMPORT
#undef DLLEXPORT
#   define DLLIMPORT __attribute__(dllimport)
#   if defined(__GNUC__) && __GNUC__ > 3
#       define DLLEXPORT __attribute__ ((visibility("default")))
#   else
#       define DLLEXPORT
#   endif
#endif


DLLEXPORT
int Tcc4tcl_Init(Tcl_Interp *interp) {
#ifdef USE_TCL_STUBS
	if (Tcl_InitStubs(interp, TCL_VERSION , 0) == 0L) {
		return TCL_ERROR;
	}
#endif

	Tcl_CreateObjCommand(interp, "tcc4tcl", Tcc4tclCreateCmd, NULL, NULL);
    Tcl_SetVar(interp,  "::TCC_VERSION", TCC_VERSION, 0);
	return TCL_OK;
}
