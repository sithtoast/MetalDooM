#!/usr/bin/env python3
"""Create a local visual-test IWAD with E1M1's player start facing its first door.

Requires the user's original IWAD; do not distribute the generated game data.
Only player-one position and angle are changed. Geometry and door logic are original.
"""
import math
import pathlib
import struct
import sys

source, output = map(pathlib.Path, sys.argv[1:3])
assert source.resolve() != output.resolve(), 'Never overwrite the source WAD'
data = bytearray(source.read_bytes())
count, directory = struct.unpack_from('<ii', data, 4)
lumps = []
for i in range(count):
    offset, size, name = struct.unpack_from('<ii8s', data, directory+i*16)
    lumps.append((name.rstrip(b'\0').upper(), offset, size))
marker = next(i for i, lump in enumerate(lumps) if lump[0] == b'E1M1')
entries = {name:(offset,size) for name,offset,size in lumps[marker+1:marker+11]}
v, _ = entries[b'VERTEXES']
s, _ = entries[b'SIDEDEFS']
sectors, _ = entries[b'SECTORS']
lines, length = entries[b'LINEDEFS']
for p in range(lines, lines+length, 14):
    a,b,flags,special,tag,front,back = struct.unpack_from('<7H',data,p)
    if special != 1 or back == 65535:
        continue
    sector = struct.unpack_from('<H',data,s+back*30+28)[0]
    floor, ceiling = struct.unpack_from('<hh',data,sectors+sector*26)
    if floor != ceiling:
        continue
    ax,ay = struct.unpack_from('<hh',data,v+a*4)
    bx,by = struct.unpack_from('<hh',data,v+b*4)
    dx,dy = bx-ax,by-ay
    distance = math.hypot(dx,dy)
    x,y = round((ax+bx)/2+dy/distance*40),round((ay+by)/2-dx/distance*40)
    angle = round(math.degrees(math.atan2(dx,-dy))) % 360
    break
else:
    raise ValueError('No closed manual door found')
things, length = entries[b'THINGS']
for p in range(things,things+length,10):
    if struct.unpack_from('<H',data,p+6)[0] == 1:
        struct.pack_into('<hhh',data,p,x,y,angle)
        break
else:
    raise ValueError('No player start')
output.write_bytes(data)
print(f'Door fixture: player ({x}, {y}), heading {angle}, door sector {sector}')
