#!/usr/bin/env python3
"""Private local fixtures; only generated tables are new, never commit outputs."""
from pathlib import Path
import struct
import sys

source, output = map(Path, sys.argv[1:3])
output.mkdir(parents=True, exist_ok=True)
raw = source.read_bytes()
count, directory = struct.unpack_from('<ii', raw, 4)
lumps = []
for i in range(count):
    offset, size, name = struct.unpack_from('<ii8s', raw, directory+i*16)
    lumps.append((name, raw[offset:offset+size]))

def write(name, extra):
    path = output/(name+'.wad')
    if path.resolve() == source.resolve():
        raise ValueError('Refusing to overwrite source')
    body = bytearray(b'IWAD'+bytes(8)); entries = []
    for n, data in lumps+extra:
        entries.append((len(body), len(data), n)); body.extend(data)
    struct.pack_into('<ii', body, 4, len(entries), len(body))
    for o, size, n in entries: body.extend(struct.pack('<ii8s', o, size, n))
    path.write_bytes(body)

def anim(kind, end, start, speed):
    return struct.pack('<b9s9si', kind, end.encode(), start.encode(), speed)

def switch(first, second, scope):
    return struct.pack('<9s9sh', first.encode(), second.encode(), scope)

endanim = anim(-1, '', '', 0)
endswitch = switch('', '', 0)
# Repeated valid records exercise storage above both historical caps.
animations = anim(0,'NUKAGE3','NUKAGE1',4)*40 + anim(1,'FIREWALL','FIREWALA',32) + endanim
switches = switch('STARTAN2','STARTAN3',1)*85 + switch('STONE2','STONE3',3) + switch('ABSENT','STARTAN2',1) + endswitch
# A prior table with a different speed verifies last-lump-wins replacement.
prior = [(b'ANIMATED', anim(0,'NUKAGE3','NUKAGE1',8)+endanim),
         (b'SWITCHES', switch('SW1COMP','SW2COMP',1)+endswitch)]
valid = [(b'ANIMATED', animations), (b'SWITCHES', switches)]
write('valid', prior+valid)
write('short-end', [(b'ANIMATED',b'\xff')])
write('padded-end', [(b'ANIMATED',b'\xff'*4)])
write('empty', [(b'ANIMATED',endanim),(b'SWITCHES',endswitch)])
write('zero-speed', [(b'ANIMATED',anim(0,'NUKAGE3','NUKAGE1',0)+endanim)])
write('negative-speed', [(b'ANIMATED',anim(0,'NUKAGE3','NUKAGE1',-1)+endanim)])
write('swirl-speed', [(b'ANIMATED',anim(0,'NUKAGE3','NUKAGE1',65536)+endanim)])
write('bad-kind', [(b'ANIMATED',anim(2,'NUKAGE3','NUKAGE1',8)+endanim)])
write('backward', [(b'ANIMATED',anim(0,'NUKAGE1','NUKAGE3',8)+endanim)])
write('missing-end', [(b'ANIMATED',anim(0,'ABSENT','NUKAGE1',8)+endanim)])
write('absent-start', [(b'ANIMATED',anim(0,'ABSENT2','ABSENT1',8)+endanim)])
write('truncated', [(b'ANIMATED',animations[:22])])
write('unterminated', [(b'ANIMATED',animations[:-23])])
write('bad-name', [(b'ANIMATED',struct.pack('<b9s9si',0,b'123456789',b'NUKAGE1',8)+endanim)])
write('switch-truncated', [(b'SWITCHES',switches[:-1])])
write('switch-unterminated', [(b'SWITCHES',switches[:-20])])
write('switch-scope', [(b'SWITCHES',switch('STARTAN2','STARTAN3',4)+endswitch)])
write('switch-name', [(b'SWITCHES',struct.pack('<9s9sh',b'123456789',b'STARTAN2',1)+endswitch)])
# Native preview: animated floor/walls; visual-only, original geometry intact.
for i,(name,data) in enumerate(lumps):
    if name.rstrip(b'\0') != b'E1M1': continue
    for j in [i+3,i+8]:
        n,b = lumps[j]; b=bytearray(b)
        if n.rstrip(b'\0') == b'SIDEDEFS':
            for o in range(0,len(b),30):
                for field in (o+4,o+12,o+20):
                    if b[field:field+8].rstrip(b'\0') != b'-': b[field:field+8]=b'FIREWALA'
        if n.rstrip(b'\0') == b'SECTORS':
            for o in range(0,len(b),26): b[o+4:o+12]=b'NUKAGE1\0'; struct.pack_into('<h',b,o+22,0)
        lumps[j]=(n,bytes(b))
    break
write('preview', valid)
print(output)
