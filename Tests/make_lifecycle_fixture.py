#!/usr/bin/env python3
"""Original rooms for real exit, inventory carryover, restart and hazard death."""
import runpy,sys,struct,pathlib
out=pathlib.Path(sys.argv[1]);out.mkdir(parents=True,exist_ok=True)
source=runpy.run_path(str(pathlib.Path(__file__).with_name('make_extended_fixture.py')))
room,wad=source['room'],source['wad']
def level(number,secret=False,death=False,pickups=True):
 result=[]
 for name,body in room:
  if name=='MAP01':name=f'MAP{number:02}'
  if name=='THINGS':
   things=[(240,0,0,1,7)]
   if pickups and not death:things += [(235,0,0,i,7) for i in [2001,5,2018,2013,2048]]
   body=b''.join(struct.pack('<5h',*t) for t in things)
  if name=='LINEDEFS':
   body=bytearray(body);struct.pack_into('<H',body,2*14+6,51 if secret else 11)
  if name=='SECTORS' and death:
   body=bytearray(body);struct.pack_into('<h',body,22,16)
  result.append((name,body))
 return result
for secret in [False,True]:
 data=sum((level(n,secret) for n in range(1,17)),[])
 (out/('lifecycle-secret.wad' if secret else 'lifecycle-normal.wad')).write_bytes(wad(data))
(out/'lifecycle-death.wad').write_bytes(wad(level(1,death=True)))
