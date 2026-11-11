"""Single owned loopback fixture: no outbound connections and no general server."""
import argparse,base64,hashlib,json,socket,ssl,time
from pathlib import Path
from verifier import verify

def run(case,root,result):
    n=int(case[1:]);group=case[0];udp=group=='D'
    server=socket.socket(socket.AF_INET,socket.SOCK_DGRAM if udp else socket.SOCK_STREAM)
    server.bind(('127.0.0.1',0));server.settimeout(16)
    if not udp:server.listen(1)
    print(json.dumps({'port':server.getsockname()[1]}),flush=True)
    report={'case':case,'accepted':0,'received_payload':0,'sent_payload':0,'status':'waiting'}
    connection=None
    try:
        if udp:
            incoming,peer=server.recvfrom(65536);report['received_payload']=len(incoming)
            if n==1:packets=[b'']
            elif n==2:packets=[b'A'*8]
            elif n==4:packets=[b'A'*9]
            elif n==6:packets=[b'2',b'1']
            elif n in (7,8):time.sleep(.25);packets=[b'ack']
            else:packets=[]
            for packet in packets:
                server.sendto(packet,peer);report['sent_payload']+=len(packet)
            if not packets:time.sleep(.5)
            report['status']='done';return
        connection,_=server.accept();report['accepted']=1;connection.settimeout(12)
        if group in ('L','I'):
            context=ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
            selected='server-backup' if case=='L03' else 'server-wrong-host' if case=='L04' else 'server-current'
            context.load_cert_chain(root/(selected+'.cert.pem'),root/(selected+'.key.pem'))
            context.minimum_version=ssl.TLSVersion.TLSv1_2
            if group=='I':
                context.verify_mode=ssl.CERT_REQUIRED;context.load_verify_locations(root/'ca.cert.pem')
            connection=context.wrap_socket(connection,server_side=True)
            report['tls_established']=True;report['tls_version']=connection.version()
            if group=='I':
                peer=connection.getpeercert(binary_form=True)
                valid=hashlib.sha256(peer).digest()==hashlib.sha256((root/'client-valid.cert.der').read_bytes()).digest()
                report['client_leaf_authorized']=valid
            else:valid=True
        else:valid=True
        if group=='T':
            if n==1:parts=[b'par',b'tial']
            elif n==2:parts=[b'\0\0\0\1a\0\0\0\1b']
            elif n==3:parts=[b'aa\r',b'\n']
            elif n==4:parts=[b'\0\0\0\2a']
            elif n==5:parts=[b'\0\0\0\11']
            elif n==6:
                incoming=connection.recv(16);report['received_payload']=len(incoming)
                if incoming!=b'go':raise ValueError('overlap trigger')
                parts=[b'ack']
            else:time.sleep(.5);parts=[]
            for part in parts:
                connection.sendall(part);report['sent_payload']+=len(part);time.sleep(.02)
            report['status']='done';return
        header=b''
        while b'\r\n\r\n' not in header:
            part=connection.recv(4096)
            if not part:raise ValueError('EOF before request')
            header+=part
            if len(header)>65536:raise ValueError('header bound')
        first,body=header.split(b'\r\n\r\n',1)
        lines=first.decode('iso-8859-1').split('\r\n');method,target,_=lines[0].split(' ',2)
        fields={}
        for line in lines[1:]:
            key,value=line.split(':',1);key=key.lower()
            if key in fields:raise ValueError('duplicate header')
            fields[key]=value.strip()
        size=int(fields.get('content-length','0'))
        if size>65536:raise ValueError('body bound')
        while len(body)<size:
            part=connection.recv(min(4096,size-len(body)))
            if not part:raise ValueError('EOF body')
            body+=part
        report['received_payload']=len(header)+max(0,len(body)-(len(header)-len(first)-4))
        if group=='H':
            req={'method':method,'target':'http://'+fields['host']+target,'body':body,'headers':fields}
            if n==6:
                report['original_signature_verified']=verify(req,{'test-key':bytes(range(32))},now=1001)
                req['body']=b'mutated'
            report['observed_content_type']=fields.get('content-type','absent')
            accepted=verify(req,{'test-key':bytes(range(32))},now=1001)
            report['signature_verified']=accepted
            status=302 if n==7 else 200 if accepted else 400
        else:status=200 if valid else 403
        payload=b'ok';response=f'HTTP/1.1 {status} Fixture\r\nContent-Length: 2\r\nConnection: close\r\n'.encode()
        if status==302:response+=f'Location: http://127.0.0.1:{server.getsockname()[1]}/follow\r\n'.encode()
        report['http_status']=status
        response+=b'\r\n'+payload
        connection.sendall(response);report['sent_payload']=len(response);report['status']='done'
    except (ssl.SSLError,OSError,ValueError) as e:
        report['status']='peer-ended';report['error_category']=type(e).__name__
        if isinstance(e,ssl.SSLError):report['tls_reason']=str(e.reason)
        if isinstance(e,ssl.SSLCertVerificationError):report['certificate_verify_code']=e.verify_code
    finally:
        if connection:
            try:connection.close()
            except OSError:pass
        server.close();result.write_text(json.dumps(report,sort_keys=True)+'\n')

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('case');p.add_argument('root',type=Path);p.add_argument('result',type=Path)
    a=p.parse_args();run(a.case,a.root,a.result)
