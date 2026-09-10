#!/usr/bin/env python3
"""Local-only PWAD for native finale checks; never modifies/distributes the IWAD.
MAP06 begins facing its original exit. MAP30 uses the same room/exit so its
presentation can be reached without replaying the battle already tested in C.
An optional map argument targets that map instead; walk exits become use exits
in the temporary fixture so a single input can reach its ending.
"""
from pathlib import Path
import struct,math,sys
source,output=map(Path,sys.argv[1:3])
assert source.resolve()!=output.resolve()
data=source.read_bytes();count,offset=struct.unpack_from('<ii',data,4)
lumps=[]
for i in range(count):
 p,size,name=struct.unpack_from('<ii8s',data,offset+16*i)
 lumps.append((name.rstrip(b'\0'),data[p:p+size]))
mapname=sys.argv[3].encode() if len(sys.argv)>3 else b'MAP06'
i=next(i for i,x in enumerate(lumps) if x[0]==mapname)
room=dict(lumps[i+1:i+11]);verts=room[b'VERTEXES'];lines=room[b'LINEDEFS']
for p in range(0,len(lines),14):
 a,b,flags,special,tag,front,back=struct.unpack_from('<7H',lines,p)
 if special not in (11,52):continue
 if special==52:
  changed=bytearray(lines);struct.pack_into('<H',changed,p+6,11);room[b'LINEDEFS']=bytes(changed)
 ax,ay=struct.unpack_from('<hh',verts,a*4);bx,by=struct.unpack_from('<hh',verts,b*4)
 dx,dy=bx-ax,by-ay;length=math.hypot(dx,dy)
 x,y=round((ax+bx)/2+dy/length*32),round((ay+by)/2-dx/length*32)
 angle=round(math.degrees(math.atan2(dx,-dy)))%360;break
else:raise ValueError('No exit switch')
room[b'THINGS']=struct.pack('<5h',x,y,angle,1,7)
entries=[]
for name in ([mapname] if len(sys.argv)>3 else [b'MAP06',b'MAP30']):
 entries.append((name,b''))
 entries.extend((key,room[key]) for key,_ in lumps[i+1:i+11])
body=bytearray();directory=bytearray()
for name,chunk in entries:
 directory.extend(struct.pack('<ii8s',12+len(body),len(chunk),name));body.extend(chunk)
output.write_bytes(b'PWAD'+struct.pack('<ii',len(entries),12+len(body))+body+directory)
print(output)
