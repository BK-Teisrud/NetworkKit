"""Non-shipping offline profile/framing models. No networking or credential access."""
import base64
import hashlib
import hmac
import math

KEY = bytes(range(32))  # Public synthetic bytes only.

def quoted(value):
    if not value or len(value) > 128 or any(ord(c) < 32 or ord(c) > 126 for c in value):
        raise ValueError('identifier')
    return '"' + value.replace('\\', '\\\\').replace('"', '\\"') + '"'

def sign(body=None, target='https://example.invalid/', method='GET', headers=None,
         key=KEY, keyid='test-key', created=1000, nonce='AAAAAAAAAAAAAAAAAAAAAA', maximum=64):
    body = b'' if body is None else body
    headers = {k.lower(): v for k, v in (headers or {}).items()}
    if maximum <= 0 or len(body) > maximum:
        raise ValueError('body-limit')
    if set(headers) & {'signature', 'signature-input', 'content-digest', 'content-encoding'}:
        raise ValueError('reserved')
    if not target.startswith('https://') or '#' in target or not method.isascii():
        raise ValueError('target')
    digest = 'sha-256=:' + base64.b64encode(hashlib.sha256(body).digest()).decode() + ':'
    covered = ['@method', '@target-uri', 'content-digest']
    covered += [x for x in ['content-type', 'authorization'] if x in headers]
    values = {'@method': method, '@target-uri': target, 'content-digest': digest, **headers}
    params = '(' + ' '.join('"' + x + '"' for x in covered) + ')'
    params += f';created={created};expires={created+60};nonce={quoted(nonce)};keyid={quoted(keyid)};alg="hmac-sha256"'
    base = '\n'.join('"' + name + '": ' + values[name] for name in covered)
    base += '\n"@signature-params": ' + params
    mac = base64.b64encode(hmac.digest(key, base.encode(), 'sha256')).decode()
    return {'body': body, 'target': target, 'method': method,
            'headers': {**headers, 'content-digest': digest,
                        'signature-input': 'sig1=' + params, 'signature': 'sig1=:' + mac + ':'}}

class Frames:
    def __init__(self, maximum=8, accumulation=16, delimiter=None):
        if not 0 < maximum <= 0xffffffff or not 0 < accumulation <= 0x7fffffffffffffff:
            raise ValueError('limit')
        if delimiter is not None and not 1 <= len(delimiter) <= 16:
            raise ValueError('delimiter')
        self.maximum, self.accumulation, self.delimiter = maximum, accumulation, delimiter
        self.buffer = b''

    def feed(self, data=b'', eof=False):
        if len(self.buffer) + len(data) > self.accumulation:
            raise ValueError('accumulation')
        self.buffer += data
        result = []
        while True:
            if self.delimiter is None:
                if len(self.buffer) < 4:
                    break
                count = int.from_bytes(self.buffer[:4], 'big')
                if count > self.maximum:
                    raise ValueError('length')
                if len(self.buffer) < 4 + count:
                    break
                result.append(self.buffer[4:4+count])
                self.buffer = self.buffer[4+count:]
            else:
                pos = self.buffer.find(self.delimiter)
                if pos < 0:
                    # Allow at most delimiter-length-minus-one bytes of a partial suffix.
                    suffix = max((n for n in range(1, len(self.delimiter))
                                  if self.buffer.endswith(self.delimiter[:n])), default=0)
                    if len(self.buffer) - suffix > self.maximum:
                        raise ValueError('length')
                    break
                if pos > self.maximum:
                    raise ValueError('length')
                result.append(self.buffer[:pos])
                self.buffer = self.buffer[pos+len(self.delimiter):]
        if eof and self.buffer:
            raise ValueError('truncated')
        return result

    def encode(self, payload, declared=None):
        if len(payload) > self.maximum or declared is not None and declared != len(payload):
            raise ValueError('length')
        if self.delimiter is not None:
            if self.delimiter in payload:
                raise ValueError('delimiter-in-payload')
            return payload + self.delimiter
        return len(payload).to_bytes(4, 'big') + payload

    def close(self):
        self.buffer = b''

class Admission:
    def __init__(self):
        self.closed = False
        self.active = set()
    def enter(self, direction, cancelled=False):
        if cancelled or self.closed or direction in self.active:
            raise ValueError('admission')
        self.active.add(direction)
    def finish(self):
        self.closed = True
        self.active.clear()

def limit(value):
    if type(value) is not int or not 0 < value <= 0x7fffffffffffffff:
        raise ValueError('limit')

def timeout(value):
    if not math.isfinite(value) or not 0 < value <= 86400:
        raise ValueError('timeout')

def security(owned=True, origin='https://example.invalid', challenge=0, signed=False, retry=False):
    if not owned or origin != 'https://example.invalid' or challenge != 0 or signed and retry:
        raise ValueError('policy')

def safe_description(_):
    return 'F6OfflinePolicyError'
