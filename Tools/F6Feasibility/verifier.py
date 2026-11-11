"""Independent fixed-profile verifier; never imports the candidate or its base builder."""
import base64
import hashlib
import hmac
import re

_PATTERN = re.compile(r'^sig1=\((.*?)\);created=(\d+);expires=(\d+);nonce="((?:[^"\\]|\\["\\])*)";keyid="((?:[^"\\]|\\["\\])*)";alg="hmac-sha256"$')

def unquote(s):
    return re.sub(r'\\(["\\])', r'\1', s)

def verify(request, keys, now=1001, seen=None):
    seen = set() if seen is None else seen
    try:
        fields = request['headers']
        match = _PATTERN.fullmatch(fields['signature-input'])
        if not match:
            return False
        components, created, expires, nonce, keyid = match.groups()
        created, expires = int(created), int(expires)
        nonce, keyid = unquote(nonce), unquote(keyid)
        names = re.findall(r'"([a-z@-]+)"', components)
        required = ['@method', '@target-uri', 'content-digest']
        if 'content-type' in fields:
            required.append('content-type')
        if 'authorization' in fields:
            required.append('authorization')
        if names != required or components != ' '.join('"'+n+'"' for n in names):
            return False
        if expires-created != 60 or now > expires or created > now+5 or (keyid, nonce) in seen:
            return False
        if keyid not in keys:
            return False
        digest = base64.b64encode(hashlib.sha256(request['body']).digest()).decode('ascii')
        if fields['content-digest'] != 'sha-256=:' + digest + ':':
            return False
        # Reconstruct without calling the candidate's encoder or serializer.
        lines = []
        for name in names:
            value = request['method'] if name == '@method' else request['target'] if name == '@target-uri' else fields[name]
            lines.append('"%s": %s' % (name, value))
        lines.append('"@signature-params": ' + fields['signature-input'][5:])
        expected = hmac.new(keys[keyid], '\n'.join(lines).encode('utf-8'), hashlib.sha256).digest()
        encoded = fields['signature']
        if not encoded.startswith('sig1=:') or not encoded.endswith(':'):
            return False
        actual = base64.b64decode(encoded[6:-1], validate=True)
        if not hmac.compare_digest(expected, actual):
            return False
        seen.add((keyid, nonce))
        return True
    except (KeyError, ValueError, TypeError):
        return False
