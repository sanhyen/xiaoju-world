"""Generate MIT-licensed geometric scenery and demonstration media from scratch."""
from pathlib import Path
import hashlib, json, math, subprocess
from PIL import Image, ImageDraw, ImageFont
import imageio_ffmpeg

ROOT=Path(__file__).resolve().parents[1]
PALETTES=[('#d8ecdf','#7eb4ad','#355c67','#f3d79b'),('#ead9cf','#bd98a7','#5d6484','#fff0bf'),('#d6e7f5','#7badd0','#395e82','#f6e9b4'),('#e8e4ce','#91ab7e','#47796f','#f2c57a'),('#ddd9eb','#999ac6','#525b91','#f5d4ae'),('#d9eadb','#78b4a0','#355e67','#f6d68d')]

def sha(path):
    with path.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()

def scenery(size,variant,label='原创演示 · 海风'):
    w,h=size;sky,sea,land,sun=PALETTES[variant%len(PALETTES)]
    im=Image.new('RGB',size,sky);d=ImageDraw.Draw(im)
    d.rectangle((0,h*.52,w,h),fill=sea)
    d.ellipse((w*.65,h*.12,w*.86,h*.12+w*.21),fill=sun)
    for i in range(5):
        y=int(h*(.60+i*.07));d.rectangle((w*(.05+(i%2)*.15),y,w*(.55+(i%3)*.12),y+max(1,h//160)),fill=sky)
    d.polygon([(0,h*.72),(w*.18,h*.62),(w*.34,h*.69),(w*.42,h*.85),(w,h*.89),(w,h),(0,h)],fill=land)
    for i in range(4):
        x=int(w*(.10+i*.18));y=int(h*(.70+(.03 if i%2 else 0)));bw=max(8,w//13);bh=max(10,h//14)
        d.rectangle((x,y-bh,x+bw,y),fill=sun)
        d.polygon([(x-bw*.12,y-bh),(x+bw*.5,y-bh*1.35),(x+bw*1.12,y-bh)],fill=land)
    font=ImageFont.truetype(str(ROOT/'assets/fonts/NotoSansSC-Medium.ttf'),max(12,min(w,h)//22))
    d.rectangle((0,h*.89,w,h),fill=sky)
    d.text((w*.06,h*.91),label,font=font,fill=land)
    return im

def main():
    recipes=json.loads((ROOT/'data/demo_media.json').read_text(encoding='utf-8'))
    cache=ROOT/'.runtime/demo_generator';cache.mkdir(parents=True,exist_ok=True)
    ffmpeg=imageio_ffmpeg.get_ffmpeg_exe()
    music=ROOT/'assets/audio/bay/arrival.wav'
    for i,item in enumerate(recipes):
        dest=ROOT/item['path'];dest.parent.mkdir(parents=True,exist_ok=True)
        if dest.suffix in ['.jpg','.png']:
            image=scenery(tuple(item['size']),item['variant'],f'原创演示 · {i+1:02d}')
            image.save(dest,**({'quality':92} if dest.suffix=='.jpg' else {}))
        elif dest.suffix=='.ogg':
            subprocess.run([ffmpeg,'-v','error','-y','-i',str(music),'-t','8','-vn','-c:a','libvorbis','-q:a','4',str(dest)],check=True)
        else:
            frame=cache/f'{i:02d}.png';scenery((640,360),item['variant'],f'原创演示短片 · {i+1:02d}').save(frame)
            subprocess.run([ffmpeg,'-v','error','-y','-loop','1','-framerate','12','-i',str(frame),'-i',str(music),'-t','8','-vf',"drawbox=x=0:y=ih-5:w=iw:h=5:color=white@0.4:t=fill",'-c:v','libtheora','-q:v','5','-pix_fmt','yuv420p','-c:a','libvorbis','-q:a','3','-shortest',str(dest)],check=True)
    records=[]
    for folder in ['assets/media','assets/audio','assets/fonts','assets/materials']:
        for p in sorted((ROOT/folder).rglob('*')):
            if not p.is_file() or p.suffix in ['.import','.uid']:continue
            rel=p.relative_to(ROOT).as_posix()
            license='SIL-OFL-1.1' if rel.startswith('assets/fonts/') else 'CC0-1.0' if p.parent==ROOT/'assets/audio' and p.suffix=='.wav' else 'MIT'
            records.append({'path':rel,'bytes':p.stat().st_size,'sha256':sha(p),'license':license,'origin':'Project procedural generation' if rel.startswith('assets/media/') else 'Noto Sans SC' if rel.startswith('assets/fonts/') else 'Project-original asset'})
    (ROOT/'data/public_asset_manifest.json').write_text(json.dumps({'edition':'0.12.0-open.1','media_generator':'tools/generate_demo_media.py','assets':records},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({'generated_media':len(recipes),'registered_assets':len(records)},ensure_ascii=False))

if __name__=='__main__':main()
