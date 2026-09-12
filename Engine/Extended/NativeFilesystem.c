// SPDX-License-Identifier: GPL-2.0-or-later
#include "NativeFilesystem.h"
#include <sys/stat.h>
#include <dirent.h>
#include <errno.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <copyfile.h>
bool MEFS_GetPathInfo(const char *path,MEFS_PathInfo *out) {
    struct stat st;
    if(stat(path,&st))return false;
    *out=(MEFS_PathInfo){S_ISDIR(st.st_mode)?MEFS_PATHTYPE_DIRECTORY:MEFS_PATHTYPE_FILE,
        st.st_size,(int64_t)st.st_mtimespec.tv_sec*1000000000+st.st_mtimespec.tv_nsec};
    return true;
}
const char *MEFS_GetError(void){return strerror(errno);}
bool MEFS_CreateDirectory(const char *path){if(!mkdir(path,0700))return true;struct stat st;return errno==EEXIST && !stat(path,&st) && S_ISDIR(st.st_mode);}
bool MEFS_RemovePath(const char *path){return remove(path)==0;}
bool MEFS_RenamePath(const char *from,const char *to){return rename(from,to)==0;}
bool MEFS_CopyFile(const char *from,const char *to){return copyfile(from,to,NULL,COPYFILE_DATA)==0;}
bool MEFS_SaveFile(const char *path,const void *data,size_t size){FILE *f=fopen(path,"wb");if(!f)return false;bool ok=fwrite(data,1,size,f)==size;return fclose(f)==0 && ok;}
bool MEFS_EnumerateDirectory(const char *path,MEFS_EnumerationResult (*callback)(void *,const char *,const char *),void *context){
    DIR *dir=opendir(path);if(!dir)return false;
    size_t n=strlen(path);char *prefix=malloc(n+2);if(!prefix){closedir(dir);return false;}
    memcpy(prefix,path,n);if(!n || path[n-1]!='/')prefix[n++]='/';prefix[n]=0;
    struct dirent *entry;errno=0;
    while((entry=readdir(dir))){if(!strcmp(entry->d_name,".") || !strcmp(entry->d_name,".."))continue;callback(context,prefix,entry->d_name);errno=0;}
    int error=errno;free(prefix);closedir(dir);errno=error;return error==0;
}
