#!/usr/bin/env python3
"""Apply shared Godot 4.4.1 bytecode to a verified native Android baseline.

Native libraries, DEX, permissions, weather/updater plugins and raw fish assets
stay byte-identical. Signing is a separate protected-server operation.
"""
import argparse
import hashlib
from pathlib import Path
import struct
import zipfile

from verify_pack import entries

BASE_SHA = 'b4cefabd459f42c7196fb785ffca71025faa9d927f4ad836fd848e4e3e097702'

def manifest_version(data, old_code, new_code, old_name, new_name):
    old = old_name.encode('utf-16-le'); new = new_name.encode('utf-16-le')
    if len(old) != len(new) or data.count(old) != 1:
        raise ValueError('Manifest string pool requires one same-length version name')
    output = bytearray(data.replace(old, new))
    u16 = lambda p: struct.unpack_from('<H', output, p)[0]
    u32 = lambda p: struct.unpack_from('<I', output, p)[0]
    pool = 8
    if u16(pool) != 1 or u32(pool + 16) & 0x100:
        raise ValueError('Expected UTF-16 Android manifest string pool')
    strings = pool + u32(pool + 20)
    names = []
    for i in range(u32(pool + 8)):
        p = strings + u32(pool + 28 + i * 4)
        names.append(output[p + 2:p + 2 + u16(p) * 2].decode('utf-16-le'))
    version_code = names.index('versionCode')
    debuggable = names.index('debuggable')
    debug_changed = 0
    p = pool + u32(pool + 4); changed = 0
    while p + 8 <= len(output):
        size = u32(p + 4)
        if size < 8: raise ValueError('Invalid manifest chunk')
        if u16(p) == 0x102:
            start, width, count = struct.unpack_from('<HHH', output, p + 24)
            for i in range(count):
                at = p + 16 + start + i * width
                if u32(at + 4) == debuggable:
                    if output[at + 15] != 0x12: raise ValueError('Expected typed debuggable boolean')
                    struct.pack_into('<I', output, at + 16, 0); debug_changed += 1
                if u32(at + 4) == version_code:
                    if u32(at + 16) != old_code: raise ValueError('Baseline version code differs')
                    struct.pack_into('<I', output, at + 16, new_code); changed += 1
        p += size
    if debug_changed != 1: raise ValueError('Expected one explicit debuggable attribute')
    if changed != 1: raise ValueError('Expected one manifest versionCode')
    return bytes(output)

def build(base, pack, output):
    if hashlib.sha256(base.read_bytes()).hexdigest() != BASE_SHA:
        raise ValueError('Unverified Android baseline')
    table = entries(pack); patches = {}
    with pack.open('rb') as source:
        for path, (offset, size, checksum, flags) in table.items():
            if not (path.startswith('companion/') and path.endswith(('.gdc', '.gd.remap'))) and path != 'project.binary':
                continue
            source.seek(offset); data = source.read(size)
            if flags or hashlib.md5(data).hexdigest() != checksum:
                raise ValueError('Corrupt shared pack entry: ' + path)
            if path.endswith('.gdc') and (data[:4] != b'GDSC' or struct.unpack_from('<I', data, 4)[0] != 100):
                raise ValueError('Bytecode must match Godot 4.4.1: ' + path)
            patches['assets/' + path] = data
    for needed in ['main', 'courtyard_ui', 'scene_effects', 'calendar_effects', 'ios_platform']:
        if 'assets/companion/' + needed + '.gdc' not in patches:
            raise ValueError('Shared source is missing ' + needed)
    output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(base) as source, zipfile.ZipFile(output, 'w') as target:
        written = set()
        for item in source.infolist():
            name = item.filename
            if name.startswith('META-INF/') and name.upper().endswith(('.RSA', '.DSA', '.EC', '.SF', 'MANIFEST.MF')):
                continue
            data = patches.get(name, source.read(name))
            if name == 'AndroidManifest.xml':
                data = manifest_version(data, 212, 217, '1.4.2', '1.5.0')
            target.writestr(item, data); written.add(name)
        for name, data in patches.items():
            if name not in written: target.writestr(name, data, compress_type=zipfile.ZIP_DEFLATED)
    with zipfile.ZipFile(base) as source, zipfile.ZipFile(output) as target:
        if target.testzip() is not None: raise ValueError('Corrupt APK')
        untouched = 0
        for name in target.namelist():
            if name not in patches and name != 'AndroidManifest.xml':
                if source.read(name) != target.read(name): raise ValueError('Unexpected native/asset mutation: ' + name)
                untouched += 1
    return {'shared_entries': len(patches), 'unchanged_entries': untouched,
            'sha256': hashlib.sha256(output.read_bytes()).hexdigest(), 'bytes': output.stat().st_size}

if __name__ == '__main__':
    import json
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--base', type=Path, required=True)
    parser.add_argument('--pack', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    print(json.dumps(build(args.base, args.pack, args.output), indent=2))
