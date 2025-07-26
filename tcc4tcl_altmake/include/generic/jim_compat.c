// jim_missing.c
// some missing routines from jim we need to work with tcc4tcl
// and some compat redefines for easier porting between tcl and jimtcl
// Jim_GetInt

#define TCL_OK      JIM_OK
#define TCL_ERROR   JIM_ERR
#define TCL_RETURN  JIM_RETURN
#define TCL_BREAK   JIM_BREAK
#define TCL_CONTINUE JIM_CONTINUE

#define Tcl_Interp Jim_Interp
#define ClientData void
#define Tcl_WideInt jim_wide
#define Tcl_Obj Jim_Obj

int Jim_GetInt(Jim_Interp *interp, Jim_Obj *objPtr, int *intPtr)
{
    jim_wide wideValue;
    int retval;

    retval = Jim_GetWide(interp, objPtr, &wideValue);
    if (retval == JIM_OK) {
        *intPtr = (int)wideValue;
        return JIM_OK;
    }
    return JIM_ERR;
}

