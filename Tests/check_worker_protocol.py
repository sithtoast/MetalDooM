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
    assert magic == b'MER1' and length <= 160*1024*1024+56
    body = p.stdout.read(length)
    assert len(body) == length
    return seq, status, body
with tempfile.TemporaryDirectory() as cache:
    command = [executable, cache, '1', '0', '0', '3', base]
    for mode in ['sequence', 'length', 'operation', 'truncated', 'reserved', 'quit', 'eof', 'action', 'action-length', 'campaign-playing', 'campaign-length', 'save-length', 'blend-length', 'restore-empty', 'restore-oversize', 'restore-truncated']:
        p = subprocess.Popen(command, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
        try:
            initial = read(p)
            assert initial[:2] == (0, 0) and initial[2][:4] == b'MVW5'
            geometry, presentation, materials, audio, ui = struct.unpack_from('<IIIII', initial[2], 36)
            sprite_data = initial[2][56+geometry:56+geometry+presentation]
            assert len(sprite_data) == presentation and sprite_data[:4] == b'MSP4'
            (pathlib.Path(executable).parent / 'initial-presentation.msp').write_bytes(sprite_data)
            (pathlib.Path(executable).parent / 'initial-view.mvw').write_bytes(initial[2])
            assert len(initial[2]) == 56+geometry+presentation+materials+audio+ui and initial[2][56+geometry+presentation:][:4] == b'MMT1'
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
            if mode == 'campaign-playing': op = 5
            if mode == 'campaign-length': op,body,length=5,b'\0',1
            if mode == 'blend-length': op,body,length=8,b'\0',1
            if mode == 'save-length': op,body,length=6,b'\0',1
            if mode == 'restore-empty': op=7
            if mode == 'restore-oversize': op,length=7,64*1024*1024+1
            if mode == 'restore-truncated': op,body,length=7,b'{',2
            if mode == 'action': op,body,length=4,struct.pack('<I',2),4
            if mode == 'action-length': op,body,length=4,b'\0',1
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
