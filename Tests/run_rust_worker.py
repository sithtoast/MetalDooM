#!/usr/bin/env python3
"""Run independent native workers; retain exact per-scenario logs under build/."""
import os, pathlib, re, shutil, subprocess, sys
out, original, rust = map(pathlib.Path,sys.argv[1:])
fixtures=out/'fixtures'; cache=out/'cache'
def run(name,cmd,expect=None,env=None):
    p=subprocess.run(list(map(str,cmd)),capture_output=True,text=True,env=env)
    text=p.stdout+p.stderr
    (out/f'{name}.log').write_text(text)
    if expect is None:
        assert p.returncode==0,(name,p.returncode,text[-2500:])
    else: assert p.returncode==1 and expect in text,(name,p.returncode,text[-2500:])
    print(name,':',next((s for s in text.splitlines() if s.startswith('PASS ')),text.splitlines()[-1]),flush=True)
    return text

def worker(paths,base=0,profile=1,map=1):
    return [out/'RustWorkerValidation',cache,map,base,profile,*paths]
def fingerprint(text):return re.search(r'sha256=([0-9a-f]{64})',text)[1]
for mode in ['pickup','pickup-bex','respawn-fast','respawn-slow','respawn-default']:
    run(mode,[out/'ID24FieldValidation',mode,cache,original,fixtures/f'{mode}.wad'])
for mode,expected in {'bad-dice':'Invalid ID24 value','bad-time':'Invalid ID24 value',
    'bad-number':'Invalid ID24 value','bad-mnemonic':'not found','plan-unknown':'Unknown GAMECONF executable',
    'plan-path':'without a path','plan-dependency':'dependency expansion',
    'plan-translation':'translations are not implemented','plan-option':'Unsupported GAMECONF option',
    'plan-option-overflow':'Invalid GAMECONF option value','plan-mode':'Unknown GAMECONF mode','plan-duplicate-key':'Duplicate GAMECONF key',
    'plan-truncated':'Invalid WAD directory'}.items():
    run(mode,worker([original,fixtures/f'{mode}.wad']),expected)
run('profile-gate',worker([original,fixtures/'pickup.wad'],profile=0),'requires explicit Rust probe')
run('id24-gate',worker([original,fixtures/'plan-id24.wad'],profile=0),'requires explicit Rust probe')
run('base-identity',worker([original,fixtures/'plan-a.wad'],base=1),'Selected base is not an IWAD')
run('duplicate-file',worker([original,original]),'Duplicate WAD')
a,b=fixtures/'plan-a.wad',fixtures/'plan-b.wad'
first=run('plan-order',worker([original,a,b]))
assert 'declared=6 options=2 title=First version=2' in first,first
again=run('plan-repeat',worker([original,a,b]));assert fingerprint(first)==fingerprint(again)
changed=run('plan-reorder',worker([original,b,a]));assert fingerprint(first)!=fingerprint(changed)
role=run('plan-base-middle',worker([a,original,b],base=1));assert fingerprint(first)!=fingerprint(role)
mbf=run('plan-profile',worker([original,a,b],profile=0));assert fingerprint(first)!=fingerprint(mbf)
relocated=fixtures/'relocated';relocated.mkdir(exist_ok=True)
shutil.copyfile(a,relocated/a.name);shutil.copyfile(b,relocated/b.name)
shutil.copyfile(original,relocated/original.name)
copy=run('plan-relocate',worker([relocated/original.name,relocated/a.name,relocated/b.name]));assert fingerprint(first)==fingerprint(copy)
role0=run('plan-role-zero',worker([original,relocated/original.name],base=0))
role1=run('plan-role-one',worker([original,relocated/original.name],base=1))
assert fingerprint(role0)!=fingerprint(role1)
basepaths=[rust/'id24res.wad',rust/'doom2.wad',rust/'id1.wad']
for m in range(1,17):run(f'rust-map{m:02}',worker(basepaths,base=1,map=m))
for mode in ['rust-fuel','rust-tank','rust-incinerator','rust-blade','rust-blade-charge','rust-blade-full']:
    fixture='rust-blade' if mode=='rust-blade-charge' else mode
    env=dict(os.environ,ME_TEST_SCENARIO=mode)
    run(mode,worker(basepaths+[fixtures/f'{fixture}.wad'],base=1),env=env)
print('PASS session planning, ID24 fields, sixteen map smoke checks and actual Rust weapon/pickup probes')
