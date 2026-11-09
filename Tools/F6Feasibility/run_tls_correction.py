"""Prepared #178 follow-up; no standing execution authority from the old Mac batch."""
import argparse,hashlib,json,os,selectors,signal,subprocess,sys,time
from pathlib import Path
from setup_native_fixture import setup
HERE=Path(__file__).resolve().parent
LOCAL=['L01','L06','L08','I01','I04']
PURE=[f'G{i:02}' for i in range(1,9)]
FIXTURE_NAMES=['server-current','server-backup','client-valid','client-expired']

def expired_proof(domain,code,fixture):
    return domain=='NSURLErrorDomain' and code in [-999,-1004,-1200,-1205,-1206] and fixture.get('certificate_verify_code')==10

def main(root,action,cases=None,reason=None):
    os.umask(0o077);root.mkdir(mode=0o700,parents=True,exist_ok=True)
    path=root/'tls178-ledger.json'
    ledger=json.loads(path.read_text()) if path.exists() else {'scope':'PREP-F6-TLS-178','build':[],'pure':[],'local':[],'fixture':None,'runtime_start':None}
    def save():path.write_text(json.dumps(ledger,indent=2)+'\n')
    def hashes():return {p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in HERE.iterdir() if p.is_file()}
    def stop(child):
        if child.poll() is None:
            os.killpg(child.pid,signal.SIGTERM)
            try:child.wait(timeout=2)
            except subprocess.TimeoutExpired:os.killpg(child.pid,signal.SIGKILL);child.wait(timeout=2)
    def execute(command,timeout,log,env=None):
        with log.open('w') as out:
            child=subprocess.Popen(command,stdout=out,stderr=subprocess.STDOUT,env=env,start_new_session=True)
            try:return child.wait(timeout=timeout)
            except subprocess.TimeoutExpired:stop(child);return -999
    if action=='build':
        if len(ledger['build'])>=3 or ledger['build'] and not reason:raise RuntimeError('Three build maximum / correction reason required')
        entry={'slot':len(ledger['build'])+1,'reason':reason,'sources':hashes(),'status':'started'}
        ledger['build'].append(entry);save()
        sdk=subprocess.check_output(['xcrun','--sdk','macosx','--show-sdk-path'],text=True).strip()
        files=['NativeValues.swift','NativeState.swift','NativeProbe.swift','NativeMain.swift']
        code=execute(['xcrun','swiftc','-parse-as-library','-swift-version','6','-warnings-as-errors','-sdk',sdk,'-target','x86_64-apple-macosx15.0',*[str(HERE/p) for p in files],'-o',str(root/'tls178-probe')],120,root/f'build-{entry["slot"]}.log')
        entry.update(status='pass' if code==0 else 'fail',exit_code=code);save();print('build',entry['slot'],entry['status'],flush=True);return
    if action=='setup':
        if ledger['fixture'] is not None:raise RuntimeError('No regeneration/reset')
        ledger['fixture']={'status':'started','pair_limit':5};save()
        ledger['fixture']=setup(root/'fixture',FIXTURE_NAMES);ledger['fixture']['status']='complete';save();return
    if action=='cleanup':
        import shutil
        shutil.rmtree(root/'fixture');ledger['cleanup']='owned material removed, not secure erasure';save();return
    if action not in ['pure','local']:raise RuntimeError('No external/public action exists')
    if not ledger['build'] or ledger['build'][-1]['status']!='pass':raise RuntimeError('Successful candidate build required')
    if action=='local' and (ledger['fixture'] or {}).get('status')!='complete':raise RuntimeError('Fixture incomplete')
    allowed=PURE if action=='pure' else LOCAL
    selected=cases.split(',') if cases else allowed
    if len(set(selected))!=len(selected) or any(c not in allowed for c in selected):raise RuntimeError('Named cases only')
    maximum=12 if action=='pure' else 8
    old=ledger[action];latest={e['case']:e for e in old}
    if len(old)+len(selected)>maximum:raise RuntimeError('Scope exhausted')
    if reason:
        if any(c not in latest or latest[c]['status']=='pass' for c in selected):raise RuntimeError('Reserves only correct failed cases')
    elif any(c in latest for c in selected):raise RuntimeError('No implicit rerun')
    env={**os.environ,'PYTHONDONTWRITEBYTECODE':'1','F6_FIXTURE':str(root/'fixture')}
    started=time.monotonic()
    if action=='local' and ledger['runtime_start'] is None:ledger['runtime_start']=time.time();save()
    for case in selected:
        if time.monotonic()-started>(120 if action=='pure' else 180):raise RuntimeError('Suite/group deadline')
        if action=='local' and time.time()-ledger['runtime_start']>300:raise RuntimeError('Five-minute native window exhausted')
        entry={'case':case,'slot':len(old)+1,'reason':reason,'sources':hashes(),'status':'started'};old.append(entry);save()
        fixture=None
        try:
            command=[str(root/'tls178-probe'),'--'+action,case]
            reportfile=root/f'{case}-{entry["slot"]}-fixture.json'
            if action=='local':
                fixture=subprocess.Popen([sys.executable,str(HERE/'native_fixture.py'),case,str(root/'fixture'),str(reportfile)],stdout=subprocess.PIPE,stderr=(root/f'{case}-{entry["slot"]}-fixture.stderr').open('w'),env=env,text=True,start_new_session=True)
                poll=selectors.DefaultSelector();poll.register(fixture.stdout,selectors.EVENT_READ)
                if not poll.select(5):raise RuntimeError('Readiness pipe timeout; no health connection')
                command.append(str(json.loads(fixture.stdout.readline())['port']));poll.close()
            log=root/f'{case}-{entry["slot"]}.log'
            code=execute(command,5 if action=='pure' else 20,log,env)
            entry.update(status='pass' if code==0 else 'fail',exit_code=code)
            if code==0:entry['observation']=json.loads(log.read_text().splitlines()[-1])
            if fixture:
                try:fixture.wait(timeout=1)
                except subprocess.TimeoutExpired:stop(fixture)
                if reportfile.exists():entry['fixture']=json.loads(reportfile.read_text())
                else:entry['fixture']={'status':'terminated without report; no proof inferred'}
            if case=='G08' and code==0:
                o=entry['observation']
                if expired_proof(o['oracleNativeDomain'],o['oracleNativeCode'],{}):entry['status']='fail';entry['oracle']='generic transport accepted without proof'
            if case=='I04' and code==0:
                o=entry['observation'];f=entry.get('fixture',{})
                if not expired_proof(o.get('domain'),o.get('code'),f):entry['status']='fail';entry['oracle']='independent expiry witness missing'
            if case=='I01' and code==0:
                f=entry.get('fixture',{})
                if not(f.get('tls_established') and f.get('client_leaf_authorized') and f.get('http_status')==200):entry['status']='fail';entry['oracle']='positive identity control missing'
            if case in ['L06','L08'] and code==0:
                o=entry['observation']
                if not(o.get('registeredChallenges',0)>0 and o.get('completedChallenges')==o.get('registeredChallenges') and o.get('admittedCredentials')==0 and o.get('pendingChallenges')==0 and o.get('suppressedLateResults',0)>0 and o.get('resultResolutions')==1):entry['status']='fail';entry['oracle']='gate proof missing'
        except Exception as e:entry.update(status='fail',controller_error=type(e).__name__)
        finally:
            if fixture:stop(fixture)
            save()
        print(action,case,entry['status'],flush=True)

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);p.add_argument('--action',choices=['build','setup','pure','local','cleanup'],required=True);p.add_argument('--cases');p.add_argument('--reason')
    a=p.parse_args();main(a.output,a.action,a.cases,a.reason)
