#!/usr/bin/env python3
"""Original room with a short walk-over teleporter; no redistributed assets."""
import pathlib,runpy,struct,sys
out=pathlib.Path(sys.argv[1]);out.mkdir(parents=True,exist_ok=True)
s=runpy.run_path(str(pathlib.Path(__file__).with_name('make_extended_fixture.py')))
lumps=[]
for name,body in s['room']:
 if name=='THINGS':body=struct.pack('<10h',32,0,180,1,7,-16,0,90,14,7)
 if name=='VERTEXES':body+=struct.pack('<4h',0,-128,0,128)
 if name=='LINEDEFS':body+=struct.pack('<7H',4,5,4,97,1,4,5)
 if name=='SIDEDEFS':body+=struct.pack('<hh8s8s8sH',0,0,s['name']('-'),s['name']('-'),s['name']('-'),0)*2
 if name=='SECTORS':
  body=bytearray(body);struct.pack_into('<h',body,24,1)
 lumps.append((name,body))
(out/'interpolation-teleport.wad').write_bytes(s['wad'](lumps))
