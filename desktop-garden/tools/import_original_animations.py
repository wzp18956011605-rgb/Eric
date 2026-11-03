from pathlib import Path
import sys,json,math,copy,hashlib
# Usage: python tools/import_original_animations.py OBB_DIRECTORY OUTPUT_DIRECTORY
# Dependencies: Pillow, texture2ddecoder (see requirements.txt).
from rsgp_codec import read_packet
from pam_codec import Reader
from PIL import Image
import texture2ddecoder
if len(sys.argv)!=3:raise SystemExit('Usage: import_original_animations.py OBB_DIRECTORY OUTPUT_DIRECTORY')
ROOT=Path(sys.argv[1]);PACK=ROOT/'Packet';OUT=Path(sys.argv[2]);OUT.mkdir(parents=True,exist_ok=True)
from decode_rton import Decoder
manifest=read_packet((PACK/'__MANIFESTGROUP__.rsgp').read_bytes());decoder=Decoder(next(iter(manifest.values())));resources=decoder.obj();assert decoder.b[decoder.p:]==b'DONE'
structure=json.loads((ROOT/'StructInfo.json').read_text());groups={g['id']:g for g in resources['groups']};subgroups={s['ID']:s for g in structure['Group'] for s in g['SubGroup']}
rlookup={};owner={}
for g in resources['groups']:
 if g.get('res')=='1536':
  for r in g.get('resources',[]):rlookup[r['id']]=r;owner[r['id']]=g['id']
IDENTITY=[1,0,0,1,0,0]
def mul(a,b):
 return [a[0]*b[0]+a[2]*b[1],a[1]*b[0]+a[3]*b[1],a[0]*b[2]+a[2]*b[3],a[1]*b[2]+a[3]*b[3],a[0]*b[4]+a[2]*b[5]+a[4],a[1]*b[4]+a[3]*b[5]+a[5]]
def bake_states(sprite):
 states=[];slots={}
 for fi,frame in enumerate(sprite['frames']):
  for i in frame.get('remove',[]):slots.pop(i,None)
  for a in frame.get('append',[]):
   slots[a['index']]={**a,'matrix':IDENTITY[:],'color':[1,1,1,1],'born':fi,'frame_base':a.get('preload',0),'frame_set':fi}
  for ch in frame.get('change',[]):
   assert ch['index'] in slots,(sprite['name'],fi,ch)
   item=slots[ch['index']];item['matrix']=ch['matrix']
   if 'color' in ch:item['color']=ch['color']
   if 'rect' in ch:item['rect']=ch['rect']
   if 'anim_frame' in ch:item['frame_base']=ch['anim_frame'];item['frame_set']=fi
  states.append(copy.deepcopy(slots))
 return states
