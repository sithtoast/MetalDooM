"""Private worker saves: exact visual/simulation continuation, without WAD redistribution."""
import copy,json,pathlib,struct,subprocess,sys,tempfile
exe,root,out=map(pathlib.Path,sys.argv[1:]);exe=exe.resolve();out.mkdir(parents=True,exist_ok=True)
class Worker:
 def __init__(self,map=1,extra=()):
  self.tmp=tempfile.TemporaryDirectory();self.seq=0
  self.p=subprocess.Popen([str(exe),self.tmp.name,str(map),'1','1','3']+[str(root/n) for n in ['id24res.wad','doom2.wad','id1.wad']]+[str(p) for p in extra],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.DEVNULL)
  self.initial=self.read()
 def read(self):
  head=self.p.stdout.read(16)
  assert len(head)==16,('worker exited',self.p.poll())
  magic,seq,status,n=struct.unpack('<4sIII',head);assert magic==b'MER1' and seq==self.seq and n<=170*1024*1024
  data=self.p.stdout.read(n);assert len(data)==n
  if status:raise ValueError(data.decode())
  return data
 def cmd(self,op,body=b''):
  self.seq+=1;self.p.stdin.write(struct.pack('<4sIII',b'MEQ1',self.seq,op,len(body))+body);self.p.stdin.flush();return self.read()
 def tick(self,buttons=0,count=35,forward=0,side=0,turn=0):return self.cmd(1,struct.pack('<bbhBB',forward,side,turn,buttons,0)*count)
 def close(self):
  if self.p.poll() is None:self.p.terminate()
  self.p.wait(timeout=5);self.tmp.cleanup()
def sections(view):
 sizes=struct.unpack_from('<5I',view,36);pos=56;parts=[]
 for size in sizes:parts.append(view[pos:pos+size]);pos+=size
 return parts

def equal(a,b,label):
 # Restored playback intentionally clears old sample tails/channels; physics,
 # actor/weapon/material/UI and every geometry field must still match exactly.
 aa,bb=sections(a),sections(b)
 for i in [0,1,2,4]:
  if aa[i]!=bb[i]:
   (out/f'{label}-a-{i}.bin').write_bytes(aa[i]);(out/f'{label}-b-{i}.bin').write_bytes(bb[i]);raise AssertionError((label,'section',i))
 assert a[:36]==b[:36],(label,'view')

cases=[(n,(),0,35) for n in range(1,17)]+[(1,(exe.parent/'fixtures/rust-incinerator.wad',),1,50),(1,(exe.parent/'fixtures/rust-blade-full.wad',),1,70),(16,(),2,70)]
for map,extra,attack,tics in cases:
 a=Worker(map,extra);b=None
 try:
  for t in range(0,tics,35):a.tick(attack,min(35,tics-t))
  # Explicit copy requests must neither advance simulation nor drain events.
  saved=a.cmd(6);assert saved==a.cmd(6)
  j=json.loads(saved);assert j['tic']==tics and j['map']==map
  (out/'sample.json').write_bytes(saved)
  b=Worker(map,extra);restored=b.cmd(7,saved)
  equal(a.cmd(2),restored,f'map{map}-initial')
  for step in range(4):
   a.tick(attack);b.tick(attack)
   equal(a.cmd(2),b.cmd(2),f'map{map}-next{step}')
  print('PASS save/restore and 140 future tics:',map,[p.name for p in extra],tics,flush=True)
 finally:
  a.close()
  if b:b.close()
# Save after real pickups, an exit and Continue: leveltime differs from gametic,
# inventory and visited-level history must survive loading in another process.
for start,secret in [(1,False),(2,True),(10,True),(15,False),(16,False)]:
 extra=(exe.parent/('fixtures/lifecycle-secret.wad' if secret else 'fixtures/lifecycle-normal.wad'),)
 a=Worker(start,extra);b=None
 try:
  a.tick(side=24,count=3);a.tick(buttons=2)
  a.cmd(4,struct.pack('<I',1));a.tick(count=7)
  saved=a.cmd(6);j=json.loads(saved)
  assert j['gametic']>j['tic'] and j['players'][0]['health']==200 and j['players'][0]['visitedlevels']
  b=Worker(j['map'],extra);equal(a.cmd(2),b.cmd(7,saved),'carryover')
  for _ in range(4):
   a.tick();b.tick();equal(a.cmd(2),b.cmd(2),'carryover-future')
  print('PASS post-transition save, pickups/history and future tics:',start,secret,j['map'],flush=True)
 finally:
  a.close()
  if b:b.close()
# Restore is single-use and only permitted before any initial tic has run.
a=Worker()
try:saved=a.cmd(6)
finally:a.close()
for boundary in ['late','twice']:
 b=Worker()
 try:
  if boundary=='late':b.tick(count=1)
  else:b.cmd(7,saved)
  try:b.cmd(7,saved)
  except ValueError:pass
  else:raise AssertionError(('restore boundary accepted',boundary))
 finally:b.close()
 print('PASS restore boundary:',boundary,flush=True)
# Deliberately malformed payloads bypass the outer checksum to test C boundaries.
a=Worker()
try:saved=a.cmd(6)
finally:a.close()
j=json.loads(saved)
for case in ['version','map','identity','tic','missing','sectors','index','class','loop','weapon','actor','duplicate','truncated']:
 bad=copy.deepcopy(j)
 if case=='version':bad['native_version']=2
 if case=='map':bad['map']=2
 if case=='identity':bad['identity']='0'*64
 if case=='tic':bad['tic']=-1
 if case=='missing':del bad['thinkercap']
 if case=='sectors':bad['sectors']=[]
 if case=='index':bad['thinkers'][0]['thinker']['subsector']=2147483647
 if case=='class':bad['thinkers'][0]['class']=999
 if case=='loop':bad['thinkercap']['next']=0;bad['thinkers'][0]['thinker']['thinker']['next']=0
 if case=='weapon':bad['players'][0]['readyweapon']=100
 if case=='actor':bad['thinkers'][0]['thinker']['type']=999999
 raw=json.dumps(bad,separators=(',',':')).encode()
 if case=='duplicate':raw=b'{"map":1,'+raw[1:]
 if case=='truncated':raw=raw[:-3]
 b=Worker()
 try:
  try:b.cmd(7,raw)
  except ValueError:pass
  else:raise AssertionError(('accepted malformed',case))
 finally:b.close()
 print('PASS malformed save rejected:',case,flush=True)
