#!/usr/bin/env python3
"""Original two-sector portal and single-room pickup/damage fixtures."""
import pathlib,runpy,struct,sys
out=pathlib.Path(sys.argv[1]);out.mkdir(parents=True,exist_ok=True)
s=runpy.run_path(str(pathlib.Path(__file__).with_name('make_extended_fixture.py')));name=s['name'];wad=s['wad']
points=[(-256,-256),(-256,256),(0,256),(256,256),(256,-256),(0,-256)]
lines=[(i,(i+1)%6,1,0,0,i,65535) for i in range(6)]+[(5,2,4,260,0,6,7)]
sides=[struct.pack('<hh8s8s8sH',0,0,name('-'),name('-'),name('STARTAN3' if i<6 else 'MIDGRATE'),[0,0,1,1,1,0,1,0][i]) for i in range(8)]
segs=[(0,1,0,0),(1,2,1,0),(2,5,6,1),(5,0,5,0),(5,2,6,0),(2,3,2,0),(3,4,3,0),(4,5,4,0)]
room=[('MAP01',b''),('THINGS',struct.pack('<5h',-128,0,0,1,7)),('LINEDEFS',b''.join(struct.pack('<7H',*l) for l in lines)),('SIDEDEFS',b''.join(sides)),('VERTEXES',b''.join(struct.pack('<hh',*p) for p in points)),('SEGS',b''.join(struct.pack('<6H',a,b,0,l,side,0) for a,b,l,side in segs)),('SSECTORS',struct.pack('<4H',4,0,4,4)),('NODES',struct.pack('<12h2H',0,0,0,512,*([0]*8),0x8001,0x8000)),('SECTORS',struct.pack('<hh8s8shhh',0,128,name('FLOOR0_1'),name('CEIL1_1'),255,0,0)*2),('REJECT',b'\0'),('BLOCKMAP',b'')]
custom=bytes((2*bg+fg)//3 for bg in range(256) for fg in range(256))
for mode in ['default','custom','tagged']:
 lumps=[]
 for label,body in room:
  if mode!='default' and label=='SIDEDEFS':
   body=bytearray(body);side=6 if mode=='custom' else 5;body[side*30+20:side*30+28]=name('WTRAN')
  if mode=='tagged' and label=='LINEDEFS':
   body=bytearray(body);struct.pack_into('<HH',body,5*14+6,260,42);struct.pack_into('<HH',body,6*14+6,0,42)
  lumps.append((label,body))
 (out/f'wall-{mode}.wad').write_bytes(wad(lumps+[('WTRAN',custom)]))
for mode,thing in [('bonus',2014),('berserk',2023),('suit',2025),('invulnerable',2022),('light',2045),('damage',0)]:
 lumps=[]
 for label,body in s['room']:
  if label=='THINGS':body=struct.pack('<5h',-128,0,0,1,7)+(struct.pack('<5h',-120,0,0,thing,7) if thing else b'')
  if label=='SECTORS' and mode=='damage':
   body=bytearray(body);struct.pack_into('<h',body,22,16)
  lumps.append((label,body))
 (out/f'palette-{mode}.wad').write_bytes(wad(lumps))
