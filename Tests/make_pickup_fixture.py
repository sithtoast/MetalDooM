#!/usr/bin/env python3
"""Create local visual-check IWADs; never distribute generated game data.

pickups: relocate one health bonus, armor bonus, and clip ahead of E1M1's start.
key-door: relocate E1M2's start before its original red door and its red key behind it.
Only THINGS records change. Door geometry/specials and game rules remain original.
"""
import math
import pathlib
import struct
import sys

source, output = map(pathlib.Path, sys.argv[1:3])
mode = sys.argv[3]
assert source.resolve() != output.resolve(), 'Do not overwrite the original WAD'
data = bytearray(source.read_bytes())
count, directory = struct.unpack_from('<ii',data,4)
lumps = [struct.unpack_from('<ii8s',data,directory+i*16) for i in range(count)]
map_name = b'E1M1' if mode == 'pickups' else b'E1M2'
index = next(i for i,e in enumerate(lumps) if e[2].rstrip(b'\0') == map_name)
things, size, _ = lumps[index+1]

def relocate(kind, x, y, angle=0):
    for offset in range(things,things+size,10):
        if struct.unpack_from('<H',data,offset+6)[0] == kind:
            struct.pack_into('<hhh',data,offset,round(x),round(y),round(angle)%360)
            struct.pack_into('<H',data,offset+8,7)
            return
    raise ValueError(f'Missing thing type {kind}')

if mode == 'pickups':
    relocate(1,1056,-3616,90)
    for kind,y in [(2014,-3560),(2015,-3504),(2007,-3448)]:
        relocate(kind,1056,y)
elif mode == 'key-door':
    lines, length, _ = lumps[index+2]
    vertices, _, _ = lumps[index+4]
    for offset in range(lines,lines+length,14):
        a,b,flags,special,tag,front,back = struct.unpack_from('<7H',data,offset)
        if special != 28 or back == 65535:
            continue
        ax,ay = struct.unpack_from('<hh',data,vertices+a*4)
        bx,by = struct.unpack_from('<hh',data,vertices+b*4)
        dx,dy = bx-ax,by-ay
        length = math.hypot(dx,dy)
        x,y = (ax+bx)/2+dy/length*40,(ay+by)/2-dx/length*40
        angle = math.degrees(math.atan2(dx,-dy))
        relocate(1,x,y,angle)
        relocate(13,x+dy/length*80,y-dx/length*80)
        print(f'Player ({x}, {y}) facing red door; back up 80 units to collect key.')
        break
    else:
        raise ValueError('No red door')
else:
    raise ValueError('Expected pickups or key-door')
output.write_bytes(data)
print(f'{mode}: {map_name.decode()} fixture saved to {output}')
