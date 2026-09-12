#!/usr/bin/env python3
"""Original two-sector rooms exercising engine-owned Boom control specials."""
import pathlib,runpy,struct,sys
out=pathlib.Path(sys.argv[1]);out.mkdir(parents=True,exist_ok=True)
s=runpy.run_path(str(pathlib.Path(__file__).with_name('make_wall_palette_fixture.py')))
name,wad=s['name'],s['wad']
for mode in ['normal','underwater','above','sky-below','sky-above','floorlight','ceilinglight']:
 lumps=[]
 for label,body in s['room']:
  if label=='THINGS':body=struct.pack('<10h',-128,0,0,1,7,-64,-64,0,2035,7)
  if label=='LINEDEFS':
   body=bytearray(body);struct.pack_into('<H',body,6*14+6,0)
   special=213 if mode=='floorlight' else 261 if mode=='ceilinglight' else 242
   struct.pack_into('<HH',body,2*14+6,special,7)
  if label=='SIDEDEFS':
   body=bytearray(body)
   for i in [6,7]:body[i*30+20:i*30+28]=name('-')
  if label=='SECTORS':
   floor=64 if mode in ['underwater','sky-below'] else 16
   ceiling=32 if mode in ['above','sky-above'] else 96
   body=struct.pack('<hh8s8shhh',0,128,name('FLOOR0_1'),name('CEIL1_1'),192,0,7)
   body+=struct.pack('<hh8s8shhh',floor,ceiling,name('F_SKY1' if mode=='sky-above' else 'NUKAGE1'),name('F_SKY1' if mode=='sky-below' else 'CEIL3_5'),64,0,0)
  lumps.append((label,body))
 (out/f'control-{mode}.wad').write_bytes(wad(lumps))
