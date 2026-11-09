"""Generate only the seven explicitly approved temporary fixture pairs."""
from datetime import datetime,timedelta,timezone
from pathlib import Path
import hashlib,json,os,subprocess

NAMES=['server-current','server-backup','server-wrong-host','client-valid','client-wrong','client-expired']
def setup(root):
    if root.exists(): raise RuntimeError('Refuse existing fixture directory / regeneration')
    root.mkdir(mode=0o700);(root/'newcerts').mkdir(mode=0o700)
    os.umask(0o077)
    (root/'index.txt').write_text('');(root/'serial').write_text('1000\n')
    config='''[ca]
default_ca=fixture
[fixture]
database=index.txt
serial=serial
new_certs_dir=newcerts
certificate=ca.cert.pem
private_key=ca.key.pem
default_md=sha256
policy=subject
unique_subject=no
copy_extensions=none
[subject]
commonName=supplied
[server_current]
basicConstraints=critical,CA:false
keyUsage=critical,digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth
subjectAltName=DNS:localhost,IP:127.0.0.1
[server_wrong]
basicConstraints=critical,CA:false
keyUsage=critical,digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth
subjectAltName=DNS:wrong.invalid
[client]
basicConstraints=critical,CA:false
keyUsage=critical,digitalSignature
extendedKeyUsage=clientAuth
'''
    (root/'ca.cnf').write_text(config)
    commands=[]
    def run(*args):
        commands.append(list(args))
        p=subprocess.run(['/usr/local/bin/openssl',*args],cwd=root,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=120)
        if p.returncode: raise RuntimeError('OpenSSL fixture command failed; no retry/key regeneration')
    run('req','-new','-newkey','rsa:2048','-noenc','-x509','-sha256','-days','7','-subj','/CN=NetworkKit F6 Fixture CA','-addext','basicConstraints=critical,CA:true','-addext','keyUsage=critical,keyCertSign,cRLSign','-keyout','ca.key.pem','-out','ca.cert.pem')
    now=datetime.now(timezone.utc)
    timestamp=lambda dt:dt.strftime('%Y%m%d%H%M%SZ')
    validity={}
    for name in NAMES:
        subject='localhost' if name in ['server-current','server-backup'] else 'wrong.invalid' if name=='server-wrong-host' else 'NetworkKit F6 '+name
        run('req','-new','-newkey','rsa:2048','-noenc','-sha256','-subj','/CN='+subject,'-keyout',name+'.key.pem','-out',name+'.csr.pem')
        start=now-timedelta(days=3 if name=='client-expired' else 1)
        end=now+timedelta(days=-2 if name=='client-expired' else 2)
        section='server_wrong' if name=='server-wrong-host' else 'server_current' if name.startswith('server-') else 'client'
        run('ca','-batch','-notext','-config','ca.cnf','-extensions',section,'-startdate',timestamp(start),'-enddate',timestamp(end),'-in',name+'.csr.pem','-out',name+'.cert.pem')
        run('x509','-in',name+'.cert.pem','-outform','DER','-out',name+'.cert.der')
        run('rsa','-in',name+'.key.pem','-traditional','-outform','DER','-out',name+'.key.der')
        validity[name]={'start':timestamp(start),'end':timestamp(end)}
    run('x509','-in','ca.cert.pem','-outform','DER','-out','ca.cert.der')
    for p in root.rglob('*'):
        if p.is_file():p.chmod(0o600)
    return {'pair_count':7,'validity':validity,'certificate_hashes':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in root.glob('*.cert.der')},'commands':commands}
