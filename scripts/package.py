"""Package the selected edition without creating installation backups."""
import argparse
import hashlib
import json
import re
from pathlib import Path
import zipfile

ROOT = Path(__file__).resolve().parent.parent
EDITIONS = {
    'de': ('de', 'Ori-Smooth-fix-DE-v4.0.0'),
    'classic': ('classic', 'Ori-Smooth-fix-Classic-v1.0.0-experimental'),
}

def digest(data):
    return hashlib.sha256(data).hexdigest().upper()

def package(edition):
    folder, name = EDITIONS[edition]
    source = ROOT / folder
    if edition == 'de':
        for required in ['Payload/oriDE_Data/Managed/Assembly-CSharp.dll',
                         'Payload/oriDE_Data/Managed/OriMotionSmoothing.dll']:
            if not (source / required).is_file():
                raise SystemExit('Build DE first; missing ' + required)
    files = []
    for path in sorted(source.rglob('*')):
        relative = path.relative_to(source)
        if not path.is_file() or any(part in {'Build', '.intermediate', '__pycache__', '.git'} for part in relative.parts):
            continue
        if path.name == 'SHA256SUMS.txt':
            continue
        if path.suffix.lower() in {'.sav', '.vdf', '.bak', '.log', '.zip'}:
            raise SystemExit('Unexpected private or temporary file: ' + str(relative))
        data = path.read_bytes()
        private_home = str(Path.home())
        private_paths = (private_home, private_home.replace('\\', '/'))
        contains_local_path = any(path.encode('utf-8') in data or path.encode('utf-16-le') in data for path in private_paths)
        contains_key = path.suffix.lower() in {'.ps1', '.py', '.cs', '.json', '.md', '.txt', '.cmd'} and re.search(rb'(?<![A-Za-z0-9])sk-[A-Za-z0-9]{20,}', data)
        if contains_local_path or contains_key:
            raise SystemExit('Unexpected local path or credential: ' + str(relative))
        files.append((relative.as_posix(), data))
    if not (source / 'Install.cmd').is_file():
        raise SystemExit('Missing Install.cmd')
    sums = ''.join(digest(data) + '  ' + relative + '\n' for relative, data in files)
    files.append(('SHA256SUMS.txt', sums.encode('utf-8')))
    destination = ROOT / 'dist'
    destination.mkdir(exist_ok=True)
    archive = destination / (name + '.zip')
    with zipfile.ZipFile(archive, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=9) as bundle:
        for relative, data in files:
            bundle.writestr(name + '/' + relative, data)
    with zipfile.ZipFile(archive) as bundle:
        if bundle.testzip() is not None:
            raise SystemExit('ZIP CRC validation failed')
        for relative, data in files:
            if bundle.read(name + '/' + relative) != data:
                raise SystemExit('ZIP content differs: ' + relative)
    summary = {'archive': archive.name, 'edition': edition, 'files': len(files),
               'bytes': archive.stat().st_size, 'sha256': digest(archive.read_bytes())}
    (destination / (name + '.sha256.txt')).write_text(summary['sha256'] + '  ' + archive.name + '\n', encoding='ascii')
    print(json.dumps(summary, indent=2))

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--edition', choices=EDITIONS, required=True)
    package(parser.parse_args().edition)
