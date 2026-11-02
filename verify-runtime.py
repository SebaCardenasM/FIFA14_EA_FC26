"""Reuse completed verification while a runtime file's size and time stay intact."""
from pathlib import Path
import hashlib
import json
import os


def main():
    root = Path(__file__).resolve().parent
    cache_path = root / '.runtime-verified.json'
    raw_manifest = (root / 'runtime.sha256').read_bytes()
    try:
        previous = json.loads(cache_path.read_text())
    except (OSError, ValueError):
        previous = {}
    if not isinstance(previous, dict):
        previous = {}
    offline = {}
    try:
        record = json.loads((root / '.runtime-offline-verified.json').read_text())
        if record['schema'] == 1 and record['runtime_manifest_sha256'] == hashlib.sha256(raw_manifest).hexdigest():
            offline = record['files']
    except (OSError, ValueError, KeyError, TypeError):
        pass
    if not isinstance(offline, dict):
        offline = {}
    checked = {}
    for line in raw_manifest.decode('utf-8').splitlines():
        digest, name = line.split(None, 1)
        name = name.strip()
        path = root / name
        stat = path.stat()
        identity = [digest, stat.st_size, stat.st_mtime_ns, stat.st_ctime_ns, stat.st_ino]
        large = stat.st_size >= 16 * 1024 * 1024
        cached = large and previous.get(name) == identity
        portable = offline.get(name)
        # exFAT timestamps can lose subsecond precision between Windows/Linux.
        # The offline record is emitted only after a complete SHA-256 audit on
        # this card; changed size/time or manifest falls back to a fresh hash.
        offline_cached = (large and isinstance(portable, list) and len(portable) == 3 and
                          isinstance(portable[2], int) and
                          portable[:2] == identity[:2] and
                          abs(portable[2] - stat.st_mtime_ns) <= 2_000_000_000)
        if not (cached or offline_cached):
            h = hashlib.sha256()
            with path.open('rb') as stream:
                for block in iter(lambda: stream.read(1024 * 1024), b''):
                    h.update(block)
            if h.hexdigest() != digest:
                raise SystemExit('Integrity check failed: ' + name)
        checked[name] = identity
        method = 'verified unchanged' if cached else ('verified offline; size/time unchanged' if offline_cached else 'SHA256 OK')
        print(name + ': ' + method, flush=True)
    temporary = cache_path.with_name(cache_path.name + '.' + str(os.getpid()) + '.tmp')
    with temporary.open('w') as stream:
        json.dump(checked, stream)
        stream.flush()
        os.fsync(stream.fileno())
    os.replace(str(temporary), str(cache_path))
    # Persist the just-verified large-file identities across reboot: exFAT
    # inode/ctime values can change even though content, size and mtime do not.
    # Small code/config files are always hashed; this is a verification cache,
    # never a save backup or a substitute for the first full hash check.
    offline_path = root / '.runtime-offline-verified.json'
    offline_temp = offline_path.with_name(offline_path.name + '.' + str(os.getpid()) + '.tmp')
    record = {'schema': 1,
              'runtime_manifest_sha256': hashlib.sha256(raw_manifest).hexdigest(),
              'files': {name: [identity[0], identity[1], identity[2]]
                        for name, identity in checked.items()}}
    with offline_temp.open('w') as stream:
        json.dump(record, stream)
        stream.flush()
        os.fsync(stream.fileno())
    os.replace(str(offline_temp), str(offline_path))


if __name__ == '__main__':
    main()
