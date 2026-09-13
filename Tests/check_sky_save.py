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

for kind in [0,1,2]:
 a=Worker(1,(exe.parent/f'fixtures/presentation-{kind}.wad',));b=None
 try:
  a.tick(count=7);saved=a.cmd(6);j=json.loads(saved)
  assert j['native_skies'][0]['offsets'][0] != 0
  assert bool(j['native_skies'][0]['fire']) == (kind==1)
  b=Worker(1,(exe.parent/f'fixtures/presentation-{kind}.wad',));equal(a.cmd(2),b.cmd(7,saved),'sky-initial')
  for _ in range(4):
   a.tick(count=7);b.tick(count=7);equal(a.cmd(2),b.cmd(2),'sky-future')
  print('PASS sky',kind,'saved scrolling/fire phase and 28 exact future tics',flush=True)
 finally:
  a.close()
  if b:b.close()
 if kind==1:
  for mode in ['missing','palette','phase','count']:
   bad=copy.deepcopy(j)
   if mode=='missing':del bad['native_skies']
   if mode=='palette':bad['native_skies'][0]['fire'][0]=255
   if mode=='phase':bad['native_skies'][0]['tics']=99999
   if mode=='count':bad['native_skies'][0]['fire'].pop()
   b=Worker(1,(exe.parent/f'fixtures/presentation-{kind}.wad',))
   try:
    try:b.cmd(7,json.dumps(bad).encode())
    except ValueError:pass
    else:raise AssertionError(('bad sky save accepted',mode))
   finally:b.close()
   print('PASS malformed sky save rejected',mode,flush=True)
