import struct,math
class Reader:
 def __init__(self,b):self.b=b;self.p=0
 def n(self,f):
  s=struct.calcsize('<'+f);v=struct.unpack_from('<'+f,self.b,self.p);self.p+=s;return v[0] if len(v)==1 else list(v)
 def st(self):
  n=self.n('H');s=self.b[self.p:self.p+n].decode();self.p+=n;return s
 def count(self):
  n=self.n('B');return self.n('H') if n==255 else n
 def frame(self):
  f={};flag=self.n('B')
  if flag&1:
   f['remove']=[]
   for _ in range(self.count()):
    n=self.n('H');f['remove'].append(self.n('i') if n>=2047 else n)
  if flag&2:
   f['append']=[]
   for _ in range(self.count()):
    v=self.n('H');a={'index':v&2047,'sprite':bool(v&32768),'additive':bool(v&16384)}
    if a['index']==2047:a['index']=self.n('i')
    a['resource']=self.n('B')
    if a['resource']==255:a['resource']=self.n('H')
    if v&8192:a['preload']=self.n('H')
    if v&4096:a['name']=self.st()
    if v&2048:a['timescale']=self.n('i')/65536
    f['append'].append(a)
  if flag&4:
   f['change']=[]
   for _ in range(self.count()):
    v=self.n('H');a={'index':v&1023}
    if a['index']==1023:a['index']=self.n('i')
    if v&4096:
     aa,c,b,d=self.n('iiii');m=[aa/65536,b/65536,c/65536,d/65536]
    elif v&16384:
     r=self.n('h')/1000;m=[math.cos(r),math.sin(r),-math.sin(r),math.cos(r)]
    else:m=[1,0,0,1]
    m+= [x/20 for x in self.n('ii' if v&2048 else 'hh')];a['matrix']=m
    if v&32768:a['rect']=[x/20 for x in self.n('hhhh')]
    if v&8192:a['color']=[x/255 for x in self.n('BBBB')]
    if v&1024:a['anim_frame']=self.n('H')
    f['change'].append(a)
  if flag&8:f['label']=self.st()
  if flag&16:f['stop']=True
  if flag&32:f['commands']=[[self.st(),self.st()] for _ in range(self.n('B'))]
  return f
 def sprite(self):
  s={'name':self.st(),'description':self.st(),'rate':self.n('i')/65536};n=self.n('H');s['work']=self.n('HH');s['frames']=[self.frame() for _ in range(n)];return s
 def decode(self):
  assert self.n('I')==0xbaf01954;assert self.n('I')==6
  d={'rate':self.n('B'),'position':[x/20 for x in self.n('hh')],'size':[x/20 for x in self.n('hh')],'images':[]}
  for _ in range(self.n('H')):
   a={'name':self.st(),'size':self.n('hh')};aa,c,b,dd=self.n('iiii');a['matrix']=[aa/1310720,b/1310720,c/1310720,dd/1310720]+[x/20 for x in self.n('hh')];d['images'].append(a)
  d['sprites']=[self.sprite() for _ in range(self.n('H'))];d['main']=self.sprite() if self.n('B') else None;assert self.p==len(self.b),(self.p,len(self.b));return d

def n(f,*v):return struct.pack('<'+f,*v)
def st(s):
 b=s.encode();return n('H',len(b))+b
def count(v):return n('B',v) if v<255 else n('BH',255,v)
def frame(f):
 flags=sum(v for k,v in [('remove',1),('append',2),('change',4),('label',8),('stop',16),('commands',32)] if f.get(k));b=n('B',flags)
 if flags&1:
  b+=count(len(f['remove']))
  for i in f['remove']:b+=n('H',i) if i<2047 else n('Hi',2047,i)
 if flags&2:
  b+=count(len(f['append']))
  for a in f['append']:
   idx=a['index'];fl=(idx if idx<2047 else 2047)|(32768 if a.get('sprite') else 0)|(4096 if a.get('name') is not None else 0)
   b+=n('H',fl)+(n('i',idx) if idx>=2047 else b'');r=a['resource'];b+=n('B',r) if r<255 else n('BH',255,r)
   if a.get('name') is not None:b+=st(a['name'])
 if flags&4:
  b+=count(len(f['change']))
  for a in f['change']:
   idx=a['index'];m=a['matrix'];fl=(idx if idx<1023 else 1023)|4096|2048|(8192 if 'color' in a else 0)
   b+=n('H',fl)+(n('i',idx) if idx>=1023 else b'')+n('iiii',*(round(x*65536) for x in [m[0],m[2],m[1],m[3]]))+n('ii',*(round(x*20) for x in m[4:]))
   if 'color' in a:b+=n('BBBB',*(max(0,min(255,round(x*255))) for x in a['color']))
 if flags&8:b+=st(f['label'])
 if flags&32:b+=n('B',len(f['commands']))+b''.join(st(a)+st(c) for a,c in f['commands'])
 return b
def sprite(s):
 f=s['frames'];return st(s.get('name',''))+st(s.get('description',''))+n('i',round(s.get('rate',30)*65536))+n('HHH',len(f),0,len(f)-1)+b''.join(frame(x) for x in f)
def encode(d):
 b=n('IIBhhhhH',0xbaf01954,6,d['rate'],*(round(x*20) for x in d['position']+d['size']),len(d['images']))
 for im in d['images']:
  m=im['matrix'];b+=st(im['name'])+n('hh',*im['size'])+n('iiii',*(round(x*1310720) for x in [m[0],m[2],m[1],m[3]]))+n('hh',*(round(x*20) for x in m[4:]))
 b+=n('H',len(d.get('sprites',[])))+b''.join(sprite(x) for x in d.get('sprites',[]))+n('B',1)+sprite(d['main']);return b
