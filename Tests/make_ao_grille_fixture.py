#!/usr/bin/env python3
"""Local-only Ultimate Doom fixture: MIDGRATE on an existing E1M1 portal.

Preserve all geometry and place the player in front of the portal. Never commit
or distribute the output IWAD; it contains the user's original game data.
"""
import math
from pathlib import Path
import struct
import sys

source, output = map(Path, sys.argv[1:3])
if source.resolve() == output.resolve():
    raise SystemExit("Choose a separate output file")
data = bytearray(source.read_bytes())
count, directory = struct.unpack_from("<ii", data, 4)
lumps = [struct.unpack_from("<ii8s", data, directory + i*16) for i in range(count)]
marker = next(i for i, (_, _, name) in enumerate(lumps) if name.rstrip(b"\0") == b"E1M1")
entries = {name.rstrip(b"\0"): (offset, size) for offset, size, name in lumps[marker+1:marker+11]}
vertices, _ = entries[b"VERTEXES"]
sides, _ = entries[b"SIDEDEFS"]
sectors, _ = entries[b"SECTORS"]
lines, size = entries[b"LINEDEFS"]
things, thing_size = entries[b"THINGS"]
player = next(p for p in range(things, things+thing_size, 10) if struct.unpack_from("<H", data, p+6)[0] == 1)
px, py = struct.unpack_from("<hh", data, player)
candidates = []
for p in range(lines, lines+size, 14):
    a, b, flags, special, tag, front, back = struct.unpack_from("<7H", data, p)
    if front == 65535 or back == 65535 or special or not flags & 4:
        continue
    fs = struct.unpack_from("<H", data, sides+front*30+28)[0]
    bs = struct.unpack_from("<H", data, sides+back*30+28)[0]
    ff, fc = struct.unpack_from("<hh", data, sectors+fs*26)
    bf, bc = struct.unpack_from("<hh", data, sectors+bs*26)
    if fs == bs or not 96 <= min(fc,bc)-max(ff,bf) <= 160:
        continue
    ax, ay = struct.unpack_from("<hh", data, vertices+a*4)
    bx, by = struct.unpack_from("<hh", data, vertices+b*4)
    dx, dy = bx-ax, by-ay
    length = math.hypot(dx, dy)
    if not 96 <= length <= 320:
        continue
    mx, my = (ax+bx)/2, (ay+by)/2
    candidates.append((math.hypot(mx-px,my-py),p,front,back,mx,my,dx,dy,length))
if not candidates:
    raise SystemExit("No suitable portal in this WAD")
_, line, front, back, mx, my, dx, dy, length = min(candidates)
for side in [front, back]:
    data[sides+side*30+20:sides+side*30+28] = b"MIDGRATE"
x, y = round(mx+dy/length*64), round(my-dx/length*64)
angle = round(math.degrees(math.atan2(dx,-dy))) % 360
struct.pack_into("<hhh", data, player, x, y, angle)
for p in range(things, things+thing_size, 10):
    kind = struct.unpack_from("<H", data, p+6)[0]
    if kind in (3001,3002,3003,3004,3005,3006,9,16,58,64,65,66,67,68,69,71,84):
        struct.pack_into("<H", data, p+8, 0)
output.write_bytes(data)
print(f"MIDGRATE fixture: line {(line-lines)//14}, player ({x},{y}), heading {angle}")
