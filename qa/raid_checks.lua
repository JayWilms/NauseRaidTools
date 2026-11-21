local root=...
local make=assert(loadfile(root.."/qa/softres/improvements_client.lua"))(root,root)
local a,e=make("Lead-Realm")
local count=0;local function check(value,message) count=count+1;assert(value,message) end
local now=100;local readyCalls=0;local chats={};local secret={}
local names={"Lead-Realm","Mage-Realm","Tank-Realm","Far-Realm","Offline-Realm","Dead-Realm"}
local classes={"PRIEST","MAGE","WARRIOR","DRUID","ROGUE","WARLOCK"}
local auras={{1243,1126,1459,19705,17626},{21564,21850,23028,18194,17538},{1126},{},{},{}}
local online={true,true,true,true,false,true};local dead={false,false,false,false,false,true}
local visible={true,true,true,false,true,true};local readUnits={}
local function unitIndex(unit) return unit=="player" and 1 or tonumber((unit or ""):match("raid(%d+)")) end
local leader=1;local assistant=false
local spellNames={[1243]="Power Word: Fortitude",[21562]="Prayer of Fortitude",[1126]="Mark of the Wild",[21849]="Gift of the Wild",[1459]="Arcane Intellect",[23028]="Arcane Brilliance",[19705]="Well Fed",[18194]="Mana Regeneration"}
e.GetBuildInfo=function() return "1.60.1","70959","",16001 end
e.GetTime=function() return now end;e.IsInGroup=function() return true end;e.IsInRaid=function() return true end
e.GetNumGroupMembers=function() return #names end
e.UnitFullName=function(unit) local name=names[unitIndex(unit)];if name then return name:match("^([^-]+)%-(.+)$") end end
e.UnitIsGroupLeader=function(unit) return unitIndex(unit)==leader end
e.UnitIsGroupAssistant=function(unit) return unit=="player" and assistant end
e.UnitIsConnected=function(unit) return online[unitIndex(unit)] end
e.UnitIsDeadOrGhost=function(unit) return dead[unitIndex(unit)] end
e.UnitIsVisible=function(unit) return visible[unitIndex(unit)] end
e.UnitInRange=function(unit) return visible[unitIndex(unit)],true end
e.UnitClass=function(unit) local class=classes[unitIndex(unit)];return class,class end
e.C_Spell={GetSpellName=function(id) return spellNames[id] end}
e.C_Secrets={ShouldSpellAuraBeSecret=function(id) return secret[id]==true end}
e.C_UnitAuras={GetAuraDataByIndex=function(unit,index)
    local i=unitIndex(unit);readUnits[i]=(readUnits[i] or 0)+1
    local id=auras[i] and auras[i][index];if id then return {spellId=id,name=spellNames[id] or ("Effect "..id),expirationTime=now+125,duration=1800} end
end}
e.DoReadyCheck=function() readyCalls=readyCalls+1 end
e.C_ChatInfo.SendChatMessage=function(message,channel) chats[#chats+1]={message=message,channel=channel} end
a:RefreshRoster();a:BuildUI()
local function byName(report,name) for _,row in ipairs(report.rows) do if row.name==name then return row end end end
local displayLines=a:RaidCheckAnnouncementLines({groups={food={label="Missing Food",names={"Zergul-Exe","Saint-Arabella"}}},unknown=0})
check(displayLines[1]=="[Nause] Missing Food: Zergul Exe, Saint Arabella","raid announcement did not use full spaced names")
local report=a:ScanRaidChecks();local tank=byName(report,names[3]);local mage=byName(report,names[2])
check(#report.rows==6 and report.offline==1 and report.dead==1,"raid scan omitted members or life status")
check(mage.effects.fortitude=="Present" and mage.effects.mark=="Present" and mage.effects.food=="Present" and mage.effects.consumable=="Present","group/rank buffs or recognised food/elixir were called missing")
check(tank.effects.intellect=="Not required" and tank.effects.fortitude=="Missing" and tank.effects.food=="Missing","class applicability or genuinely missing buffs incorrect")
check(byName(report,names[4]).effects.fortitude=="Unknown" and not report.groups.mark,"out-of-sight player produced a false missing buff")
check(not readUnits[4] and not readUnits[5] and not readUnits[6],"unavailable/offline/dead unit aura data was queried")
check(report.unknown==1 and not a.state,"raid checks changed or required a loot session")
secret[1243]=true;report=a:ScanRaidChecks()
check(byName(report,names[3]).effects.fortitude=="Unknown" and not report.groups.fortitude,"restricted aura was announced as missing")
secret[1243]=nil
-- Mana Regeneration is shared by a food and a potion: only the food ID counts.
auras[3]={1126,24363};spellNames[24363]="Mana Regeneration"
report=a:ScanRaidChecks();check(byName(report,names[3]).effects.food=="Missing","a potion sharing a food name counted as food")
-- Paladin effects are observed without requiring conflicting blessings.
local savedAuras=a.Copy(auras);local savedClass=classes[6]
classes[6]="PALADIN"
auras[1][#auras[1]+1]=25898;auras[2][#auras[2]+1]=25918;auras[3][#auras[3]+1]=25916
report=a:ScanRaidChecks()
check(not a:RaidCheckSettings().kings and not a:RaidCheckSettings().might and not a:RaidCheckSettings().wisdom,"Paladin requirements were enabled indiscriminately")
check(byName(report,names[1]).effects.kings=="Present" and byName(report,names[2]).effects.wisdom=="Present"
    and byName(report,names[3]).effects.might=="Present","Greater Paladin buffs were not recognised")
check(not report.groups.kings and not report.groups.might and not report.groups.wisdom,"optional missing blessings produced raid alerts")
a:ShowRaidChecks();local paladinUI=a.ui.raidChecks
check(paladinUI:GetWidth()<=960 and #paladinUI.headers==8,"Paladin columns did not fit the compact grid")
local lastRight=0
for _,header in ipairs(paladinUI.headers) do if header:IsShown() then local point=rawget(header,"_point");lastRight=math.max(lastRight,point[2]+header:GetWidth()) end end
check(lastRight<paladinUI:GetWidth()-14,"Paladin header overlapped the window edge")
for _,row in ipairs(paladinUI.rows) do if row:IsShown() then for _,cell in ipairs(row.cells) do
    if cell:IsShown() then check(cell.time:GetWidth()>=39,"duration column was too narrow for its full minute label") end
end end end
assert(a:SetRaidCheckSetting("kings",true));report=a.raidCheckReport
check(report.groups.kings and byName(report,names[1]).effects.kings=="Present","required Kings did not distinguish missing players from Greater Kings")
assert(a:SetRaidCheckSetting("might",true));report=a.raidCheckReport
check(byName(report,names[3]).effects.might=="Present" and byName(report,names[2]).effects.might=="Not required","Might requirement ignored physical class eligibility")
assert(a:SetRaidCheckSetting("wisdom",true));report=a.raidCheckReport
check(byName(report,names[2]).effects.wisdom=="Present" and byName(report,names[3]).effects.wisdom=="Not required","Wisdom requirement ignored mana-class eligibility")
for _,key in ipairs({"kings","might","wisdom"}) do assert(a:SetRaidCheckSetting(key,false)) end
classes[6]=savedClass;auras=savedAuras
report=a:ScanRaidChecks();check(a.ui.raidChecks:GetWidth()==942,"grid width changed when the Paladin left")
-- No provider means that buff is not required.
classes[2]="ROGUE";report=a:ScanRaidChecks()
check(byName(report,names[1]).effects.intellect=="Present" and not report.groups.intellect,"an existing Intellect buff was hidden without a Mage, or absent Intellect was called missing")
classes[2]="MAGE"
-- Buffs from players outside the current group remain visible during solo preview.
local ownClass=classes[1];classes[1]="WARRIOR";e.IsInRaid=function() return false end;e.IsInGroup=function() return false end
local ownAuras=a.Copy(auras[1]);auras[1][#auras[1]+1]=25898
report=a:ScanRaidChecks();local solo=report.rows[1]
check(#report.rows==1 and solo.effects.fortitude=="Present" and solo.effects.mark=="Present" and solo.effects.intellect=="Present",
    "solo preview hid buffs because their provider classes were outside the group")
local kingsIndex,mightIndex,wisdomIndex
for index,definition in ipairs(a.raidCheckDefinitions) do if definition.key=="kings" then kingsIndex=index elseif definition.key=="might" then mightIndex=index elseif definition.key=="wisdom" then wisdomIndex=index end end
a:RenderRaidChecks()
check(a.ui.raidChecks.headers[kingsIndex]:IsShown() and a.ui.raidChecks.headers[mightIndex]:IsShown() and a.ui.raidChecks.headers[wisdomIndex]:IsShown()
    and solo.effects.kings=="Present" and solo.effects.might=="Not required" and solo.effects.wisdom=="Not required",
    "fixed Paladin columns hid an active blessing or required absent optional effects")
check(solo.effectTiming.fortitude and not report.groups.fortitude,"solo Fortitude lost its duration or generated a missing warning")
auras[1]=ownAuras;classes[1]=ownClass;e.IsInRaid=function() return true end;e.IsInGroup=function() return true end
report=a:ScanRaidChecks()
assert(a:SetRaidCheckSetting("food",false));check(byName(a.raidCheckReport,names[3]).effects.food=="Not required","food preference was ignored")
assert(a:SetRaidCheckSetting("food",true))
assert(a:StartRaidReadyCheck());check(readyCalls==1 and byName(a.raidCheckReport,names[1]).ready=="Waiting","native Ready Check did not start or show waiting state")
check(not a:StartRaidReadyCheck() and readyCalls==1,"Ready Check could be restarted while pending")
local event=rawget(a.raidCheckEvents,"_scripts").OnEvent
event(a.raidCheckEvents,"READY_CHECK_CONFIRM","raid2",false)
event(a.raidCheckEvents,"READY_CHECK_CONFIRM","raid3",true)
event(a.raidCheckEvents,"READY_CHECK_CONFIRM","raid4",nil)
event(a.raidCheckEvents,"READY_CHECK_FINISHED")
report=a:ScanRaidChecks()
check(byName(report,names[2]).ready=="Not ready" and byName(report,names[3]).ready=="Ready" and byName(report,names[4]).ready=="No reply","native replies or unanswered ready checks were incorrect")
assert(a:AnnounceRaidCheckIssues());local joined={}
for _,chat in ipairs(chats) do check(chat.channel=="RAID" and #chat.message<=255,"raid issue announcement had wrong channel/length");joined[#joined+1]=chat.message end
local text=table.concat(joined," ")
check(text:find("Missing Power Word: Fortitude: Tank Realm",1,true) and text:find("Offline: Offline Realm",1,true),"grouped issue announcements omitted names")
check(not text:find("Missing Power Word: Fortitude: Far Realm",1,true),"unknown aura data was announced as missing")
leader=2;a:RefreshRoster();local chatCount=#chats
check(not a:StartRaidReadyCheck() and not a:AnnounceRaidCheckIssues() and #chats==chatCount,"member could trigger group ready checks/announcements")
assistant=true;check(a:CanControlRaidChecks(),"raid assistant could not control ready checks")
assistant=false;leader=1;a:RefreshRoster();a.demo=true;a.groupTest=true
assert(a:AnnounceRaidCheckIssues());check(#chats==chatCount,"loot test announced real raid issues")
check(not a:StartRaidReadyCheck() and readyCalls==1,"loot test started a real Ready Check")
a.demo=nil;a.groupTest=nil
-- Icon grid keeps each effect separate and shrinks to a small group.
a:ShowRaidChecks();local compact=a.ui.raidChecks
check(compact:GetWidth()==942 and compact:GetHeight()<400,"small group retained the oversized readiness layout")
local foundMissing,foundUnknown,foundPresent=false,false,false
for _,row in ipairs(compact.rows) do if row:IsShown() then
    if row.playerName==a:FullDisplayName(names[3]) then foundMissing=row.cells[1].state=="Missing" and row.cells[1].badge:IsShown() end
    if row.playerName==a:FullDisplayName(names[4]) then foundUnknown=row.cells[1].state=="Unknown" and row.cells[1].badge:IsShown() end
    if row.playerName==a:FullDisplayName(names[1]) then foundPresent=row.cells[1].state=="Present" and row.cells[1].time:GetText()=="2m" and not row.cells[1].badge:IsShown() end
end end
check(foundMissing and foundUnknown and foundPresent,"icon grid lost missing/unknown states or readable aura expiry")
check(compact.headers[1].count:GetText()=="1","buff header did not show its missing-player count")
check(a:RaidCheckRemainingText({expires=0})=="" and a:RaidCheckRemainingText(nil)==""
    and a:RaidCheckRemainingText({expires=now+10})=="<1m","unknown/permanent aura time was fabricated")
-- Data access failures must remain unknown.
local nativeAuras=e.C_UnitAuras.GetAuraDataByIndex
e.C_UnitAuras.GetAuraDataByIndex=function() error("restricted") end
report=a:ScanRaidChecks();check(byName(report,names[3]).effects.food=="Unknown" and not report.groups.food,"failed aura API produced missing food")
e.C_UnitAuras.GetAuraDataByIndex=nativeAuras
-- The supported legacy aura shape still works, and missing APIs stay unknown.
local modern=e.C_UnitAuras;e.C_UnitAuras=nil
e.UnitBuff=function(unit,index)
    local id=auras[unitIndex(unit)][index]
    if id then return spellNames[id] or ("Effect "..id),nil,nil,nil,nil,nil,nil,nil,nil,id end
end
report=a:ScanRaidChecks();check(byName(report,names[2]).effects.food=="Present","legacy UnitBuff did not recognise food")
e.UnitBuff=nil
report=a:ScanRaidChecks();check(byName(report,names[3]).effects.food=="Unknown" and not report.groups.food,"missing aura APIs were called missing buffs")
e.C_UnitAuras=modern
-- Deadlines expire to No reply even if the native finish event is absent.
a:BeginRaidReadyRecord(10);now=now+11
report=a:ScanRaidChecks();check(byName(report,names[1]).ready=="No reply","ready deadline did not expire unanswered members")
-- Reach every member with the bounded scroll row pool.
for i=7,40 do names[i]=string.format("Raider%02d-Realm",i);classes[i]="WARRIOR";auras[i]={};online[i]=true;dead[i]=false;visible[i]=true end
a:ShowRaidChecks();local f=a.ui.raidChecks;f.scroll:SetVerticalScroll(100000);a:RenderRaidChecks()
check(#a.raidCheckReport.rows==40 and #f.rows==42 and f.rows[1].name:GetText()~="","raid list failed to scroll through 40 players")
f.issues:GetScript("OnClick")();check(f.rows[1].issue:IsShown() and not f.rows[1].cells[1]:IsShown(),"By Issue view did not group affected players")
check(f:GetHeight()<=658 and not f.headers[1]:IsShown(),"grouped view exceeded the compact height or retained icon headers")
f.players:GetScript("OnClick")();check(f.headers[1]:IsShown() and f.rows[1].cells[1]:IsShown() and not f.rows[1].issue:IsShown(),"returning from grouped view did not restore the icon grid")
f.filter:GetScript("OnClick")();check(a.raidCheckIssuesOnly and f.filter:GetText()=="Show: Issues","compact issue filter lost its state")
for _,line in ipairs(a:RaidCheckAnnouncementLines(a.raidCheckReport)) do check(#line<=255,"large raid announcement exceeded chat length") end
-- Scrollbar, wheel and bottom-edge resizing use the current viewport.
f.scroll.GetVerticalScrollRange=function() return math.max(0,f.content:GetHeight()-f.scroll:GetHeight()) end
a:RenderRaidChecks();local chrome=f.scroll.nrtScrollChrome
check(chrome.rail:IsShown() and chrome.range>0,"large raid did not expose a visible scrollbar")
chrome.slider:GetScript("OnValueChanged")(chrome.slider,125)
check(f.scroll:GetVerticalScroll()==125,"scrollbar thumb did not move the player list")
f.scroll:GetScript("OnMouseWheel")(f.scroll,-1)
check(f.scroll:GetVerticalScroll()==161,"mouse wheel did not advance the player list")
f.rows[1].cells[1]:GetScript("OnMouseWheel")(f.rows[1].cells[1],-1)
check(f.scroll:GetVerticalScroll()==197,"mouse wheel over a buff icon did not scroll")
f:ClearAllPoints();f:SetPoint("TOPLEFT",e.UIParent,"TOPLEFT",30,-40)
local beforeWidth,beforeHeight=f:GetWidth(),f:GetHeight()
local cursorY,mouseDown=700,true
e.GetCursorPosition=function() return 500,cursorY end
e.IsMouseButtonDown=function() return mouseDown end
local topBefore=select(2,a:WindowTopLeft(f))
f.resizeGrip:GetScript("OnMouseDown")(f.resizeGrip,"LeftButton")
cursorY=400;f.resizeGrip:GetScript("OnUpdate")(f.resizeGrip)
check(f:GetHeight()>beforeHeight and f:GetWidth()==beforeWidth and select(2,a:WindowTopLeft(f))==topBefore,"bottom drag changed width/top instead of growing downward")
local chosenHeight=f:GetHeight()
check(a:WindowLayoutStore().raidCheckHeight==chosenHeight and f.scroll:GetHeight()==chosenHeight-218,"manual height was not saved or did not expand the viewport")
mouseDown=false;f.resizeGrip:GetScript("OnMouseUp")(f.resizeGrip)
a:ScanRaidChecks();f:Hide();a:ShowRaidChecks()
check(f:GetHeight()==chosenHeight and not f.nrtResizing,"refresh/reopen reset the chosen height or retained dragging state")
f.scroll:SetVerticalScroll(100000);a:RenderRaidChecks()
local lastName=a:FullDisplayName("Tank-Realm");local foundLast=false
for _,row in ipairs(f.rows) do if row:IsShown() and row.playerName==lastName then foundLast=true end end
check(foundLast,"expanded row pool could not display the last raider")
local locks=a:WindowLayoutStore();locks.windowLocks=locks.windowLocks or {};locks.windowLocks.NauseRaidToolsRaidChecks=true
a:RefreshWindowChrome(f);mouseDown=true
f.resizeGrip:GetScript("OnMouseDown")(f.resizeGrip,"LeftButton")
check(not f.resizeGrip:IsShown() and not f.nrtResizing,"window lock did not prevent resizing")
locks.windowLocks.NauseRaidToolsRaidChecks=false;a:RefreshWindowChrome(f);mouseDown=false
f.autoHeight:GetScript("OnClick")()
check(a:WindowLayoutStore().raidCheckHeight==nil and f:GetHeight()<chosenHeight,"Auto Height did not restore compact sizing")
assert(a:SetRaidCheckHeight(700));assert(a:ResetOneWindowLayout("NauseRaidToolsRaidChecks"))
check(a:WindowLayoutStore().raidCheckHeight==nil,"Reset Window did not clear the saved Raid Check height")
check(a.ui.settingsPages["Raid Tools"] and a.ui.launcherButtons["Raid Check"],"Raid Check entry points missing")
print("RAID CHECKS PASS: "..count.." checks; native buffs, rank/group variants, food, unknown/secret data, ready replies, permissions, test isolation and 40-player scrolling")
