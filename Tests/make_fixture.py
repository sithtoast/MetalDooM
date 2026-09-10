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
    ('VERTEXES', b''.join(struct.pack('<hh',*p) for p in points+[(4096,4096)])),
    ('SEGS', b''.join(struct.pack('<6H',i,(i+1)%4,0,i,0,0) for i in range(4))),
    ('SSECTORS', struct.pack('<HH',4,0)),
    ('NODES', b''),
    ('SECTORS', struct.pack('<hh8s8shhh',0,128,name('TESTFLAT'),name('TESTFLAT'),192,0,0)),
    ('REJECT',b'\0'),('BLOCKMAP',b''),
    ('TESTFLAT',bytes((80 if ((x//8)+(y//8))%2 else 160) for y in range(64) for x in range(64)))
]
# A sloping wall split at x=64 has a true intersection at y=128.5, but
# classic node builders store integer seg vertices. The two BSP leaves must
# still cover the complete original room, up to the unsplit linedef.
split_points = [(0,0),(0,128),(128,129),(128,0),(64,128),(64,0)]
split_segs = [(0,1,0),(1,4,1),(5,0,3),(4,2,1),(2,3,2),(3,5,3)]
lumps += [
    ('MAP02', b''),
    ('THINGS', struct.pack('<hhhhh',32,64,0,1,7)),
    ('LINEDEFS', b''.join(struct.pack('<7H',i,(i+1)%4,1,0,0,i,65535) for i in range(4))),
    ('SIDEDEFS', b''.join(struct.pack('<hh8s8s8sH',0,0,name('-'),name('-'),name('TESTWALL'),0) for _ in range(4))),
    ('VERTEXES', b''.join(struct.pack('<hh',*p) for p in split_points)),
    ('SEGS', b''.join(struct.pack('<6H',a,b,0,line,0,0) for a,b,line in split_segs)),
    ('SSECTORS', struct.pack('<4H',3,0,3,3)),
    ('NODES', struct.pack('<12h2H',64,0,0,129,*([0]*8),0x8001,0x8000)),
    ('SECTORS', struct.pack('<hh8s8shhh',0,128,name('TESTFLAT'),name('TESTFLAT'),192,0,0)),
    ('REJECT',b'\0'),('BLOCKMAP',b'')
]
pathlib.Path(sys.argv[1]).write_bytes(make_wad(lumps))
