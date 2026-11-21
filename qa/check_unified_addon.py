from pathlib import Path
from lupa.lua54 import LuaRuntime
from lupa.lua51 import LuaRuntime as ClientLua
root=Path(__file__).resolve().parent.parent
source=root/'NauseRaidTools'
toc=(source/'NauseRaidTools.toc').read_text(encoding='utf-8')
assert 'NauseSoftReserveDB' in toc and '## Dependencies:' not in toc
assert len(list(root.glob('*/Nause*.toc')))==1
assert len(list(source.rglob('*'))) > 80
syntax=ClientLua()
for line in toc.splitlines():
    if line.endswith('.lua'):
        syntax.execute('assert(loadstring(...))',(source/line).read_text(encoding='utf-8'))
p=root/'qa/unified_addon.lua'
LuaRuntime(unpack_returned_tuples=True).execute(p.read_text(encoding='utf-8'),root.as_posix(),name='@'+p.as_posix())
