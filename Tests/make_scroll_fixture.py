#!/usr/bin/env python3
"""Original tagged rooms with independent Boom floor/ceiling scrollers."""
import pathlib,runpy,struct,sys
out=pathlib.Path(sys.argv[1]);out.mkdir(parents=True,exist_ok=True)
source=runpy.run_path(str(pathlib.Path(__file__).with_name('make_extended_fixture.py')))
for label,lines in {'floor':[(0,251)],'ceiling':[(1,250)],'both':[(0,251),(1,250)],'reverse':[(2,251),(3,250)],'carry':[(0,253)]}.items():
 lumps=[]
 for name,body in source['room']:
  if name=='THINGS':body=struct.pack('<5h',-128,0,0,1,7)
  if name=='LINEDEFS':
   body=bytearray(body)
   for line,special in lines:struct.pack_into('<HH',body,line*14+6,special,1)
  if name=='SECTORS':
   body=bytearray(body);struct.pack_into('<h',body,24,1)
  lumps.append((name,body))
 (out/f'scroll-{label}.wad').write_bytes(source['wad'](lumps))
