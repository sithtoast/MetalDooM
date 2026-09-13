"""Decode every private bundled H_ track, with bounded malformed-input rejection."""
import ctypes,pathlib,struct,sys
lib=ctypes.CDLL(sys.argv[1]);lib.MD_DecodeVorbis.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.POINTER(ctypes.c_void_p),ctypes.POINTER(ctypes.c_int),ctypes.POINTER(ctypes.c_int)]
lib.MD_FreeVorbis.argtypes=[ctypes.c_void_p]
data=pathlib.Path(sys.argv[2]).read_bytes();count,directory=struct.unpack_from('<II',data,4)
tracks=[]
for offset,size,name in struct.iter_unpack('<II8s',data[directory:directory+count*16]):
 if name.startswith(b'H_'):tracks.append((name.rstrip(b'\0').decode(),data[offset:offset+size]))
for name,track in tracks:
 pcm=ctypes.c_void_p();channels=ctypes.c_int();rate=ctypes.c_int()
 frames=lib.MD_DecodeVorbis(track,len(track),ctypes.byref(pcm),ctypes.byref(channels),ctypes.byref(rate))
 assert frames>0 and channels.value in (1,2) and rate.value in (44100,48000),(name,frames,channels.value,rate.value)
 values=ctypes.cast(pcm,ctypes.POINTER(ctypes.c_int16));assert any(values[i] for i in range(0,frames*channels.value,997)),name
 lib.MD_FreeVorbis(pcm)
 print('PASS',name,frames,channels.value,rate.value,round(frames/rate.value,3),'seconds',flush=True)
for bad in [b'',b'OggS'+b'\0'*128,tracks[0][1][:100],tracks[0][1][:len(tracks[0][1])//2]]:
 pcm=ctypes.c_void_p();channels=ctypes.c_int();rate=ctypes.c_int()
 assert lib.MD_DecodeVorbis(bad,len(bad),ctypes.byref(pcm),ctypes.byref(channels),ctypes.byref(rate))<0 and not pcm.value
print('PASS',len(tracks),'recorded tracks and malformed input')
