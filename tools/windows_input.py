"""Exercise an owned game window via Win32 SendInput; observer never drives gameplay."""
from pathlib import Path
from ctypes import wintypes as w
import argparse, ctypes, hashlib, json, math, os, shutil, subprocess, time, traceback

ROOT=Path(__file__).resolve().parents[1]
# Use the real GUI binary directly so the owned child PID is the window PID.
ENGINE=Path(os.environ.get('GODOT_BIN','godot'))
u=ctypes.WinDLL('user32',use_last_error=True)
ULONG_PTR=ctypes.c_size_t
class Mouse(ctypes.Structure):
    _fields_=[('dx',w.LONG),('dy',w.LONG),('mouseData',w.DWORD),('dwFlags',w.DWORD),('time',w.DWORD),('dwExtraInfo',ULONG_PTR)]
class Key(ctypes.Structure):
    _fields_=[('wVk',w.WORD),('wScan',w.WORD),('dwFlags',w.DWORD),('time',w.DWORD),('dwExtraInfo',ULONG_PTR)]
class Hardware(ctypes.Structure):
    _fields_=[('uMsg',w.DWORD),('wParamL',w.WORD),('wParamH',w.WORD)]
class Payload(ctypes.Union):
    _fields_=[('mi',Mouse),('ki',Key),('hi',Hardware)]
class Input(ctypes.Structure):
    _anonymous_=('payload',)
    _fields_=[('type',w.DWORD),('payload',Payload)]
u.SendInput.argtypes=[w.UINT,ctypes.POINTER(Input),ctypes.c_int];u.SendInput.restype=w.UINT
u.GetForegroundWindow.restype=w.HWND
u.GetWindowThreadProcessId.argtypes=[w.HWND,ctypes.POINTER(w.DWORD)];u.GetWindowThreadProcessId.restype=w.DWORD
u.IsWindowVisible.argtypes=[w.HWND];u.IsWindowVisible.restype=w.BOOL
u.SetForegroundWindow.argtypes=[w.HWND];u.SetForegroundWindow.restype=w.BOOL
u.ShowWindow.argtypes=[w.HWND,ctypes.c_int];u.ShowWindow.restype=w.BOOL
u.SetWindowPos.argtypes=[w.HWND,w.HWND,ctypes.c_int,ctypes.c_int,ctypes.c_int,ctypes.c_int,w.UINT];u.SetWindowPos.restype=w.BOOL
u.GetClientRect.argtypes=[w.HWND,ctypes.POINTER(w.RECT)];u.GetClientRect.restype=w.BOOL
u.ClientToScreen.argtypes=[w.HWND,ctypes.POINTER(w.POINT)];u.ClientToScreen.restype=w.BOOL
u.SetCursorPos.argtypes=[ctypes.c_int,ctypes.c_int];u.SetCursorPos.restype=w.BOOL
u.GetCursorPos.argtypes=[ctypes.POINTER(w.POINT)];u.GetCursorPos.restype=w.BOOL
u.WindowFromPoint.argtypes=[w.POINT];u.WindowFromPoint.restype=w.HWND
u.GetSystemMetrics.argtypes=[ctypes.c_int];u.GetSystemMetrics.restype=ctypes.c_int
CALLBACK=ctypes.WINFUNCTYPE(w.BOOL,w.HWND,w.LPARAM)
u.EnumWindows.argtypes=[CALLBACK,w.LPARAM];u.EnumWindows.restype=w.BOOL
u.MapVirtualKeyW.argtypes=[w.UINT,w.UINT];u.MapVirtualKeyW.restype=w.UINT
u.AttachThreadInput.argtypes=[w.DWORD,w.DWORD,w.BOOL];u.AttachThreadInput.restype=w.BOOL
u.SetFocus.argtypes=[w.HWND];u.SetFocus.restype=w.HWND
k=ctypes.WinDLL('kernel32',use_last_error=True)
k.GetCurrentThreadId.restype=w.DWORD

def process_id(hwnd):
    pid=w.DWORD();u.GetWindowThreadProcessId(hwnd,ctypes.byref(pid));return pid.value

