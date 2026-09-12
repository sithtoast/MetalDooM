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
 'blend-empty':[(label,struct.pack('<5h',-128,0,0,1,7) if label=='THINGS' else body) for label,body in room],
}.items(): (out/f'{name}.wad').write_bytes(s['wad'](lumps))
# A shared state table overrides both default additive selection and opaque flags.
# Another table is first used after two tics, and must already have a stable ID.
custom_a=bytes((2*bg+fg)//3 for bg in range(256) for fg in range(256))
custom_b=bytes(255-fg for bg in range(256) for fg in range(256))
custom_patch=patch.replace('Frame 1100\n','Frame 1100\nTranmap = BLEND_A\n').replace('Duration = -1\nNext frame = 1100','Duration = 2\nNext frame = 1103')
custom_patch=custom_patch.replace('Frame 1101\n','Frame 1101\nTranmap = BLEND_A\n').replace('Frame 1102\n','Frame 1102\nTranmap = BLEND_A\n')
custom_patch+='Frame 1103\nSprite number = 0\nDuration = -1\nNext frame = 1103\nTranmap = BLEND_B\n\nThing 503\nID # = 9503\nInitial frame = 1104\nBits = 0\n\nFrame 1104\nSprite number = 0\nSprite subnumber = 32768\nDuration = -1\nNext frame = 1104\nTranmap = BLEND_A\n\n'
custom_room=[(label,body+struct.pack('<5h',128,0,0,9503,7) if label=='THINGS' else body) for label,body in room]
for label,a,b in [('blend-custom',custom_a,custom_b),('blend-custom-short',custom_a[:-1],custom_b),('blend-custom-long',custom_a,custom_b+b'\0')]:
 (out/f'{label}.wad').write_bytes(s['wad'](custom_room+[('DEHACKED',custom_patch.encode()),('BLEND_A',a),('BLEND_B',b)]))
# Validate the bank bound during initialization, including tables unused at spawn.
large=base;entries=[]
for i in range(63):
 large+=f'Frame {1200+i}\nTranmap = BL{i:05d}\n\n'
 entries.append((f'BL{i:05d}',custom_a))
(out/'blend-custom-limit.wad').write_bytes(s['wad'](room+[('DEHACKED',large.encode())]+entries))
limit_patch=base
for i in range(62):limit_patch+=f'Frame {1200+i}\nTranmap = BL{i:05d}\n\n'
limit_patch+='Thing 500\nID # = 9500\nInitial frame = 1261\nBits = 0\n\nFrame 1261\nSprite number = 0\nDuration = -1\nNext frame = 1261\n\n'
limit_room=[(label,body[:20] if label=='THINGS' else body) for label,body in room]
(out/'blend-custom-max.wad').write_bytes(s['wad'](limit_room+[('DEHACKED',limit_patch.encode())]+entries[:62]))
