"""Safe local import: preserve inputs, hash deduplicate, proportional images, actual Theora conversion.

This inbox creates an indexed personal library. It never replaces the main portrait automatically.
"""
from pathlib import Path
import hashlib,json,csv,subprocess,shutil,sys
from PIL import Image,ImageOps,UnidentifiedImageError
import imageio_ffmpeg
ROOT=Path(__file__).resolve().parents[1]
import argparse
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('inbox',nargs='?',type=Path,default=ROOT/'待导入素材')
parser.add_argument('--output',type=Path,default=ROOT/'UserMedia')
args=parser.parse_args()
INBOX=args.inbox
OUT=args.output;OUT.mkdir(parents=True,exist_ok=True)
INDEX=OUT/'library.json'
items=json.loads(INDEX.read_text(encoding='utf-8')) if INDEX.exists() else []
hashes={i['sha256'] for i in items};report=[]
for p in sorted(INBOX.iterdir()):
    if not p.is_file() or p.suffix.lower() in ['.md','.txt','.json','.gdignore']:continue
    digest=hashlib.sha256(p.read_bytes()).hexdigest()
    if digest in hashes:report.append({'file':p.name,'status':'duplicate','sha256':digest});continue
    stem='personal_'+digest[:16]
    try:
        with Image.open(p) as im:
            im=ImageOps.exif_transpose(im).convert('RGB');original=list(im.size);im.thumbnail((2048,2048));dest=OUT/(stem+'.jpg');im.save(dest,quality=93)
        kind='image'
    except (UnidentifiedImageError,OSError):
        if p.suffix.lower() not in ['.mp4','.mov','.mkv','.webm','.ogv','.mp3','.wav','.ogg','.flac']:
            report.append({'file':p.name,'status':'unsupported_or_corrupt'});continue
        kind='audio' if p.suffix.lower() in ['.mp3','.wav','.ogg','.flac'] else 'video'
        dest=OUT/(stem+('.ogg' if kind=='audio' else '.ogv'))
        command=[imageio_ffmpeg.get_ffmpeg_exe(),'-v','error','-y','-i',str(p)]
        command+=['-vn','-c:a','libvorbis','-q:a','5'] if kind=='audio' else ['-vf','scale=1280:720:force_original_aspect_ratio=decrease,pad=1280:720:(ow-iw)/2:(oh-ih)/2,setsar=1','-r','30','-c:v','libtheora','-q:v','6','-c:a','libvorbis','-q:a','5']
        result=subprocess.run(command+[str(dest)],capture_output=True,text=True)
        if result.returncode:
            report.append({'file':p.name,'status':'conversion_failed','error':result.stderr[-1200:]});continue
        original=None
    record={'asset_id':stem,'kind':kind,'title':p.stem,'source_path':str(p),'sha256':digest,'original_size':original,'runtime_path':dest.name,'rights':'user supplied; permission unknown; no public distribution','source_url':None}
    items.append(record);hashes.add(digest);report.append({'file':p.name,'status':'imported','asset_id':stem})
INDEX.write_text(json.dumps(items,ensure_ascii=False,indent=2),encoding='utf-8')
(OUT/'import_report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(report,ensure_ascii=False,indent=2))
