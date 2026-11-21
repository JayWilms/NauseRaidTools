from pathlib import Path
from lupa.lua54 import LuaRuntime
from lupa.lua51 import LuaRuntime as ClientLua
root=Path(__file__).resolve().parent.parent
client=ClientLua()
for name in ('UI.lua','LootUI.lua','RaiderUI.lua','CouncilUI.lua','WindowLayouts.lua','RaidAssignmentBoard.lua','SettingsUI.lua'):
    client.execute('assert(loadstring(...))',(root/'NauseRaidTools'/name).read_text(encoding='utf-8'))
p=root/'qa/lc_scroll.lua'
LuaRuntime(unpack_returned_tuples=True).execute(p.read_text(encoding='utf-8'),root.as_posix(),name='@'+p.as_posix())
