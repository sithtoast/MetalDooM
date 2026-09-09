#!/usr/bin/env python3
"""Local-only Ultimate Doom finale fixture; every M8 uses E1M1's real exit room."""
import pathlib, struct, sys
source, output = map(pathlib.Path, sys.argv[1:3])
assert source.resolve() != output.resolve()
b = bytearray(source.read_bytes())
n, directory = struct.unpack_from('<ii', b, 4)
lumps = [struct.unpack_from('<ii8s', b, directory+i*16) for i in range(n)]
base = next(i for i, lump in enumerate(lumps) if lump[2].rstrip(b'\0') == b'E1M1')
p, size, _ = lumps[base+1]
for offset in range(p, p+size, 10):
    kind = struct.unpack_from('<H', b, offset+6)[0]
    if kind == 1:
        struct.pack_into('<hhhHH', b, offset, 2944, -4768, 180, 1, 7)
    else:
        struct.pack_into('<H', b, offset+8, 0)
for episode in range(1, 5):
    marker = next(i for i, lump in enumerate(lumps) if lump[2].rstrip(b'\0') == f'E{episode}M8'.encode())
    for offset in range(1, 11):
        struct.pack_into('<ii8s', b, directory+(marker+offset)*16, *lumps[base+offset])
output.write_bytes(b)
print(output)
