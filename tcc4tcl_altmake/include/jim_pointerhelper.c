#ifndef POINTERHELPER_H
#define POINTERHELPER_H
/* Taken from cffi project
 * Pointer is a Tcl "type" whose internal representation is stored
 * as the pointer value and an associated C pointer/handle type.
 * The Jim_Obj.internalRep.twoPtrValue.ptr1 holds the C pointer value
 * and Jim_Obj.internalRep.twoPtrValue.ptr2 holds a Jim_Obj describing
 * the type. This may be NULL if no type info needs to be associated
 * with the value.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef Jim_Obj *Tclh_PointerTypeTag;

static Jim_Interp *_interp;
 
static void DupPointerType(Jim_Interp *interp, Jim_Obj *srcP, Jim_Obj *dstP);
static void FreePointerType(Jim_Interp *interp, Jim_Obj *objP);
static void UpdatePointerTypeString(Jim_Obj *objP);
static int  SetPointerFromAny(Jim_Interp *interp, Jim_Obj *objP);

static struct Jim_ObjType gPointerType = {
    "Pointer",
    FreePointerType,
    DupPointerType,
    UpdatePointerTypeString,
    0,
};
 void *PointerValueGet(Jim_Obj *objP) {
     //printf("DEBUG: PointerValueGet objP = %p\n",objP);
     //printf("DEBUG: PointerValueGet objP->internalRep.twoPtrValue.ptr1 = %p\n",objP->internalRep.twoPtrValue.ptr1);
    return objP->internalRep.twoPtrValue.ptr1;
}
 void PointerValueSet(Jim_Obj *objP, void *valueP) {
     //printf("DEBUG: PointerValueSet objP %p= %p\n",objP,valueP);
    objP->internalRep.twoPtrValue.ptr1 = valueP;
     //printf("DEBUG: PointerValueSet objP->internalRep.twoPtrValue.ptr1 = %p\n",objP->internalRep.twoPtrValue.ptr1);
}
/* May return NULL */
Tclh_PointerTypeTag PointerTypeGet(Jim_Obj *objP) {
    return objP->internalRep.twoPtrValue.ptr2;
}
void PointerTypeSet(Jim_Obj *objP, Tclh_PointerTypeTag tag) {
    objP->internalRep.twoPtrValue.ptr2 = (void*)tag;
}

int Tclh_PointerTagMatch(Tclh_PointerTypeTag pointer_tag, Tclh_PointerTypeTag expected_tag)
{
    if (expected_tag == NULL)
        return 1;               /* Anything can be a void pointer */
    if (pointer_tag == NULL)
        return 0;               /* But not the other way */

    if(!strcmp("ptr", Jim_String(expected_tag)))
        return 1;               /* Anything can be a unspecified pointer */
    if(!strcmp("ptr", Jim_String(pointer_tag)))
        return 1;               /* This can be converted as unspecified pointer */

    if(strcmp(Jim_String(pointer_tag), Jim_String(expected_tag))) {
        // this is just a warning
        //printf("Pointertypes diff got %s wanted %s\n",Jim_String(pointer_tag), Jim_String(expected_tag));
        return 0;
    }
    return 1;
}

static void
FreePointerType(Jim_Interp *interp, Jim_Obj *objP)
{ 
    Tclh_PointerTypeTag tag = PointerTypeGet(objP);
   //printf("DEBUG: FreePointerType %p\n",objP);
   //printf("DEBUG: size %d intrepstring %p size %d text %s\n",sizeof(*Tclh_PointerTypeTag),objP->bytes,objP->length,objP->bytes);
   //printf("DEBUG: tag is %p %s\n",tag,Jim_String(tag));
    PointerTypeSet(objP, NULL);
    PointerValueSet(objP, NULL);
    objP->typePtr = NULL;
   //printf("DEBUG: FreePointerType bytes %p %s\n",objP->bytes,objP->bytes);
    if (tag) Jim_DecrRefCount(interp, tag);
   //printf("DEBUG: FreePointerType end %p\n",objP);
    return;
}

