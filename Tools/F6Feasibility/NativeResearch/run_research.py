"""One explicitly authorized #179 experiment; never runs by import or default action."""
import argparse,hashlib,json,os,selectors,signal,subprocess,sys,time
from pathlib import Path
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE.parent))
from setup_native_fixture import setup
PURE=[f'{g}{i:02}' for g,n in [('B',10),('L',6),('M',6),('Q',8)] for i in range(1,n+1)]
LOCAL=[f'N{i:02}' for i in range(1,7)]+[f'Q{i:02}' for i in range(1,11)]
COST={i:2 if i=='N02' else 1 for i in LOCAL}
SOURCES=[HERE.parent/'NativeState.swift',HERE.parent/'NativeValues.swift']+[HERE/n for n in ['Values.swift','State.swift','ListenerPeer.swift','QUICPeer.swift','ProbeMain.swift']]

def main(root,action,cases=None,reason=None):
    os.umask(0o077);root.mkdir(mode=0o700,parents=True,exist_ok=True)
    path=root/'research179-ledger.json'
    d=json.loads(path.read_text()) if path.exists() else {'scope_commit':'c70a780a3cf4ce76eefd07fd540fb64787489dad','compiler':[],'pure':[],'local':[],'sessions':0,'fixture':None,'runtime_start':None}
    def save():path.write_text(json.dumps(d,indent=2)+'\n')
    def hashes():return {str(p.relative_to(HERE.parent)):hashlib.sha256(p.read_bytes()).hexdigest() for p in set(SOURCES+list(HERE.glob('*'))+[HERE.parent/'setup_native_fixture.py']) if p.is_file()}
    def stop(child):
        if child.poll() is None:
            os.killpg(child.pid,signal.SIGTERM)
            try:child.wait(timeout=2)
            except subprocess.TimeoutExpired:os.killpg(child.pid,signal.SIGKILL);child.wait(timeout=2)
    def execute(command,limit,log,env=None):
        with log.open('w') as out:
            child=subprocess.Popen(command,stdout=out,stderr=subprocess.STDOUT,env=env,start_new_session=True)
            try:return child.wait(timeout=limit)
            except subprocess.TimeoutExpired:stop(child);return -999
    def line(child,seconds):
        poll=selectors.DefaultSelector();poll.register(child.stdout,selectors.EVENT_READ)
        ready=poll.select(seconds);poll.close()
        if not ready:raise TimeoutError('Bounded stdout response deadline')
        text=child.stdout.readline()
        if not text:raise RuntimeError('Child exited without outcome')
        return text
    env={**os.environ,'PYTHONDONTWRITEBYTECODE':'1','F6_RESEARCH_FIXTURE':str(root/'fixture')}
    if action in ['declarations','build']:
        routes=[('macosx','x86_64-apple-macosx15.0'),('iphonesimulator','arm64-apple-ios18.0-simulator'),('appletvsimulator','arm64-apple-tvos18.0-simulator'),('watchsimulator','arm64-apple-watchos11.0-simulator')] if action=='declarations' else [('executable','x86_64-apple-macosx15.0')]
        if cases:routes=[r for r in routes if r[0] in cases.split(',')]
        if not routes or len(d['compiler'])+len(routes)>8:raise RuntimeError('Compiler envelope')
        for tag,target in routes:
            previous=[e for e in d['compiler'] if e['kind']==tag]
            if previous and not reason:raise RuntimeError('No uncounted rebuild/recheck')
            entry={'slot':len(d['compiler'])+1,'kind':tag,'target':target,'reason':reason,'sources':hashes(),'status':'started'}
            d['compiler'].append(entry);save()
            sdk='macosx' if tag=='executable' else tag
            sdkpath=subprocess.check_output(['xcrun','--sdk',sdk,'--show-sdk-path'],text=True).strip()
            command=['xcrun','swiftc','-swift-version','6','-warnings-as-errors','-sdk',sdkpath,'-target',target]
            command+=['-parse-as-library','-j','1',*[str(p) for p in SOURCES],'-o',str(root/'research179')] if tag=='executable' else ['-typecheck',str(HERE/'CapabilityProbe.swift')]
            entry['command']=[str(p).replace(str(HERE.parent),'<tool>') for p in command]
            code=execute(command,120,root/f'compiler-{entry["slot"]}.log')
            entry.update(status='pass' if code==0 else 'fail',exit_code=code);save();print('compiler',tag,entry['status'],flush=True)
        return
    if action=='setup':
        if d['fixture'] is not None:raise RuntimeError('Fixture quota already consumed')
        d['fixture']={'status':'started','pairs':2};save()
        d['fixture']=setup(root/'fixture',['server-current']);d['fixture']['status']='complete';save();print('Two fixture pairs created',flush=True);return
    if action=='cleanup':
        import shutil
        shutil.rmtree(root/'fixture');d['cleanup']='owned fixture material removed, not secure erasure';d['runtime_closed']=True;save();return
    if action not in ['pure','local']:raise RuntimeError('No implicit/public/LAN mode')
    executable=[e for e in d['compiler'] if e['kind']=='executable']
    if not executable or executable[-1]['status']!='pass':raise RuntimeError('Successful candidate build required')
    allowed=PURE if action=='pure' else LOCAL
    chosen=cases.split(',') if cases else allowed
    if not chosen or len(chosen)!=len(set(chosen)) or any(c not in allowed for c in chosen):raise RuntimeError('Exact named inputs only')
    old={e['case']:e for e in d[action]}
    for case in chosen:
        if case in old and (not reason or old[case]['status']=='pass'):raise RuntimeError('Only failed-case documented corrections')
    if action=='pure' and len(d['pure'])+len(chosen)>40:raise RuntimeError('Pure envelope')
    if action=='local':
        if d.get('runtime_closed'):raise RuntimeError('Native scope closed after cleanup')
        if d['sessions']+sum(COST[c] for c in chosen)>25:raise RuntimeError('Transport session envelope')
        if (d['fixture'] or {}).get('status')!='complete':raise RuntimeError('Fixture not ready')
        if d['runtime_start'] is None:d['runtime_start']=time.monotonic();save()
    def consume(case):
        if action=='local':
            if time.monotonic()-d['runtime_start']>600:raise RuntimeError('Native ten-minute window')
            d['sessions']+=COST[case]
        e={'case':case,'slot':len(d[action])+1,'reason':reason if case in old else None,'status':'started','sources':hashes()}
        if action=='local':e['transport_sessions']=COST[case]
        d[action].append(e);save();return e
    if action=='pure':
        started=time.monotonic()
        for case in chosen:
            if time.monotonic()-started>120:raise RuntimeError('Pure suite deadline')
            e=consume(case);log=root/f'pure-{case}-{e["slot"]}.log'
            code=execute([str(root/'research179'),'--pure',case],5,log,env)
            e.update(status='pass' if code==0 else 'fail',exit_code=code)
            try:e['observation']=json.loads(log.read_text().splitlines()[-1])
            except Exception:e['status']='fail'
            save();print('pure',case,e['status'],flush=True)
        return
    # A single explicitly selected native batch retains N01's actual NWInterface value for N06.
    normal=[c for c in chosen if c!='Q10'];child=None
    if normal:
        err=(root/f'local-batch-{len(d["local"])+1}.stderr').open('w')
        child=subprocess.Popen([str(root/'research179'),'--local-batch','explicit'],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=err,text=True,env=env,start_new_session=True)
        start=time.monotonic()
        try:
            for case in normal:
                if time.monotonic()-start>180:raise RuntimeError('Native group deadline')
                e=consume(case);child.stdin.write(case+'\n');child.stdin.flush()
                try:
                    text=line(child,20);(root/f'local-{case}-{e["slot"]}.log').write_text(text)
                    result=json.loads(text);e.update(status=result.get('status','fail'),observation=result)
                except Exception as error:
                    e.update(status='fail',controller_error=type(error).__name__);stop(child)
                save();print('local',case,e['status'],flush=True)
                if child.poll() is not None:break
        finally:
            if child.poll() is None:
                try:child.stdin.write('quit\n');child.stdin.flush();child.wait(timeout=2)
                except (OSError,subprocess.TimeoutExpired):stop(child)
            err.close()
    if 'Q10' in chosen:
        e=consume('Q10');peer=None;client=None
        deadline=time.monotonic()+20
        def remaining(limit):
            left=deadline-time.monotonic()
            if left<=0:raise TimeoutError('Q10 whole-case deadline')
            return min(limit,left)
        cleanenv={k:v for k,v in env.items() if k not in ['OPENSSL_ENGINES','OPENSSL_MODULES','SSL_CERT_FILE','SSL_CERT_DIR']};cleanenv['OPENSSL_CONF']='/dev/null'
        try:
            with (root/f'Q10-peer-{e["slot"]}.stderr').open('w') as err:
                peer=subprocess.Popen([str(root/'research179'),'--peer','Q10'],stdout=subprocess.PIPE,stderr=err,text=True,env=env,start_new_session=True)
                ready=json.loads(line(peer,remaining(5)));port=int(ready['observations']['port'])
                command=['/usr/local/bin/openssl','s_client','-quic','-connect',f'127.0.0.1:{port}','-alpn','networkkit-f6-test','-CAfile',str(root/'fixture/ca.cert.pem'),'-verify_return_error','-verify_hostname','localhost','-servername','localhost','-quiet','-no_ign_eof','-no-CApath','-no-CAstore']
                with (root/f'Q10-client-{e["slot"]}.stderr').open('w') as cerr:
                    client=subprocess.Popen(command,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=cerr,env=cleanenv,start_new_session=True)
                    client.stdin.write(b'q10\n');client.stdin.flush()
                    poll=selectors.DefaultSelector();poll.register(client.stdout,selectors.EVENT_READ)
                    if not poll.select(remaining(10)):raise TimeoutError('Independent client reply deadline')
                    response=os.read(client.stdout.fileno(),1024);poll.close()
                    client.stdin.close();code=client.wait(timeout=remaining(5))
                    peer_result=json.loads(line(peer,remaining(3)));peer.wait(timeout=remaining(2))
                    e.update(status='pass' if response==b'q10\n' and code==0 and peer_result.get('status')=='pass' else 'fail',client_exit=code,reply_bytes=len(response),peer_observation=peer_result)
        except Exception as error:e.update(status='fail',controller_error=type(error).__name__)
        finally:
            if client:stop(client)
            if peer:stop(peer)
            save();print('local Q10',e['status'],flush=True)

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);p.add_argument('--action',choices=['declarations','build','setup','pure','local','cleanup'],required=True);p.add_argument('--cases');p.add_argument('--reason')
    a=p.parse_args();main(a.output,a.action,a.cases,a.reason)
