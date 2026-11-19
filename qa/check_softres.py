from pathlib import Path
from lupa.lua54 import LuaRuntime
from lupa.lua51 import LuaRuntime as ClientLua

root=Path(__file__).resolve().parent.parent
client=ClientLua()
source=root/"NauseSoftReserve"
manifest=(source/(source.name+".toc")).read_text(encoding="utf-8")
assert "## Dependencies: NauseRaidTools" in manifest
for line in manifest.splitlines():
    if line.endswith(".lua"):
        file=source/line
        assert file.is_file(),line
        client.execute("assert(loadstring(...))",file.read_text(encoding="utf-8"))
print("PASS: SoftRes manifest and Lua 5.1 syntax",flush=True)
for name in ("test.lua","alpha55.lua","improvements.lua","delivery.lua","paced_sr.lua","nrt_integration.lua","solo_test.lua","group_test.lua","scenarios.lua","level_picker.lua","reservation_browser.lua","award_roll_lists.lua"):
    test=root/"qa/softres"/name
    lua=LuaRuntime(unpack_returned_tuples=True)
    lua.execute(test.read_text(encoding="utf-8"),root.as_posix(),root.as_posix(),name="@"+test.as_posix())
    print("PASS: SoftRes "+name,flush=True)
