"""Original layered/fire skies and authored brightmap/custom colormap resources."""
import pathlib,runpy,struct,json,sys
out=pathlib.Path(sys.argv[1]);out.mkdir(parents=True,exist_ok=True)
s=runpy.run_path(str(pathlib.Path(__file__).with_name('make_wall_palette_fixture.py')));name,wad=s['name'],s['wad']
for kind in [0,1,2]:
 lumps=[]
 for label,body in s['room']:
  if label=='LINEDEFS':
   body=bytearray(body);struct.pack_into('<HH',body,6*14+6,0,0)
  if label=='SECTORS':body=struct.pack('<hh8s8shhh',0,128,name('FLOOR0_1'),name('F_SKY1'),96,0,0)*2
  if label=='THINGS':body+=struct.pack('<5h',96,64,180,3001,7)
  lumps.append((label,body))
 sky=dict(type=kind,name='SKY1',mid=100,scrollx=7,scrolly=0,scalex=1,scaley=1,fire=None,foregroundtex=None)
 if kind==1:sky['fire']=dict(updatetime=.05715,palette=list(range(160,176)))
 if kind==2:sky['foregroundtex']=dict(name='SKY2',mid=60,scrollx=-13,scrolly=5,scalex=2,scaley=1)
 defs={'type':'skydefs','version':'1.0.0','metadata':{},'data':{'skies':[sky],'flatmapping':None}}
 lumps += [('UMAPINFO',b'map MAP01 { skytexture = "SKY1" }'),('SKYDEFS',json.dumps(defs).encode()),('BRGHTMPS',b'brightmap HOT 160-175\ntexture STARTAN3 HOT\nflat FLOOR0_1 HOT\nsprite TROO HOT\nstate 10 HOT\n'),('C_START',b''),('TESTTINT',bytes((i+17)%256 for row in range(34) for i in range(256))),('C_END',b'')]
 (out/f'presentation-{kind}.wad').write_bytes(wad(lumps))
