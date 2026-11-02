"""Usage: extract_effect_audio.py OBB_DIR OUTPUT_DIR WW2OGG CODEBOOK_FILE. Needs ffmpeg/ffprobe."""
import sys,struct,json
from pathlib import Path
from rsgp_codec import read_packet
root=Path(sys.argv[1])/'Packet';out=Path(sys.argv[2]);out.mkdir(parents=True,exist_ok=True);media={};objs={};sources={}
for name in ['WiseAlwaysLoaded','PlantPeashooterAudio','PlantSunflowerAudio','PlantSquashAudio','AudioCommon']:
 p=root/(name+'.rsgp')
 if not p.exists():continue
 for path,b in read_packet(p.read_bytes()).items():
  if not path.endswith('.BNK'):continue
  chunks={};i=0
  while i+8<=len(b):
   key=b[i:i+4];size=struct.unpack_from('<I',b,i+4)[0];chunks[key]=b[i+8:i+8+size];i+=8+size

  if b'DIDX' in chunks:
   for i in range(0,len(chunks[b'DIDX']),12):
    id,off,size=struct.unpack_from('<III',chunks[b'DIDX'],i);media[id]=chunks[b'DATA'][off:off+size];sources[id]=path
  if b'HIRC' in chunks:
   h=chunks[b'HIRC'];n=struct.unpack_from('<I',h,0)[0];i=4
   for _ in range(n):
    typ=h[i];size=struct.unpack_from('<I',h,i+1)[0];obj=h[i+5:i+5+size];id=struct.unpack_from('<I',obj,0)[0];objs[id]=(typ,obj);i+=5+size

def hashname(s):
 h=2166136261
 for c in s.lower().encode():h=((h*16777619)&0xffffffff)^c
 return h

def walk(id,seen=None):
 seen=set() if seen is None else seen
 if id in seen or id not in objs:return []
 seen.add(id);typ,obj=objs[id]
 if typ==2:
  return sorted({struct.unpack_from('<I',obj,i)[0] for i in range(4,len(obj)-3) if struct.unpack_from('<I',obj,i)[0] in media})
 if typ==4:
  n=struct.unpack_from('<I',obj,4)[0];refs=struct.unpack_from('<'+'I'*n,obj,8)
 elif typ==3:refs=[struct.unpack_from('<I',obj,6)[0]]
 elif typ in [5,6,9]:
  candidates=[]
  for i in range(4,len(obj)-3):
   n=struct.unpack_from('<I',obj,i)[0]
   if 0<n<100 and i+4+n*4<=len(obj):
    ids=struct.unpack_from('<'+'I'*n,obj,i+4)
    if all(x in objs and objs[x][0] in [2,5,6,9] for x in ids):candidates.append(ids)
  refs=max(candidates,key=len) if candidates else []
 else:return []
 return sorted({m for child in refs for m in walk(child,seen)})

# Arguments 3 and 4 are external ww2ogg executable and its aoTuV codebook file.
import tempfile,subprocess
ww=Path(sys.argv[3]);pcb=Path(sys.argv[4]);result={}
events={'shoot':'Play_Throw','impact':'Play_Splat','sun':'Play_Spawn_Sun','plant':'Play_Plant','shovel':'Play_Shovel','squash':'Play_Plant_Squash_Attack','food':'Play_Peashooter_Food'}
with tempfile.TemporaryDirectory() as temp:
 work=Path(temp)
 for name,event in events.items():
  samples=[]
  for id in walk(hashname(event)):
   wem=work/(str(id)+'.wem');ogg=work/(str(id)+'.ogg');wem.write_bytes(media[id])
   p=subprocess.run([str(ww),str(wem),'--pcb',str(pcb),'-o',str(ogg)],capture_output=True)
   if p.returncode:continue
   probe=subprocess.run(['ffprobe','-v','error','-show_entries','format=duration','-of','csv=p=0',str(ogg)],capture_output=True,text=True)
   try:duration=float(probe.stdout.strip())
   except ValueError:continue
   if duration>0.065:samples.append((duration,id,ogg))
  samples.sort();chosen=samples[:(3 if name in ['shoot','impact'] else 1)]
  if not chosen:raise RuntimeError('No decodable media for '+event)
  result[name]={'event':event,'variants':[]}
  for i,(duration,id,ogg) in enumerate(chosen):
   target=out/(name+str(i)+'.wav')
   subprocess.run(['ffmpeg','-v','error','-y','-i',str(ogg),'-ar','22050','-ac','1','-c:a','pcm_s16le',str(target)],check=True)
   result[name]['variants'].append({'file':target.name,'source_media_id':id,'duration':duration})
(out/'audio-map.json').write_text(json.dumps(result,indent=2))
print('Extracted seven effect categories; Wwise switch routing is approximated.')
