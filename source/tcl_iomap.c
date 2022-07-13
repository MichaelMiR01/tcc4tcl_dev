/*  Override io.h for use in tcc4tcl 
    functions to override:
    lseek
    open
    close
    read
    
    Tcl IO Functions work on Tcl_Channel, io.h operate on int handles, 
    so we additionally need a mapping//hashtable to translate from one to the other
    
    in tcc.c beneath include tcctools.c
    #include "tcl_iomap.c"
*/    

#ifdef HAVE_TCL_H

#ifndef USE_TCL_STUBS
#define USE_TCL_STUBS
#endif
#ifndef _TCL
#include <tcl.h>
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

#define MAXCHAN 128
#define CHANBASE 10000

Tcl_Channel _tcl_channels[MAXCHAN];
static int _chan_cnt =0;
static int lastchan=0;
static int _chaninit=0;

void _initchantable () {
    _tcl_channels[0]=NULL;
    _chan_cnt=0;
    _chaninit=1;
    for(int i=0;i<MAXCHAN;i++) {
        _tcl_channels[i]=NULL;
    }
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

#define str_append(buf,str) strcat(buf, str);
int t_open(const char *_Filename,int _OpenFlag,...) {
    Tcl_Channel chan;
    Tcl_Obj *path;
    char buf[1024], src[500];
    buf[0] = '\0';
    char* rdmode="RDONLY";
    int isnative=0;
    // interpret openflags to tcl
    int flagMask = 1 << 15; // start with high-order bit...
    while( flagMask != 0 )   // loop terminates once all flags have been compared
    {
      // switch on only a single bit...
      switch( _OpenFlag & flagMask )
      {
       //case O_RDONLY:
       //  str_append(buf,"RDONLY ");
       //  break;
       case O_WRONLY:
         rdmode="WRONLY";
         isnative=1;
         break;
       case O_RDWR:
         rdmode="RDWR";
         break;
       case O_APPEND:
         str_append(buf,"APPEND ");
         break;
       case O_CREAT:
         str_append(buf,"CREAT ");
         break;
       case O_TRUNC:
         str_append(buf,"TRUNC ");
         break;
       case O_EXCL:
         str_append(buf,"EXCL ");
         break;
       case O_BINARY:
         str_append(buf,"BINARY ");
         break;
      }
      flagMask >>= 1;  // bit-shift the flag value one bit to the right
    }    
    str_append(buf,rdmode);
    //tcc_warning("open %s %s",_Filename,buf);
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

char * t_fgets(char *_Buf,int _MaxCount,FILE *_File) {
    //
    _Buf[0]='\0';
    if(_File==NULL) {
        // tcl mode
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
        _Buf[n-1]='.';
        _Buf[n]='.';
        _Buf[n+1]='\0';
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
    int native_fd=0;
    FILE* f;
    lastchan=0;
    chan=_int2chan(fd);
    int tclmode=TCL_READABLE;
    if(&mode[0]!="r") {
        tclmode=TCL_WRITABLE;
    }
    if(chan==NULL) {
        #undef fdopen
        f = fdopen(fd, mode);
        #define fdopen t_fdopen
        return f;
    }
    // Get Channel Handle, we will just need the readable part....
    if(tclmode&&Tcl_GetChannelMode (chan)) {};
    tcl_ret = Tcl_GetChannelHandle(chan, tclmode, (void*)&native_fd);
    if (tcl_ret != TCL_OK) {
       lastchan=fd;
	   return NULL;
    }

    #undef fdopen
    f = fdopen(native_fd, mode);
    #define fdopen t_fdopen
    if (f==NULL) {
        lastchan=fd;
        return NULL;
    }
    return f;
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

int t_close(int _FileHandle) {
    //
    Tcl_Channel chan;
    chan=_int2chan(_FileHandle);
    if(chan==NULL) {
        #undef close
        return close(_FileHandle);
        #define close t_close
    }
    _tcl_channels[_FileHandle-CHANBASE]=NULL;
    _cleanchanlist();
    return Tcl_Close(NULL,chan);
}

int t_fclose(FILE* fp) {
    if(fp!=NULL) {
        #undef fclose
        return fclose(fp);
        #define fclose t_fclose
    }
    if(lastchan!=0) {
        Tcl_Channel chan=_int2chan(lastchan);
        t_close(lastchan);
        lastchan=0;
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

#endif // HAVE_TCL_H


