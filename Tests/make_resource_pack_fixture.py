#!/usr/bin/env python3
"""Combine a base IWAD and *resource-only* PWAD into a private test IWAD.

This tests tables without admitting unsupported campaigns through the app's gate.
No simulation patches or additional maps are allowed. Output must stay private.
"""
from pathlib import Path
import struct
import sys
sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parents[1]/'scripts'))
from importlib import import_module
read_wad = import_module('audit-rust').read_wad
base, resources, output = map(Path,sys.argv[1:4])
if output.resolve() in (base.resolve(),resources.resolve()): raise ValueError('Output aliases source')
_, a = read_wad(base); _, b = read_wad(resources)
if any(n in ('THINGS','DEHACKED','UMAPINFO','MAPINFO','GAMECONF') for n,_ in b):
    raise ValueError('Only resource tables/art allowed in this fixture')
general=[]; namespaces=[{},{}]
for archive in (a,b):
    mode=None
    for name,data in archive:
        if name in ('S_START','SS_START'): mode=0;continue
        if name in ('F_START','FF_START'): mode=1;continue
        if name in ('S_END','SS_END','F_END','FF_END'): mode=None;continue
        if len(name)==8 and name[0] in 'SF' and name[1].isdigit() and name[2:]=='_START': continue
        if len(name)==6 and name[0] in 'SF' and name[1].isdigit() and name[2:]=='_END': continue
        if mode is not None:
            if data:
                # Last replacement's directory position determines animation order.
                namespaces[mode].pop(name,None); namespaces[mode][name]=data
        else: general.append((name,data))
    if mode is not None: raise ValueError('Unclosed namespace')
merged=general+[("S_START",b'')]+list(namespaces[0].items())+[("S_END",b''),("F_START",b'')]+list(namespaces[1].items())+[("F_END",b'')]
body=bytearray(b'IWAD'+bytes(8)); entries=[]
for name,data in merged:
    entries.append((len(body),len(data),name.encode()));body.extend(data)
struct.pack_into('<ii',body,4,len(entries),len(body))
for row in entries:body.extend(struct.pack('<ii8s',*row))
output.parent.mkdir(parents=True,exist_ok=True);output.write_bytes(body);print(output)
