#!/usr/bin/env python3
"""Validate the packaged model, Android permissions and ELF load alignment.
Usage: python tools/check_apk.py path/to/app-debug.apk --aapt2 /path/to/aapt2
"""
import argparse
import hashlib
import json
import re
import struct
import subprocess
import zipfile
from pathlib import Path

p = argparse.ArgumentParser()
p.add_argument('apk', type=Path)
p.add_argument('--aapt2', required=True)
p.add_argument('--output', type=Path)
a = p.parse_args()
permissions_text = subprocess.check_output([a.aapt2, 'dump', 'permissions', str(a.apk)], text=True)
permissions = re.findall(r"uses-permission: name='([^']+)'", permissions_text)
required = {'android.permission.CAMERA', 'android.permission.FOREGROUND_SERVICE',
            'android.permission.FOREGROUND_SERVICE_CAMERA', 'android.permission.SYSTEM_ALERT_WINDOW',
            'android.permission.POST_NOTIFICATIONS', 'android.permission.VIBRATE'}
assert required <= set(permissions)
for forbidden in ['INTERNET', 'RECEIVE_BOOT_COMPLETED', 'ACCESS_NETWORK_STATE', 'WAKE_LOCK',
                  'FOREGROUND_SERVICE_DATA_SYNC', 'RECORD_AUDIO', 'WRITE_EXTERNAL_STORAGE']:
    assert f'android.permission.{forbidden}' not in permissions, forbidden
alignment = {}
zip_alignment = {}
with zipfile.ZipFile(a.apk) as z:
    model = z.read('assets/models/efficientdet_lite0.tflite')
    checksum = hashlib.sha256(model).hexdigest()
    assert checksum == '2e04c53bfeac0ac2a30c057c7e2a777594ce39baaac35a92f74fb1e8c4fc4e0b'
    assert z.getinfo('assets/models/efficientdet_lite0.tflite').compress_type == zipfile.ZIP_STORED
    for name in z.namelist():
        if not name.startswith('lib/') or not name.endswith('.so'):
            continue
        info = z.getinfo(name)
        with a.apk.open('rb') as file:
            file.seek(info.header_offset + 26)
            filename_length, extra_length = struct.unpack('<HH', file.read(4))
        data_offset = info.header_offset + 30 + filename_length + extra_length
        assert info.compress_type == zipfile.ZIP_STORED
        assert data_offset % 16384 == 0, f'{name}: ZIP alignment below 16 KB'
        zip_alignment[name] = data_offset
        b = z.read(name)
        assert b[:4] == b'\x7fELF'
        is64 = b[4] == 2
        phoff = struct.unpack_from('<Q' if is64 else '<I', b, 32 if is64 else 28)[0]
        phsize, phnum = struct.unpack_from('<HH', b, 54 if is64 else 42)
        aligns = []
        for i in range(phnum):
            off = phoff + i * phsize
            if struct.unpack_from('<I', b, off)[0] == 1:
                aligns.append(struct.unpack_from('<Q' if is64 else '<I', b, off + (48 if is64 else 28))[0])
        alignment[name] = aligns
        assert all(v >= 16384 for v in aligns), f'{name}: ELF alignment below 16 KB'
result = {'apk': a.apk.name, 'apk_bytes': a.apk.stat().st_size,
          'sha256': hashlib.sha256(a.apk.read_bytes()).hexdigest(),
          'permissions': permissions, 'embedded_model_sha256': checksum,
          'model_uncompressed': True, 'native_zip_offsets_aligned_16kb': zip_alignment, 'elf_load_alignment': alignment}
print(json.dumps(result, indent=2))
if a.output:
    a.output.parent.mkdir(parents=True, exist_ok=True)
    a.output.write_text(json.dumps(result, indent=2) + '\n')
