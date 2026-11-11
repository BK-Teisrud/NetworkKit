"""Explicit staged controller for the one owner-approved F6 Mac batch."""
import argparse,base64,hashlib,json,os,selectors,signal,subprocess,sys,time
from pathlib import Path
from setup_native_fixture import setup
from verifier import verify
HERE=Path(__file__).resolve().parent
FILES=['NativeValues.swift','NativeState.swift','NativeProbe.swift','NativeMain.swift']

def main(output,action,reason=None,cases=None):
    os.umask(0o077);output.mkdir(mode=0o700,parents=True,exist_ok=True)
    ledger=output/'native-ledger.json'
    d=json.loads(ledger.read_text()) if ledger.exists() else {'scope_commit':'b4c86d322dbabb72f4c5c94075ceb1f427ebc430','builds':[],'pure':[],'local':[],'public':[],'fixture':None,'started':None}
    def save():ledger.write_text(json.dumps(d,indent=2)+'\n')
    def hashes():return {p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in HERE.glob('*') if p.is_file()}
    def stop(child):
        if child.poll() is None:
            os.killpg(child.pid,signal.SIGTERM)
            try:child.wait(timeout=2)
            except subprocess.TimeoutExpired:os.killpg(child.pid,signal.SIGKILL);child.wait(timeout=2)
    def execute(command,timeout,log,env=None):
        with log.open('w') as stream:
            child=subprocess.Popen(command,stdout=stream,stderr=subprocess.STDOUT,env=env,start_new_session=True)
            try:code=child.wait(timeout=timeout)
            except subprocess.TimeoutExpired:stop(child);code=-999
        return code
    if action=='build':
        if len(d['builds'])>=4:raise RuntimeError('Build scope exhausted')
        if d['builds'] and not reason:raise RuntimeError('Documented correction reason required')
        sdk=subprocess.check_output(['xcrun','--sdk','macosx','--show-sdk-path'],text=True).strip()
        entry={'slot':len(d['builds'])+1,'reason':reason or 'initial','sources':hashes(),'status':'started'}
        d['builds'].append(entry);save()
        cmd=['xcrun','swiftc','-parse-as-library','-swift-version','6','-warnings-as-errors','-sdk',sdk,'-target','x86_64-apple-macosx15.0',*[str(HERE/f) for f in FILES],'-o',str(output/'f6-native-probe')]
        code=execute(cmd,120,output/f'build-{entry["slot"]}.log')
        entry.update(status='pass' if code==0 else 'fail',exit_code=code);save();print('build',entry['slot'],entry['status'],flush=True);return
    if action=='setup':
        if d['fixture'] is not None:raise RuntimeError('Fixture generation already consumed')
        d['fixture']={'status':'started','pairs_authorized':7};save()
        d['fixture']=setup(output/'fixture');d['fixture']['status']='complete';save();print('Fixture seven-pair setup complete');return
    if action=='cleanup':
        import shutil
        shutil.rmtree(output/'fixture');d['cleanup']='owned fixture material removed; no secure-erasure guarantee';save();return
    if action not in ['pure','local','public']:raise RuntimeError('Explicit action required')
    if action in ['local','public'] and d.get('network_scope_status','').startswith('Completed/exhausted'):
        raise RuntimeError('Network scope closed; new authorization required')
    if not d['builds'] or d['builds'][-1]['status']!='pass':raise RuntimeError('Successful candidate build required')
    if d['fixture'] is None or d['fixture'].get('status')!='complete':raise RuntimeError('Fixture not ready')
    if action=='pure':default=[f'W{i:02}' for i in range(1,33)];maximum=48;deadline=120
    elif action=='local':default=[f'{g}{i:02}' for g in 'HTDLI' for i in range(1,9)];maximum=48;deadline=180
    else:default=[f'E{i:02}' for i in range(1,5)];maximum=4;deadline=80
    selected=cases.split(',') if cases else default
    if any(c not in default for c in selected) or len(selected)!=len(set(selected)):raise RuntimeError('Invalid explicit case list')
    old=[e['case'] for e in d[action]]
    if any(c in old for c in selected) and not reason:raise RuntimeError('Spent case needs correction reason')
    latest={e['case']:e for e in d[action]}
    if reason and any(c in latest and latest[c]['status']=='pass' and latest[c].get('acceptance')!='invalid-evidence' for c in selected):
        raise RuntimeError('Correction slots are only for failed/invalid evidence, not repeated passing cases')
    if any(c not in old for c in selected) and reason:raise RuntimeError('Correction reserves cannot add new cases')
    if len(old)+len(selected)>maximum:raise RuntimeError('Case scope exhausted')
    if action!='pure':
        if d['started'] is None:d['started']=time.time();save()
        if time.time()-d['started']>900:raise RuntimeError('Network batch wall deadline exhausted')
    group_start=time.monotonic();lastgroup=None
    env={**os.environ,'PYTHONDONTWRITEBYTECODE':'1','F6_FIXTURE':str(output/'fixture'),'F6_OBSERVED_LEAF':str(output/'observed-public-leaf.der')}
    for case in selected:
        if action=='local' and case[0]!=lastgroup:group_start=time.monotonic();lastgroup=case[0]
        if time.monotonic()-group_start>deadline:raise RuntimeError('Group deadline')
        if action!='pure' and time.time()-d['started']>900:raise RuntimeError('Batch deadline')
        entry={'case':case,'slot':len(d[action])+1,'reason':reason,'sources':hashes(),'status':'started'}
        d[action].append(entry);save();fixture=None
        try:
            command=[str(output/'f6-native-probe'),'--'+action,case]
            if action=='local':
                fixture=subprocess.Popen([sys.executable,str(HERE/'native_fixture.py'),case,str(output/'fixture'),str(output/(case+'-fixture.json'))],stdout=subprocess.PIPE,stderr=(output/(case+'-fixture.stderr')).open('w'),text=True,start_new_session=True,env=env)
                selector=selectors.DefaultSelector();selector.register(fixture.stdout,selectors.EVENT_READ)
                if not selector.select(5):raise RuntimeError('Fixture readiness timeout, no health connection')
                ready=json.loads(fixture.stdout.readline());selector.close();command.append(str(ready['port']))
            log=output/(case+f'-{entry["slot"]}.log')
            code=execute(command,5 if action=='pure' else 20 if action=='local' else 15,log,env)
            entry.update(exit_code=code,status='pass' if code==0 else 'fail')
            if code==0:
                result=json.loads(log.read_text().splitlines()[-1]);entry['observation']={k:v for k,v in result.items() if k not in ['signed','keyid']}
                if 'signed' in result:
                    request=result['signed'];request['body']=base64.b64decode(request.pop('body64'))
                    keys={} if result.get('retired') else {result.get('keyid','test-key'):bytes(range(32))}
                    verified=verify(request,keys)
                    if verified==bool(result.get('retired')):entry['status']='fail';entry['verifier']='unexpected result'
                    if 'mutate' in result:
                        request['headers'][result['mutate']]+='mutation'
                        if verify(request,keys):entry['status']='fail';entry['verifier']='mutation accepted'
            if fixture:
                try:fixture.wait(timeout=1)
                except subprocess.TimeoutExpired:stop(fixture)
                p=output/(case+'-fixture.json')
                if p.exists():
                    observed=json.loads(p.read_text());entry['fixture_observation']=observed
                    proof = True
                    if case=='H06':proof=observed.get('original_signature_verified') is True and observed.get('signature_verified') is False
                    if case=='I02':proof=observed.get('tls_reason')=='PEER_DID_NOT_RETURN_A_CERTIFICATE'
                    if case=='I03':proof=observed.get('tls_established') is True and observed.get('client_leaf_authorized') is False and observed.get('http_status')==403
                    if case=='I04':proof=observed.get('certificate_verify_code')==10
                    if not proof:entry['status']='fail';entry['fixture_proof']='required independent control missing'

                else:entry['fixture_observation']='terminated before report; no success inferred'
        except Exception as e:
            entry.update(status='fail',controller_error=type(e).__name__)
        finally:
            if fixture:stop(fixture)
            save()
        print(action,case,entry['status'],flush=True)
    print('Completed selected',action,'cases; failures retained, no automatic retries',flush=True)

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);p.add_argument('--action',choices=['build','setup','pure','local','public','cleanup'],required=True);p.add_argument('--reason');p.add_argument('--cases')
    a=p.parse_args();main(a.output,a.action,a.reason,a.cases)
