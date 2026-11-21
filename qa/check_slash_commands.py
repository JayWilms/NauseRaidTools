from pathlib import Path
import re

from lupa.lua51 import LuaRuntime

source = Path(__file__).resolve().parent.parent / 'NauseRaidTools'
manifest=source/(source.name+'.toc')
assert manifest.is_file(), 'Folder and TOC name differ'
toc=manifest.read_text(encoding='utf-8')
assert '## Title: Nause Raid Tools' in toc
assert '## SavedVariables: NauseRaidToolsDB' in toc
for path in source.glob('*.lua'):
    code=path.read_text(encoding='utf-8')
    assert 'Sanguine' not in code and '/slt' not in code, path.name
    normalized=code.replace(chr(92)+chr(92),'/').replace(chr(92),'/')
    for asset in re.findall(r'Interface/AddOns/([^"]+\.tga)',normalized):
        addon,relative=asset.split('/',1)
        assert addon==source.name and (source/relative).is_file(), asset
lua = LuaRuntime()
lua.execute("""
A={}; SlashCmdList={}
function CreateFrame()
    return {scripts={},RegisterEvent=function() end, SetScript=function(self,event,callback) self.scripts[event]=callback end}
end
""")
for line in toc.splitlines():
    if line.endswith('.lua') and not line.startswith('SoftRes/'):
        lua.execute((source / line).read_text(encoding='utf-8'), source.name, lua.globals().A)

lua.execute("""
local player='Leader-Forever'
local grouped=false
function A.Client:ClockReady() return true end
function A.Client:Combat() return false end
function A.Client:InGroup() return grouped end
function A.Client:InRaid() return false end
function A.Client:ServerTime() return 100 end
function A:Name(unit) if unit=='player' then return player end end
function UnitIsGroupLeader(unit) return grouped and unit=='player' end
function A:Print() end
function A:Publish() end
function A:Changed() self:Render() end
function A:RequestSync() end

local launcher={nrtManagedWindow=true,Show=function(self) self.shown=true end, IsShown=function(self) return self.shown end}
local other={nrtManagedWindow=true, IsShown=function() return true end}
local text={SetText=function(self,value) self.value=value end}
A.ui={launcher=launcher,raidMemberHelp={Show=function() end},masterStatus=text,masterCouncil={SetText=function() end}}
function A:BuildUI() end
function A:Render() self:RenderMasterSettings() end
function A:RefreshWindowLayers() end

local registered
C_ChatInfo={RegisterAddonMessagePrefix=function(prefix) registered=prefix;return true end}
assert(NauseRaidTools==A and SLASH_NAUSERAIDTOOLS1=="/nrt")
A.events.scripts.OnEvent(A.events,"ADDON_LOADED","NauseRaidTools")
assert(NauseRaidToolsDB and registered=="NauseRT")
local function command(input)
    local verb,arguments=input:match("^(%S+)%s*(.-)%s*$")
    assert(verb==SLASH_NAUSERAIDTOOLS1)
    return SlashCmdList.NAUSERAIDTOOLS(arguments)
end
local slash=function(input) return command("/nrt "..input) end
A:RefreshRoster()
assert(A.gameLeader==false)
for attempt=1,2 do
    A:StartDemo()
    assert(A:IsSoloTest() and A.state.master==player)
    assert(A.state.responseDuration==60 and #A.state.trackedLoot>0)
end
A:LeaveTest()
assert(not A.demo and not A.state)

grouped=true
for attempt=1,2 do
    A:StartDemo()
    assert(A.groupTest and A.state.groupTest and A.state.master==player)
    assert(A.state.responseDuration==60 and #A.state.trackedLoot>0)
end
A:LeaveTest()
assert(not A.demo and not A.state)

slash('')
assert(launcher.shown and A.windowStack[#A.windowStack]==launcher)
A:FocusWindow(other)
assert(A.windowStack[#A.windowStack]==other)
slash('')
assert(A.windowStack[#A.windowStack]==launcher)
""")
