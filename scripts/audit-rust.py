#!/usr/bin/env python3
"""Read-only installed Legacy of Rust inventory. Outputs metadata, never lump payloads.

Usage: python3 scripts/audit-rust.py /path/to/rerelease > build/rust-audit.json
This is an inventory, not an engine compatibility validator or GAMECONF interpreter.
"""
import collections
import hashlib
import json
from pathlib import Path
import re
import struct
import sys


def read_wad(path):
    data = path.read_bytes()
    if len(data) < 12 or data[:4] not in (b'IWAD', b'PWAD'):
        raise ValueError(f'{path.name}: invalid WAD header')
    count, directory = struct.unpack_from('<ii', data, 4)
    if count < 0 or directory < 0 or directory + count*16 > len(data):
        raise ValueError(f'{path.name}: invalid directory bounds')
    lumps = []
    for index in range(count):
        offset, size, name = struct.unpack_from('<ii8s', data, directory+index*16)
        if offset < 0 or size < 0 or offset+size > len(data):
            raise ValueError(f'{path.name}: invalid lump bounds at {index}')
        lumps.append((name.split(b'\0')[0].decode('ascii'), data[offset:offset+size]))
    return hashlib.sha256(data).hexdigest(), lumps


def records(data, stride, offset):
    if len(data) % stride:
        raise ValueError('Invalid classic map record size')
    return dict(sorted(collections.Counter(struct.unpack_from('<H', data, i+offset)[0]
                                          for i in range(0, len(data), stride)).items()))


def deh_summary(data):
    text = data.decode('ascii')
    sections = collections.defaultdict(list)
    for kind, index in re.findall(r'^(Thing|Frame|Weapon|Ammo|Sound|Sprite)\s+(-?\d+)(?:\s*\([^\r\n]*\))?\s*$', text, re.M):
        sections[kind].append(int(index))
    fields = set()
    for line in text.splitlines():
        if '=' in line and not line.startswith('#'):
            key = line.split('=', 1)[0].strip()
            if not re.fullmatch(r'(?:FRAME\s+)?\d+', key, re.I): fields.add(key)
    return {'sections': {k: {'count': len(v), 'min': min(v), 'max': max(v)} for k,v in sections.items()},
            'fields': sorted(fields),
            'actions': sorted(set(re.findall(r'^FRAME\s+\d+\s*=\s*(\w+)', text, re.M|re.I)))}


def table_summary(data, animation):
    stride = 23 if animation else 20
    if len(data) % stride:
        raise ValueError('Invalid resource table record size')
    rows = []
    for i in range(0, len(data), stride):
        if animation:
            kind, end, start, speed = struct.unpack_from('<b9s9si', data, i)
            if kind == -1: return rows
            rows.append({'kind': kind, 'start': start.split(b'\0')[0].decode(),
                         'end': end.split(b'\0')[0].decode(), 'tics': speed})
        else:
            first, second, scope = struct.unpack_from('<9s9sh', data, i)
            if scope == 0: return rows
            rows.append({'first': first.split(b'\0')[0].decode(),
                         'second': second.split(b'\0')[0].decode(), 'scope': scope})
    raise ValueError('Resource table missing terminator')


def inventory(directory):
    files = ['doom2.wad','id24res.wad','id1.wad','id1-res.wad','id1-weap.wad',
             'id1-tex.wad','id1-mus.wad','extras.wad']
    source = {name: read_wad(directory/name) for name in files}
    campaign = dict(source['id1.wad'][1])
    result = {'format': 1, 'files': {}}
    for name,(digest,lumps) in source.items():
        effective = dict(lumps)
        item = {'sha256': digest, 'lump_count': len(lumps), 'maps': []}
        if name not in ('id1.wad','doom2.wad'):
            item['comparison_with_id1'] = {
                'identical_count': sum(n in campaign and campaign[n] == b for n,b in lumps),
                'different': [n for n,b in lumps if n in campaign and campaign[n] != b],
                'absent_in_id1': [n for n,b in lumps if n not in campaign]}
        for index,(label,_) in enumerate(lumps):
            if index+1 >= len(lumps) or lumps[index+1][0] != 'THINGS': continue
            # Inspect only the ten records belonging to this map; never borrow
            # records from a later marker through global last-name lookup.
            block = dict(lumps[index+1:index+11])
            required = ['THINGS','LINEDEFS','SIDEDEFS','VERTEXES','SEGS','SSECTORS','NODES','SECTORS','REJECT','BLOCKMAP']
            if list(block) != required: raise ValueError(f'{name}/{label}: nonclassic map block')
            nodes = block['NODES']
            item['maps'].append({'name': label, 'things': records(block['THINGS'],10,6),
                                 'line_specials': records(block['LINEDEFS'],14,6),
                                 'line_flags': records(block['LINEDEFS'],14,4),
                                 'sector_specials': records(block['SECTORS'],26,22),
                                 'node_format': nodes[:4].decode() if nodes[:4] in (b'XNOD',b'ZNOD') else 'classic',
                                 'node_bytes': len(nodes)})
        for lump,kind in [('ANIMATED',True),('SWITCHES',False)]:
            if lump in effective: item[lump.lower()] = table_summary(effective[lump],kind)
        if 'GAMECONF' in effective: item['gameconf'] = json.loads(effective['GAMECONF'])
        if 'DEHACKED' in effective: item['dehacked'] = deh_summary(effective['DEHACKED'])
        if 'UMAPINFO' in effective:
            # Deliberately a narrow metadata inventory, not a UMAPINFO parser.
            text = effective['UMAPINFO'].decode('ascii')
            item['umapinfo'] = {}
            for label,body in re.findall(r'\bmap\s+(\w+)\s*\{([^}]+)\}',text,re.I):
                item['umapinfo'][label] = {key: re.findall(r'^\s*'+key+r'\s*=\s*([^\r\n]+)',body,re.M)
                    for key in ['levelname','label','episode','next','nextsecret','endpic','endfinale','music','skytexture',
                                'enteranim','exitanim','intermusic','interbackdrop','bossaction','kex_nolevelselect']
                    if re.search(r'^\s*'+key+r'\s*=',body,re.M)}
        item['music'] = {n: ('MIDI' if b[:4]==b'MThd' else 'MUS' if b[:4]==b'MUS\x1a' else 'other')
                         for n,b in lumps if n.startswith('D_')}
        item['json_lumps'] = {}
        for n,b in lumps:
            if b.lstrip().startswith(b'{'):
                try: obj=json.loads(b)
                except (ValueError,UnicodeError): continue
                if isinstance(obj,dict):
                    item['json_lumps'][n] = {k:obj[k] for k in ('type','version') if k in obj}
        result['files'][name] = item
    return result


if __name__ == '__main__':
    try:
        if len(sys.argv) != 2: raise ValueError('Provide the installed rerelease directory')
        print(json.dumps(inventory(Path(sys.argv[1])),indent=2))
    except (ValueError,OSError,struct.error) as error:
        sys.exit(f'FAIL: {error}')