class Driver:
    def __init__(self,child,folder,mode,checks):
        self.child=child;self.folder=folder;self.mode=mode;self.checks=checks;self.hwnd=None;self.down=set()
        self.live=folder/'reports'/f'{mode}_live.json'
    def snapshot(self):
        try:
            item=json.loads(self.live.read_text(encoding='utf-8'))
            return item if item.get('pid')==self.child.pid else None
        except (OSError,ValueError):return None
    def wait(self,predicate,timeout=15):
        end=time.monotonic()+timeout
        while time.monotonic()<end:
            if self.child.poll() is not None:raise RuntimeError(f'Game exited early: {self.child.returncode}')
            item=self.snapshot()
            if item is not None and predicate(item):return item
            time.sleep(.05)
        raise TimeoutError(f'Observer condition timed out: {self.snapshot()}')
    def focus(self):
        found=[]
        @CALLBACK
        def visit(hwnd,_):
            if process_id(hwnd)==self.child.pid and u.IsWindowVisible(hwnd):found.append(hwnd)
            return True
        u.EnumWindows(visit,0)
        if not found:raise RuntimeError('No visible window belonging to the owned game child')
        self.hwnd=found[0]
        # Keep only this disposable test window above existing topmost applications.
        if process_id(self.hwnd)!=self.child.pid:raise RuntimeError('Owned window identity changed')
        if not u.SetWindowPos(self.hwnd,w.HWND(-1),0,0,0,0,0x0001|0x0002):raise ctypes.WinError(ctypes.get_last_error())
        for attempt in range(8):
            u.ShowWindow(self.hwnd,9);u.SetForegroundWindow(self.hwnd);time.sleep(.25)
            if process_id(u.GetForegroundWindow())==self.child.pid:return
        # Coordinate thread focus only; send no keyboard/mouse events until guard passes.
        # All queue links are immediately detached, including on errors.
        caller=k.GetCurrentThreadId();pid=w.DWORD()
        foreground=u.GetWindowThreadProcessId(u.GetForegroundWindow(),ctypes.byref(pid))
        owner=u.GetWindowThreadProcessId(self.hwnd,ctypes.byref(pid));attached=[]
        try:
            for thread in dict.fromkeys([foreground,owner]):
                if thread and thread!=caller and u.AttachThreadInput(caller,thread,True):attached.append(thread)
            u.ShowWindow(self.hwnd,9);u.SetForegroundWindow(self.hwnd);u.SetFocus(self.hwnd)
        finally:
            for thread in reversed(attached):u.AttachThreadInput(caller,thread,False)
        time.sleep(.25)
        self.guard()
    def guard(self):
        if self.child.poll() is not None or process_id(u.GetForegroundWindow())!=self.child.pid:
            raise RuntimeError('Input stopped: foreground window no longer belongs to the owned game')
    def send(self,item,release=False):
        if not release:self.guard()
        if u.SendInput(1,ctypes.byref(item),ctypes.sizeof(Input))!=1:raise ctypes.WinError(ctypes.get_last_error())
    def key(self,vk,up=False):
        scan=u.MapVirtualKeyW(vk,0)
        item=Input(type=1);item.ki=Key(0,scan,0x0008|(0x0002 if up else 0),0,0)
        self.send(item,release=up)
        if up:self.down.discard(vk)
        else:self.down.add(vk)
    def hold(self,keys,seconds):
        try:
            for vk in keys:self.key(vk)
            end=time.monotonic()+seconds
            while time.monotonic()<end:self.guard();time.sleep(.025)
        finally:
            for vk in reversed(keys):
                if vk in self.down:self.key(vk,True)
        time.sleep(.25)
    def tap(self,vk):self.hold([vk],.08)
    def approach(self,target):
        end=time.monotonic()+12
        while time.monotonic()<end:
            state=self.snapshot();dx=target[0]-state['position'][0];dz=target[2]-state['position'][2]
            if math.hypot(dx,dz)<1.5:return state
            # Map the observed world direction to the ordinary controller's physical keys.
            c,s=math.cos(state['yaw']),math.sin(state['yaw']);lx=c*dx-s*dz;lz=s*dx+c*dz;keys=[]
            if abs(lx)>.6:keys.append(ord('D' if lx>0 else 'A'))
            if abs(lz)>.6:keys.append(ord('S' if lz>0 else 'W'))
            before=state['sequence'];self.hold(keys,.18);self.wait(lambda item:item['sequence']>before)
        raise TimeoutError('Ordinary keyboard approach did not reach the observed station stamp')
    def mouse(self,flags,dx=0,dy=0,data=0):
        item=Input(type=0);item.mi=Mouse(dx,dy,data,flags,0,0);self.send(item)
    def click_control(self,text,kind='button'):
        state=self.wait(lambda s:any(c['text']==text and c['kind']==kind and not c.get('disabled',False) for c in s['controls']))
        c=next(c for c in state['controls'] if c['text']==text and c['kind']==kind and not c.get('disabled',False))
        point=c.get('center') or [c['rect'][0]+c['rect'][2]/2,c['rect'][1]+c['rect'][3]/2]
        # Wait without sending input while Windows finishes positioning a new window.
        until=time.monotonic()+5
        while True:
            self.guard();rect=w.RECT()
            if not u.GetClientRect(self.hwnd,ctypes.byref(rect)):raise ctypes.WinError(ctypes.get_last_error())
            x=round(point[0]/state['viewport_size'][0]*(rect.right-rect.left));y=round(point[1]/state['viewport_size'][1]*(rect.bottom-rect.top))
            if not 0<=x<rect.right or not 0<=y<rect.bottom:raise RuntimeError('UI control is outside the visible client area')
            screen=w.POINT(x,y);u.ClientToScreen(self.hwnd,ctypes.byref(screen))
            if process_id(u.WindowFromPoint(screen))==self.child.pid:break
            if time.monotonic()>=until:raise RuntimeError('Input stopped: UI target remains covered by another window')
            time.sleep(.1)
        # Probe absolute virtual-desktop mapping before any button event. Then send
        # move/down/up together: Windows keeps this packet contiguous in its queue.
        left,top=u.GetSystemMetrics(76),u.GetSystemMetrics(77)
        width,height=u.GetSystemMetrics(78),u.GetSystemMetrics(79)
        if width<=0 or height<=0:raise RuntimeError('No valid virtual desktop extent')
        ax=round((screen.x-left+.5)*65536/width);ay=round((screen.y-top+.5)*65536/height)
        if not 0<=ax<=65535 or not 0<=ay<=65535:raise RuntimeError('UI target outside virtual desktop')
        movement=0x0001|0x8000|0x4000|0x2000
        hover=None;until=time.monotonic()+4.0
        while time.monotonic()<until:
            self.guard()
            if process_id(u.WindowFromPoint(screen))!=self.child.pid:raise RuntimeError('Input stopped: target ownership changed while probing cursor')
            probe_sequence=(self.snapshot() or {}).get('sequence',-1)
            self.mouse(movement,ax,ay);time.sleep(.18)
            # A just-focused window can still publish its pre-move snapshot.
            # Never turn that stale cursor into a corrective mouse movement.
            candidate=self.wait(lambda item:item.get('sequence',-1)>probe_sequence,min(2.0,max(.2,until-time.monotonic())))
            cursor=w.POINT()
            if not u.GetCursorPos(ctypes.byref(cursor)):raise ctypes.WinError(ctypes.get_last_error())
            if candidate is not None and math.hypot(candidate['cursor_viewport'][0]-point[0],candidate['cursor_viewport'][1]-point[1])<4 and math.hypot(cursor.x-screen.x,cursor.y-screen.y)<3:
                hover=candidate;break
            # Window decorations / canvas letterboxing can offset client-to-viewport
            # scaling. Calibrate with the read-only in-game pointer observation;
            # no click is sent until both coordinate and ownership guards pass.
            if candidate is not None and math.hypot(cursor.x-screen.x,cursor.y-screen.y)<3:
                screen.x+=round((point[0]-candidate['cursor_viewport'][0])*(rect.right-rect.left)/state['viewport_size'][0])
                screen.y+=round((point[1]-candidate['cursor_viewport'][1])*(rect.bottom-rect.top)/state['viewport_size'][1])
                ax=round((screen.x-left+.5)*65536/width);ay=round((screen.y-top+.5)*65536/height)
                if not 0<=ax<=65535 or not 0<=ay<=65535:raise RuntimeError('Calibrated UI target outside virtual desktop')
        if hover is None:raise RuntimeError('Input stopped: bounded cursor probe did not settle on owned UI target')
        print('UI_CURSOR',text,{'target':point,'actual':hover['cursor_viewport'],'client':[rect.right,rect.bottom]},flush=True)
        cursor=w.POINT()
        if not u.GetCursorPos(ctypes.byref(cursor)):raise ctypes.WinError(ctypes.get_last_error())
        if math.hypot(cursor.x-screen.x,cursor.y-screen.y)>3:
            raise RuntimeError('Input stopped: pointer moved after the UI-coordinate probe')
        if process_id(u.WindowFromPoint(screen))!=self.child.pid:raise RuntimeError('Input stopped: UI target ownership changed')
        self.guard()
        packet=(Input*3)()
        for index,flags in enumerate([movement,0x0002,0x0004]):
            packet[index].type=0;packet[index].mi=Mouse(ax if index==0 else 0,ay if index==0 else 0,0,flags,0,0)
        sent=u.SendInput(3,packet,ctypes.sizeof(Input))
        if sent!=3:
            release=Input(type=0);release.mi=Mouse(0,0,0,0x0004,0,0);self.send(release,release=True)
            raise ctypes.WinError(ctypes.get_last_error())
        time.sleep(.25)
    def check(self,name,ok,details=None):
        self.checks.append({'test':name,'passed':bool(ok),'details':details or {}})
        print(name,bool(ok),flush=True)
        if not ok:raise AssertionError(name)
    def capture(self,name):
        request=self.folder/'reports'/f'{self.mode}_request.json'
        request.write_text(json.dumps({'id':name,'action':'capture','pid':self.child.pid}),encoding='utf-8')
        state=self.wait(lambda s:s['last_capture'].get('id')==name)
        self.check('capture_'+name,state['last_capture']['ok'],{key:state[key] for key in ['position','yaw','pitch','zoom','player_enabled','on_floor']})
        return self.folder/'screenshots'/state['last_capture']['path']
    def release(self):
        for vk in list(self.down):self.key(vk,True)

def distance(a,b):return math.hypot(a[0]-b[0],a[2]-b[2])
