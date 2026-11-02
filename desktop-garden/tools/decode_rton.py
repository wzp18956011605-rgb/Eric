import struct,json,sys
from pathlib import Path
class Decoder:
 def __init__(self,b): self.b=b;self.p=8;self.a=[];self.u=[]
 def read(self,n):
  v=self.b[self.p:self.p+n];self.p+=n;return v
 def byte(self):return self.read(1)[0]
 def var(self):
  n=s=0
  while True:
   x=self.byte();n|=(x&127)<<s
   if x<128:return n
   s+=7
 def string(self):return self.read(self.var()).decode('utf-8')
 def obj(self):
  d={}
  while True:
   t=self.byte()
   if t==255:return d
   k=self.val(t);d[k]=self.val(self.byte())
 def val(self,t):
  if t in (0,1):return bool(t)
  nums={8:'b',16:'h',32:'i',34:'f',38:'I',64:'q',66:'d',70:'Q'}
  if t in nums:
   f='<'+nums[t];return struct.unpack(f,self.read(struct.calcsize(f)))[0]
  if t in (9,17,33,35,39,65,67,71):return 0
  if t in (36,40,68,72):return self.var()
  if t in (37,41,69,73):
   n=self.var();return (n>>1)^-(n&1)
  if t==129:return self.string()
  if t==130:self.var();return self.string()
  if t in (144,146):
   if t==146:self.var()
   s=self.string();(self.a if t==144 else self.u).append(s);return s
  if t in (145,147):return (self.a if t==145 else self.u)[self.var()]
  if t==132:return 'RTID(0)'
  if t==131:
   sub=self.byte()
   if sub==0:return 'RTID(0)'
   if sub==3:
    self.var();sheet=self.string();self.var();name=self.string();return f'RTID({name}@{sheet})'
   if sub in (1,2):
    sheet=''
    if sub==2:self.var();sheet=self.string()
    a=self.var();b=self.var();c=struct.unpack('<I',self.read(4))[0];return f'RTID({b}.{a}.{c:08x}@{sheet})'
   raise ValueError(('RTID',sub,self.p))
  if t==133:return self.obj()
  if t==134:
   assert self.byte()==253
   a=[self.val(self.byte()) for _ in range(self.var())];assert self.byte()==254;return a
  raise ValueError(('unknown',hex(t),self.p))
if __name__=='__main__':
 p=Path(sys.argv[1]);d=Decoder(p.read_bytes());o=d.obj();assert d.b[d.p:]==b'DONE';out=Path(sys.argv[2]);out.write_text(json.dumps(o,ensure_ascii=False,indent=2)+'\n');print(out,len(o.get('objects',[])))
