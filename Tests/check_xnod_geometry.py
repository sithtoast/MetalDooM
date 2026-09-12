"""Independent byte-level MAP13 check against the worker's copied geometry."""
import pathlib
import struct
import sys

wad = pathlib.Path(sys.argv[1]).read_bytes()
count, directory = struct.unpack_from('<II', wad, 4)
lumps = []
for i in range(count):
    offset, size, name = struct.unpack_from('<II8s', wad, directory + i*16)
    lumps.append((name.rstrip(b'\0'), wad[offset:offset+size]))
marker = next(i for i, lump in enumerate(lumps) if lump[0] == b'MAP13')
assert lumps[marker+4][0] == b'VERTEXES' and lumps[marker+7][0] == b'NODES'
vertices = [tuple(v*65536 for v in xy) for xy in struct.iter_unpack('<hh', lumps[marker+4][1])]
nodes = lumps[marker+7][1]
assert nodes[:4] == b'XNOD'
original, added = struct.unpack_from('<II', nodes, 4)
assert original == len(vertices)
vertices += list(struct.iter_unpack('<ii', nodes[12:12+added*8]))
cursor = 12+added*8
leaf_count, = struct.unpack_from('<I', nodes, cursor)
cursor += 4
leaves = []
first = 0
for i in range(leaf_count):
    size, = struct.unpack_from('<I', nodes, cursor+i*4)
    leaves.append((size, first))
    first += size
cursor += leaf_count*4
seg_count, = struct.unpack_from('<I', nodes, cursor)
cursor += 4
assert first == seg_count
segs = list(struct.iter_unpack('<IIHB', nodes[cursor:cursor+seg_count*11]))
cursor += seg_count*11
node_count, = struct.unpack_from('<I', nodes, cursor)
cursor += 4
partitions = []
for i in range(node_count):
    offset = cursor+i*32
    xy = struct.unpack_from('<hhhh', nodes, offset)
    children = struct.unpack_from('<II', nodes, offset+24)
    partitions.append(tuple(v*65536 for v in xy)+children)
assert cursor+node_count*32 == len(nodes)

snapshot = pathlib.Path(sys.argv[2]).read_bytes()
assert snapshot[:4] == b'MGE2'
counts = struct.unpack_from('<7I', snapshot, 28)
strides = (8, 20, 36, 44, 16, 12, 24)
offsets = []
cursor = 120
for count, stride in zip(counts, strides):
    offsets.append(cursor)
    cursor += count*stride
assert cursor == len(snapshot)
assert (len(vertices), seg_count, leaf_count, node_count) == (counts[0], counts[4], counts[5], counts[6])
copied_vertices = list(struct.iter_unpack('<ii', snapshot[offsets[0]:offsets[1]]))
# MBF21 projects split vertices onto their parent linedefs during level setup.
# Linedef endpoints must retain their map coordinates; split adjustments are
# deliberately taken from the engine instead of reimplemented by the renderer.
line_vertices = {v for row in struct.iter_unpack('<7H', lumps[marker+2][1]) for v in row[:2]}
assert all(vertices[v] == copied_vertices[v] for v in line_vertices)
projected = sum(a != b for a, b in zip(vertices, copied_vertices))
assert segs == list(struct.iter_unpack('<4I', snapshot[offsets[4]:offsets[5]]))
assert leaves == [row[:2] for row in struct.iter_unpack('<3I', snapshot[offsets[5]:offsets[6]])]
assert partitions == list(struct.iter_unpack('<iiiiII', snapshot[offsets[6]:]))
print(f'PASS MAP13 XNOD byte parity: {original} original + {added} added vertices, '
      f'{seg_count} segs, {leaf_count} leaves, {node_count} nodes; linedef coordinates and every seg/leaf/node reference match; {projected} split vertices use engine projection')
