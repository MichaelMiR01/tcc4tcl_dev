/*  Override io.h for use in tcc4tcl 
    functions to override:
    lseek
    open
    close
    read
    
    Tcl IO Functions work on Tcl_Channel, io.h operate on int handles, 
    so we additionally need a mapping//hashtable to translate from one to the other
    
    in tcc.c beneath include tcc.h
    # @include "tcc.h"
    # @include "../tcl_iomap.c"
    #if ONE_SOURCE
    # @include "libtcc.c"
    #endif
    # @include "tcctools.c"
*/    
#ifndef HAVE_IOMAP_H
#define HAVE_IOMAP_H
#ifdef HAVE_TCL_H
#include "config_tcc4tcl.h"
#ifndef USE_TCL_STUBS
#define USE_TCL_STUBS
#endif
#ifndef _TCL
#include <tcl.h>
#endif

#ifdef NO_TCC_LIST_SYMBOLS
void tcc_list_symbols(TCCState *s, void *ctx,
    void (*symbol_cb)(void *ctx, const char *name, const void *val)) {
// dummy
    }
#endif

#include <fcntl.h>

#define open t_open
#define fdopen t_fdopen
#define fclose t_fclose
#define read t_read
#define lseek t_lseek
#define close t_close
#define fgets t_fgets
#define dup t_dup

#define stat(a,b) _t_stat(a,b)

#define MAXCHAN 128
#define CHANBASE 10000

// these are sometimes undefined under linux
#ifndef O_TEXT
#define O_TEXT 0x4000
#endif
#ifndef O_BINARY
#define O_BINARY 0x8000
#endif


/* taken from rosetta-code https://rosettacode.org/wiki/Stack#C */
#define DECL_STACK_TYPE(type, name)					\
typedef struct stk_##name##_t{type *buf; size_t alloc,len;}*stk_##name;	\
stk_##name stk_##name##_create(size_t init_size) {			\
	stk_##name s; if (!init_size) init_size = 4;			\
	s = tcc_malloc(sizeof(struct stk_##name##_t));			\
	if (!s) return 0;						\
	s->buf = tcc_malloc(sizeof(type) * init_size);			\
	if (!s->buf) { tcc_free(s); return 0; }				\
	s->len = 0, s->alloc = init_size;				\
	return s; }							\
int stk_##name##_push(stk_##name s, type item) {			\
	type *tmp;							\
	if (s->len >= s->alloc) {					\
		tmp = tcc_realloc(s->buf, s->alloc*2*sizeof(type));		\
		if (!tmp) return -1; s->buf = tmp;			\
		s->alloc *= 2; }					\
	s->buf[s->len++] = item;					\
	return s->len; }						\
type stk_##name##_pop(stk_##name s) {					\
	type tmp;							\
	if (!s->len) abort();						\
	tmp = s->buf[--s->len];						\
	if (s->len * 2 <= s->alloc && s->alloc >= 8) {			\
		s->alloc /= 2;						\
		s->buf = tcc_realloc(s->buf, s->alloc * sizeof(type));}	\
	return tmp; }							\
type stk_##name##_peek(stk_##name s) {					\
	type tmp;							\
	if (!s->len) abort();						\
	tmp = s->buf[s->len-1];						\
	return tmp; }							\
void stk_##name##_delete(stk_##name s) {				\
	tcc_free(s->buf); tcc_free(s); }
 
#define stk_empty(s) (!(s)->len)
#define stk_size(s) ((s)->len)
 
DECL_STACK_TYPE(int, int)

Tcl_Channel _tcl_channels[MAXCHAN];
static int _chan_cnt =0;
static int _chaninit=0;
static stk_int chan_stk;


void _initchantable () {
    _tcl_channels[0]=NULL;
    _chan_cnt=0;
    _chaninit=1;
    for(int i=0;i<MAXCHAN;i++) {
        _tcl_channels[i]=NULL;
    }
    chan_stk = stk_int_create(0);
}

void _cleanchanlist () {
    while (_tcl_channels[_chan_cnt]==NULL) {
        _chan_cnt+=-1;
        if(_chan_cnt<1) break;
    }
    _chan_cnt++;
}    

