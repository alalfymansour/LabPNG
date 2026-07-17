import struct
import sys
import glob

for pattern in sys.argv[1:]:
    for path in glob.glob(pattern):
        with open(path, 'r+b') as f:
            data = bytearray(f.read())
            idx = data.find(b'\x51\xe5\x74\x64')
            if idx < 0:
                continue
            flags = struct.unpack_from('<I', data, idx + 4)[0]
            new_flags = flags & ~1
            struct.pack_into('<I', data, idx + 4, new_flags)
            f.seek(0)
            f.write(data)
            print(f'Fixed: {path}  {flags:#x} -> {new_flags:#x}')
