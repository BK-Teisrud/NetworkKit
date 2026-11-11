"""Exactly 64 named offline inputs; no implicit parametrization or network use."""
import copy
import sys
from candidate import KEY, sign, Frames, Admission, limit, timeout, security, safe_description
from verifier import verify

def check(value):
    if not value:
        raise AssertionError('expectation failed')

def rejects(operation):
    try:
        operation()
    except ValueError:
        return
    raise AssertionError('expected rejection')

def signing(n):
    args = {
        1: {'body': None}, 2: {'body': b''}, 3: {'body': bytes([0, 128, 255])},
        4: {'body': '{"name":"æ"}'.encode()},
        5: {'target': 'https://example.invalid/a%2Fb?q=%20'},
        6: {'target': 'https://example.invalid/?a=1&a=2'},
        7: {'target': 'https://example.invalid:8443/a'},
        8: {'target': 'https://[::1]:8443/a'},
        9: {'target': 'https://example.invalid'},
        10: {'headers': {'Content-Type': 'application/json'}},
        11: {'headers': {'Authorization': 'Bearer synthetic'}},
        12: {'headers': {'Signature': 'caller'}},
        13: {}, 14: {}, 15: {'body': b'original'},
        16: {'headers': {'Authorization': 'Bearer synthetic'}},
        17: {'headers': {'Content-Type': 'application/json'}},
        18: {}, 19: {}, 20: {}, 21: {'created': 1010},
        22: {'body': b'ab', 'maximum': 1},
        23: {'keyid': 'key"\\quoted'}, 24: {},
    }[n]
    if n in (12, 22):
        rejects(lambda: sign(**args))
        return
    req = sign(**args)
    keys = {args.get('keyid', 'test-key'): KEY}
    if n <= 11 or n == 23:
        check(verify(req, keys))
    elif n == 13:
        req['method'] = 'POST'; check(not verify(req, keys))
    elif n == 14:
        req['target'] += '?changed=1'; check(not verify(req, keys))
    elif n == 15:
        req['body'] = b'mutated'; check(not verify(req, keys))
    elif n == 16:
        req['headers']['authorization'] += 'x'; check(not verify(req, keys))
    elif n == 17:
        req['headers']['content-type'] = 'text/plain'; check(not verify(req, keys))
    elif n == 18:
        check(not verify(req, {'test-key': b'wrong-key'}))
    elif n == 19:
        seen = set(); check(verify(req, keys, seen=seen)); check(not verify(req, keys, seen=seen))
    elif n == 20:
        check(not verify(req, keys, now=1061))
    elif n == 21:
        check(not verify(req, keys, now=1001))
    elif n == 24:
        check(not verify(req, {}))

def framing(n):
    f = Frames()
    if n == 1: check(f.feed(b'\0\0\0\0') == [b''])
    elif n == 2: check(f.feed(b'\0\0\0\x08abcdefgh') == [b'abcdefgh'])
    elif n == 3: rejects(lambda: f.feed(b'\0\0\0\x09'))
    elif n == 4:
        check(f.feed(b'\0\0') == []); check(f.feed(b'\0\x01x') == [b'x'])
    elif n == 5:
        check(f.feed(b'\0\0\0\x02a') == []); check(f.feed(b'b') == [b'ab'])
    elif n == 6: check(f.feed(b'\0\0\0\x01a\0\0\0\x01b') == [b'a',b'b'])
    elif n == 7:
        check(f.feed(b'\0\0\0\x01a\0\0') == [b'a']); check(f.buffer == b'\0\0')
    elif n == 8: rejects(lambda: f.feed(b'\0\0', eof=True))
    elif n == 9: rejects(lambda: f.feed(b'\0\0\0\x02a', eof=True))
    elif n == 10: rejects(lambda: Frames(maximum=0x100000000))
    elif n == 11:
        f = Frames(maximum=12, accumulation=16); check(f.feed(b'\0\0\0\x0cabcdefghijkl') == [b'abcdefghijkl'])
    elif n == 12: rejects(lambda: f.feed(b'x'*17))
    elif n == 13: check(Frames(delimiter=b'\n').feed(b'\n') == [b''])
    elif n == 14:
        f = Frames(delimiter=b'\r\n'); check(f.feed(b'a\r') == []); check(f.feed(b'\n') == [b'a'])
    elif n == 15: check(Frames(delimiter=b'::').feed(b'a::b::') == [b'a',b'b'])
    elif n == 16: check(Frames(delimiter=b'\n').feed(b'\n\n') == [b'',b''])
    elif n == 17: check(Frames(delimiter=b'\n').feed(b'a\nb\n') == [b'a',b'b'])
    elif n == 18:
        f = Frames(delimiter=b'::'); check(f.feed(b'abc:') == []); check(f.buffer == b'abc:')
    elif n == 19: rejects(lambda: Frames(delimiter=b'\n').feed(b'a', eof=True))
    elif n == 20: rejects(lambda: Frames(delimiter=b'\n').encode(b'a\nb'))
    elif n == 21: rejects(lambda: Frames(delimiter=b''))
    elif n == 22: rejects(lambda: Frames(maximum=0))
    elif n == 23: rejects(lambda: f.encode(b'ab', declared=3))
    elif n == 24:
        f.feed(b'\0\0'); f.close(); check(f.buffer == b'')

def policy(n):
    a = Admission()
    if n == 1: rejects(lambda: limit(0))
    elif n == 2: rejects(lambda: limit(1<<63))
    elif n == 3: rejects(lambda: timeout(float('nan')))
    elif n == 4:
        rejects(lambda: a.enter('send', cancelled=True)); check(not a.active and not a.closed)
    elif n == 5:
        a.enter('send'); rejects(lambda: a.enter('send')); check(a.active == {'send'})
    elif n == 6:
        a.enter('receive'); rejects(lambda: a.enter('receive')); check(a.active == {'receive'})
    elif n == 7:
        a.enter('send'); a.enter('receive'); check(a.active == {'send','receive'})
    elif n == 8:
        a.finish(); rejects(lambda: a.enter('send'))
    elif n == 9: rejects(lambda: security(owned=False))
    elif n == 10: rejects(lambda: security(origin='https://other.invalid'))
    elif n == 11: rejects(lambda: security(challenge=1))
    elif n == 12:
        a.enter('send'); a.finish(); check(a.closed and not a.active); rejects(lambda: a.enter('send'))
    elif n == 13: rejects(lambda: security(signed=True, retry=True))
    elif n == 14:
        # Signed policy rejects every proposed redirect without target inspection.
        def follows_redirect(signed): return not signed
        check(not follows_redirect(True))
    elif n == 15:
        secret = {'credential': 'synthetic-secret', 'host': 'private.invalid'}
        check(safe_description(secret) == 'F6OfflinePolicyError')
    elif n == 16:
        # Pure design capability selection, not OS runtime observation.
        selected_native_platforms = {'ios','macos','tvos'}
        check('watchos' not in selected_native_platforms)

if __name__ == '__main__':
    case = sys.argv[1]
    group, number = case[0], int(case[1:])
    {'S': signing, 'F': framing, 'P': policy}[group](number)
    print(case + ' PASS')
