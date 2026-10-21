"""Verify a released Windows game through owned-window SendInput and a passive observer."""
from pathlib import Path
import argparse,ctypes,datetime,hashlib,json,os,subprocess,time,traceback
from ctypes import wintypes as w
from windows_input import Driver,u,process_id,distance

ROOT=Path(__file__).resolve().parents[1]
u.PostMessageW.argtypes=[w.HWND,w.UINT,w.WPARAM,w.LPARAM]
u.PostMessageW.restype=w.BOOL

def main():
 parser=argparse.ArgumentParser(description=__doc__)
 parser.add_argument('--destination',type=Path,default=ROOT/'builds/windows')
 parser.add_argument('--label',required=True)
 args=parser.parse_args();folder=args.destination.resolve();mode='desktop_public_'+args.label
 isolated=ROOT/'.runtime'/mode
 if isolated.exists():raise SystemExit('Use a new label; prior test profiles are preserved.')
 isolated.mkdir(parents=True)
 evidence=folder/'qa_evidence';(evidence/'reports').mkdir(parents=True,exist_ok=True)
 env=os.environ.copy();env.update(APPDATA=str(isolated/'appdata'),LOCALAPPDATA=str(isolated/'local'),TEMP=str(ROOT/'.runtime/temp'),TMP=str(ROOT/'.runtime/temp'))
 try:
  u.SetProcessDpiAwarenessContext.argtypes=[ctypes.c_void_p];u.SetProcessDpiAwarenessContext.restype=w.BOOL
  u.SetProcessDpiAwarenessContext(ctypes.c_void_p(-4))
 except AttributeError:pass
 checks=[];failure=None;child=None;driver=None;saved=None
 try:
  for phase in ['write','read']:
   with (ROOT/'reports'/f'{mode}_{phase}.log').open('w',encoding='utf-8') as output:
    child=subprocess.Popen([str(folder/'XiaojuWorld.exe'),'--resolution','1280x720','--log-file',str(ROOT/'reports'/f'{mode}_{phase}_engine.log'),'--','--qa='+mode],cwd=folder,env=env,stdout=output,stderr=subprocess.STDOUT)
    driver=Driver(child,evidence,mode,checks)
    state=driver.wait(lambda s:s['menu_visible'] and s['sequence']>=3,45);driver.focus()
    driver.check(phase+'_ordinary_controller',not state['program_driven'] and not state['automated_motion'])
    driver.click_control('开始探索' if phase=='write' else '继续上次旅行')
    state=driver.wait(lambda s:s['active_game'] and s['player_enabled'] and not s['transitioning'] and s['on_floor'],60)
    if phase=='write':
     driver.capture('opening')
     for key in ['S','A','D','W']:
      before=driver.snapshot();driver.hold([ord(key)],.55);after=driver.wait(lambda s:s['sequence']>before['sequence'])
      driver.check('keyboard_'+key+'_moves',distance(before['position'],after['position'])>1)
     before=driver.snapshot();driver.hold([0x10,ord('S')],.55);after=driver.wait(lambda s:s['sequence']>before['sequence'])
     driver.check('shift_running',distance(before['position'],after['position'])>3)
     before=driver.wait(lambda s:s['on_floor']);driver.tap(0x20)
     first=driver.wait(lambda s:s['position'][1]>before['position'][1]+.35)
     driver.check('space_jump',True)
     driver.tap(0x20);second=driver.wait(lambda s:s['position'][1]>first['position'][1]+.3)
     driver.check('second_jump',second['position'][1]>first['position'][1]+.3)
     driver.wait(lambda s:s['on_floor'],15)
     driver.tap(ord('B'));state=driver.wait(lambda s:s['modal_visible'])
     driver.check('bag_key_opens_search',any(c['kind']=='line_edit' and '搜索名称' in c['text'] for c in state['controls']))
     driver.tap(0x1B);driver.wait(lambda s:not s['modal_visible'])
     driver.tap(ord('M'));state=driver.wait(lambda s:s['modal_visible'])
     driver.check('map_key_opens_catalog',any(c['kind']=='map_zone' for c in state['controls']))
     driver.capture('map');driver.tap(0x1B);driver.wait(lambda s:not s['modal_visible'])
     before=driver.snapshot();driver.tap(ord('N'))
     driver.wait(lambda s:s['minimap_collapsed']!=before['minimap_collapsed']);driver.check('minimap_toggle',True)
     driver.tap(ord('P'));driver.wait(lambda s:s['photo_mode'])
     before=driver.snapshot();driver.tap(0x7B)
     state=driver.wait(lambda s:s['photo_count']>before['photo_count'] and not s['photo_saving'],25)
     driver.check('photo_saved_from_f12',state['last_photo'].get('saved',False) and state['last_photo'].get('indexed',False))
     if state['photo_mode']:driver.tap(0x1B);driver.wait(lambda s:not s['photo_mode'])
     driver.hold([ord('S')],.4)
     driver.tap(0x74)
     saved=driver.wait(lambda s:len(s['saved_position'])==3 and distance(s['position'],s['saved_position'])<.1)
     driver.check('f5_saves_position',True)
    else:
     driver.check('cold_restore_position',distance(state['position'],saved['position'])<.4)
     driver.check('cold_restore_photo_index',state['photo_count']==saved['photo_count'] and state['photo_count']>=1)
     driver.capture('restored')
    driver.release();driver.guard()
    if process_id(driver.hwnd)!=child.pid:raise RuntimeError('Window ownership changed before close')
    u.PostMessageW(driver.hwnd,0x0010,0,0)
    code=child.wait(timeout=20);driver.check(phase+'_clean_exit',code==0);child=None;driver=None
 except Exception as error:
  failure={'type':type(error).__name__,'message':str(error),'traceback':traceback.format_exc()}
 finally:
  if driver is not None:
   try:driver.release()
   except Exception:pass
  if child is not None and child.poll() is None:child.terminate();child.wait(timeout=15)
 with (folder/'XiaojuWorld.pck').open('rb') as stream:identity=hashlib.file_digest(stream,'sha256').hexdigest()
 report={'passed':failure is None and all(x['passed'] for x in checks),'checks':checks,'failure':failure,'pck_sha256':identity,'at':datetime.datetime.now().astimezone().isoformat(),'scope':'Owned Windows window: ordinary keyboard/mouse, photo, manual save and a new-process restore; no gameplay commands from observer'}
 (ROOT/'reports'/f'{mode}.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
 print(json.dumps({'passed':report['passed'],'checks':len(checks),'failure':failure},ensure_ascii=False))
 return 0 if report['passed'] else 1

if __name__=='__main__':raise SystemExit(main())
