import pathlib
import struct
import subprocess
import sys
import tempfile

executable, base = sys.argv[1:]
def read(p):
    head = p.stdout.read(16)
    assert len(head) == 16, head
    magic, seq, status, length = struct.unpack('<4sIII', head)
    assert magic == b'MER1' and length <= 160*1024*1024+44
    body = p.stdout.read(length)
    assert len(body) == length
    return seq, status, body
with tempfile.TemporaryDirectory() as cache:
    command = [executable, cache, '1', '0', '0', '3', base]
    for mode in ['sequence', 'length', 'operation', 'truncated', 'reserved', 'quit', 'eof']:
        p = subprocess.Popen(command, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
        try:
            initial = read(p)
            assert initial[:2] == (0, 0) and initial[2][:4] == b'MVW2'
            geometry, presentation = struct.unpack_from('<II', initial[2], 36)
            sprite_data = initial[2][44+geometry:]
            assert len(sprite_data) == presentation and sprite_data[:4] == b'MSP1'
            (pathlib.Path(executable).parent / 'initial-presentation.msp').write_bytes(sprite_data)
            if mode == 'eof':
                p.stdin.close()
                assert p.wait(timeout=3) == 0
                continue
            seq, op, body, length = 1, 2, b'', 0
            if mode == 'sequence': seq = 2
            if mode == 'length': length = 211
            if mode == 'operation': op = 99
            if mode == 'truncated': length = 1
            if mode == 'reserved': op, body, length = 1, b'\0'*5+b'\1', 6
            if mode == 'quit': op = 3
            p.stdin.write(struct.pack('<4sIII', b'MEQ1', seq, op, length)+body)
            p.stdin.close()
            reply = read(p)
            assert reply[:2] == (1, 0 if mode == 'quit' else 1), (mode, reply)
            assert p.wait(timeout=3) == (0 if mode == 'quit' else 1)
        finally:
            if p.poll() is None: p.kill(); p.wait(timeout=3)
        print('PASS worker request boundary:', mode)

out = pathlib.Path(executable).parent
for mode in ['stall', 'oversize', 'sequence', 'truncated']:
    reply = {'oversize':struct.pack('<4sIII', b'MER1', 0, 0, 0xffffffff),
             'sequence':struct.pack('<4sIII', b'MER1', 1, 0, 0),
             'truncated':b'MER1'}.get(mode, b'')
    code = f'#!{sys.executable}\nimport sys,time\nsys.stdout.buffer.write({reply!r});sys.stdout.buffer.flush()\n'
    if mode == 'stall': code += 'time.sleep(10)\n'
    path = out / ('fake-'+mode)
    path.write_text(code);path.chmod(0o755)
