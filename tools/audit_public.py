"""Audit the distributable source tree and the registered public assets."""
from pathlib import Path
import hashlib,json,re,subprocess,sys
ROOT=Path(__file__).resolve().parents[1]
SKIP={'.git','.godot','.runtime','reports','builds','dist','UserMedia','待导入素材','__pycache__'}
TEXT={'.gd','.py','.json','.md','.txt','.godot','.cfg','.yml','.yaml','.cmd','.tres','.tscn','.gdshader','.import'}
PATTERNS={
 'private_key':re.compile(r'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----'),
 'github_credential':re.compile(r'\b(?:gh[pousr]_[A-Za-z0-9]{25,}|github_pat_[A-Za-z0-9_]{30,})\b'),
 'personal_absolute_path':re.compile(r'[A-Z]:[\\/]+(?:Users|xiaojuWorld|微博|edge|codex)',re.I),
 'credential_in_url':re.compile(r'https?://[^\s/:@]+:[^\s/@]+@'),
}
def digest(p):
 with p.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
def main():
 errors=[];files=[]
 for p in ROOT.rglob('*'):
  if not p.is_file() or any(s in SKIP for s in p.relative_to(ROOT).parts):continue
  rel=p.relative_to(ROOT).as_posix();files.append(rel)
  if p.stat().st_size>100*1024**2:errors.append(rel+': exceeds GitHub 100 MiB limit')
  if p.suffix in TEXT and p.name!='audit_public.py':
   txt=p.read_text(encoding='utf-8-sig',errors='replace')
   for name,pattern in PATTERNS.items():
    if pattern.search(txt):errors.append(rel+': '+name)
  if any(s in {'source_media','checkpoints','review_packages','qa_evidence'} for s in p.relative_to(ROOT).parts):errors.append(rel+': private/internal directory')
 forbidden_metadata={'source_caption','source_local_path','source_path','source_copy','original_media_url','original_local_path'}
 def inspect_metadata(value,path):
  if isinstance(value,dict):
   for key,item in value.items():
    if key in forbidden_metadata:errors.append(path+': private raw media metadata '+key)
    inspect_metadata(item,path)
  elif isinstance(value,list):
   for item in value:inspect_metadata(item,path)
  elif value=='local-only path omitted':errors.append(path+': unresolved sanitized path')
 for p in (ROOT/'data').glob('*.json'):inspect_metadata(json.loads(p.read_text(encoding='utf-8-sig')),p.relative_to(ROOT).as_posix())
 manifest=json.loads((ROOT/'data/public_asset_manifest.json').read_text(encoding='utf-8'))
 registered={item['path']:item for item in manifest['assets']}
 for rel,item in registered.items():
  p=ROOT/rel
  if not p.is_file() or digest(p)!=item['sha256']:errors.append(rel+': public asset hash mismatch')
 for p in (ROOT/'assets/media').rglob('*'):
  if p.is_file() and p.suffix not in ['.import','.uid'] and p.relative_to(ROOT).as_posix() not in registered:errors.append(str(p.relative_to(ROOT))+': unregistered media')
 for name in ['assets.json','programs.json','life_media_bay.json']:
  records=json.loads((ROOT/'data'/name).read_text(encoding='utf-8'))
  for item in records:
   if item.get('rights')!='MIT':errors.append(name+': non-public media record')
   for key in ['runtime_path','video','audio','poster']:
    if item.get(key) and not (ROOT/item[key]).is_file():errors.append(name+': missing '+item[key])
 report={'ok':not errors,'source_files':len(files),'registered_public_assets':len(registered),'errors':errors}
 (ROOT/'reports').mkdir(exist_ok=True)
 (ROOT/'reports/public_audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
 print(json.dumps(report,ensure_ascii=False))
 return 0 if not errors else 1
if __name__=='__main__':raise SystemExit(main())
