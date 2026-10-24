#!/usr/bin/env python3
"""211 interaction/location update, retaining verified native/weather/assets from210."""
from pathlib import Path
import argparse, hashlib, struct, zipfile, json
from urllib.parse import urlparse

def require(condition, message):
    if not condition:
        raise ValueError(message)
BASE_SHA = 'c4f6881b5035edcedb9e6fc5e15cc36a1287ec35aa451f4baaec251fa76e3529'
NAMES = ['main', 'actor', 'world', 'fish_actor', 'duet', 'duet_props', 'interaction_poses', 'location_name', 'android_bridge']

def manifest(data):
    b = bytearray(data)
    old = '1.4.0'.encode('utf-16-le')
    require(b.count(old) == 1, 'package invariant failed')
    b = b.replace(old, '1.4.1'.encode('utf-16-le'))

    def u16(p):
        return struct.unpack_from('<H', b, p)[0]

    def u32(p):
        return struct.unpack_from('<I', b, p)[0]
    start = 8 + u32(28)
    names = []
    for i in range(u32(16)):
        p = start + u32(36 + i * 4)
        n = u16(p)
        names.append(b[p + 2:p + 2 + n * 2].decode('utf-16-le'))
    idx = names.index('versionCode')
    p = 8 + u32(12)
    changed = 0
    while p + 8 <= len(b):
        size = u32(p + 4)
        require(size >= 8, 'package invariant failed')
        if u16(p) == 258:
            ast, asz, cnt = struct.unpack_from('<HHH', b, p + 24)
            for i in range(cnt):
                at = p + 16 + ast + i * asz
                if u32(at + 4) == idx:
                    require(u32(at + 16) == 210, 'package invariant failed')
                    struct.pack_into('<I', b, at + 16, 211)
                    changed += 1
        p += size
    require(changed == 1, 'package invariant failed')
    return bytes(b)

def main():
    p = argparse.ArgumentParser()
    for name in ['base', 'compiled', 'poses', 'release-config', 'geocoder-dex', 'output']:
        p.add_argument('--' + name, type=Path, required=True)
    a = p.parse_args()
    require(hashlib.sha256(a.base.read_bytes()).hexdigest() == BASE_SHA, 'package invariant failed')
    patches = {'assets/companion/' + n + '.gdc': (a.compiled / (n + '.gdc')).read_bytes() for n in NAMES}
    for data in patches.values():
        require(data[:4] == b'GDSC' and struct.unpack_from('<I', data, 4)[0] == 100, 'package invariant failed')
    for n in NAMES:
        patches['assets/companion/' + n + '.gd.remap'] = ('[remap]\n\npath="res://companion/' + n + '.gdc"\n').encode()
    config = json.loads(a.release_config.read_text())
    require(set(config) == {'update_url'} and isinstance(config['update_url'], str), 'package invariant failed')
    require(not any((ord(c) <= 32 or ord(c) == 127 for c in config['update_url'])), 'package invariant failed')
    url = urlparse(config['update_url'])
    require(url.scheme == 'https' and url.hostname and (not url.username) and (not url.password) and (not url.fragment), 'package invariant failed')
    patches['classes6.dex'] = a.geocoder_dex.read_bytes()
    require(patches['classes6.dex'][:4] == b'dex\n', 'package invariant failed')
    patches['assets/companion/release.json'] = json.dumps(config, ensure_ascii=False, separators=(',', ':')).encode()
    patches['assets/companion/art/interaction-poses-v1.png'] = a.poses.read_bytes()
    with zipfile.ZipFile(a.base) as src, zipfile.ZipFile(a.output, 'w') as out:
        done = set()
        for item in src.infolist():
            n = item.filename
            if n.startswith('META-INF/') and n.upper().endswith(('.RSA', '.DSA', '.EC', '.SF', 'MANIFEST.MF')):
                continue
            data = patches.get(n, src.read(n))
            if n == 'AndroidManifest.xml':
                data = manifest(data)
            out.writestr(item, data)
            done.add(n)
        for n, d in patches.items():
            if n not in done:
                out.writestr(n, d)
    with zipfile.ZipFile(a.base) as src, zipfile.ZipFile(a.output) as out:
        require(out.testzip() is None, 'package invariant failed')
        for n in out.namelist():
            if n in patches or n == 'AndroidManifest.xml':
                continue
            require(src.read(n) == out.read(n), n)
    print('UNSIGNED_211', hashlib.sha256(a.output.read_bytes()).hexdigest())
if __name__ == '__main__':
    main()
