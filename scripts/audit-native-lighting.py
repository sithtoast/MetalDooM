#!/usr/bin/env python3
"""Historical build159 RGB baseline against canonical 320-wide plane lighting.

Pinned Woof acd1c7f: r_main.c R_InitLightTables, r_plane.c R_MapPlane;
LIGHTLEVELS=16, LIGHTSEGSHIFT=4, LIGHTZSHIFT=20, LIGHTSCALESHIFT=12.
Legacy native: build159 Geometry.swift/Renderer.swift RGB shade.
Current indexed shading is tested with test-indexed-lighting.sh GPU readback.
Only JSON statistics leave the caller's WAD; no artwork or palettes are exported.
"""
import hashlib,json,pathlib,struct,sys
path=pathlib.Path(sys.argv[1]);data=path.read_bytes()
count,directory=struct.unpack_from('<II',data,4)
assert data[:4] in (b'IWAD',b'PWAD') and directory+count*16<=len(data)
lumps={}
for i in range(count):
 offset,size,name=struct.unpack_from('<II8s',data,directory+i*16)
 assert offset+size<=len(data)
 lumps[name.rstrip(b'\0').decode('ascii')]=data[offset:offset+size]
palette=lumps['PLAYPAL'][:768];maps=lumps['COLORMAP'];assert len(palette)==768 and len(maps)>=32*256
rows=[]
for light in [0,32,64,96,128,160,192,224,255]:
 for distance in [64,128,256,512,1024,2048]:
  z=min(127,(distance*65536)>>20)
  scale=(160*65536*65536)//((z+1)<<20)
  start=((15-(light>>4))*2)*32//16
  level=max(0,min(31,start-((scale>>12)//2)))
  shade=max(0.12,light/255)*max(0.3,min(1,1-distance/3200))
  errors=[]
  for color in range(256):
   native=[round(palette[color*3+c]*shade) for c in range(3)]
   software=[palette[maps[level*256+color]*3+c] for c in range(3)]
   errors.append(sum(abs(a-b) for a,b in zip(native,software)))
  rows.append(dict(light=light,distance=distance,colormap=level,different=sum(e>0 for e in errors),mean_rgb_error=round(sum(errors)/768,3)))
print(json.dumps(dict(reference='Woof acd1c7f84fdd0fae92d1c58643c14364a131c75a, 320-wide plane table',
 scope='Historical build159 RGB baseline. Unfiltered opaque plane samples, no powers, fixed maps, translations, extra light or brightmaps; native RGB rounding modeled, not GPU readback or whole-frame acceptance.',
 wad_sha256=hashlib.sha256(data).hexdigest(),samples=len(rows)*256,different=sum(r['different'] for r in rows),rows=rows),indent=2))