static void
DupPointerType(Jim_Interp *interp, Jim_Obj *srcP, Jim_Obj *dstP)
{
   //printf("DEBUG: DupPointerType %p -> %p\n",srcP,dstP);
    Tclh_PointerTypeTag tag;
    dstP->typePtr = &gPointerType;
    PointerValueSet(dstP, PointerValueGet(srcP));
    tag = PointerTypeGet(srcP);
    if (tag)
        Jim_IncrRefCount(tag);
    PointerTypeSet(dstP, tag);
}
static int
SetPointerFromAny(Jim_Interp *interp, Jim_Obj *objP)
{
    //printf("DEBUG: SetPointerFromAny %p \n",objP);
    void *pv;
    Tclh_PointerTypeTag tagObj;
    const char *srep;
    char *s;

    if (objP->typePtr == &gPointerType)
        return JIM_OK;

    /* Pointers are address^tag, 0 or NULL*/
    srep = Jim_String(objP);
//    if (sscanf(srep, "0x%p^", &pv) == 1) 
   // SCNxPTR
   int scansucc=0;
    if (sizeof(void*) == sizeof(int)) {
        //snprintf(buf, buflen, "0x%.8x", i);
        scansucc=sscanf(srep, "0x%x", (unsigned int*)&pv);
        if (scansucc != 1) {
            // try as interger
            scansucc=sscanf(srep, "%u", (unsigned int*)&pv);
        }
    }
    else {
        //snprintf(buf, buflen, "0x%.16llx", ull);
        scansucc=sscanf(srep, "0x%llx", (unsigned long long int*) &pv);
        if (scansucc != 1) {
            // try as interger
            scansucc=sscanf(srep, "%llu", (unsigned long long int*)&pv);
        }
    }
   
   if (scansucc == 1) {
        s = strchr(srep, '^');
        if (s == NULL) {
            tagObj = Jim_NewStringObj(interp,"",-1);
            goto notag;
        }
        if (s[1] == '\0')
            tagObj = Jim_NewStringObj(interp,"",-1);
        else {
            tagObj = Jim_NewStringObj(interp, s + 1, -1);
            Jim_IncrRefCount(tagObj);
        }
    }
    else {
        if (strcmp(srep, "NULL"))
            goto invalid_value;
        pv = NULL;
        tagObj = NULL;
    }
notag:
    /* OK, valid opaque rep. Convert the passed object's internal rep */
    if (objP->typePtr && objP->typePtr->freeIntRepProc) {
        objP->typePtr->freeIntRepProc(interp, objP);
    }
    objP->typePtr = &gPointerType;
    PointerValueSet(objP, pv);
    PointerTypeSet(objP, tagObj);

    return JIM_OK;

invalid_value: /* s must point to value */
    return JIM_ERR;
}

char *TclhPrintAddress(const void *address, char *buf, int buflen)
{
    /*
     * Note we do not sue %p here because generated output differs
     * between compilers in terms of the 0x prefix. Moreover, gcc
     * prints (nil) for NULL pointers which is not what we want.
     */
    if (sizeof(void*) == sizeof(int)) {
        unsigned int i = (unsigned int) (intptr_t) address;
        snprintf(buf, buflen, "0x%.8x", i);
    }
    else {
        unsigned long long ull = (intptr_t)address;
        snprintf(buf, buflen, "0x%.16llx", ull);
    }
    return buf;
}

static void
UpdatePointerTypeString(Jim_Obj *objP)
{
    //printf("DEBUG: UpdatePointerTypeString %p \n",objP);
    Tclh_PointerTypeTag tagObj;
    int len;
    int taglen;
    const char *tagStr;
    char *bytes;

    tagObj = PointerTypeGet(objP);
    if (tagObj) {
        tagStr = Jim_GetString(tagObj, &taglen);
    }
    else {
        tagStr = "";
        taglen = 0;
    }
    /* Assume 40 bytes enough for address */
    bytes = malloc(40 + 1 + taglen + 1);
    (void) TclhPrintAddress(PointerValueGet(objP), bytes, 40);
   //printf("ptr bytes: %p %s\n",bytes,bytes);
    len = strlen(bytes);
    bytes[len] = '^';
    memcpy(bytes + len + 1, tagStr, taglen+1);
    objP->bytes = Jim_StrDup(bytes);
    objP->length = len + 1 + taglen;
    free(bytes);
}

