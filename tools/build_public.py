"""Build and verify Xiaoju World with an explicitly selected Godot executable."""
from pathlib import Path
import argparse,datetime,hashlib,json,os,shutil,subprocess,sys,zipfile
ROOT=Path(__file__).resolve().parents[1]
VERSION='0.12.0-open.1'

def main():
 p=argparse.ArgumentParser(description=__doc__)
 p.add_argument('task',choices=['import','demo','bake','text','check','smoke','restore','export','package','audit','all'])
 p.add_argument('--engine',default=os.environ.get('GODOT_BIN') or shutil.which('godot'))
 p.add_argument('--templates-dir',type=Path,help='Optional directory containing the matching Windows export templates')
 args=p.parse_args()
 for name in ['reports','.runtime/appdata','.runtime/local','.runtime/temp','builds/windows','dist']:(ROOT/name).mkdir(parents=True,exist_ok=True)
 env=os.environ.copy();env.update(APPDATA=str(ROOT/'.runtime/appdata'),LOCALAPPDATA=str(ROOT/'.runtime/local'),TEMP=str(ROOT/'.runtime/temp'),TMP=str(ROOT/'.runtime/temp'))
 if args.templates_dir:
  dest=Path(env['APPDATA'])/'Godot/export_templates/4.7.2.stable';dest.mkdir(parents=True,exist_ok=True)
  for name in ['windows_release_x86_64.exe','windows_debug_x86_64.exe']:
   source=args.templates_dir/name
   if source.is_file():shutil.copy2(source,dest/name)
 history=ROOT/'reports/public_build.json'
 results=json.loads(history.read_text(encoding='utf-8')) if history.exists() else []
 def run(label,command,timeout=900):
  log=ROOT/'reports'/f'public_{label}.log'
  if log.exists():
   old=ROOT/'reports/history';old.mkdir(exist_ok=True)
   shutil.copy2(log,old/(datetime.datetime.now().strftime('%Y%m%d_%H%M%S_%f')+'_'+log.name))
  print('START '+label,flush=True)
  with log.open('w',encoding='utf-8') as output:
   proc=subprocess.run(command,cwd=ROOT,env=env,stdout=output,stderr=subprocess.STDOUT,timeout=timeout)
  txt=log.read_text(encoding='utf-8',errors='replace')
  issues=[line for line in txt.splitlines() if 'SCRIPT ERROR:' in line or 'ERROR:' in line]
  results.append({'task':label,'at':datetime.datetime.now().astimezone().isoformat(),'exit_code':proc.returncode,'errors':issues,'log':log.relative_to(ROOT).as_posix()})
  (ROOT/'reports/public_build.json').write_text(json.dumps(results,ensure_ascii=False,indent=2),encoding='utf-8')
  if proc.returncode or issues:
   print(txt[-5000:]);raise SystemExit(proc.returncode or 1)
  print('PASS '+label,flush=True)
 def godot(label,options):
  if not args.engine:raise SystemExit('Specify --engine or set GODOT_BIN to Godot 4.7.2.')
  run(label,[args.engine,'--path',str(ROOT),'--log-file',str(ROOT/'reports'/f'public_{label}_engine.log'),*options])
 tasks=['demo','import','bake','check','export','audit','package'] if args.task=='all' else [args.task]
 if any(t in tasks for t in ['import','bake','text','check','smoke','restore','export']):
  if not args.engine:raise SystemExit('Specify --engine or set GODOT_BIN to Godot 4.7.2.')
  version=subprocess.check_output([args.engine,'--version'],env=env,text=True).strip()
  if not version.startswith('4.7.2.'):raise SystemExit('Expected Godot 4.7.2, got '+version)
 for task in tasks:
  if task=='demo':run('demo',[sys.executable,str(ROOT/'tools/generate_demo_media.py')])
  elif task=='import':
   godot('licenses',['--headless','--script','res://tools/write_engine_licenses.gd'])
   godot('import',['--headless','--editor','--import'])
  elif task=='bake':
   godot('bake',['--resolution','640x360','--rendering-method','mobile','--rendering-driver','vulkan','--script','res://tools/bake_stream_world.gd'])
   godot('public_text',['--resolution','64x64','--rendering-method','mobile','--rendering-driver','vulkan','--script','res://tools/refresh_public_text.gd'])
  elif task=='text':godot('public_text',['--resolution','64x64','--rendering-method','mobile','--rendering-driver','vulkan','--script','res://tools/refresh_public_text.gd'])
  elif task=='check':
   for name in ['design120_contracts','creative110_items']:
    godot(name,['--headless','--script','res://tests/'+name+'.gd'])
  elif task in ['smoke','restore']:
   fixture=ROOT/'.runtime/public_library_fixture';inbox=fixture/'inbox';library=fixture/'UserMedia'
   inbox.mkdir(parents=True,exist_ok=True)
   shutil.copy2(ROOT/'assets/media/portrait_01.jpg',inbox/'demo.jpg')
   if task=='smoke':
    for attempt in [1,2]:run('import_fixture_'+str(attempt),[sys.executable,str(ROOT/'tools/import_media.py'),str(inbox),'--output',str(library)])
   godot(task,['--resolution','1280x720','--rendering-method','mobile','--','--qa=public_'+('release' if task=='smoke' else 'restore'),'--qa-library='+str(library)])
  elif task=='export':godot('export',['--headless','--export-release','Windows Public',str(ROOT/'builds/windows/XiaojuWorld.exe')])
  elif task=='audit':run('audit',[sys.executable,str(ROOT/'tools/audit_public.py')])
  elif task=='package':package()

def package():
 folder=ROOT/'builds/windows'
 if not (folder/'XiaojuWorld.pck').is_file():raise SystemExit('Export the game before packaging.')
 for name in ['LICENSE','README_怎么玩.md','导入素材.cmd']:shutil.copy2(ROOT/name,folder/name)
 for name in ['LICENSES','tools']:(folder/name).mkdir(exist_ok=True)
 for p in (ROOT/'LICENSES').iterdir():
  if p.is_file():shutil.copy2(p,folder/'LICENSES'/p.name)
 for name in ['import_media.py','requirements-import.txt']:shutil.copy2(ROOT/'tools'/name,folder/'tools'/name)
 (folder/'待导入素材').mkdir(exist_ok=True)
 (folder/'待导入素材/说明.txt').write_text('将有权使用的素材放在这里，再运行“导入素材.cmd”。原文件保留。\n',encoding='utf-8')
 archive=ROOT/'dist'/f'XiaojuWorld-{VERSION}-windows-x86_64.zip'
 with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
  for p in sorted(folder.rglob('*')):
   if p.is_file() and not any(part in ['UserMedia','qa_evidence','logs'] for part in p.relative_to(folder).parts):z.write(p,Path('XiaojuWorld')/p.relative_to(folder))
 with archive.open('rb') as f:digest=hashlib.file_digest(f,'sha256').hexdigest()
 (ROOT/'dist/SHA256SUMS.txt').write_text(digest+'  '+archive.name+'\n',encoding='utf-8')
 with zipfile.ZipFile(archive) as z:
  if z.testzip():raise SystemExit('ZIP CRC verification failed.')
 print(json.dumps({'archive':archive.name,'bytes':archive.stat().st_size,'sha256':digest}))

if __name__=='__main__':main()
