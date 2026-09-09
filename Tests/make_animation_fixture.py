#!/usr/bin/env python3
"""Local E1M1 animation/face fixture; never alter or redistribute the source IWAD."""
import pathlib, struct, sys
source, output = map(pathlib.Path, sys.argv[1:3])
assert source.resolve() != output.resolve()
b = bytearray(source.read_bytes())
n, directory = struct.unpack_from('<ii', b, 4)
lumps = [struct.unpack_from('<ii8s', b, directory + i * 16) for i in range(n)]
m = next(i for i, x in enumerate(lumps) if x[2].rstrip(b'\0') == b'E1M1')
p, size, _ = lumps[m + 1]
x, y = next(struct.unpack_from('<hh', b, o) for o in range(p, p+size, 10) if struct.unpack_from('<H', b, o+6)[0] == 1)
placed = False
for o in range(p, p+size, 10):
    kind = struct.unpack_from('<H', b, o+6)[0]
    if kind == 1: continue
    if not placed:
        struct.pack_into('<hhhHH', b, o, x, y, 0, 2022, 7) # invulnerability at start
        placed = True
    else: struct.pack_into('<H', b, o+8, 0)
p, size, _ = lumps[m + 8] # SECTORS
assert lumps[m+8][2].rstrip(b'\0') == b'SECTORS'
for o in range(p, p+size, 26):
    b[o+4:o+12] = b'NUKAGE1\0'
    struct.pack_into('<h', b, o+22, 0) # no damaging floors
p, size, _ = lumps[m + 3] # SIDEDEFS
assert lumps[m+3][2].rstrip(b'\0') == b'SIDEDEFS'
for o in range(p, p+size, 30):
    if b[o+20:o+28].rstrip(b'\0') != b'-': b[o+20:o+28] = b'FIREWALA'
output.write_bytes(b)
print(output)
