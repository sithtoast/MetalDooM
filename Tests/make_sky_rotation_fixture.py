#!/usr/bin/env python3
"""Original sector-local sky transfers and floor/ceiling rotation controls."""
import pathlib,runpy,struct,sys
out=pathlib.Path(sys.argv[1]);out.mkdir(parents=True,exist_ok=True)
s=runpy.run_path(str(pathlib.Path(__file__).with_name('make_wall_palette_fixture.py')))
name,wad=s['name'],s['wad']
for mode,special in [('sky271',271),('sky272',272),('sky-scroll',271),('floor',2051),('ceiling',2052),('both',2053),('offset-both',2056)]:
 lumps=[]
 for label,body in s['room']:
  if label=='THINGS':body=struct.pack('<5h',-192,0,0,1,7)
  if label=='LINEDEFS':
   body=bytearray(body);struct.pack_into('<HH',body,(2 if mode.startswith("sky") else 3)*14+6,special,7);struct.pack_into('<H',body,6*14+6,0)
   if mode=='sky-scroll':struct.pack_into('<H',body,2*14+6,271);struct.pack_into('<HH',body,3*14+6,254,7)
  if label=='SIDEDEFS':
   body=bytearray(body)
   for i in [6,7]:body[i*30+20:i*30+28]=name('-')
   if mode.startswith('sky'):
    struct.pack_into('<hh',body,2*30,4096,60);body[2*30+4:2*30+12]=name('SKY2')
    struct.pack_into('<h',body,3*30,8)
  if label=='VERTEXES' and mode=='offset-both':
   body=bytearray(body);struct.pack_into('<hh',body,4*4,192,-240)
  if label=='SECTORS':
   body=struct.pack('<hh8s8shhh',0,128,name('F_SKY1' if mode.startswith('sky') else 'FLOOR0_1'),name('F_SKY1' if mode.startswith('sky') else 'CEIL1_1'),192,0,7)
   body+=struct.pack('<hh8s8shhh',0,128,name('FLOOR0_1'),name('F_SKY1'),192,0,0)
  lumps.append((label,body))
 (out/f'sky-rotation-{mode}.wad').write_bytes(wad(lumps))
