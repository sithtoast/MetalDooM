#!/usr/bin/env python3
"""Original synthetic MBF21 room/patch; Doom art is resolved from caller's IWAD."""
import pathlib
import struct
import sys

def name(s): return s.encode().ljust(8, b'\0')
def wad(lumps):
    data = bytearray(b'PWAD' + b'\0' * 8)
    directory = bytearray()
    for label, body in lumps:
        directory += struct.pack('<ii8s', len(data), len(body), name(label))
        data += body
    struct.pack_into('<ii', data, 4, len(lumps), len(data))
    return data + directory

points = [(-256,-256),(-256,256),(256,256),(256,-256)]
room = [
    ('MAP01', b''),
    ('THINGS', struct.pack('<10h', -128,0,0,1,7, 128,0,180,9500,7)),
    ('LINEDEFS', b''.join(struct.pack('<7H',i,(i+1)%4,1,0,0,i,65535) for i in range(4))),
    ('SIDEDEFS', b''.join(struct.pack('<hh8s8s8sH',0,0,name('-'),name('-'),name('STARTAN3'),0) for _ in range(4))),
    ('VERTEXES', b''.join(struct.pack('<hh',*p) for p in points)),
    ('SEGS', b''.join(struct.pack('<6H',i,(i+1)%4,0,i,0,0) for i in range(4))),
    ('SSECTORS', struct.pack('<HH',4,0)), ('NODES', b''),
    ('SECTORS', struct.pack('<hh8s8shhh',0,128,name('FLOOR0_1'),name('CEIL1_1'),192,0,0)),
    ('REJECT',b'\0'), ('BLOCKMAP',b'')]
patch = '''Patch File for DeHackEd v3.0
Doom version = 21
Patch format = 6

Thing 500
ID # = 9500
Initial frame = 1100
Hit points = 200
Width = 1048576
Height = 3670016
Bits = 6
MBF21 Bits = 1

Frame 1100
Sprite number = 0
Duration = 1
Next frame = 1101

Frame 1101
Sprite number = 0
Duration = -1
Next frame = 1101
Args1 = 512

Weapon 1
Shooting frame = 1200

Frame 1200
Sprite number = 2
Duration = 1
Next frame = 1201
Args1 = 2

Frame 1201
Sprite number = 2
Duration = 1
Next frame = 10
Args1 = 0
Args2 = 0
Args3 = 1
Args4 = 7
Args5 = 1

[CODEPTR]
Frame 1101 = AddFlags
Frame 1200 = ConsumeAmmo
Frame 1201 = WeaponBulletAttack

'''
out = pathlib.Path(sys.argv[1]); out.mkdir(parents=True, exist_ok=True)
for mode, text in {
    'combat': patch,
    'bad-actor': patch.replace('Frame 1101 = AddFlags','Frame 1101 = WeaponBulletAttack'),
    'bad-weapon': patch.replace('Frame 1200 = ConsumeAmmo','Frame 1200 = AddFlags'),
    'id24-field': patch.replace('Hit points = 200', 'Hit points = 200\nPickup item type = 1'),
    'unknown-field': patch.replace('Hit points = 200', 'Misspelled health = 200'),
    'unknown-section': patch.replace('Thing 500', 'UNSUPPORTED 1\nValue = 3\n\nThing 500'),
}.items(): (out / f'{mode}.wad').write_bytes(wad(room + [('DEHACKED',text.encode())]))
(out / 'id24-config.wad').write_bytes(wad([('GAMECONF',b'{}')]))
(out / 'bad-table.wad').write_bytes(wad([('ANIMATED',b'\x01' * 22)]))
# Boom floor conveyor: no input, the tagged floor carries the player north.
conveyor = []
for label, body in room:
    if label == 'THINGS': body = struct.pack('<5h', -128,0,0,1,7)
    if label == 'LINEDEFS':
        body = bytearray(body); struct.pack_into('<HH', body, 6, 252, 1)
    if label == 'SECTORS':
        body = bytearray(body); struct.pack_into('<h', body, 24, 1)
    conveyor.append((label, body))
(out / 'conveyor.wad').write_bytes(wad(conveyor))
