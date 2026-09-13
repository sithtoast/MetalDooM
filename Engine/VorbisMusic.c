// SPDX-License-Identifier: GPL-2.0-or-later
#define STB_VORBIS_NO_STDIO
#define STB_VORBIS_NO_PUSHDATA_API
#define STB_VORBIS_MAX_CHANNELS 2
#include "../Vendor/stb/stb_vorbis.c"
#include <stdint.h>
// A bounded, owned PCM copy. Swift releases with MD_FreeVorbis; no decoder state
// or filesystem access escapes this function.
int MD_DecodeVorbis(const uint8_t *data,int length,short **pcm,int *channels,int *rate) {
    *pcm=NULL;*channels=0;*rate=0;
    if(!data || length<32 || length>64*1024*1024)return -1;
    size_t cursor=0;unsigned page=0;int ended=0;uint32_t serial=0;
    while(cursor<(size_t)length) {
        if(ended || (size_t)length-cursor<27 || memcmp(data+cursor,"OggS",4) || data[cursor+4]!=0)return -1;
        const uint8_t *p=data+cursor;unsigned segments=p[26];
        if((size_t)length-cursor<27+segments)return -1;
        uint32_t id=(uint32_t)p[14]|(uint32_t)p[15]<<8|(uint32_t)p[16]<<16|(uint32_t)p[17]<<24;
        uint32_t sequence=(uint32_t)p[18]|(uint32_t)p[19]<<8|(uint32_t)p[20]<<16|(uint32_t)p[21]<<24;
        if(!page)serial=id;
        if(id!=serial || sequence!=page++ || (!cursor && !(p[5]&2)))return -1;
        size_t size=27+segments;for(unsigned i=0;i<segments;i++)size+=p[27+i];
        if(size>(size_t)length-cursor)return -1;cursor+=size;ended=(p[5]&4)!=0;
    }
    if(!ended || page<2)return -1;
    int error=0;stb_vorbis *v=stb_vorbis_open_memory(data,length,&error,NULL);if(!v)return -1;
    stb_vorbis_info info=stb_vorbis_get_info(v);unsigned frames=stb_vorbis_stream_length_in_samples(v);
    if(info.channels<1 || info.channels>2 || info.sample_rate<8000 || info.sample_rate>192000 || !frames || frames>info.sample_rate*1800u || (uint64_t)frames*info.channels*2>256*1024*1024) {stb_vorbis_close(v);return -1;}
    short *out=malloc((size_t)frames*info.channels*sizeof(short));if(!out){stb_vorbis_close(v);return -1;}
    int n=stb_vorbis_get_samples_short_interleaved(v,info.channels,out,frames*info.channels);
    error=stb_vorbis_get_error(v);stb_vorbis_close(v);
    if(error || n!=(int)frames) {free(out);return -1;}
    *pcm=out;*channels=info.channels;*rate=info.sample_rate;return n;
}
void MD_FreeVorbis(short *pcm){free(pcm);}
