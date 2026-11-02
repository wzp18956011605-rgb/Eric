"""Extract native front-lawn layers; usage: extract_lawn.py OBB_DIR ASSET_DIR."""
from pathlib import Path
import sys,json
from PIL import Image
import texture2ddecoder
from rsgp_codec import read_packet
from decode_rton import Decoder
root=Path(sys.argv[1]);out=Path(sys.argv[2]);out.mkdir(parents=True,exist_ok=True)
manifest=read_packet((root/'Packet/__MANIFESTGROUP__.rsgp').read_bytes());d=Decoder(next(iter(manifest.values())));resources=d.obj()
g=next(g for g in resources['groups'] if g['id']=='DelayLoad_Background_FrontLawn_1536');atlas=next(r for r in g['resources'] if r.get('atlas'));w,h=atlas['width'],atlas['height'];raw=read_packet((root/'Packet/DelayLoad_Background_FrontLawn_1536.rsgp').read_bytes())['\\'.join(atlas['path']).upper()+'.PTX']
assert len(raw)==w*h*3//2
im=Image.frombytes('RGBA',(w,h),texture2ddecoder.decode_etc1(raw[:w*h//2],w,h),'raw','BGRA');im.putalpha(Image.frombytes('L',(w,h),raw[w*h//2:]))
for ident,name in [('IMAGE_BACKGROUNDS_FRONTLAWN_TEXTURE','frontlawn.png'),('IMAGE_BACKGROUNDS_FRONTLAWN_ROW_05','frontlawn-grass.png')]:
 r=next(r for r in g['resources'] if r['id']==ident);x,y,aw,ah=[r[k] for k in ['ax','ay','aw','ah']];im.crop((x,y,x+aw,y+ah)).save(out/name)
print('Extracted native front lawn')
