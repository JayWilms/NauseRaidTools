local root=...
local make=assert(loadfile(root.."/qa/softres/improvements_client.lua"))(root,root)
local a,e=make("Lead-Realm");local n=0;local function check(v,m) n=n+1;assert(v,m) end
local now=100;local combat=false;local raid=true;local grouped=true;local reads=0
local names={"Lead-Realm","Mage-Realm","Tank-Realm","Druid-Realm","Priest-Realm","Paladin-Realm","Unknown-Realm","Offline-Realm","Dead-Realm"}
local classes={"PRIEST","MAGE","WARRIOR","DRUID","PRIEST","PALADIN","ROGUE","PRIEST","DRUID"}
local groups={1,1,2,3,4,5,6,7,8};local online={true,true,true,true,true,true,true,false,true};local dead={false,false,false,false,false,false,false,false,true}
local visible={true,true,true,true,true,true,false,true,true};local auras={};local secret={}
local function index(unit)
 if unit=="player" then return 1 end
 local i=tonumber((unit or ""):match("raid(%d+)"));if i then return i end
 i=tonumber((unit or ""):match("party(%d+)"));return i and i+1
end
e.GetBuildInfo=function() return "1.60.1","70959","",16001 end
e.GetTime=function() return now end;e.InCombatLockdown=function() return combat end
e.IsInGroup=function() return grouped end;e.IsInRaid=function() return grouped and raid end
e.GetNumGroupMembers=function() return not grouped and 0 or (raid and #names or 5) end
e.UnitFullName=function(unit) local i=index(unit);if names[i] then return names[i]:match("^([^-]+)%-(.+)$") end end
e.UnitIsGroupLeader=function(unit) return index(unit)==1 end;e.UnitIsGroupAssistant=function() return false end
e.UnitClass=function(unit) local c=classes[index(unit)];return c,c end
e.UnitIsConnected=function(unit) return online[index(unit)] end
e.UnitIsDeadOrGhost=function(unit) return dead[index(unit)] end
e.UnitIsVisible=function(unit) return visible[index(unit)] end
e.UnitInRange=function(unit) return visible[index(unit)],true end
e.GetRaidRosterInfo=function(i) return names[i],i==1 and 2 or 0,groups[i],60,classes[i],classes[i] end
e.C_Spell={GetSpellName=function(id) return "Spell"..id end}
e.C_Secrets={ShouldSpellAuraBeSecret=function(id) return secret[id]==true end}
e.C_UnitAuras={GetAuraDataByIndex=function(unit,i)
 check(not combat,"aura API queried during combat");reads=reads+1
 local value=auras[index(unit)] and auras[index(unit)][i]
 if value then return {spellId=value[1],name="Spell"..value[1],expirationTime=value[2] and now+value[2] or 0,duration=1800} end
end}
a:RefreshRoster();a:BuildUI()
local defs={};for _,def in ipairs(a.raidCheckDefinitions) do defs[def.key]=def end
local function plan(key,coverage,primary,backup)
 local b=a:CleanAssignmentPlan({rows={}})
 assert(a:EditMarkerBoardCell(b,{kind="buff",buff=key,value=primary or a.me,encounter="raid"}))
 assert(a:EditMarkerBoardCell(b,{kind="buff",buff=key,field="coverage",value=coverage or "raid",encounter="raid"}))
 if backup then assert(a:EditMarkerBoardCell(b,{kind="buff",buff=key,field="backup",value=backup,encounter="raid"})) end
 b.owner=a.me;b.epoch=100;b.revision=0;a.assignmentOwner=a.me;a.assignmentBoard=b;return b
end
local function target(report,name,key)
 for _,g in ipairs(report.groups) do if not key or g.key==key then for _,v in ipairs(g.targets) do if v.name==name then return v,g end end end end
end
local settings=a:BuffReminderSettings();check(settings.enabled and settings.expiring,"assigned reminder defaults wrong")
check(not a:BuffReminderClickBinding({name="Wrong-Realm",unit="raid1"},"fortitude"),"click binding accepted mismatched identity")
check(not a:BuffReminderClickBinding({name=names[1],unit="raid1;bad"},"fortitude"),"click binding accepted an invalid unit token")
-- All six assignable buff families work without using Raid Check's optional requirement switches.
for _,key in ipairs(a.assignmentBuffOrder) do
 classes[1]=defs[key].provider;auras={};local b=plan(key);local recipient=key=="might" and 3 or 1
 local binding=a:BuffReminderClickBinding({name=names[recipient],unit="raid"..recipient},key)
 check(binding and binding.macro:find("Spell"..(defs[key].nameIDs or defs[key].ids)[1],1,true),key.." click binding did not use its single-target spell family")
 local report=a:BuildBuffReminderReport(b)
 check(target(report,names[recipient],key)~=nil,key.." missing for assigned provider")
 check(not target(report,names[7]) and not target(report,names[8]) and not target(report,names[9]),key.." included distant/offline/dead player")
 if key=="intellect" or key=="wisdom" then check(not target(report,names[3]),"mana buff required on warrior") end
 if key=="might" then check(target(report,names[3]) and not target(report,names[2]),"Might class applicability wrong") end
 check(a:RaidCheckSettings().kings==false,"reminder changed Raid Check settings")
 -- Highest known rank/Greater version satisfies the same assignment.
 local ids=defs[key].ids;auras[recipient]={{ids[#ids],1800}};report=a:BuildBuffReminderReport(b)
 check(not target(report,names[recipient],key),key.." existing rank/Greater buff ignored")
 auras[recipient]={{ids[1],30}};report=a:BuildBuffReminderReport(b)
 check(target(report,names[recipient],key).state=="Expiring",key.." expiry warning missing")
 report=a:BuildBuffReminderReport(b,{enabled=true,expiring=false});check(not target(report,names[recipient],key),key.." expiry switch ignored")
 auras[recipient]={{ids[1],1800}};report=a:BuildBuffReminderReport(b);check(not target(report,names[recipient],key),"long buff warned")
 secret[ids[1]]=true;report=a:BuildBuffReminderReport(b);check(not target(report,names[recipient],key) and report.unknown>0,"secret buff called missing");secret[ids[1]]=nil
end
classes[1]="PRIEST";auras={}
for _,range in ipairs({"raid","1","2","1-2","3-4","5-6","7-8","1-4","5-8"}) do
 local b=plan("fortitude",range);local report=a:BuildBuffReminderReport(b)
 for i=1,6 do check((target(report,names[i])~=nil)==a:BuffReminderCoverage(range,groups[i]),"raid subgroup coverage incorrect: "..range) end
end
local b=plan("fortitude","1-2");local savedGroup=groups[3];groups[3]=nil
check(not target(a:BuildBuffReminderReport(b),names[3]),"unknown subgroup treated as assigned");groups[3]=savedGroup
raid=false;a:RefreshRoster();b=plan("fortitude","1-2");check(a:BuildBuffReminderReport(b).count==5,"party not treated as group one")
b=plan("fortitude","3-4");check(a:BuildBuffReminderReport(b).count==0,"party incorrectly included in raid group three")
raid=true;a:RefreshRoster()
-- Backups act only when the primary is absent, offline or dead.
b=plan("fortitude","raid",names[5],a.me);check(a:BuildBuffReminderReport(b).count==0,"backup duplicated available primary")
online[5]=false;local report=a:BuildBuffReminderReport(b);check(report.count>0 and report.groups[1].backup,"offline primary did not activate backup")
online[5]=true;dead[5]=true;check(a:BuildBuffReminderReport(b).count>0,"dead primary did not activate backup");dead[5]=false
online[5]=nil;check(a:BuildBuffReminderReport(b).count==0,"unknown primary connection activated backup");online[5]=true
b=plan("fortitude","raid","Absent-Realm",a.me);check(a:BuildBuffReminderReport(b).count>0,"absent primary did not activate backup")
classes[1]="WARRIOR";check(a:BuildBuffReminderReport(b).count==0,"wrong-class player got buff reminders");classes[1]="PRIEST"
-- Event-driven UI: hidden in combat, immediate end-of-combat refresh, no chat/network output.
b=plan("fortitude","1-2");local sent=#a.sent
local scripts=rawget(a.buffReminderEvents,"_scripts");scripts.OnEvent(a.buffReminderEvents,"ADDON_LOADED","NauseRaidTools")
a:RefreshBuffReminders();local f=a.ui.buffReminders
check(f:IsShown() and a.buffReminderReport.count==3,"confirmed missing buffs did not open personal reminder")
check(f.rows[2].label:GetText()=="Lead Realm" and rawget(f.rows[2],"status")==nil,"compact names retained a Missing column or lost full names")
-- Secure click overlays are independent of ordinary NRT windows and arm only visible names.
local automaticCasts=0;local drivers={};local protectedMutations=0
local create=e.CreateFrame
e.CreateFrame=function(kind,name,parent,template)
 local frame=create(kind,name,parent,template)
 if template=="SecureHandlerStateTemplate" or template=="SecureActionButtonTemplate" then
  frame.attributes={}
  frame.SetAttribute=function(self,key,value) check(not combat,"protected attributes changed during combat");self.attributes[key]=value;protectedMutations=protectedMutations+1 end
  frame.GetAttribute=function(self,key) return self.attributes[key] end
  for _,method in ipairs({"SetPoint","SetSize","SetFrameStrata","SetFrameLevel","Show","Hide"}) do
   local original=frame[method]
   frame[method]=function(self,...) check(not combat,"protected overlay changed during combat: "..method);protectedMutations=protectedMutations+1;return original(self,...) end
  end
 end
 return frame
end
e.RegisterStateDriver=function(frame,state,condition) check(not combat,"driver registered during combat");drivers[frame]=condition end
e.UnregisterStateDriver=function(frame) check(not combat,"driver unregistered during combat");drivers[frame]=nil end
e.C_Macro={RunMacroText=function() automaticCasts=automaticCasts+1 end}
e.RAID_CLASS_COLORS={PRIEST={r=1,g=1,b=1},MAGE={r=.25,g=.78,b=.92},WARRIOR={r=.78,g=.61,b=.43}}
local scrollLeft=100
f.scroll.GetLeft=function() return scrollLeft end
f.scroll.GetTop=function() return 900 end
local makeRow=f.createRow
local function instrument(row)
 row.GetTop=function(self) return f.scroll:GetTop()+(rawget(self,"_point")[3] or 0)+f.scroll:GetVerticalScroll() end
 row.label.SetTextColor=function(self,r,g,b) self.reminderColor={r,g,b} end
end
f.createRow=function(i) local row=makeRow(i);instrument(row);return row end
for _,row in ipairs(f.rows) do instrument(row) end
a:RefreshBuffReminders()
local host=a.buffReminderClickHost
check(f:GetWidth()==300 and f:GetHeight()<180 and not rawget(f,"summary") and not rawget(f,"hint"),"reminder retained oversized layout/prose")
check(host and drivers[host]=="[combat] hide; show" and #host.buttons==3,"secure visible-name overlays not provisioned")
for _,window in ipairs(a.allWindowFrames) do check(window~=host,"protected overlay was added to normal NRT layering") end
local mageButton
for _,button in ipairs(host.buttons) do
 check(button.attributes.type1=="macro" and button.attributes.macrotext1:find("[nocombat,@"..button.nativeUnit..",help,nodead] Spell1243",1,true),"secure macro did not bind intended buff/unit with combat guard")
 if button.targetName==names[2] then mageButton=button end
end
check(mageButton~=nil,"Mage target overlay missing")
check(f.rows[4].label.reminderColor[1]==.78 and f.rows[4].label.reminderColor[2]==.61,"recipient name not coloured by warrior class")
check(automaticCasts==0,"refresh automatically executed a cast")
-- Identity and plan-version guards stop stale names/assignments before the secure action runs.
local originalName=names[2];names[2]="Replaced-Realm"
mageButton:GetScript("PreClick")(mageButton)
check(mageButton.attributes.type1==nil,"recycled raid unit could cast on a different player");names[2]=originalName
a:RefreshBuffReminders();b.revision=b.revision+1
mageButton:GetScript("PreClick")(mageButton);check(mageButton.attributes.type1==nil,"stale assignment revision still castable")
a:PositionBuffReminderClicks();check(not host:IsShown(),"outdated report kept active click overlays")
a:RefreshBuffReminders();check(host:IsShown(),"fresh report did not rearm click overlays")
-- Clip hit targets to fully visible rows, follow scrolling and moving the reminder.
f.scroll:SetHeight(26);a:PositionBuffReminderClicks()
for _,button in ipairs(host.buttons) do check(not button:IsShown(),"partially clipped name had an active hit target") end
f.scroll:SetVerticalScroll(26);f.scroll:GetScript("OnVerticalScroll")()
local visibleCount=0;for _,button in ipairs(host.buttons) do if button:IsShown() then visibleCount=visibleCount+1 end end
check(visibleCount==1,"scrolling did not rebind the visible name")
scrollLeft=140;a:PositionBuffReminderClicks()
for _,button in ipairs(host.buttons) do if button:IsShown() then check(rawget(button,"_point")[4]==140,"click overlay did not follow window position") end end
f.scroll:SetVerticalScroll(0);a:RefreshBuffReminders()
local mutationCount=protectedMutations
-- The game state driver hides the secure root; addon combat handlers never mutate it.
combat=true;for frame in pairs(drivers) do frame._shown=false end
scripts.OnEvent(a.buffReminderEvents,"PLAYER_REGEN_DISABLED");a:RefreshWindowLayers();scripts.OnUpdate(a.buffReminderEvents,1)
check(not host:IsShown() and protectedMutations==mutationCount,"combat changed protected click frames instead of using native visibility")
combat=false;scripts.OnEvent(a.buffReminderEvents,"PLAYER_REGEN_ENABLED")
check(host:IsShown() and automaticCasts==0,"post-combat refresh failed or cast without a click")
-- Missing secure API support degrades to the readable reminder only.
e.C_Macro=nil;a:PositionBuffReminderClicks();check(not host:IsShown() and f:IsShown(),"unsupported secure API left live cast targets or hid reminder")
e.C_Macro={RunMacroText=function() automaticCasts=automaticCasts+1 end};a:RefreshBuffReminders()
local oldReads=reads;combat=true;scripts.OnEvent(a.buffReminderEvents,"PLAYER_REGEN_DISABLED")
scripts.OnUpdate(a.buffReminderEvents,1);check(not f:IsShown() and reads==oldReads,"combat did not hide/stop scans")
check(a:BuildBuffReminderReport(b).count==0 and reads==oldReads,"direct report queried combat auras")
combat=false;scripts.OnEvent(a.buffReminderEvents,"PLAYER_REGEN_ENABLED");check(f:IsShown() and reads>oldReads,"out-of-combat event did not refresh")
-- Buffing the listed recipients clears the reminder while the Raid Check window is closed.
for i=1,3 do auras[i]={{1243,1800}} end
scripts.OnEvent(a.buffReminderEvents,"UNIT_AURA","raid2");scripts.OnUpdate(a.buffReminderEvents,.1)
check(not f:IsShown() and a.buffReminderReport.count==0,"rebuffed list did not clear")
auras[2]={};scripts.OnUpdate(a.buffReminderEvents,1);check(f:IsShown(),"lost buff did not reopen reminder")
f.closeButton:GetScript("OnClick")();scripts.OnUpdate(a.buffReminderEvents,1);check(not f:IsShown(),"dismissed unchanged report reopened")
auras[3]={};scripts.OnUpdate(a.buffReminderEvents,1);check(f:IsShown(),"changed missing list did not clear dismissal")
-- Resurrection becomes eligible again; no reminder while dead.
dead[2]=true;a:RefreshBuffReminders();check(not target(a.buffReminderReport,names[2]),"dead player prompted rebuff")
dead[2]=false;scripts.OnEvent(a.buffReminderEvents,"UNIT_FLAGS","raid2");scripts.OnUpdate(a.buffReminderEvents,.1)
check(target(a.buffReminderReport,names[2])~=nil,"resurrected player not rechecked")
check(a:SetBuffReminderSetting("enabled",false) and not f:IsShown(),"disable did not hide window")
a:SetBuffReminderSetting("enabled",true);check(f:IsShown(),"re-enable did not restore confirmed reminders")
a:ShowSettings();a:SelectSettingsPage("Raid Tools");check(a.ui.buffReminderToggles.enabled.toggleOn,"settings reminder toggle wrong")
a.ui.buffReminderToggles.expiring:GetScript("OnClick")();check(not a:BuffReminderSettings().expiring,"expiry settings toggle failed")
check(not a:SetBuffReminderSetting("enabled","yes"),"invalid reminder setting accepted")
a.demo=true;a:RefreshBuffReminders();check(not f:IsShown(),"loot test opened live reminders");a.demo=nil
local live=a.assignmentBoard;a:OpenSimpleAssignmentsBoard(true);a:RefreshBuffReminders();check(not f:IsShown() and a.assignmentBoard==live,"assignment practice used live reminders")
a.ui.assignments:Hide();grouped=false;a:RefreshBuffReminders();check(not f:IsShown(),"solo preparation opened group reminders")
check(#a.sent==sent,"buff reminder sent chat/network messages")
print("Buff reminders: "..n.." checks passed; six buff families, ranks, expiry, groups/party, primary/backup, unknown data, combat/resurrection, compact class-coloured UI, secure click bindings/visibility, stale-target guards and local-only operation")
