import struct,zlib,math

def canonical(path):return path.replace('/','\\').upper()
def align(b):return b+b'\0'*((-len(b))%4096)
def trie_table(entries):
 tree={}
 for path,meta in entries:
  node=tree
  for c in path.encode('ascii')+b'\0':node=node.setdefault(c,{})
  assert 'meta' not in node;node['meta']=meta
 out=bytearray()
 def emit(children):
  previous=None
  for c,child in sorted(children.items()):
   start=len(out)
   if previous is not None:out[previous+1:previous+4]=(start//4).to_bytes(3,'little')
   previous=start;out.extend(bytes([c,0,0,0]))
   if c==0:out.extend(child['meta'])
   else:emit(child)
 emit(tree);return bytes(out)
def packet(files):
 data=b'';tex=b'';atlas=0;entries=[];seen=set()
 for path,raw,size in sorted(files,key=lambda f:canonical(f[0])):
  path=canonical(path);assert path not in seen;seen.add(path)
  if size:
   meta=struct.pack('<8I',1,len(tex),len(raw),atlas,0,0,*size);tex+=align(raw);atlas+=1
  else:meta=struct.pack('<3I',0,len(data),len(raw));data+=align(raw)
  entries.append((path,meta))
 table=trie_table(entries);off=math.ceil((92+len(table))/4096)*4096
 general=align(zlib.compress(data,9));textures=align(zlib.compress(tex,9)) if tex else b''
 head=bytearray(92)
 for k,v in {0:0x72736770,4:4,16:3,20:off,24:off,28:len(general),32:len(data),40:off+len(general),44:len(textures),48:len(tex),72:len(table),76:92}.items():struct.pack_into('<I',head,k,v)
 return bytes(head)+table+b'\0'*(off-92-len(table))+general+textures

def table_entries(b):
 u=lambda p:struct.unpack_from('<I',b,p)[0];start=u(76);end=start+u(72);out=[]
 def walk(p,prefix):
  while p<end:
   c=b[p];nxt=int.from_bytes(b[p+1:p+4],'little');q=p+4
   if c==0:
    kind,offset,size=struct.unpack_from('<III',b,q);extra=struct.unpack_from('<5I',b,q+12) if kind else None
    out.append((prefix,kind,offset,size,extra))
   else:walk(q,prefix+chr(c))
   if not nxt:break
   p=start+nxt*4
 walk(start,'');return out

def read_packet(b):
 u=lambda p:struct.unpack_from('<I',b,p)[0];flags=u(16)
 general=b[u(24):u(24)+u(28)];tex=b[u(40):u(40)+u(44)]
 if flags&2:general=zlib.decompress(general)
 if flags&1 and tex:tex=zlib.decompress(tex)
 assert len(general)==u(32) and len(tex)==u(48)
 return {name:(tex if kind else general)[off:off+size] for name,kind,off,size,extra in table_entries(b)}

def lookup(b,name):
 # Search by branch pointers, independently of the sequential enumeration reader.
 u=lambda p:struct.unpack_from('<I',b,p)[0];start=u(76);p=start;key=canonical(name).encode('ascii')+b'\0';i=0
 for _ in range(len(b)//4):
  c=b[p];nxt=int.from_bytes(b[p+1:p+4],'little')
  if c==key[i]:
   if c==0:return struct.unpack_from('<III',b,p+4)
   p+=4;i+=1
  elif nxt:p=start+nxt*4
  else:return None
 raise ValueError('index loop')
