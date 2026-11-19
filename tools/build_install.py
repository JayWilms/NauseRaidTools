from pathlib import Path
import hashlib
import re
import zipfile

root = Path(__file__).resolve().parent.parent
(root / 'work').mkdir(exist_ok=True)
(root / 'outputs').mkdir(exist_ok=True)
source = root / 'NauseRaidTools'
toc = (source / 'NauseRaidTools.toc').read_text(encoding='utf-8')
version = re.search(r'^## Version: (.+)$', toc, re.M).group(1).strip()
core = (source / 'Core.lua').read_text(encoding='utf-8')
assert f'A.version = "{version}"' in core
protocol = int(re.search(r'^A\.protocol = (\d+)$', core, re.M).group(1))
assert core.count('self.state.responseDuration=60') == 2
addons = [source, root / 'NauseSoftReserve']
files = sorted(p for addon in addons for p in addon.rglob('*') if p.is_file())
assert len([p for p in source.rglob('*') if p.is_file()]) == 41
assert all((addon / (addon.name + '.toc')).is_file() for addon in addons)
output = root / 'outputs' / f'NauseRaidTools-{version}-install.zip'
staged = root / 'work' / f'NauseRaidTools-{version}-verified.zip'
with zipfile.ZipFile(staged, 'w', compression=zipfile.ZIP_DEFLATED) as archive:
    for file in files:
        archive.write(file, file.relative_to(root).as_posix())
with zipfile.ZipFile(staged) as archive:
    assert archive.testzip() is None
    assert len(archive.namelist()) == len(files)
    for file in files:
        assert archive.read(file.relative_to(root).as_posix()) == file.read_bytes()
    for addon in addons:
        manifest = (addon / (addon.name + '.toc')).read_text(encoding='utf-8')
        for line in manifest.splitlines():
            if line.strip() and not line.startswith('#'):
                assert addon.name + '/' + line.replace(chr(92), '/') in archive.namelist()
staged.replace(output)
print(f'Built and verified {version}: {len(files)} files across two addons, complete manifests, protocol {protocol}.')
print(output)
print('SHA256:', hashlib.sha256(output.read_bytes()).hexdigest())
