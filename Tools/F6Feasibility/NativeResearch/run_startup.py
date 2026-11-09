"""Explicit 3bffb74 startup-only experiment. Never executes on import/default."""
import argparse,hashlib,json,os,signal,subprocess,sys,time
from pathlib import Path
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE.parent))
from setup_native_fixture import setup
ROOT=Path('/private/tmp/networkkit-f6-startup179')
SCOPE='3bffb74d71b1306d3426901634f120663e0eb0e9'
SOURCES=[HERE.parent/'NativeState.swift',HERE.parent/'NativeValues.swift']+[HERE/n for n in ['Values.swift','State.swift','ListenerPeer.swift','QUICPeer.swift','StartupCoordinator.swift','StartupMain.swift']]

def main(action,cases,reason,final):
    os.umask(0o077);ROOT.mkdir(mode=0o700,exist_ok=True)
    path=ROOT/'startup-ledger.json'
    d=json.loads(path.read_text()) if path.exists() else dict(scope_commit=SCOPE,compiler=[],pure=[],native=[],sessions=0,corrections=0,final_cases=[],fixture=None,start=None,closed=False)
    assert d['scope_commit']==SCOPE
    def save():path.write_text(json.dumps(d,indent=2)+'\n')
    def hashes():return {str(p.relative_to(HERE.parent)):hashlib.sha256(p.read_bytes()).hexdigest() for p in SOURCES+[HERE/'run_startup.py',HERE.parent/'setup_native_fixture.py']}
    def swift_hashes():return {str(p.relative_to(HERE.parent)):hashlib.sha256(p.read_bytes()).hexdigest() for p in SOURCES}
    def execute(command,limit,log,env=None):
        with log.open('w') as out:
            child=subprocess.Popen(command,stdout=out,stderr=subprocess.STDOUT,env=env,start_new_session=True)
            forced=False
            try:code=child.wait(timeout=limit)
            except subprocess.TimeoutExpired:
                forced=True;os.killpg(child.pid,signal.SIGTERM)
                try:child.wait(timeout=1)
                except subprocess.TimeoutExpired:os.killpg(child.pid,signal.SIGKILL);child.wait(timeout=1)
                code=-999
            return code,forced
    if action=='cleanup':
        import shutil
        if (ROOT/'fixture').exists():shutil.rmtree(ROOT/'fixture')
        d.update(closed=True,cleanup='owned fixture directory absent; ordinary removal, not secure erasure');save();return
    if d['closed']:raise RuntimeError('Closed scope; no reset/reopen')
    if action=='build':
        if len(d['compiler'])>=4 or (d['compiler'] and not reason):raise RuntimeError('Compiler quota/reason')
        e=dict(slot=len(d['compiler'])+1,status='started',reason=reason,sources=hashes());d['compiler'].append(e);save()
        sdk=subprocess.check_output(['xcrun','--sdk','macosx','--show-sdk-path'],text=True).strip()
        command=['xcrun','swiftc','-swift-version','6','-warnings-as-errors','-sdk',sdk,'-target','x86_64-apple-macosx15.0','-parse-as-library','-j','1',*[str(p) for p in SOURCES],'-o',str(ROOT/'startup179')]
        e['command']=[x.replace(str(HERE.parent),'<tool>') for x in command];save()
        code,forced=execute(command,120,ROOT/f'compiler-{e["slot"]}.log');e.update(status='pass' if code==0 else 'fail',exit_code=code,forced_teardown=forced);save();print('compiler',e['slot'],e['status'],flush=True);return
    if action=='setup':
        if d['fixture'] is not None:raise RuntimeError('Pair quota consumed')
        d['fixture']={'status':'started','pairs':2};save();d['fixture']=setup(ROOT/'fixture',['server-current']);d['fixture']['status']='complete';save();print('fixture: two pairs',flush=True);return
    if action not in ['pure','native'] or not cases:raise RuntimeError('Explicit inputs required')
    if not d['compiler'] or d['compiler'][-1]['status']!='pass' or d['compiler'][-1]['sources']!=hashes():raise RuntimeError('Matching successful build required')
    chosen=cases.split(',');allowed=[f'L{i:02}' for i in range(1,13)] if action=='pure' else [f'S{i:02}' for i in range(1,7)]
    if len(chosen)!=len(set(chosen)) or any(c not in allowed for c in chosen):raise RuntimeError('Named inputs only')
    if action=='pure' and len(d['pure'])+len(chosen)>20:raise RuntimeError('Pure quota')
    if action=='native':
        if {e['case'] for e in d['pure'] if e['status']=='pass'}!={f'L{i:02}' for i in range(1,13)}:raise RuntimeError('Swift coordinator controls required')
        if (d['fixture'] or {}).get('status')!='complete' or d['sessions']+len(chosen)>18:raise RuntimeError('Fixture/session quota')
        if d['start'] is None:d['start']=time.monotonic();save()
    group_start=time.monotonic()
    for c in chosen:
        if time.monotonic()-group_start>180:raise RuntimeError('Batch deadline')
        previous=[e for e in d[action] if e['case']==c];kind='initial'
        if final:
            if action!='native' or not previous or c in d['final_cases'] or previous[-1]['swift_sources']==swift_hashes():raise RuntimeError('Final once on older relevant Swift source')
            d['final_cases'].append(c);kind='final'
        elif previous:
            if previous[-1]['status']=='pass' or not reason or previous[-1]['sources']==hashes():raise RuntimeError('Failed input plus changed source/reason required')
            kind='correction'
            if action=='native':
                if d['corrections']>=6:raise RuntimeError('Native correction quota')
                d['corrections']+=1
        if action=='native':
            if time.monotonic()-d['start']>900:raise RuntimeError('Native window')
            if c!='S01' and not any(e['case']=='S01' and e['status']=='pass' and e['swift_sources']==swift_hashes() for e in d['native']):raise RuntimeError('Matching S01 prerequisite')
            d['sessions']+=1
        e=dict(case=c,slot=len(d[action])+1,kind=kind,status='started',sources=hashes(),swift_sources=swift_hashes(),reason=reason);d[action].append(e);save()
        env={**os.environ,'PYTHONDONTWRITEBYTECODE':'1','F6_RESEARCH_FIXTURE':str(ROOT/'fixture')}
        log=ROOT/f'{action}-{c}-{e["slot"]}.log';start=time.monotonic()
        code,forced=execute([str(ROOT/'startup179'),'--'+action,c],5 if action=='pure' else 20,log,env)
        e.update(status='pass' if code==0 else 'fail',exit_code=code,forced_teardown=forced,elapsed_seconds=round(time.monotonic()-start,3))
        try:
            lines=[json.loads(line) for line in log.read_text().splitlines() if line.startswith('{')]
            e['observation']=lines[-1]
            if e['observation'].get('status')!='pass':e['status']='fail'
        except (ValueError,IndexError):e['status']='fail'
        save();print(action,c,e['status'],flush=True)
        if action=='native' and c=='S01' and e['status']!='pass':break

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--action',choices=['build','pure','setup','native','cleanup'],required=True);p.add_argument('--cases');p.add_argument('--reason');p.add_argument('--final',action='store_true');a=p.parse_args();main(a.action,a.cases,a.reason,a.final)
