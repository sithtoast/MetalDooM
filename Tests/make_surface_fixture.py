#!/usr/bin/env python3
"""Local visual fixture: original E1M1 geometry/art, relocated player, no monsters."""
import pathlib,struct,sys
source,output=map(pathlib.Path,sys.argv[1:3]);scene=sys.argv[3]
assert source.resolve()!=output.resolve()
b=bytearray(source.read_bytes());n,o=struct.unpack_from('<ii',b,4)
lumps=[struct.unpack_from('<ii8s',b,o+i*16) for i in range(n)]
m=next(i for i,x in enumerate(lumps) if x[2].rstrip(b'\0')==b'E1M1')
p,size,_=lumps[m+1]
poses={'exit':(3008,-4256,0),'sky':(2000,-3540,90),'progression':(2944,-4768,180),'pillar':(288,-3040,270),'ceiling':(2848,-2960,45),'light':(384,-3120,225)}
x,y,angle=poses[scene]
for off in range(p,p+size,10):
 kind=struct.unpack_from('<H',b,off+6)[0]
 if kind==1: struct.pack_into('<hhhHH',b,off,x,y,angle,1,7)
 elif kind in (3001,3002,3003,3004,3005,3006,9,16,58,64,65,66,67,68,69,71,84): struct.pack_into('<H',b,off+8,0)
output.write_bytes(b)
print(scene,output)
