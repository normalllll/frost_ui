"""Native Windows placement acceptance using flutter-ui-automation capture.

Build example/lib/placement_probe.dart first. This dedicated entrypoint disables
startup framework focus; do not substitute the normal application entrypoint.
Only this script writes evidence; the library never persists window data.
"""
import ctypes as c
from ctypes import wintypes as w
import argparse, base64, importlib.util, json, msvcrt, os, re, threading, time, urllib.parse, urllib.request, uuid
from pathlib import Path

parser=argparse.ArgumentParser(description='Owned Windows cold-start placement checks; no desktop input or activation.')
parser.add_argument('--automation-skill',type=Path,required=True)
parser.add_argument('--output',type=Path,required=True,help='A new evidence directory; existing evidence is never replaced.')
args=parser.parse_args()
root=Path(__file__).resolve().parents[3];out=args.output.resolve();out.mkdir(parents=True)
skill=args.automation_skill.resolve()
spec=importlib.util.spec_from_file_location('capture',skill/'scripts/window_capture.py');capture=importlib.util.module_from_spec(spec);spec.loader.exec_module(capture)
class Startup(c.Structure):
    _fields_=[('cb',w.DWORD),('lpReserved',w.LPWSTR),('lpDesktop',w.LPWSTR),('lpTitle',w.LPWSTR),('dwX',w.DWORD),('dwY',w.DWORD),('dwXSize',w.DWORD),('dwYSize',w.DWORD),('dwXCountChars',w.DWORD),('dwYCountChars',w.DWORD),('dwFillAttribute',w.DWORD),('dwFlags',w.DWORD),('wShowWindow',w.WORD),('cbReserved2',w.WORD),('lpReserved2',c.c_void_p),('hStdInput',w.HANDLE),('hStdOutput',w.HANDLE),('hStdError',w.HANDLE)]
class Process(c.Structure):
    _fields_=[('hProcess',w.HANDLE),('hThread',w.HANDLE),('dwProcessId',w.DWORD),('dwThreadId',w.DWORD)]
class Rect(c.Structure):_fields_=[('left',w.LONG),('top',w.LONG),('right',w.LONG),('bottom',w.LONG)]
k=c.WinDLL('kernel32',use_last_error=True);u=c.WinDLL('user32',use_last_error=True)
u.CreateDesktopW.argtypes=[w.LPCWSTR,c.c_void_p,c.c_void_p,w.DWORD,w.DWORD,c.c_void_p];u.CreateDesktopW.restype=w.HANDLE
u.OpenDesktopW.argtypes=[w.LPCWSTR,w.DWORD,w.BOOL,w.DWORD];u.OpenDesktopW.restype=w.HANDLE
u.CloseDesktop.argtypes=[w.HANDLE];u.GetForegroundWindow.restype=w.HWND
u.GetWindowThreadProcessId.argtypes=[w.HWND,c.POINTER(w.DWORD)];u.GetClassNameW.argtypes=[w.HWND,w.LPWSTR,c.c_int]
u.GetWindowRect.argtypes=[w.HWND,c.POINTER(Rect)];u.IsWindowVisible.argtypes=[w.HWND]
u.SetWindowPos.argtypes=[w.HWND,w.HWND,c.c_int,c.c_int,c.c_int,c.c_int,w.UINT]
callback=c.WINFUNCTYPE(w.BOOL,w.HWND,w.LPARAM);u.EnumDesktopWindows.argtypes=[w.HANDLE,callback,w.LPARAM]
k.CreateProcessW.argtypes=[w.LPCWSTR,w.LPWSTR,c.c_void_p,c.c_void_p,w.BOOL,w.DWORD,c.c_void_p,w.LPCWSTR,c.POINTER(Startup),c.POINTER(Process)]
k.WaitForSingleObject.argtypes=[w.HANDLE,w.DWORD];k.CloseHandle.argtypes=[w.HANDLE];k.TerminateProcess.argtypes=[w.HANDLE,w.UINT]
exe=root/'packages/frost_window/example/build/windows/x64/runner/Debug/frost_window_example.exe';report=[]

