"""One explicitly authorized e337478 simulator comparison; no execution by import."""
import argparse,hashlib,json,os,signal,subprocess,sys,time
from pathlib import Path
HERE=Path(__file__).resolve().parent
BASE=HERE.parent
sys.path.insert(0,str(BASE.parent))
from setup_native_fixture import setup
ROOT=Path('/private/tmp/networkkit-f6-runtime179')
SCOPE='e33747857c40b913a9f3e8af23df9f587300c647'
SHARED=[BASE.parent/'NativeState.swift',BASE.parent/'NativeValues.swift']+[BASE/n for n in ['Values.swift','State.swift','ListenerPeer.swift','QUICPeer.swift','StartupCoordinator.swift','DatagramRouteState.swift']]+[HERE/'RuntimeMain.swift',HERE/'RuntimeState.swift']

def main(action,candidate,cases,reason,final):
    os.umask(0o077);ROOT.mkdir(mode=0o700,exist_ok=True)
    path=ROOT/'runtime-ledger.json'
    d=json.loads(path.read_text()) if path.exists() else dict(scope_commit=SCOPE,compiler=[],pure=[],native=[],sessions=0,corrections=0,final_cases=[],simulator=None,fixture=None,start=None,closed=False)
    assert d['scope_commit']==SCOPE
    def save():path.write_text(json.dumps(d,indent=2)+'\n')
    def sources():return SHARED+([HERE/'ModernQUICProbe.swift'] if candidate=='modern' else [])
    def hashes():return {str(p.relative_to(BASE.parent)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sources()+[HERE/'run_runtime.py',BASE.parent/'setup_native_fixture.py']}
    def swift_hashes():return {str(p.relative_to(BASE.parent)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sources()}
    def execute(cmd,seconds,log,env=None):
        with log.open('w') as out:
            child=subprocess.Popen(cmd,stdout=out,stderr=subprocess.STDOUT,env=env,start_new_session=True)
            forced=False
            try:code=child.wait(timeout=seconds)
            except subprocess.TimeoutExpired:
                forced=True;os.killpg(child.pid,signal.SIGTERM)
                try:child.wait(timeout=1)
                except subprocess.TimeoutExpired:os.killpg(child.pid,signal.SIGKILL);child.wait(timeout=1)
                code=-999
        return code,forced
    if action=='cleanup':
        import shutil
        if (ROOT/'fixture').exists():shutil.rmtree(ROOT/'fixture')
        sim=d.get('simulator')
        if sim and sim.get('device'):
            device=sim['device']
            sim['shutdown_exit']=execute(['xcrun','simctl','shutdown',device],30,ROOT/'simulator-shutdown.log')[0]
            sim['delete_exit']=execute(['xcrun','simctl','delete',device],30,ROOT/'simulator-delete.log')[0]
            actual=json.loads(subprocess.check_output(['xcrun','simctl','list','devices','-j'],text=True))
            sim['absence_verified']=not any(v['udid']==device for group in actual['devices'].values() for v in group)
        d.update(closed=True,cleanup='owned fixture removed; simulator cleanup outcomes recorded; not secure erasure');save();return
    if d['closed']:raise RuntimeError('Closed runtime; no reset/reopen')
    if action=='build':
        previous=[e for e in d['compiler'] if e['candidate']==candidate]
        if len(d['compiler'])>=6 or (previous and not reason):raise RuntimeError('Compiler envelope/reason')
        if candidate=='modern' and not (d.get('simulator') or {}).get('booted'):raise RuntimeError('Simulator route first')
        e=dict(slot=len(d['compiler'])+1,candidate=candidate,sources=hashes(),status='started',reason=reason);d['compiler'].append(e);save()
        sdk=subprocess.check_output(['xcrun','--sdk','iphonesimulator','--show-sdk-path'],text=True).strip()
        cmd=['xcrun','swiftc','-swift-version','6','-warnings-as-errors','-sdk',sdk,'-target','x86_64-apple-ios26.2-simulator','-parse-as-library','-j','1']
        if candidate=='modern':cmd+=['-D','MODERN_QUIC']
        cmd += [*[str(p) for p in sources()],'-o',str(ROOT/candidate)]
        e['command']=[v.replace(str(BASE.parent),'<tool>') for v in cmd];save()
        code,forced=execute(cmd,120,ROOT/f'compiler-{e["slot"]}.log');e.update(status='pass' if code==0 else 'fail',exit_code=code,forced_teardown=forced);save();print('compiler',candidate,e['slot'],e['status'],flush=True);return
    if action=='boot':
        if d['simulator'] is not None:raise RuntimeError('One device/boot quota')
        if not any(e['candidate']=='legacy' and e['status']=='pass' for e in d['compiler']):raise RuntimeError('Legacy build first')
        runtimes=json.loads(subprocess.check_output(['xcrun','simctl','list','runtimes','-j'],text=True))
        runtime=next(r for r in runtimes['runtimes'] if r['name']=='iOS 26.2' and r['isAvailable'] and 'x86_64' in r['supportedArchitectures'])
        dtype=next(t['identifier'] for t in runtime['supportedDeviceTypes'] if t['name']=='iPhone 16')
        d['simulator']={'status':'creating','runtime':runtime['identifier'],'architecture':'x86_64','boot_attempts':0};save()
        code,forced=execute(['xcrun','simctl','create','NetworkKit-F6-RuntimeComparison',dtype,runtime['identifier']],30,ROOT/'simulator-create.log')
        if code!=0:raise RuntimeError('Temporary simulator creation failed; no fallback')
        device=(ROOT/'simulator-create.log').read_text().strip();d['simulator'].update(device=device,status='booting',boot_attempts=1);save()
        started=time.monotonic();code,forced=execute(['xcrun','simctl','boot',device],20,ROOT/'simulator-boot.log')
        if code==0:code,forced=execute(['xcrun','simctl','bootstatus',device,'-b'],max(1,180-(time.monotonic()-started)),ROOT/'simulator-bootstatus.log')
        d['simulator'].update(status='ready' if code==0 else 'failed',booted=code==0,boot_exit=code,forced_teardown=forced,elapsed_seconds=round(time.monotonic()-started,3));save();print('temporary simulator',d['simulator']['status'],flush=True);return
    if action=='setup':
        if d['fixture'] is not None:raise RuntimeError('Fixture pair quota')
        if not (d.get('simulator') or {}).get('executable_route'):raise RuntimeError('Executable route first')
        d['fixture']={'status':'started','pairs':2};save();d['fixture']=setup(ROOT/'fixture',['server-current']);d['fixture']['status']='complete';save();print('fixture: two pairs',flush=True);return
    if action not in ['pure','native'] or not cases:raise RuntimeError('Explicit inputs required')
    if not (d.get('simulator') or {}).get('booted'):raise RuntimeError('Simulator boot required')
    built=[e for e in d['compiler'] if e['candidate']==candidate]
    if not built or built[-1]['status']!='pass' or built[-1]['sources']!=hashes():raise RuntimeError('Matching successful build required')
    chosen=cases.split(',');allowed=[f'V{i:02}' for i in range(1,7)] if action=='pure' else ([f'L{i:02}' for i in range(1,6)] if candidate=='legacy' else [f'M{i:02}' for i in range(1,5)])
    if len(chosen)!=len(set(chosen)) or any(c not in allowed for c in chosen):raise RuntimeError('Exact inputs only')
    if action=='pure' and len(d['pure'])+len(chosen)>12:raise RuntimeError('Pure quota')
    if action=='native':
        if {e['case'] for e in d['pure'] if e['status']=='pass'}!={f'V{i:02}' for i in range(1,7)}:raise RuntimeError('Six shared Swift inputs required')
        if (d['fixture'] or {}).get('status')!='complete' or d['sessions']+len(chosen)>24:raise RuntimeError('Fixture/session quota')
        if d['start'] is None:d['start']=time.monotonic();save()
    group_start=time.monotonic()
    for c in chosen:
        if time.monotonic()-group_start>240:raise RuntimeError('Batch deadline')
        prev=[e for e in d[action] if e['case']==c];kind='initial'
        if final:
            if action!='native' or not prev or c in d['final_cases'] or prev[-1]['swift_sources']==swift_hashes():raise RuntimeError('Changed-source final once')
            d['final_cases'].append(c);kind='final'
        elif prev:
            if prev[-1]['status']=='pass' or not reason or prev[-1]['sources']==hashes():raise RuntimeError('Failed input/source change/reason required')
            kind='correction'
            if action=='native':
                if d['corrections']>=6:raise RuntimeError('Correction quota')
                d['corrections']+=1
        if action=='native':
            if time.monotonic()-d['start']>1200:raise RuntimeError('Native window')
            current=[e for e in d['native'] if e['candidate']==candidate and e['swift_sources']==swift_hashes()]
            anchor='L01' if candidate=='legacy' else 'M01'
            if c in ['L02','L03','M02','M03'] and not any(e['case']==anchor and e.get('observation',{}).get('observations',{}).get('positiveReady')=='true' and e.get('observation',{}).get('observations',{}).get('positiveDatagram')=='true' for e in current):raise RuntimeError('Positive route prerequisites')
            if c=='L04' and not any(e['case'] in ['L01','L02','L03'] and e['status']=='pass' for e in current):raise RuntimeError('Direct complete empty control required')
            if c=='L05' and not any(e['case']=='L04' and e['status']=='pass' for e in current):raise RuntimeError('Complete group required')
            if c=='M04' and not any(e['case'] in ['M01','M02','M03'] and e['status']=='pass' for e in current):raise RuntimeError('Modern complete empty control required')
            d['sessions']+=1
        e=dict(case=c,candidate=candidate,slot=len(d[action])+1,kind=kind,status='started',sources=hashes(),swift_sources=swift_hashes(),reason=reason);d[action].append(e);save()
        cmd=['xcrun','simctl','spawn',d['simulator']['device'],str(ROOT/candidate),'--'+action,c]
        env={**os.environ,'SIMCTL_CHILD_F6_RESEARCH_FIXTURE':str(ROOT/'fixture')};started=time.monotonic()
        log=ROOT/f'{action}-{c}-{e["slot"]}.log';code,forced=execute(cmd,5 if action=='pure' else 20,log,env)
        e.update(status='pass' if code==0 else 'fail',exit_code=code,forced_teardown=forced,elapsed_seconds=round(time.monotonic()-started,3))
        try:
            records=[json.loads(s) for s in log.read_text().splitlines() if s.startswith('{')];e['observation']=records[-1]
            if e['observation'].get('status')!='pass':e['status']='fail'
        except (ValueError,IndexError):e['status']='fail'
        if action=='pure':
            if 'observation' in e:d['simulator']['executable_route']=True
            else:d['simulator']['executable_route']=False
        save();print(action,c,e['status'],flush=True)
        if action=='pure' and not d['simulator'].get('executable_route'):raise RuntimeError('Standalone executable route failed; stop, no host/signing fallback')
        if action=='native' and c in ['L01','M01'] and e['status']!='pass' and e.get('observation',{}).get('observations',{}).get('positiveDatagram')!='true':break

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--action',choices=['build','boot','pure','setup','native','cleanup'],required=True);p.add_argument('--candidate',choices=['legacy','modern'],default='legacy');p.add_argument('--cases');p.add_argument('--reason');p.add_argument('--final',action='store_true');a=p.parse_args();main(a.action,a.candidate,a.cases,a.reason,a.final)