cache={}
def decode_atlas(rid):
 if rid in cache:return cache[rid]
 r=rlookup[rid];gid=owner[rid];path='\\'.join(r['path']).upper()+'.PTX';raw=read_packet((PACK/(gid+'.rsgp')).read_bytes())[path];info=next(x['AtlasInfo'] for x in subgroups[gid]['Res'] if '\\'.join(x['Path']).upper()==path);w,h=info['Size'];fmt=info['TexFmt']
 if fmt==147:
  im=Image.frombytes('RGBA',(w,h),texture2ddecoder.decode_etc1(raw[:w*h//2],w,h),'raw','BGRA');im.putalpha(Image.frombytes('L',(w,h),raw[w*h//2:]))
 elif fmt==0:im=Image.frombytes('RGBA',(w,h),raw)
 else:raise ValueError((rid,fmt))
 name=rid.lower()+'.png';im.save(OUT/name);cache[rid]=name;return name

def convert(key,gid,pam_suffix,wanted):
 actor_key=key.removeprefix('egypt_')
 rawfiles=read_packet((PACK/(gid+'_Common.rsgp')).read_bytes());path=next(n for n in rawfiles if n.upper().endswith(pam_suffix.upper()));pam=Reader(rawfiles[path]).decode();main=pam['main'];sprite_states=[bake_states(s) for s in pam['sprites']];mainstates=bake_states(main);images=[];atlases=[]
 for im in pam['images']:
  rid=im['name'].split('|')[-1];r=rlookup[rid];parent=r['parent'];atlas=decode_atlas(parent)
  if atlas not in atlases:atlases.append(atlas)
  images.append([atlases.index(atlas),*[r[k] for k in ['ax','ay','aw','ah']],*im['size']])
 flags={'rect':0,'additive':0}
 def flatten(states,fi,parent=IDENTITY,color=[1,1,1,1],depth=0):
  assert depth<30
  output=[]
  for idx,it in sorted(states[fi].items()):
   c=[a*b for a,b in zip(color,it['color'])]
   if c[3]<=0:continue
   matrix=mul(parent,it['matrix']);res=it['resource']
   if it.get('rect'):flags['rect']+=1
   if it.get('additive'):flags['additive']+=1
   if it['sprite']:
    child=pam['sprites'][res];childname=child['name'].lower()
    if key not in ['megapuff','sweetpea'] and (childname.startswith('custom') or childname.startswith('_custom') or (childname=='_wallnut_armor_states' and key!='wallnut_armored')):continue
    if actor_key in ['zombie','cone','bucket','cone_damage_01','cone_damage_02','bucket_damage_01','bucket_damage_02','giant']:
     if childname in ['ink','butter','ground_swatch','ground_swatch_plane'] or 'bone' in childname:continue
     if childname.startswith('zombie_armor_'):
      basekey=actor_key.split('_')[0];damage_stage='_'.join(actor_key.split('_')[1:]) if '_' in actor_key else 'norm';allowed='zombie_armor_'+basekey+'_'+damage_stage
      if childname!=allowed:continue
    n=len(child['frames']);elapsed=fi-it['frame_set'];childframe=int(elapsed*it.get('timescale',1)+it['frame_base'])
    stops=[i for i,f in enumerate(child['frames']) if f.get('stop')]
    if stops:childframe=min(childframe,stops[0])
    else:childframe%=n
    output.extend(flatten(sprite_states[res],max(0,min(childframe,n-1)),matrix,c,depth+1))
   else:
    matrix=mul(matrix,pam['images'][res]['matrix']);output.append([res,*[round(x,5) for x in matrix],*[round(x,4) for x in c]])
  return output
 labels=[(i,f['label']) for i,f in enumerate(main['frames']) if f.get('label')];clips={};bounds=[]
 for (start,label),(end,_) in zip(labels,labels[1:]+[(len(main['frames']),'')]):
  if label not in wanted:continue
  frames=[flatten(mainstates,f) for f in range(start,end)];events={str(f-start):main['frames'][f]['commands'] for f in range(start,end) if main['frames'][f].get('commands')};clips[label]={'frames':frames,'events':events}
  if label==wanted[0]:
   for frame in frames:
    for item in frame:
     im=images[item[0]];m=item[1:7];w,h=im[-2:]
     for x,y in [(0,0),(w,0),(0,h),(w,h)]:bounds.append((m[0]*x+m[2]*y+m[4],m[1]*x+m[3]*y+m[5]))
 assert clips and bounds
 bbox=[min(x for x,y in bounds),min(y for x,y in bounds),max(x for x,y in bounds),max(y for x,y in bounds)]
 if key=='wallnut_armored' and (OUT/'wallnut.json').exists():bbox=json.loads((OUT/'wallnut.json').read_text())['bounds']
 if actor_key in ['cone','bucket','cone_damage_01','cone_damage_02','bucket_damage_01','bucket_damage_02']:
  basefile=OUT/('egypt_zombie.json' if key.startswith('egypt_') else 'zombie.json')
  if basefile.exists():bbox=json.loads(basefile.read_text())['bounds']
 data={'rate':pam['rate'],'atlases':atlases,'images':images,'clips':clips,'idle':wanted[0],'bounds':bbox,'source':gid,'flags':flags};(OUT/(key+'.json')).write_text(json.dumps(data,separators=(',',':')))
 print(key,'clips',[(k,len(v['frames'])) for k,v in clips.items()],'bounds',bbox,'flags',flags,flush=True)
 return {'key':key,'packet':gid,'pam':path,'clips':list(clips),'image_count':len(images),'flags':flags}

items=[('pea','PlantPeashooter','\\PEASHOOTER.PAM',['idle','attack','plantfood']),('sunflower','PlantSunflower','\\SUNFLOWER.PAM',['idle','special','plantfood_on','plantfood','plantfood_off']),('wallnut','PlantWallnut','\\WALLNUT.PAM',['idle','damage','damage2','damage3','plantfood_on','plantfood','plantfood_off']),('snowpea','PlantSnowPea','\\SNOWPEA.PAM',['idle','attack','plantfood_on','plantfood','plantfood_off']),('sweetpea','PlantSweetpea','\\SWEETPEA.PAM',['idle','attack','plantfood']),('megapuff','PlantMegaGatlingPuff','\\MEGAGATLINGPUFF.PAM',['idle_stage1','special_stage1','plantfood_on','plantfood','plantfood_off']),('torchwood','PlantTorchwood','\\TORCHWOOD.PAM',['idle','idle2','plantfood_on','plantfood','plantfood_on_t2','plantfood_t2']),('squash','PlantSquash','\\SQUASH.PAM',['idle','size_up','jump_up_right','jump_down_right','plantfood_jump_down_right']),('zombie','ZombieTutorialGroup','\\ZOMBIE_TUTORIAL.PAM',['idle','walk','eat','die']),('cone','ZombieTutorialGroup','\\ZOMBIE_TUTORIAL.PAM',['idle','walk','eat','die']),('bucket','ZombieTutorialGroup','\\ZOMBIE_TUTORIAL.PAM',['idle','walk','eat','die']),('wallnut_armored','PlantWallnut','\\WALLNUT.PAM',['idle','damage','damage2','damage3','plantfood_on','plantfood','plantfood_off']),('giant','ZombieTutorialGargantuarGroup','\\TUTORIAL_GARGANTUAR.PAM',['idle','walk','eat','smash_left','die'])]
for armor in ['cone','bucket']:
 for stage in ['damage_01','damage_02']:items.append((armor+'_'+stage,'ZombieTutorialGroup','\\ZOMBIE_TUTORIAL.PAM',['idle','walk','eat','die']))
items.extend([
 ('cabbage','PlantCabbagepult','\\CABBAGEPULT.PAM',['idle','attack','plantfood']),
 ('bloomerang','PlantBloomerang','\\BLOOMERANG.PAM',['idle','attack','attack_02','plantfoodON','plantfood','plantfoodOFF']),
 ('mine','PlantPotatomine','\\POTATOMINE.PAM',['idle','plant','plant_idle','recover','attack','plantfood_on','plantfood','plantfood_off']),
 ('bonk','PlantBonkchoy','\\BONKCHOY.PAM',['idle','attack','attack2','plantfood_on','plantfood','plantfood_off']),
 ('gravebuster','PlantGraveBuster','\\GRAVEBUSTER.PAM',['attack','attack1']),
 ('grave','Egypt_Gravestone','\\EGYPT_HIEROGLYPH.PAM',['undamaged','damage1','damage2','damage3','damage4']),
 ('mine_fx','PlantPotatomine','\\POTATOMINE_EXPLOSION.PAM',['animation']),
 ('egypt_zombie','ZombieEgyptBasicGroup','\\ZOMBIE_EGYPT_BASIC.PAM',['idle','walk','eat','die'])])
for armor in ['cone','bucket']:
 for stage in ['', '_damage_01','_damage_02']:items.append(('egypt_'+armor+stage,'ZombieEgyptBasicGroup','\\ZOMBIE_EGYPT_BASIC.PAM',['idle','walk','eat','die']))
items.append(('egypt_giant','ZombieEgyptGargantuarGroup','\\EGYPT_GARGANTUAR.PAM',['idle','walk','eat','smash_left','die']))
report=[]
for args in items:report.append(convert(*args))
(OUT/'conversion-report.json').write_text(json.dumps(report,indent=2))