int _chan2int (Tcl_Channel chan) {
    // insert channel to array, incr cnt, return cnt
    // start with 1, not 0
    if(_chaninit==0) _initchantable();
    if(chan==NULL) return -1;
    _cleanchanlist ();
    _chan_cnt++;
    if (_chan_cnt>MAXCHAN) {
        // out of channels
        Tcl_Panic("Out of channels");
        return -1;
    }
    int i=1;
    while(i<_chan_cnt) {
        if(_tcl_channels[i]==NULL) {
            break;
        }
        i++;
    }
    _tcl_channels[i]=chan;
    return CHANBASE+i;    
}

Tcl_Channel _int2chan (int fd) {
    // get channel from array by int
    // start with 1 not 0
    Tcl_Channel chan;
    int fn;
    if(fd<CHANBASE) {
        return NULL; // not a tclhannel
    }
    fn=fd-CHANBASE;
    if (fn>_chan_cnt) {
        return NULL;
    }
    chan= _tcl_channels[fn];
    return chan;
}

int t_dup (int fd) {
    //
    int fn;
    if(fd<CHANBASE) {; // not a tclhannel
        #undef dup
        fn=dup(fd);
        #define dup t_dup
        return fn;
    }
    return fd;
}

#define BUF_SIZE 1024
static inline char *_strcatn(char *buf, const char *s)
{
    int len,lens;
    len = strlen(buf);
    lens = strlen(s);
    if (len+lens < BUF_SIZE)
        strcat(buf, s);
    return buf;
}

int callOpen(const char * path, int flags, va_list args) {
    #undef open
  if (flags & (O_CREAT))
  {
    //mode_t mode = va_arg(args, mode_t);
    //fake mode_t to int to satisfy older gcc va_arg can't pass mode_t for some reason
    int mode = va_arg(args, int);
    return open(path, flags, mode);
  }
  else {
    return open(path, flags);
  }
  #define open t_open
}
int t_open(const char *_Filename,int _OpenFlag,...) {
    Tcl_Channel chan;
    Tcl_Obj *path;
    char buf[BUF_SIZE];
    buf[0] = '\0';
    char* rdmode="RDONLY";
    int readmode=1;
    // interpret openflags to tcl
    int flagMask = 1 << 15; // start with high-order bit...
    while( flagMask != 0 )   // loop terminates once all flags have been compared
    {
      // switch on only a single bit...
      switch( _OpenFlag & flagMask )
      {
       //case O_RDONLY:
       //  _strcatn(buf,"RDONLY ");
       //  break;
       case O_WRONLY:
         rdmode="WRONLY";
         readmode=0;
         break;
       case O_RDWR:
         rdmode="RDWR";
         readmode=0;
         break;
       case O_APPEND:
         rdmode="APEND";
         readmode=0;
         break;
       case O_CREAT:
         rdmode="CREAT";
         readmode=0;
         break;
       case O_TRUNC:
         _strcatn(buf,"TRUNC ");
         readmode=0;
         break;
       case O_EXCL:
         _strcatn(buf,"EXCL ");
         break;
       case O_BINARY:
         _strcatn(buf,"BINARY ");
         break;
      }
      flagMask >>= 1;  // bit-shift the flag value one bit to the right
    }    
    _strcatn(buf,rdmode);
    if(readmode==0) {
        va_list args;
        va_start(args, _OpenFlag);
        return callOpen(_Filename, _OpenFlag, args);
    }
    if (strcmp(_Filename, "-") == 0) {
        chan = Tcl_GetStdChannel(TCL_STDIN);
        _Filename = "stdin";
    } else {
        path = Tcl_NewStringObj(_Filename,-1);
        Tcl_IncrRefCount(path);
        chan = Tcl_FSOpenFileChannel(NULL,path, buf, 0);
        Tcl_DecrRefCount(path);
    }    
    return _chan2int(chan);
}

int t_close(int _FileHandle) {
    //
    Tcl_Channel chan;
    chan=_int2chan(_FileHandle);
    if(chan!=NULL) {
        _tcl_channels[_FileHandle-CHANBASE]=NULL;
    }
    _cleanchanlist();
    
    if(chan==NULL) {
        #undef close
        return close(_FileHandle);
        #define close t_close
    }
    return Tcl_Close(NULL,chan);
}

