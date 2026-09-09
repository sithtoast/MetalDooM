#!/usr/bin/env python3
"""Generate a tiny original test room; no Doom assets are included."""
import pathlib
import struct
import sys

def name(value):
    return value.encode('ascii').ljust(8, b'\0')

def make_wad(lumps):
    data = bytearray(b'PWAD' + b'\0' * 8)
    directory = bytearray()
    for label, body in lumps:
        directory += struct.pack('<ii8s', len(data), len(body), name(label))
        data += body
    struct.pack_into('<ii', data, 4, len(lumps), len(data))
    return data + directory

points = [(-128,-128),(-128,128),(128,128),(128,-128)]
lumps = [
    ('MAP01', b''),
    ('THINGS', struct.pack('<hhhhh', 0,0,0,1,7)),
    ('LINEDEFS', b''.join(struct.pack('<7H',i,(i+1)%4,1,0,0,i,65535) for i in range(4))),
    ('SIDEDEFS', b''.join(struct.pack('<hh8s8s8sH',0,0,name('-'),name('-'),name('TESTWALL'),0) for _ in range(4))),
    ('VERTEXES', b''.join(struct.pack('<hh',*p) for p in points)),
    ('SEGS', b''.join(struct.pack('<6H',i,(i+1)%4,0,i,0,0) for i in range(4))),
    ('SSECTORS', struct.pack('<HH',4,0)),
    ('NODES', b''),
    ('SECTORS', struct.pack('<hh8s8shhh',0,128,name('TESTFLAT'),name('TESTFLAT'),192,0,0)),
    ('REJECT',b'\0'),('BLOCKMAP',b''),
    ('TESTFLAT',bytes((80 if ((x//8)+(y//8))%2 else 160) for y in range(64) for x in range(64)))
]
pathlib.Path(sys.argv[1]).write_bytes(make_wad(lumps))
