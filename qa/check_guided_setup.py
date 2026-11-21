
from pathlib import Path
import ast
from lupa.lua51 import LuaRuntime

root=Path(__file__).resolve().parent.parent
tree=ast.parse((root/'qa/check_reason_dropdown.py').read_text(encoding='utf-8'))
frames=next(ast.literal_eval(n.value) for n in tree.body if isinstance(n,ast.Assign)
            and any(isinstance(t,ast.Name) and t.id=='FRAMES' for t in n.targets))
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute(frames)
lua.execute('''SlashCmdList={}
local create=CreateFrame
function CreateFrame(...)
    local frame=create(...)
    function frame:CreateTexture() return create('Texture',nil,self) end
    function frame:GetPushedTexture() return create('Texture',nil,self) end
    return frame
end
''')
for name in ('Core','Features','Voting','ResponseConfig','Responses','LootConfiguration','Warnings','MasterLooter','Recovery','LootConfigurationUI','SettingsUI'):
    lua.execute((root/'NauseRaidTools'/f'{name}.lua').read_text(encoding='utf-8'),'NauseRaidTools',lua.globals().A)
lua.execute('''
A.me='Leader-Realm';A.leader=A.me;A.gameLeader=A.me
A.roster={[A.me]='raid1',['Council-Realm']='raid2',['Assistant-Realm']='raid3'}
A.Client={}
local raid,combat,gameMaster=true,false,nil
function A.Client:InGroup() return raid end
function A.Client:InRaid() return raid end
function A.Client:ClockReady() return true end
function A.Client:Combat() return combat end
function A.Client:ServerTime() return 100 end
function A:ReadGameMaster() return gameMaster,'none' end
function A:IsRaidAssistant(name) return name=='Assistant-Realm' end
function A:Changed() end
function A:Print(message) self.lastMessage=message end
function A:HostRequest(sender,request)
    if request.op=='start' then
        self.startedWith=self:RaidSettings()
        self.state={id='started'}
        return true
    end
end
A:InitStorage()
local original=A:RaidSettings()
local draft=A:NewRaidSetupDraft()
draft.settings.council['Council-Realm']=true
draft.settings.recoveryAssistant='Assistant-Realm'
draft.settings.responseDuration=90
assert(not A:RaidSettings().council['Council-Realm'],'draft leaked into saved settings')
local summary,issues=A:RaidSetupReview(draft)
assert(summary:find('90 seconds',1,true) and #issues==0)
draft.settings.council['Absent-Realm']=true
local _,issues=A:RaidSetupReview(draft)
assert(table.concat(issues):find('absent',1,true))
assert(A:ApplyRaidSetupDraft(draft,'Guild Raid',false))
assert(A:RaidSettings().responseDuration==90 and not A.state)
assert(NauseRaidToolsDB.profiles['Guild Raid'].recoveryAssistant=='Assistant-Realm')
assert(A:LoadProfile('Guild Raid'))
assert(A:RaidSettings().recoveryAssistant=='Assistant-Realm')
assert(not A:ApplyRaidSetupDraft(draft,'',false),'stale draft replaced newer setup')
draft=A:NewRaidSetupDraft()
draft.settings.responseOptions[1].label='Pass'
assert(not A:ApplyRaidSetupDraft(draft,'',false),'duplicate response accepted')
draft=A:NewRaidSetupDraft()
assert(not A:ApplyRaidSetupDraft(draft,'Guild Raid',false),'existing profile overwritten')
gameMaster='Council-Realm'
assert(not A:ApplyRaidSetupDraft(draft,'',true),'unreviewed game Master Looter accepted')
draft=A:NewRaidSetupDraft()
local _,issues=A:RaidSetupReview(draft)
assert(table.concat(issues):find('instead of saved Master Looter',1,true))
combat=true
assert(not A:ApplyRaidSetupDraft(draft,'',true))
combat=false
A.gameLeader='Council-Realm'
assert(not A:ApplyRaidSetupDraft(draft,'',false),'nonleader applied setup')
A.gameLeader=A.me
assert(A:ApplyRaidSetupDraft(draft,'',true))
assert(A.startedWith.master=='Council-Realm' and A.startedWith.responseDuration==90)
A.state=nil

-- Build the actual wizard and exercise all four pages with the shared UI fixture.
function A:StyleRailArrow() end
function A:StyleCrossButton() end
function A:BindSettingsDropdown(control,choices,apply) control.choices=choices;control.apply=apply end
function A:CreateScrollFrame(parent)
    local frame=CreateFrame('ScrollFrame',nil,parent)
    function frame:SetScrollChild(child) self.child=child end
    return frame
end
function A:AddonIssues() return {} end
function A:RosterKey() return 'roster' end
function A:ProbeScope() return false end
local function window(name,title,w,h)
    local frame=CreateFrame('Frame',name,UIParent);frame:SetSize(w,h);return frame
end
local function text(parent,label)
    local frame=CreateFrame('FontString',nil,parent);frame:SetText(label)
    function frame:GetStringHeight() return 400 end
    return frame
end
local function button(parent,label,x,y,w,action)
    local frame=CreateFrame('Button',nil,parent);frame:SetText(label);frame:SetScript('OnClick',action);return frame
end
local function edit(parent)
    local frame=CreateFrame('EditBox',nil,parent);frame.hint=text(frame,'');return frame
end
A.ui={}
A:BuildRaidSetupUI(A.ui,window,text,button,edit)
A.raidSetupDraft=A:NewRaidSetupDraft()
local p=A.ui.raidSetup
for step=1,4 do
    A.raidSetupDraft.step=step
    A:RenderRaidSetup()
    assert(p.pages[step]:IsShown())
end
assert(p.review:GetText():find('Run Pre-Raid Loot Check',1,true))
assert(p.start:IsEnabled())
A.raidSetupDraft.step=2
A:RenderRaidSetup()
local count=#A.raidSetupDraft.settings.responseOptions
p.addTransmog:Click()
local options=A.raidSetupDraft.settings.responseOptions
assert(#options==count+1 and options[#options].id==6)
local tmog=options[#options-1]
assert(tmog.transmog and tmog.label=='Transmog' and tmog.enabled)
assert(A:CleanResponses(options))
assert(p.addTransmog:IsEnabled() and p.addTransmog:GetText()=='Remove Transmog')
p.addTransmog:Click()
assert(#A.raidSetupDraft.settings.responseOptions==count)
assert(p.addTransmog:GetText()=='Add Transmog')
assert(A.raidSetupDraft.settings.responseOptions[count].id==6)
p.addTransmog:Click()
options=A.raidSetupDraft.settings.responseOptions
assert(#options==count+1 and options[#options-1].transmog)
options[#options-1].enabled=false
A:RenderRaidSetup()
assert(p.addTransmog:GetText()=='Remove Transmog' and p.addTransmog:IsEnabled())
p.addTransmog:Click()
assert(#A.raidSetupDraft.settings.responseOptions==count)
assert(#A:RaidSettings().responseOptions==count,'Transmog escaped the setup draft')
local first=A.raidSetupDraft.settings.responseOptions[1].id
p.responses[1].down:Click()
assert(A.raidSetupDraft.settings.responseOptions[2].id==first)
p.responses[2].up:Click()
assert(A.raidSetupDraft.settings.responseOptions[1].id==first)
local savedCount=#A:RaidSettings().responseOptions
p.addResponse:Click()
local added=#A.raidSetupDraft.settings.responseOptions
assert(added==count+1)
p.responses[added-1].remove:Click()
assert(#A.raidSetupDraft.settings.responseOptions==count)
assert(not p.responses[count].remove:IsEnabled())
assert(not A:EditSetupResponse(count,'remove'))
assert(#A:RaidSettings().responseOptions==savedCount)

A.raidSetupDraft.step=4
p.back:Click();assert(A.raidSetupDraft.step==3)
local before=A:RaidSettings().lootConfiguration.collection
p.collection:Click()
assert(A.raidSetupDraft.settings.lootConfiguration.collection~=before)
assert(A:RaidSettings().lootConfiguration.collection==before)
''')
print('Guided setup passed draft isolation, profile roundtrip, roster review, stale edits, role changes, validation and four-page rendering.')
