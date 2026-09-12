#!/usr/bin/env python3
"""Original static actors, additive/fullbright states and a diagnostic TRANMAP."""
import pathlib,runpy,struct,sys
out=pathlib.Path(sys.argv[1]);out.mkdir(parents=True,exist_ok=True)
s=runpy.run_path(str(pathlib.Path(__file__).with_name('make_extended_fixture.py')))
base='Patch File for DeHackEd v3.0\nDoom version = 21\nPatch format = 6\n\n'
patch=base
for i,flags in enumerate([0x80000000,0x80000000,0x80040000]):
 patch+=f'Thing {500+i}\nID # = {9500+i}\nInitial frame = {1100+i}\nBits = {flags}\n\nFrame {1100+i}\nSprite number = 0\nSprite subnumber = {32768 if i==1 else 0}\nDuration = -1\nNext frame = {1100+i}\n\n'
room=[]
for label,body in s['room']:
 if label=='THINGS':body=b''.join(struct.pack('<5h',*t) for t in [(-128,0,0,1,7),(0,0,0,9500,7),(64,32,0,9501,7),(64,-32,0,9502,7)])
 room.append((label,body))
table=bytes((background+2*foreground)//3 for background in range(256) for foreground in range(256))
for name,lumps in {
 'blend-actors':room+[('DEHACKED',patch.encode()),('TRANMAP',table)],
 'blend-bad-table':room+[('TRANMAP',table[:-1])],
 'blend-custom':room+[('DEHACKED',patch.replace('Frame 1100\n','Frame 1100\nTranmap = CUSTOM\n').encode()),('CUSTOM',table)],
 'blend-empty':[(label,struct.pack('<5h',-128,0,0,1,7) if label=='THINGS' else body) for label,body in room],
}.items(): (out/f'{name}.wad').write_bytes(s['wad'](lumps))
