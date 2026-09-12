#!/usr/bin/env python3
"""Original test geometry and ID24 field/session fixtures. No commercial data."""
import json, pathlib, struct, sys
# Reuse only the project's original room/writer definitions; generator arguments
# are preserved and the regular extended fixtures are generated alongside these.
from make_extended_fixture import room, wad, patch
out = pathlib.Path(sys.argv[1])
def write(name, lumps): (out/f'{name}.wad').write_bytes(wad(lumps))
def config(data): return ('GAMECONF',json.dumps({'type':'gameconf','version':'1.0.0','data':data}).encode())
def replace_room(things): return [(n,things if n=='THINGS' else d) for n,d in room]
player = (-128,0,0,1,7)
# Cell pickup keeps vanilla ammo behavior; only its message changes.
base = 'Patch File for DeHackEd v3.0\n\n'
for key, override in [('pickup',''),('pickup-bex','\n[STRINGS]\nID24_GOTFUELCAN = Custom fuel pickup.\n')]:
    p = base+'Thing 68\nPickup message = ID24_GOTFUELCAN\n'+override
    write(key,replace_room(struct.pack('<10h',*player,-110,0,0,2047,7))+[('DEHACKED',p.encode())])
for name, value in [('respawn-fast',64),('respawn-slow',2100),('respawn-default',None)]:
    p = base+'''Thing 500
ID # = 9500
Initial frame = 1100
Hit points = 100
Width = 1048576
Height = 3670016
Mass = 100
Bits = 4194310
Death frame = 1102

Frame 1100
Sprite number = 0
Duration = 10
Next frame = 1101

Frame 1101
Sprite number = 0
Duration = 1
Next frame = 1102

Frame 1102
Sprite number = 0
Duration = -1
Next frame = 1102

[CODEPTR]
Frame 1101 = Die

'''
    if value is not None: p += f'Thing 500\nMin respawn tics = {value}\nRespawn dice = {64 if value == 2100 else 255}\n\n'
    write(name,room+[('DEHACKED',p.encode())])
for name, field in [('bad-dice','Respawn dice = 256'),('bad-time','Min respawn tics = -1'),
                    ('bad-number','Respawn dice = potato'),('bad-mnemonic','Pickup message = NO_SUCH_MESSAGE')]:
    write(name,[('DEHACKED',(base+'Thing 68\n'+field+'\n').encode())])
for name, data in {
    'plan-a':{'title':'First','version':'1','executable':'mbf21','options':'comp_soul 1'},
    'plan-b':{'title':None,'version':'2','executable':'boom2.02','options':'comp_soul 0'},
    'plan-id24':{'executable':'id24'},
    'plan-unknown':{'executable':'not-a-port'},
    'plan-path':{'iwad':'../doom2.wad'},
    'plan-dependency':{'pwadfiles':['missing.wad']},
    'plan-translation':{'wadtranslation':'REMAP'},
    'plan-option':{'options':'unknown_option 0'},
    'plan-option-overflow':{'options':'comp_soul 9999999999999999999999999999999999'},
    'plan-mode':{'mode':'shareware'},
}.items():write(name,[config(data)])
write('plan-duplicate-key',[('GAMECONF',b'{"type":"gameconf","version":"1.0.0","data":{"title":"a","title":"b"}}')])
write('plan-truncated',[('TEST',b'data')])
p=out/'plan-truncated.wad';p.write_bytes(p.read_bytes()[:-3])
# Actual Rust patch/resources will supply behavior to these original rooms.
for name, things in {'rust-incinerator':[(*player,),(-110,0,0,2004,7)],
                     'rust-blade':[(*player,),(-110,0,0,2006,7)],
                     'rust-blade-full':[(*player,),(-110,0,0,2006,7),(-110,0,0,17,7)],
                     'rust-fuel':[(*player,),(-110,0,0,2047,7)],
                     'rust-tank':[(*player,),(-110,0,0,17,7)]}.items():
    write(name,replace_room(b''.join(struct.pack('<5h',*t) for t in things)))