Jim_Obj *
Tclh_PointerWrap(Jim_Interp* interp, void *pointerValue, Tclh_PointerTypeTag tag)
{
    Jim_Obj *objP;

    objP = Jim_NewObj(interp);
    //printf("DEBUG: Tclh_PointerWrap new %p from tag %p \n",objP,tag);
   //printf ("invalidating %p %p\n",objP,objP->bytes);
    //Jim_InvalidateStringRep(objP);
    objP->bytes = NULL;
    PointerValueSet(objP, pointerValue);
    if (tag)
        Jim_IncrRefCount(tag);
    PointerTypeSet(objP, tag);
    objP->typePtr = &gPointerType;
    return objP;
}

int
Tclh_PointerUnwrap(Jim_Interp *interp,
                   Jim_Obj *objP,
                   void **pvP,
                   Tclh_PointerTypeTag expected_tag)
{
    //printf("DEBUG: Tclh_PointerUnwrap  %p \n",objP);
    Tclh_PointerTypeTag tag;
    void *pv;
   //printf("Tclh_PointerUnwrap %p\n",objP);
    /* Try converting Jim_Obj internal rep */
    if (objP->typePtr != &gPointerType) {
        if (SetPointerFromAny(interp, objP) != JIM_OK) {
            Jim_SetResultString(interp, "",-1);
            Jim_AppendStrings(interp, Jim_GetResult(interp), "Pointer error with ",Jim_String(objP),NULL);
            return JIM_ERR;
        }
    }

    tag = PointerTypeGet(objP);
    pv  = PointerValueGet(objP);
    if(pv==NULL) {
        //printf("Got NULL pointer\n");
        // NULL pointers should be compatible to anything
    }
    /*
    * No tag check if
    * - expected_tag is NULL or
    * - pointer is NULL AND has no tag
    * expected_tag NULL means no type check
    * NULL pointers
    */
    if (expected_tag && (pv || tag)
        && !Tclh_PointerTagMatch(tag, expected_tag)) {
            Jim_SetResultString(interp, "err",-1);
        Jim_AppendStrings(interp, Jim_GetResult(interp), "Pointertypes diff got ",Jim_String(tag), " wanted ",Jim_String(expected_tag),NULL);
        return JIM_ERR;
    }

    *pvP = PointerValueGet(objP);
    return JIM_OK;
}



/* taken from ffidl project and modified a bit to our needs */
/*
 * Tcl object type used for representing pointers within Tcl.
 *
 * We wrap an existing "expr"-compatible Jim_ObjType, in order to easily support
 * pointer arithmetic and formatting withing Tcl.  The size of the Jim_ObjType
 * needs to match the pointer size of the platform: long on LP64, Jim_WideInt on
 * LLP64 (e.g. WIN64).
 */
 
#include "stdint.h"

#if INTPTR_MAX == INT32_MAX
    #define THIS_IS_32_BIT_ENVIRONMENT
    #define SIZEOF_VOID_P 4
    #define INTTYPE int
#elif INTPTR_MAX == INT64_MAX
    #define THIS_IS_64_BIT_ENVIRONMENT
    #define SIZEOF_VOID_P 8
    #if SIZEOF_VOID_P == __SIZEOF_LONG__
        #define INTTYPE long
    #else
        #define INTTYPE long long
    #endif
#else
    #error "Environment not 32 or 64-bit."
#endif
 
