"""Explicit fabf77a correction envelope; no execution on import or default action."""
import argparse, hashlib, json, os, selectors, signal, subprocess, sys, time
from pathlib import Path
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE.parent))
from setup_native_fixture import setup
ROOT=Path('/private/tmp/networkkit-f6-quic179-correction')
SCOPE='fabf77a55a9fdcf69e0b4f503075c60409d3eb63'
SOURCES=[HERE.parent/'NativeState.swift',HERE.parent/'NativeValues.swift']+[HERE/n for n in ['Values.swift','State.swift','ListenerPeer.swift','QUICPeer.swift','ProbeMain.swift']]
LOCAL=['C01','Q01','C02','C03']+[f'Q{i:02}' for i in range(2,10)]

def rejects(kind, terminal, trust_rejected, ready, exchanged):
    return terminal=='tls' and not ready and not exchanged and (kind=='alpn' or trust_rejected>0)

def main(action,cases=None,reason=None):
    os.umask(0o077);ROOT.mkdir(mode=0o700,exist_ok=True)
    path=ROOT/'correction-ledger.json'
    d=json.loads(path.read_text()) if path.exists() else dict(scope_commit=SCOPE,compiler=[],pure=[],local=[],sessions=0,fixture=None,runtime_start=None,closed=False)
    assert d['scope_commit']==SCOPE
    def save():path.write_text(json.dumps(d,indent=2)+'\n')
    def hashes():return {str(p.relative_to(HERE.parent)):hashlib.sha256(p.read_bytes()).hexdigest() for p in set(SOURCES+list(HERE.glob('*.py'))+[HERE.parent/'setup_native_fixture.py'])}
    def stop(p):
        if p and p.poll() is None:
            os.killpg(p.pid,signal.SIGTERM)
            try:p.wait(timeout=1)
            except subprocess.TimeoutExpired:os.killpg(p.pid,signal.SIGKILL);p.wait(timeout=1)
    def run(cmd,seconds,log,env=None):
        with log.open('w') as out:
            p=subprocess.Popen(cmd,stdout=out,stderr=subprocess.STDOUT,env=env,start_new_session=True)
            try:return p.wait(timeout=seconds)
            except subprocess.TimeoutExpired:stop(p);return -999
    if action=='cleanup':
        import shutil
        if (ROOT/'fixture').exists():shutil.rmtree(ROOT/'fixture')
        d.update(closed=True,cleanup='owned fixture directory absent; ordinary removal, not secure erasure');save();return
    if d['closed']:raise RuntimeError('Correction runtime closed; no reset')
    if action=='pure':
        chosen=(cases or 'O01,O02,O03,O04').split(',')
        if len(chosen)!=len(set(chosen)) or any(c not in ['O01','O02','O03','O04'] for c in chosen) or len(d['pure'])+len(chosen)>8:raise RuntimeError('Pure quota/input')
        for c in chosen:
            prev=[e for e in d['pure'] if e['case']==c]
            if prev and (prev[-1]['status']=='pass' or not reason):raise RuntimeError('Failed input corrections only')
            e=dict(case=c,slot=len(d['pure'])+1,status='started',sources=hashes(),reason=reason);d['pure'].append(e);save()
            start=time.monotonic()
            if c=='O01':passed=not rejects('alpn','timeout',0,False,False)
            elif c=='O02':passed=not rejects('alpn','posix',0,False,False)
            elif c=='O03':passed=rejects('trust','tls',1,False,False) and not rejects('trust','tls',0,False,False) and not rejects('trust','tls',1,True,False) and not rejects('trust','tls',1,False,True)
            else:
                history=[];overflow=False
                for i in range(33):
                    if len(history)<32:history.append(i)
                    else:overflow=True
                passed=len(history)==32 and overflow
            e.update(status='pass' if passed and time.monotonic()-start<5 else 'fail',evidence='offline oracle control, not native TLS/state proof');save();print(c,e['status'],flush=True)
        return
    if action=='build':
        if len(d['compiler'])>=4 or (d['compiler'] and not reason):raise RuntimeError('Compiler envelope/reason')
        if {e['case'] for e in d['pure'] if e['status']=='pass'}!={'O01','O02','O03','O04'}:raise RuntimeError('Oracle gate')
        e=dict(slot=len(d['compiler'])+1,status='started',sources=hashes(),reason=reason);d['compiler'].append(e);save()
        sdk=subprocess.check_output(['xcrun','--sdk','macosx','--show-sdk-path'],text=True).strip()
        cmd=['xcrun','swiftc','-swift-version','6','-warnings-as-errors','-sdk',sdk,'-target','x86_64-apple-macosx15.0','-parse-as-library','-j','1',*[str(p) for p in SOURCES],'-o',str(ROOT/'correction179')]
        e['command']=[a.replace(str(HERE.parent),'<tool>') for a in cmd];save()
        code=run(cmd,120,ROOT/f'compiler-{e["slot"]}.log');e.update(status='pass' if code==0 else 'fail',exit_code=code);save();print('compiler',e['slot'],e['status'],flush=True);return
    if action=='setup':
        if d['fixture'] is not None:raise RuntimeError('Fixture already consumed')
        d['fixture']={'status':'started','pairs':2};save();d['fixture']=setup(ROOT/'fixture',['server-current']);d['fixture']['status']='complete';save();print('fixture created: two pairs',flush=True);return
    if action!='local' or not cases:raise RuntimeError('Explicit local cases required')
    if not d['compiler'] or d['compiler'][-1]['status']!='pass':raise RuntimeError('Build required')
    if (d['fixture'] or {}).get('status')!='complete':raise RuntimeError('Fixture required')
    if hashes()!=d['compiler'][-1]['sources']:raise RuntimeError('Source changed since build; rebuild within budget')
    chosen=cases.split(',')
    if len(set(chosen))!=len(chosen) or any(c not in LOCAL for c in chosen) or d['sessions']+len(chosen)>16:raise RuntimeError('Session quota/input')
    env={**os.environ,'PYTHONDONTWRITEBYTECODE':'1','F6_RESEARCH_FIXTURE':str(ROOT/'fixture')}
    group_start=time.monotonic()
    if d['runtime_start'] is None:d['runtime_start']=time.monotonic();save()
    for c in chosen:
        if time.monotonic()-d['runtime_start']>600 or time.monotonic()-group_start>240:raise RuntimeError('Native window/group deadline')
        passed={e['case'] for e in d['local'] if e['status']=='pass'}
        if c!='C01' and c not in ['Q06','Q07'] and 'C01' not in passed:raise RuntimeError('C01 bootstrap required')
        if c in ['Q02','Q03','Q04','Q05','Q08','Q09'] and not {'Q01','C02','C03'}.issubset(passed):raise RuntimeError('Native group controls required')
        prev=[e for e in d['local'] if e['case']==c]
        if prev and (prev[-1]['status']=='pass' or not reason or prev[-1]['sources']==hashes()):raise RuntimeError('Only corrected failed input')
        e=dict(case=c,slot=len(d['local'])+1,status='started',sources=hashes(),reason=reason,transport_sessions=1);d['local'].append(e);d['sessions']+=1;save()
        deadline=time.monotonic()+20
        def remaining():
            left=deadline-time.monotonic()
            if left<=0:raise TimeoutError('Whole case deadline')
            return left
        def line(p):
            sel=selectors.DefaultSelector();sel.register(p.stdout,selectors.EVENT_READ)
            try:
                if not sel.select(remaining()):raise TimeoutError('Output deadline')
                text=p.stdout.readline()
                if not text:raise RuntimeError('EOF before outcome')
                return text
            finally:sel.close()
        peer=client=None
        try:
            with (ROOT/f'{c}-{e["slot"]}.stderr').open('w') as err:
                if c not in ['C02','C03']:
                    client=subprocess.Popen([str(ROOT/'correction179'),'--local-batch','explicit'],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=err,text=True,env=env,start_new_session=True)
                    client.stdin.write(c+'\n');client.stdin.flush()
                    result=json.loads(line(client));e['observation']=result;e['status']=result.get('status','fail')
                    client.stdin.write('quit\n');client.stdin.flush();e['exit_code']=client.wait(timeout=remaining())
                    if e['exit_code']!=0:e['status']='fail'
                else:
                    mode=['--correction-peer','C02'] if c=='C02' else ['--peer','Q10']
                    peer=subprocess.Popen([str(ROOT/'correction179'),*mode],stdout=subprocess.PIPE,stderr=err,text=True,env=env,start_new_session=True)
                    ready=json.loads(line(peer));e['peer_ready']=ready
                    port=int(ready['observations']['port']);assert 0<port<65536
                    if c=='C02':
                        cmd=[str(ROOT/'correction179'),'--correction-client','C02',str(port)]
                        client=subprocess.Popen(cmd,stdout=subprocess.PIPE,stderr=err,text=True,env=env,start_new_session=True)
                        result=json.loads(line(client));e['observation']=result;e['client_exit']=client.wait(timeout=remaining())
                    else:
                        clean={k:v for k,v in env.items() if k not in ['OPENSSL_ENGINES','OPENSSL_MODULES','SSL_CERT_FILE','SSL_CERT_DIR']};clean['OPENSSL_CONF']='/dev/null'
                        cmd=['/usr/local/bin/openssl','s_client','-quic','-connect',f'127.0.0.1:{port}','-alpn','networkkit-f6-test','-CAfile',str(ROOT/'fixture/ca.cert.pem'),'-verify_return_error','-verify_hostname','localhost','-servername','localhost','-quiet','-no_ign_eof','-no-CApath','-no-CAstore']
                        client=subprocess.Popen(cmd,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=err,env=clean,start_new_session=True)
                        client.stdin.write(b'q10\n');client.stdin.flush()
                        sel=selectors.DefaultSelector();sel.register(client.stdout,selectors.EVENT_READ)
                        try:
                            if not sel.select(remaining()):raise TimeoutError('Echo deadline')
                            response=os.read(client.stdout.fileno(),1024)
                        finally:sel.close()
                        client.stdin.close();e['client_exit']=client.wait(timeout=remaining());e['reply_bytes']=len(response);result={'status':'pass' if response==b'q10\n' else 'fail'}
                    peer_result=json.loads(line(peer));e['peer_observation']=peer_result;e['peer_exit']=peer.wait(timeout=remaining())
                    e['status']='pass' if result.get('status')=='pass' and peer_result.get('status')=='pass' and e['client_exit']==0 and e['peer_exit']==0 else 'fail'
        except Exception as error:e.update(status='fail',controller_error=type(error).__name__)
        finally:
            stop(client);stop(peer);e['elapsed_seconds']=round(time.monotonic()-(deadline-20),3);save()
        if c in ['Q06','Q07']:
            obs=e.get('observation',{}).get('observations',{});raw=(ROOT/f'{c}-{e["slot"]}.stderr').read_text();diags=[json.loads(t) for t in raw.splitlines() if t.startswith('{')]
            diag=diags[-1].get('observations',{}) if diags else {}
            terminal='tls' if 'tls(' in obs.get('nativeError','').lower() else 'other'
            okay=rejects('trust' if c=='Q07' else 'alpn',terminal,int(diag.get('trustRejected','0')),'ready' in diag.get('client',''),False)
            e['strict_negative_oracle']=okay
            if not okay:e['status']='fail'
            save()
        print(c,e['status'],flush=True)
        if c=='C01' and e['status']!='pass':break

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--action',choices=['pure','build','setup','local','cleanup'],required=True);p.add_argument('--cases');p.add_argument('--reason');a=p.parse_args();main(a.action,a.cases,a.reason)
