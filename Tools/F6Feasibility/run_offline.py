"""One-shot approved batch runner. Existing ledgers prevent accidental repeats."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time

HERE = Path(__file__).resolve().parent

def run(output):
    output.mkdir(parents=True, exist_ok=True)
    ledger = output/'ledger.json'
    if ledger.exists():
        raise SystemExit('Existing ledger: no implicit rerun is permitted')
    data = {'phase':'F6-A','compiler_limit':8,'case_limit':96,'network_attempts':0,
            'sources':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in HERE.glob('*') if p.is_file()},
            'compilers':[],'cases':[],'status':'running'}
    def save(): ledger.write_text(json.dumps(data,indent=2)+'\n')
    save()
    routes = [('macosx','x86_64-apple-macosx15.0'),
              ('iphonesimulator','arm64-apple-ios18.0-simulator'),
              ('appletvsimulator','arm64-apple-tvos18.0-simulator'),
              ('watchsimulator','arm64-apple-watchos11.0-simulator')]
    for sdk,target in routes:
        path = subprocess.check_output(['xcrun','--sdk',sdk,'--show-sdk-path'],text=True).strip()
        command = ['xcrun','swiftc','-typecheck','-swift-version','6','-warnings-as-errors',
                   '-sdk',path,'-target',target,str(HERE/'CapabilityProbe.swift')]
        entry = {'slot':len(data['compilers'])+1,'sdk':sdk,'target':target,'status':'started'}
        data['compilers'].append(entry);save()
        start=time.monotonic()
        try:
            p=subprocess.run(command,capture_output=True,text=True,timeout=120)
            raw=p.stdout+p.stderr
            entry.update(exit_code=p.returncode,status='pass' if p.returncode==0 else 'fail')
        except subprocess.TimeoutExpired:
            raw='Compiler timeout after 120 seconds';entry.update(status='timeout')
        entry['seconds']=round(time.monotonic()-start,3)
        (output/(sdk+'.log')).write_text(raw)
        save();print('COMPILE',sdk,entry['status'],flush=True)
    suite_start=time.monotonic()
    cases=[f'{g}{i:02}' for g,count in [('S',24),('F',24),('P',16)] for i in range(1,count+1)]
    for case in cases:
        if time.monotonic()-suite_start>=120:
            data['status']='suite-deadline';save();return
        entry={'id':case,'status':'started'};data['cases'].append(entry);save()
        try:
            p=subprocess.run([sys.executable,str(HERE/'cases.py'),case],capture_output=True,text=True,
                             timeout=min(5,120-(time.monotonic()-suite_start)),env={**os.environ,'PYTHONDONTWRITEBYTECODE':'1'})
            entry.update(status='pass' if p.returncode==0 else 'fail',exit_code=p.returncode)
            (output/(case+'.log')).write_text(p.stdout+p.stderr)
        except subprocess.TimeoutExpired:
            entry.update(status='timeout')
        save();print(case,entry['status'],flush=True)
    data['status']='completed';save()

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--output',type=Path,required=True)
    run(parser.parse_args().output)