int t_fclose(FILE* fp) {
    int lastchan=0;
    if(fp!=NULL) {
        #undef fclose
        return fclose(fp);
        #define fclose t_fclose
    }
    if(stk_size(chan_stk)) {
        lastchan=stk_int_pop(chan_stk);
    } 
    if(lastchan!=0) {
        Tcl_Channel chan=_int2chan(lastchan);
        t_close(lastchan);
    }
    return 1;
}

long t_lseek(int _FileHandle,long _Offset,int _Origin) {
    //
    Tcl_Channel chan;
    chan=_int2chan(_FileHandle);
    if(chan==NULL) {
        #undef lseek
        return lseek(_FileHandle,_Offset, _Origin);
        #define lseek t_lseek
    }
    return Tcl_Seek(chan, _Offset, _Origin);
}

int t_read(int _FileHandle,void *_DstBuf,unsigned int _MaxCharCount) {
    //
    Tcl_Channel chan;
    chan=_int2chan(_FileHandle);
    if(chan==NULL) {
        #undef read
        return read(_FileHandle,_DstBuf,_MaxCharCount);
        #define read t_read
    }
    return Tcl_Read(chan, (char * )_DstBuf, _MaxCharCount);

} 

char * t_fgets(char *_Buf,int _MaxCount,FILE *_File) {
    //
     int lastchan=0;
    _Buf[0]='\0';
    
    if(_File==NULL) {
        // tcl mode
        if(stk_size(chan_stk)) {
            lastchan=stk_int_peek(chan_stk);
        } 
        
        if(lastchan==0) {
            return NULL;
        }
        Tcl_Channel chan=_int2chan(lastchan);
        
        int n;
        for (n = 0; n < _MaxCount - 1; )
            if (Tcl_Read(chan, _Buf + n, 1) < 1 || _Buf[n++] == '\n')
                break;
        if (0 == n)
            return NULL;
        _Buf[n]='\0';
        return _Buf;
    } else {
        #undef fgets
        return fgets(_Buf,_MaxCount,_File);
        #define fgets t_fgets
    }
    return _Buf;
}

FILE *t_fdopen(int fd, const char *mode) {
    //
    Tcl_Channel chan;
    int tcl_ret;
    int native_fd,fd1;
    FILE* f;
    chan=_int2chan(fd);
    if(chan==NULL) {
        #undef fdopen
        f = fdopen(fd, mode);
        #define fdopen t_fdopen
        return f;
    }
    // Get Channel Handle, we will just need the readable part....
    tcl_ret = Tcl_GetChannelHandle(chan, TCL_READABLE, (void*)&native_fd);
    if (tcl_ret != TCL_OK) {
       stk_int_push(chan_stk, fd);
	   return NULL;
    }

	errno=0;
	fd1=native_fd;
	#ifdef _WIN32
	fd1=_open_osfhandle(native_fd,O_RDONLY);
	#endif

    #undef fdopen
    f=fdopen(fd1, mode);
    #define fdopen t_fdopen
    
    if (!f) {
        stk_int_push(chan_stk, fd);
        return NULL;
    }
    return f;
}

int t_stat(const char *entryname, struct stat *st) { 
    //
    Tcl_StatBuf statBuf; 
    Tcl_Obj *path;
    //printf("tclstat %s \n",entryname);
    path = Tcl_NewStringObj(entryname,-1);
    Tcl_IncrRefCount(path);
    int r=Tcl_FSStat(path, &statBuf); 
    Tcl_DecrRefCount(path);
    if(r) {
        #undef stat
        return stat(entryname,st);
        #define stat(a,b) t_stat(a,b)
    }
    st->st_size=statBuf.st_size;
    st->st_dev=statBuf.st_dev;
    st->st_ino=statBuf.st_ino;
    //printf("tclstat %s %d %d %d\n",entryname,statBuf.st_size,statBuf.st_dev,statBuf.st_ino);
    return r;
}

#endif // HAVE_TCL_H
#endif // HAVE_IOMAP_H 