def run(name,saved=None,background=True):
    desktop_name='Default' if background else 'FrostF5c_'+uuid.uuid4().hex
    desktop=u.OpenDesktopW('Default',0,False,0x1ff) if background else u.CreateDesktopW(desktop_name,None,None,0,0x1ff,None)
    if not desktop:raise c.WinError(c.get_last_error())
    proc=Process();hwnd=None;samples=[];front=[];stop=threading.Event();monitor=None
    try:
        with open(out/f'{name}.log','wb') as log,open(os.devnull,'rb') as stdin:
            for stream in [log,stdin]:os.set_handle_inheritable(msvcrt.get_osfhandle(stream.fileno()),True)
            startup=Startup();startup.cb=c.sizeof(startup);startup.lpDesktop=desktop_name;startup.dwFlags=0x100
            startup.hStdInput=msvcrt.get_osfhandle(stdin.fileno());startup.hStdOutput=startup.hStdError=msvcrt.get_osfhandle(log.fileno())
            args='' if saved is None else ' --placement='+base64.urlsafe_b64encode(json.dumps(saved).encode()).decode()
            if not k.CreateProcessW(str(exe),c.create_unicode_buffer('"'+str(exe)+'"'+args),None,None,True,0x08000000,None,str(exe.parent),c.byref(startup),c.byref(proc)):raise c.WinError(c.get_last_error())
            @callback
            def find(window,_):
                nonlocal hwnd
                pid=w.DWORD();u.GetWindowThreadProcessId(window,c.byref(pid));cls=c.create_unicode_buffer(256);u.GetClassNameW(window,cls,256)
                if pid.value==proc.dwProcessId and cls.value=='FLUTTER_RUNNER_WIN32_WINDOW':hwnd=int(window)
                return True
            def sample():
                if hwnd:
                    rect=Rect();u.GetWindowRect(hwnd,c.byref(rect));item={'visible':bool(u.IsWindowVisible(hwnd)),'rect':[rect.left,rect.top,rect.right,rect.bottom]}
                    if not samples or item!=samples[-1]:samples.append(item)
                pid=w.DWORD();u.GetWindowThreadProcessId(u.GetForegroundWindow(),c.byref(pid));front.append(pid.value==proc.dwProcessId)
            deadline=time.monotonic()+35;uri=None
            while time.monotonic()<deadline:
                u.EnumDesktopWindows(desktop,find,0);sample()
                text=(out/f'{name}.log').read_text(encoding='utf-8',errors='replace');match=re.search(r'(http://127\.0\.0\.1:\d+/[^\s]+/)',text)
                if match and hwnd:uri=match.group(1);break
                if k.WaitForSingleObject(proc.hProcess,50)!=258:raise RuntimeError(text)
            if not uri:raise TimeoutError('Missing VM service/runner HWND')
            def observe():
                while not stop.wait(.005):sample()
            monitor=threading.Thread(target=observe,daemon=True);monitor.start()
            def rpc(method,**args):
                with urllib.request.urlopen(uri+method+'?'+urllib.parse.urlencode(args),timeout=20) as response:data=json.load(response)
                if 'error' in data:raise RuntimeError(data)
                return data['result']
            while time.monotonic()<deadline:
                isolates=rpc('getVM')['isolates']
                if isolates:break
                time.sleep(.05)
            else:raise TimeoutError('Missing main isolate')
            isolate=isolates[0]['id']
            def command(action):return rpc('ext.frostWindowPlacementProbe',isolateId=isolate,command=action)
            while time.monotonic()<deadline:
                try:prepared=command('snapshot');break
                except Exception:time.sleep(.1)
            else:raise TimeoutError('Missing probe/first frame')
            assert not any(s['visible'] for s in samples),'Runner showed before Dart applied placement'
            if background:
                assert not (saved and saved.get('maximized'))
                # Establish background Z-order while hidden; show() uses the
                # documented SW_SHOWNOACTIVATE path. Never raise or focus it.
                assert u.SetWindowPos(hwnd,1,0,0,0,0,0x213)
            command('show');time.sleep(.35);result=command('snapshot');sample()
            actual=result['placement'];expected=result['expected']
            tolerance=.5/actual['displayScale']+1e-6
            assert all(abs(a-b)<=tolerance for a,b in zip(actual['rect'],expected['rect'])),(actual,expected)
            assert actual['maximized']==expected['maximized'],(actual,expected)
            initial=list(samples);visible=[s['rect'] for s in initial if s['visible']]
            assert visible and all(r==visible[-1] for r in visible),(name,visible)
            captures=[]
            def take(label):
                # Only this app's HWND/PID, never desktop capture. Exact marker
                # verification rejects stale/blank native presentation.
                metadata=capture.capture_png(out/f'{label}.png',hwnd=hwnd,process_id=proc.dwProcessId,helper=skill/'examples/capture_lab/build/windows/x64/runner/Debug/window_capture.exe',backend='wgc',probe=result['probe'])
                captures.append(metadata)
            if background:take(name)
            if name=='first':
                command('move');time.sleep(.35);result=command('snapshot');sample()
                assert abs(result['placement']['rect'][0]-70)<1 and abs(result['placement']['rect'][1]-65)<1,result
                take('moved')
            maximized_snapshot=None
            if not background:
                maximized_snapshot=result
                assert result['maximized'] is True
                command('minimize');time.sleep(.35);result=command('snapshot')
                assert result['minimized'] is True and result['placement']['maximized'] is True,result
                assert result['placement']['rect']==maximized_snapshot['placement']['rect']
            record={'name':name,'pid':proc.dwProcessId,'hwnd':hwnd,'state':result,'maximizedSnapshot':maximized_snapshot,'initialSamples':initial,'samples':samples,'firstVisibleBoundsStable':True,'foregroundSamples':sum(front),'foregroundObservations':len(front),'captures':captures}
            report.append(record);(out/'report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
            print(name,json.dumps({'placement':result['placement'],'adjustments':result['adjustments'],'captures':[x['presentationVerified'] for x in captures],'foregroundSamples':sum(front),'evidence':str(out)}),flush=True)
            return result['placement']
    finally:
        stop.set()
        if monitor:monitor.join(timeout=2)
        if proc.hProcess:k.TerminateProcess(proc.hProcess,0);k.WaitForSingleObject(proc.hProcess,10000)
        for handle in [proc.hThread,proc.hProcess]:
            if handle:k.CloseHandle(handle)
        u.CloseDesktop(desktop)

saved=run('first')
run('restored',saved)
run('missing-display',{**saved,'displayId':'intentionally-removed-display'})
run('maximized',{**saved,'maximized':True},background=False)