#if SIZEOF_VOID_P == __SIZEOF_LONG__
#  define CINV_POINTER_IS_LONG 1
#elif SIZEOF_VOID_P == 8 && defined(HAVE_WIDE_INT)
#  define CINV_POINTER_IS_LONG 0
#else
#  error "pointer size not supported"
#endif
#if CINV_POINTER_IS_LONG
# define PTR_TYPE long
# define JIM_NEWPTROBJ Jim_NewLongObj
static Jim_Obj *Cinv_NewPointerObj(Jim_Interp *interp, PTR_TYPE *ptr,char* tag) {
    _interp=interp;
    Jim_Obj* o=Jim_NewStringObj(interp, tag,-1);
    Jim_Obj*rv= Tclh_PointerWrap(interp,ptr,o);
  //printf("PTR_TYPE long Cinv_NewPointerObj in interp %p from ptr_type %p == %p\n",interp,ptr,rv);
   //printf("DEBUG: Jim_Obj* o =%p Jim_Obj* rv= %p %s\n",o,rv,Jim_String(rv));
    return rv;
    
}
static int Cinv_GetPointerFromObj(Jim_Interp *interp, Jim_Obj *obj, PTR_TYPE **ptr,char* tag) {
  int status;
  long l;
    _interp=interp;
  void *pvP=NULL;
  Jim_Obj* otag;
  if(tag!=NULL) {
      otag= Jim_NewStringObj(interp, tag,-1);
  } else {
      otag= Jim_NewStringObj(interp, "ptr",-1);
  }

  status =Tclh_PointerUnwrap(interp, obj, &pvP, otag);
  //if (Jim_IsShared(otag)) Jim_DecrRefCount(interp, otag);
  if (otag) Jim_DecrRefCount(interp, otag);
  if(status!=JIM_OK) {
      return JIM_ERR;
  }
  l=(long) pvP;
  if(l==0) {
      *ptr=NULL;
      return JIM_OK;
  } else {
      *ptr = (PTR_TYPE *)l;
  }
  //printf("PTR_TYPE long Cinv_GetPointerFromObj in interp %p from ptr_type %p\n",interp,l);
   //printf("DEBUG: Jim_Obj* obj =%p void *pvP= %p (%p) PTR_TYPE **ptr %p (%p)\n",obj,&pvP,pvP, ptr, *ptr);
  
  return status;
}
#  define CINV_GETPOINTER CINV_GETINT
#else
#  define PTR_TYPE Jim_WideInt
# define JIM_NEWPTROBJ Jim_NewWideIntObj

static Jim_Obj *Cinv_NewPointerObj(Jim_Interp *interp, PTR_TYPE *ptr) {
    _interp=interp;
    Jim_Obj* o=Jim_NewStringObj(interp, tag,-1);
    Jim_Obj* rv= Tclh_PointerWrap(interp,ptr,o);
   //printf("PTR_TYPE Jim_WideInt Cinv_NewPointerObj in interp %p from ptr_type %p\n",interp,ptr);
   //printf("DEBUG: Jim_Obj* o =%p Jim_Obj* rv= %p\n",o,rv);
    return rv;
}
static int Cinv_GetPointerFromObj(Jim_Interp *interp, Jim_Obj *obj, PTR_TYPE **ptr) {
  int status;
    _interp=interp;
  Jim_WideInt w;
  void *pvP=NULL;
  Jim_Obj* otag;
  if(tag!=NULL) {
      otag= Jim_NewStringObj(interp, tag,-1);
  } else {
      otag= Jim_NewStringObj(interp, "ptr",-1);
  }
  status =Tclh_PointerUnwrap(interp, obj, &pvP, otag);
  //if (Jim_IsShared(otag)) Jim_DecrRefCount(interp, otag);
  if (otag) Jim_DecrRefCount(interp, otag);
  if(status!=JIM_OK) {
      return JIM_ERR;
  }
  w=(Jim_WideInt)pvP;
  if(w==0) {
      *ptr=NULL;
  } else {
      *ptr = (PTR_TYPE *)w;
  }
   //printf("PTR_TYPE Jim_WideInt Cinv_GetPointerFromObj in interp %p from ptr_type %p\n",interp,w);
   //printf("DEBUG: Jim_Obj* obj =%p void *pvP= %p\n",obj,&pvP);
  return status;
}
#  define CINV_GETPOINTER CINV_GETWIDEINT
#endif
static Jim_Obj *PointerCast(Jim_Interp* interp, Jim_Obj* obj, Jim_Obj* newtag) {
    _interp=interp;
    void *pvP=NULL;
    Tclh_PointerUnwrap(interp, obj, &pvP, NULL);
    Jim_Obj*rv= Tclh_PointerWrap(interp,pvP,newtag);
    return rv;
}    
#endif
