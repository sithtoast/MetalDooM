#!/usr/bin/env python3
"""Two-sector manual door/lift, with a pickup riding the lift."""
import pathlib,runpy,struct,sys
out=pathlib.Path(sys.argv[1]);out.mkdir(parents=True,exist_ok=True)
s=runpy.run_path(str(pathlib.Path(__file__).with_name('make_wall_palette_fixture.py')))
for mode in ['door','lift']:
 lumps=[]
 for label,body in s['room']:
  if label=='THINGS':body=struct.pack('<5h',40,0,180,1,7)+(struct.pack('<5h',-64,0,0,2014,7) if mode=='lift' else b'')
  if label=='LINEDEFS':
   body=bytearray(body);struct.pack_into('<HH',body,6*14+6,1 if mode=='door' else 62,0 if mode=='door' else 42)
  if label=='SIDEDEFS':
   body=bytearray(body)
   for i in [6,7]:body[i*30+4:i*30+28]=s['name']('STARTAN3')*2+s['name']('-')
  if label=='SECTORS':
   body=bytearray(body);struct.pack_into('<hh',body,0,0 if mode=='door' else 32,0 if mode=='door' else 128);struct.pack_into('<h',body,24,42)
  lumps.append((label,body))
 (out/f'motion-{mode}.wad').write_bytes(s['wad'](lumps))
