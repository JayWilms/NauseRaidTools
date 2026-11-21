local root=...
local make=assert(loadfile(root.."/qa/softres/improvements_client.lua"))(root,root)
local a,e=make("Lead-Exe");local checks=0;local function check(v,m) checks=checks+1;assert(v,m) end
local now=100;local roster={"Lead-Exe"};local raid=false;local leader=true;local assistant=false;local combat=false
local invites={};local converts=0;local guild={"Guild One","Guild-Two"};local refreshes=0
local function identity(unit)
 if unit=="player" then return roster[1] end
 local index=tonumber((unit or ""):match("party(%d+)"));if index then return roster[index+1] end
 index=tonumber((unit or ""):match("raid(%d+)"));return index and roster[index]
end
e.GetBuildInfo=function() return "1.60.1","70959","",16001 end
e.UnitFullName=function(unit) local name=identity(unit);if name then return name:match("^([^%-]+)%-(.+)$") end end
e.GetNormalizedRealmName=function() return "Realm" end
e.GetTime=function() return now end;e.IsInGroup=function() return #roster>1 or raid end;e.IsInRaid=function() return raid end
e.GetNumGroupMembers=function() if #roster>1 or raid then return #roster else return 0 end end
e.UnitIsGroupLeader=function(unit) return unit=="player" and leader end
e.UnitIsGroupAssistant=function(unit) return unit=="player" and assistant end
e.InCombatLockdown=function() return combat end
e.GetNumGuildMembers=function() return #guild end;e.GetGuildRosterInfo=function(i) return guild[i] end
e.GuildRoster=function() refreshes=refreshes+1 end
e.InviteUnit=function(name) invites[#invites+1]=name end
e.ConvertToRaid=function() converts=converts+1 end
e.C_PartyInfo=e.C_PartyInfo or {};e.C_PartyInfo.InviteUnit=nil;e.C_PartyInfo.ConvertToRaid=nil
a:BuildUI()
local function reset()
 a.autoInviteState=nil;invites={};converts=0;roster={"Lead-Exe"};raid=false;leader=true;assistant=false;combat=false;now=now+100
 a.demo=nil;a.groupTest=nil;a.ui.assignments:Hide();a.ui.myAssignments:Hide()
 a:SetAutoInviteSetting("enabled",true);a:SetAutoInviteSetting("guildOnly",false);a:SetAutoInviteSetting("convert",false);a:SetAutoInviteSetting("keyword","inv")
end
local defaults=a:AutoInviteSettings();check(not defaults.enabled and not defaults.convert and defaults.guildOnly and defaults.keyword=="inv","defaults unsafe")
check(not a:HandleAutoInviteWhisper("inv","One-Test") and #invites==0,"disabled feature invited")
check(a:SetAutoInviteSetting("keyword","  JOIN  ") and a:AutoInviteSettings().keyword=="join","keyword not normalised")
for _,word in ipairs({"","two words","|cffbad",string.rep("a",33),"line\nword"}) do check(not a:SetAutoInviteSetting("keyword",word),"invalid keyword saved") end
check(not a:SetAutoInviteSetting("enabled","yes"),"nonboolean toggle saved")
reset()
for _,message in ipairs({"please inv","inv please","!sr","invasion","inv!"}) do check(not a:HandleAutoInviteWhisper(message,"One-Test"),"nonexact keyword invited") end
check(a:HandleAutoInviteWhisper(" INV ","One Test") and invites[1]=="One-Test","Forever sender/exact case-insensitive trigger failed")
check(not a:HandleAutoInviteWhisper("inv","one-test") and #invites==1,"duplicate trigger invited twice")
check(not a:HandleAutoInviteWhisper("inv","Lead Exe"),"host invited itself")
check(not a:HandleAutoInviteWhisper("inv","|Hbad"),"invalid sender accepted")
check(a:HandleAutoInviteWhisper("inv","Two-Test") and #invites==1,"burst bypassed pacing")
now=now+1;a:PumpAutoInvites();check(#invites==2,"queued invite not paced")
-- Pending invitations reserve party slots, including while the host is still alone.
check(a:HandleAutoInviteWhisper("inv","Three-Test"),"third request failed");now=now+1;a:PumpAutoInvites()
check(a:HandleAutoInviteWhisper("inv","Four-Test"),"fourth request failed");now=now+1;a:PumpAutoInvites()
check(a:HandleAutoInviteWhisper("inv","Five-Test"),"waiting request failed");now=now+1;a:PumpAutoInvites()
check(#invites==4 and #a.autoInviteState.queue==1,"pending party invites overbooked slots")
roster={"Lead-Exe","One-Test","Two-Test","Three-Test","Four-Test"};a:PumpAutoInvites()
check(converts==0 and #invites==4,"raid conversion occurred while disabled")
-- Enable conversion on an actual five-member party and wait for native confirmation.
a:SetAutoInviteSetting("convert",true)
check(a:HandleAutoInviteWhisper("inv","Six-Test"),"sixth player not queued")
check(converts==1 and #invites==4,"did not convert before sixth invitation")
now=now+2;a:PumpAutoInvites();check(converts==1 and #invites==4,"sent invite before conversion confirmed")
raid=true;a:PumpAutoInvites();check(invites[5]=="Six-Test","queued player not invited after raid confirmation")
-- Guild filters use full canonical identities and fail closed without roster data.
reset();a:SetAutoInviteSetting("guildOnly",true)
check(refreshes>0 and a:HandleAutoInviteWhisper("inv","guild-one"),"guild roster full-name match failed")
check(not a:HandleAutoInviteWhisper("inv","Outsider-Test"),"guild-only filter invited outsider")
e.GetNumGuildMembers=nil;check(not a:HandleAutoInviteWhisper("inv","Guild-Two"),"missing guild API bypassed filter")
e.GetNumGuildMembers=function() return #guild end
-- Eligibility is checked again before sending a queued request.
now=now+1;combat=true;check(a:HandleAutoInviteWhisper("inv","Guild Two"),"guild request not queued during combat")
guild={"Guild One"};a.autoInviteGuildCache=nil;combat=false;a:PumpAutoInvites();check(#invites==1,"departed guild member was invited from queue");guild={"Guild One","Guild-Two"}
reset();combat=true;check(a:HandleAutoInviteWhisper("inv","Wait-Test") and #invites==0,"combat sent invite")
combat=false;a:PumpAutoInvites();check(invites[1]=="Wait-Test","combat queue did not resume")
reset();combat=true;a:HandleAutoInviteWhisper("inv","Expired-Test");now=now+61;combat=false;a:PumpAutoInvites()
check(#invites==0 and #a.autoInviteState.queue==0,"expired request sent later")
reset();combat=true;a:HandleAutoInviteWhisper("inv","Disabled-Test");a:SetAutoInviteSetting("enabled",false);combat=false;a:PumpAutoInvites();check(#invites==0,"disabling retained request")
reset();combat=true;a:HandleAutoInviteWhisper("inv","Old-Test");a:SetAutoInviteSetting("keyword","join");combat=false;a:PumpAutoInvites();check(#invites==0 and not a:HandleAutoInviteWhisper("inv","New-Test"),"old keyword/queue remained active")
reset();combat=true;a:HandleAutoInviteWhisper("inv","Old-Test");roster={"Lead-Exe","Leader-Test"};leader=false;combat=false;a:PumpAutoInvites()
check(#invites==0 and #a.autoInviteState.queue==0,"permission loss retained queued invite")
check(not a:HandleAutoInviteWhisper("inv","Member-Test"),"party member invited")
raid=true;assistant=true;check(a:HandleAutoInviteWhisper("inv","Assistant-Test"),"raid assistant could not invite")
reset();roster={"Lead-Exe","Joined-Test"};check(not a:HandleAutoInviteWhisper("inv","Joined Test"),"existing member reinvited")
reset();raid=true;for i=2,40 do roster[i]="Member"..i.."-Test" end
check(not a:HandleAutoInviteWhisper("inv","Full-Test"),"full raid accepted invite")
reset();a.demo=true;check(not a:HandleAutoInviteWhisper("inv","Demo-Test"),"LC test invited")
a.demo=nil;a.groupTest=true;check(not a:HandleAutoInviteWhisper("inv","Group-Test"),"group test invited")
a.groupTest=nil;a:OpenSimpleAssignmentsBoard(true);check(not a:HandleAutoInviteWhisper("inv","Practice-Test"),"assignment practice invited")
a.ui.assignments.mineButton:GetScript("OnClick")();check(not a:HandleAutoInviteWhisper("inv","Personal-Test"),"personal practice invited")
reset();combat=true;for i=1,60 do a:HandleAutoInviteWhisper("inv","Flood"..i.."-Test") end
check(#a.autoInviteState.queue==40,"request queue unbounded")
-- Prefer modern APIs; missing, throwing or explicitly failing APIs do not make pending invites.
reset();e.C_PartyInfo.InviteUnit=function(name) invites[#invites+1]="modern:"..name end
check(a:HandleAutoInviteWhisper("inv","Modern-Test") and invites[1]=="modern:Modern-Test","modern invite API not preferred")
e.C_PartyInfo.InviteUnit=nil
reset();local invite=e.InviteUnit;e.InviteUnit=nil;a:HandleAutoInviteWhisper("inv","Missing-Test");check(next(a.autoInviteState.pending)==nil,"missing API marked invite pending")
e.InviteUnit=function() error("native failure") end;now=now+1;a:HandleAutoInviteWhisper("inv","Throw-Test");check(next(a.autoInviteState.pending)==nil,"throwing API marked invite pending");e.InviteUnit=invite
reset();roster={"Lead-Exe","A-Test","B-Test","C-Test","D-Test"};e.C_PartyInfo.ConvertToRaid=function() converts=converts+1;return false end
a:SetAutoInviteSetting("convert",true);a:PumpAutoInvites();now=now+20;a:PumpAutoInvites()
check(converts==1 and #invites==0 and a.autoInviteState.convertBlocked,"failed conversion spammed/retried")
e.C_PartyInfo.ConvertToRaid=nil
reset();roster={"Lead-Exe","A-Test","B-Test","C-Test","D-Test"};a:SetAutoInviteSetting("convert",true);a:PumpAutoInvites();now=now+9;a:PumpAutoInvites();now=now+30;a:PumpAutoInvites()
check(converts==1 and a.autoInviteState.convertBlocked,"unconfirmed conversion retried or invited")
-- Missing group APIs must never turn unknown membership into a solo invitation.
reset();local inGroup=e.IsInGroup;e.IsInGroup=nil
check(not a:HandleAutoInviteWhisper("inv","Unknown-Test") and #invites==0,"missing group API was treated as solo")
e.IsInGroup=inGroup
-- Saved preferences are character-local and omitted from raid profile data.
reset();a:SetAutoInviteSetting("keyword","nause");local saved=a:AutoInviteSettings();check(saved.keyword=="nause" and e.NauseRaidToolsDB.autoInviteSettings["Lead-Exe"].keyword=="nause","keyword not persisted by character")
roster[1]="Alt-Test";check(not a:AutoInviteSettings().enabled and a:AutoInviteSettings().keyword=="inv","another character inherited enabled automation");roster[1]="Lead-Exe"
-- Actual event path and Settings controls use the same validated implementation.
reset();rawget(a.autoInviteEvents,"_scripts").OnEvent(a.autoInviteEvents,"ADDON_LOADED","NauseRaidTools")
rawget(a.autoInviteEvents,"_scripts").OnEvent(a.autoInviteEvents,"CHAT_MSG_WHISPER","inv","Event-Test");check(invites[1]=="Event-Test","whisper event not wired")
a:ShowSettings();a:SelectSettingsPage("Raid Tools");a:RenderSettings()
check(a.ui.autoInviteToggles.enabled.toggleOn and not a.ui.autoInviteToggles.convert.toggleOn,"settings switches inconsistent")
a.ui.autoInviteKeyword:SetText("custom");a.ui.autoInviteSave:GetScript("OnClick")();check(a:AutoInviteSettings().keyword=="custom","Save keyword button failed")
a.ui.autoInviteKeyword:SetText("enter");a.ui.autoInviteKeyword:GetScript("OnEnterPressed")();check(a:AutoInviteSettings().keyword=="enter","Enter keyword save failed")
a.ui.autoInviteToggles.enabled:GetScript("OnClick")();check(not a:AutoInviteSettings().enabled,"settings enable toggle failed")
print("Auto Invite: "..checks.." checks passed; keyword, guild, character settings, native party/raid permissions, pacing, pending slots, conversion confirmation, expiry, combat, test isolation and UI")
