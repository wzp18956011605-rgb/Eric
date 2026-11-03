"""Extract uploaded OBB's native Egypt background. Usage: OBB_DIR ASSET_DIR."""
from pathlib import Path
import sys
from PIL import Image
import texture2ddecoder
from rsgp_codec import read_packet
from decode_rton import Decoder
root=Path(sys.argv[1]);out=Path(sys.argv[2]);out.mkdir(parents=True,exist_ok=True)
m=read_packet((root/'Packet/__MANIFESTGROUP__.rsgp').read_bytes());resources=Decoder(next(iter(m.values()))).obj()
gid='DelayLoad_Background_Egypt_Compressed_1536'
g=next(g for g in resources['groups'] if g['id']==gid)
a=next(r for r in g['resources'] if r.get('atlas'));w,h=a['width'],a['height']
raw=read_packet((root/f'Packet/{gid}.rsgp').read_bytes())['\\'.join(a['path']).upper()+'.PTX']
im=Image.frombytes('RGBA',(w,h),texture2ddecoder.decode_etc1(raw[:w*h//2],w,h),'raw','BGRA');im.putalpha(Image.frombytes('L',(w,h),raw[w*h//2:]))
r=next(r for r in g['resources'] if r['id']=='IMAGE_BACKGROUNDS_EGYPT_TEXTURE');x,y,aw,ah=[r[k] for k in ['ax','ay','aw','ah']]
im.crop((x,y,x+aw,y+ah)).save(out/'egypt.png')
