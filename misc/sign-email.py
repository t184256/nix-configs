#!/usr/bin/env python3
# sign-email.py < message | msmtp -t

import hashlib
import sys

import gpg

KEY = 'B0E9DD20B29F1432'


raw = sys.stdin.buffer.read()
raw_u = raw.replace(b'\r\n', b'\n').decode('utf-8')
head, sep, body = raw_u.partition('\n\n')
assert sep, 'missing blank line after headers'

inner_boundary = '-' + hashlib.sha256(b'inner_boundary' + raw).hexdigest()[:26]
outer_boundary = '-' + hashlib.sha256(b'outer_boundary' + raw).hexdigest()[:26]

headers = {l.split(':', 1)[0].strip().lower() for l in head.split('\n') if l}
for h in ('to', 'from', 'subject', 'date', 'message-id'):
    assert h in headers, f'missing {h}'
assert 'content-type' not in headers
assert 'content-transfer-encoding' not in headers

inner = f'''Content-Type: multipart/mixed; protected-headers="v1"; hp="clear";
 boundary="{inner_boundary}"
MIME-Version: 1.0
{head}

--{inner_boundary}
Content-Type: text/plain; charset=UTF-8
Content-Transfer-Encoding: 8bit

{body}
--{inner_boundary}--
'''
inner_bytes = inner.replace('\n', '\r\n').encode('utf-8')

ctx = gpg.Context(armor=True)
ctx.signers = [ctx.get_key(KEY, secret=True)]
sig, _ = ctx.sign(inner_bytes, mode=gpg.constants.SIG_MODE_DETACH)
sig_armor = sig.decode('ascii').rstrip('\n')

outer = f'''{head}
MIME-Version: 1.0
Content-Type: multipart/signed; micalg=pgp-sha256;
 protocol="application/pgp-signature";
 boundary="{outer_boundary}"

This is an OpenPGP/MIME signed message (RFC 4880 and 3156)
--{outer_boundary}
{inner}
--{outer_boundary}
Content-Type: application/pgp-signature; name="signature.asc"

{sig_armor}
--{outer_boundary}--
'''.replace('\n', '\r\n').encode('utf-8')

assert inner_bytes in outer

sys.stdout.buffer.write(outer)
