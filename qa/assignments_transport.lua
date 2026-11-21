local root=...
local make=assert(loadfile(root.."/qa/softres/improvements_client.lua"))(root,root)
local now=100;local wire={};local sentFragments=0;local skipMember=false;local clients={};local names={"Leader-Realm","Assist-Realm","Member-Realm","Mage-Realm","Hunter-Realm"}
for index,name in ipairs(names) do
    local a,e=make(name)
    e.GetTime=function() return now end;e.GetServerTime=function() return 1800000000+math.floor(now) end
    e.GetBuildInfo=function() return "1.60.1","1","",16001 end
    e.IsInGroup=function() return true end;e.IsInRaid=function() return true end;e.GetNumGroupMembers=function() return #names end
    function a:Name(unit) if unit=="player" then return name end;return names[tonumber((unit or ""):match("raid(%d+)"))] end
    e.UnitIsGroupLeader=function(u) return a:Name(u)==names[1] end
    e.UnitIsGroupAssistant=function(u) return a:Name(u)==names[2] end
    e.UnitClass=function(u) local classes={[names[1]]="WARRIOR",[names[2]]="PRIEST",[names[3]]="WARLOCK",[names[4]]="MAGE",[names[5]]="HUNTER"};local class=classes[a:Name(u)];return class,class end
    e.C_ChatInfo.SendAddonMessage=function(prefix,message,channel,target)
        sentFragments=sentFragments+1;wire[#wire+1]={from=name,prefix=prefix,message=message,channel=channel,target=target};return 0
    end
    a.Send=a.WireSend;a:RefreshRoster();a.leader=names[2] -- Loot council may delegate its authority to a different player.
    a._env=e;clients[index]=a
end
local host,assistant,member=clients[1],clients[2],clients[3]
local b=host:AssignmentBoard()
b.raidName="A custom raid with four entirely fictional encounters"
for i=1,4 do b.encounters[i]={id="e"..i,name="Custom encounter "..i} end
b.nextEncounter=5;b.activeEncounter="e1"
for i=1,480 do
 local index=(i-1)%120;local kind=index<60 and "tank" or "interrupt"
 b.rows[i]={id=i,kind=kind,role=kind=="tank" and "off" or "interrupt",player="Character"..i.."-"..string.rep("Surname",11),
  target=string.rep("Custom target ",5),note=string.rep("Note "..i.." ",12),slot=index%60+1,encounter="e"..math.ceil(i/120),job="",backup=names[3],link=0}
end
b.nextRow=481
assert(host:CleanAssignmentPlan(b));assert(#host.Encode(b)>131072,"large plan did not exercise expanded transport bound")
host:PublishAssignments()
local function pump()
    for i=1,10000 do
        now=now+.2;for _,a in ipairs(clients) do a:PumpSender() end
        local pending=wire;wire={}
        for _,m in ipairs(pending) do for _,a in ipairs(clients) do
            if a.me~=m.from and (not m.target or m.target==a.me) and not (skipMember and a.me==names[3] and m.from==names[1]) then a:Receive(m.prefix,m.message,m.channel,m.from:gsub("-"," ")) end
        end end
        local queued=0;for _,a in ipairs(clients) do queued=queued+a:NetworkQueueStats() end
        if queued==0 then return end
    end
    error("assignment queue did not drain")
end
pump()
assert(member:AssignmentBoard() and #member:AssignmentBoard().rows==480,"large board failed across delegated LC transport")
assert(assistant:AssignmentBoard() and assistant:CanEditAssignments(),"assistant did not receive board")
assert(assistant:EditAssignment("remove",nil,1));pump()
assert(#host:AssignmentBoard().rows==479 and #member:AssignmentBoard().rows==479,"native assistant edit did not converge")
assert(not member:EditAssignment("remove",nil,2),"native member could edit")
member.assignmentBoard=nil;member:RefreshAssignments(true);pump()
assert(member:AssignmentBoard() and #member:AssignmentBoard().rows==479,"late join/recovery sync failed")
assert(assistant:EditAssignment("encounterAdd",{name="Another custom encounter"}));pump()
assert(host:AssignmentBoard().activeEncounter=="e5" and member:AssignmentBoard().activeEncounter=="e5","shared encounter change did not converge")
local edit={kind="healer",role="tank",player=names[2],target="",note="Linked tank",encounter="e1",slot=1,link=3,backup=names[3]}
local before=sentFragments;assert(assistant:EditAssignment("update",edit,2));pump()
assert(sentFragments-before<=12,"small edit resent the entire raid plan")
assert(member:AssignmentBoard().rows[1].id==2 and member:AssignmentBoard().rows[1].link==3,"linked edit did not converge")
-- Party sharing also works when a separate LC session is present.
for index,a in ipairs(clients) do
 local name=names[index]
 function a:Name(unit)
  if unit=="player" then return name end
  local n=tonumber((unit or ""):match("party(%d+)"));local others={}
  for _,memberName in ipairs(names) do if memberName~=name then others[#others+1]=memberName end end
  return others[n]
 end
 a._env.IsInRaid=function() return false end
 a:RefreshRoster();a.leader=names[2];a.state={id="party-lc",items={},master=names[2]};a:ResetTestTransport()
end
assert(assistant:EditAssignment("raidName",{name="Party plan with LC present"}));pump()
assert(host:AssignmentBoard().raidName=="Party plan with LC present" and member:AssignmentBoard().raidName=="Party plan with LC present","party sharing with LC state failed")
-- A lost delta must recover from a later revision without silently diverging.
skipMember=true;assert(host:EditAssignment("raidName",{name="Lost update"}));pump();skipMember=false
assert(member:AssignmentBoard().raidName~="Lost update","loss simulation did not drop the update")
now=now+4;assert(host:EditAssignment("activate",nil,"e2"));pump()
assert(member:AssignmentBoard().revision==host:AssignmentBoard().revision and member:AssignmentBoard().raidName=="Lost update","delta gap failed to recover a full snapshot")
skipMember=true;assert(host:EditAssignment("raidName",{name="Lost final update"}));pump();skipMember=false
now=now+4;host:SendAssignments("head",{epoch=host:AssignmentBoard().epoch,revision=host:AssignmentBoard().revision});pump()
assert(member:AssignmentBoard().raidName=="Lost final update","head announcement did not repair a lost final delta")
-- Marker/healer creation is one atomic edit: all clients must allocate the same IDs.
assert(host:CommitAssignmentPlan({schema=2,raidName="Marker test",encounters={},activeEncounter="raid",rows={}}));pump()
assert(assistant:SetSimpleAssignmentCell({kind="healer",marker=8,seat=2},"player",names[2]));pump()
local markerTank=host:MarkerBoardRow(host:AssignmentBoard(),"raid","tank",8)
local markerHealer=member:MarkerBoardRow(member:AssignmentBoard(),"raid","healer",8,2)
assert(markerTank and markerHealer and markerHealer.link==markerTank.id and markerHealer.player==names[2],"atomic healer/placeholder tank did not converge")
assert(assistant:SetSimpleAssignmentCell({kind="banish",marker=7},"player",names[3]));pump()
assert(member:MarkerBoardRow(member:AssignmentBoard(),"raid","banish",7).player==names[3],"banish marker delta was rejected")
assert(assistant:SetSimpleAssignmentCell({kind="sheep",marker=5},"player",names[4]));pump()
assert(assistant:SetSimpleAssignmentCell({kind="buff",buff="fortitude"},"player",names[2]));pump()
assert(assistant:SetSimpleAssignmentCell({kind="buff",buff="fortitude"},"coverage","5-8"));pump()
assert(member:MarkerBoardRow(member:AssignmentBoard(),"raid","buff",nil,nil,"fortitude").target=="5-8","buff coverage delta did not converge")
assert(member:MarkerBoardRow(member:AssignmentBoard(),"raid","sheep",5).player==names[4],"sheep marker did not converge")
-- Group-cleanup slots and tranqs must survive deltas, full sync and boss overrides.
assert(assistant:SetSimpleAssignmentCell({kind="tranq",marker=8},"player",names[5]));pump()
assert(assistant:SetSimpleAssignmentCell({kind="dispel",slot=1},"player",names[2]));pump()
assert(assistant:SetSimpleAssignmentCell({kind="dispel",slot=1},"coverage","3-4"));pump()
assert(assistant:SetSimpleAssignmentCell({kind="decurse",slot=4},"player",names[4]));pump()
assert(assistant:SetSimpleAssignmentCell({kind="decurse",slot=4},"coverage","7-8"));pump()
assert(assistant:SetSimpleAssignmentCell({kind="buff",buff="fortitude"},"coverage","5-6"));pump()
assert(member:MarkerBoardRow(member:AssignmentBoard(),"raid","tranq",8).player==names[5],"hunter tranq delta failed")
assert(member:MarkerBoardRow(member:AssignmentBoard(),"raid","dispel",nil,nil,nil,nil,1).target=="3-4","dispel group pair delta failed")
assert(member:MarkerBoardRow(member:AssignmentBoard(),"raid","decurse",nil,nil,nil,nil,4).target=="7-8","decurse slot delta failed")
assert(member:MarkerBoardRow(member:AssignmentBoard(),"raid","buff",nil,nil,"fortitude").target=="5-6","buff group pair delta failed")
member.assignmentBoard=nil;now=now+4;member:RefreshAssignments(true);pump()
assert(member:MarkerBoardRow(member:AssignmentBoard(),"raid","dispel",nil,nil,nil,nil,1).target=="3-4","cleanup slot lost in full sync")
assert(assistant:EditAssignment("encounterAdd",{name="Cleanup boss"}));pump()
local encounter=host:AssignmentBoard().activeEncounter
assert(assistant:SetSimpleAssignmentCell({kind="dispel",slot=1},"coverage","1-2"));pump()
assert(member:MarkerBoardRow(member:AssignmentBoard(),encounter,"dispel",nil,nil,nil,nil,1).target=="1-2" and member:MarkerBoardRow(member:AssignmentBoard(),"raid","dispel",nil,nil,nil,nil,1).target=="3-4","boss dispel override changed whole raid groups")
-- Recipients are not dispellers: targets may be any class and retain canonical identity.
assert(assistant:SetSimpleAssignmentCell({kind="dispel",slot=1},"target",names[3]));pump()
assert(member:MarkerBoardRow(member:AssignmentBoard(),encounter,"dispel",nil,nil,nil,nil,1).targetPlayer==names[3],"single-player dispel target did not converge")
assert(member:MarkerBoardRow(member:AssignmentBoard(),"raid","dispel",nil,nil,nil,nil,1).targetPlayer=="","boss recipient changed raid defaults")
member.assignmentBoard=nil;now=now+4;member:RefreshAssignments(true);pump()
assert(member:MarkerBoardRow(member:AssignmentBoard(),encounter,"dispel",nil,nil,nil,nil,1).targetPlayer==names[3],"recipient lost in full snapshot")
assert(assistant:SetSimpleAssignmentCell({kind="decurse",slot=4},"target",names[1]));pump()
assert(member:MarkerBoardRow(member:AssignmentBoard(),encounter,"decurse",nil,nil,nil,nil,4).targetPlayer==names[1],"single-player decurse target did not converge")
assert(assistant:SetSimpleAssignmentCell({kind="dispel",slot=1},"coverage","5-6"));pump()
assert(member:MarkerBoardRow(member:AssignmentBoard(),encounter,"dispel",nil,nil,nil,nil,1).targetPlayer=="" and member:MarkerBoardRow(member:AssignmentBoard(),encounter,"dispel",nil,nil,nil,nil,1).target=="5-6","group selection did not replace individual target")
-- Whole-raid debuffs use class-checked assistant edits and survive real fragmented snapshots.
assert(assistant:EditAssignment("activate",nil,"raid"));pump()
assert(assistant:SetSimpleAssignmentCell({kind="debuff",debuff="elements"},"player",names[3]));pump()
assert(member:MarkerBoardRow(member:AssignmentBoard(),"raid","debuff",nil,nil,"elements").player==names[3],"curse delta did not converge")
local revision=host:AssignmentBoard().revision
assert(not host:ApplyAssignmentEdit("boardCell",{kind="debuff",debuff="elements",field="backup",value=names[4],encounter="raid"}),"host accepted mage curse backup")
assert(host:AssignmentBoard().revision==revision,"invalid class changed live plan")
member.assignmentBoard=nil;now=now+4;member:RefreshAssignments(true);pump()
assert(member:MarkerBoardRow(member:AssignmentBoard(),"raid","debuff",nil,nil,"elements").player==names[3],"curse lost in full sync")
assert(assistant:SetSimpleAssignmentCell({kind="debuff",debuff="elements"},"player",""));pump()
assert(member:MarkerBoardRow(member:AssignmentBoard(),"raid","debuff",nil,nil,"elements").player=="","cleared curse did not converge")
-- Test Raid shares through the same native party transport, without replacing saved setup.
local saved=host.Encode(host._env.NauseRaidToolsDB.raidAssignments)
local previous=host:AssignmentPlan(host:AssignmentBoard())
assert(not member:OpenAssignmentTest(),"member started a test without the native leader")
assistant:OpenSimpleAssignmentsBoard(true);assistant.ui.assignments.mineButton:GetScript("OnClick")()
assert(assistant.ui.myAssignments.practice,"local practice adoption fixture failed")
assert(host:OpenAssignmentTest());pump()
assert(not assistant.ui.assignments.practice and not assistant.ui.myAssignments.practice,"incoming shared test did not replace local rehearsal view")
assert(host:AssignmentBoard().test and assistant:AssignmentBoard().test and member:AssignmentBoard().test,"party Test Raid was not shared automatically")
assert(#member:AssignmentBoard().encounters==10 and host.ui.assignments.save:GetText()=="End Test","shared test lacks route/end control")
for _,row in ipairs(member:AssignmentBoard().rows) do
 assert(not row.player:find("Practice",1,true) and not row.backup:find("Practice",1,true),"fictional players leaked into shared test")
end
assert(host.Encode(host._env.NauseRaidToolsDB.raidAssignments)==saved,"test start overwrote saved raid setup")
assert(host:SetSimpleAssignmentCell({kind="tank",marker=8},"player",names[1]));pump()
assert(host:SetSimpleAssignmentCell({kind="healer",marker=8,seat=1},"player",names[2]));pump()
for _,enc in ipairs(member:AssignmentBoard().encounters) do
 assert(member:MarkerBoardRow(member:AssignmentBoard(),enc.id,"tank",8).player==names[1],"shared raid-wide tank did not follow into every boss")
 assert(member:MarkerBoardRow(member:AssignmentBoard(),enc.id,"healer",8,1).player==names[2],"shared raid-wide healer did not follow into every boss")
end
assert(host:SetSimpleAssignmentCell({kind="buff",buff="fortitude"},"player",names[2]));pump()
assert(assistant:MarkerBoardRow(assistant:AssignmentBoard(),"raid","buff",nil,nil,"fortitude").player==names[2],"real party member buff assignment did not arrive")
assert(assistant:OpenLauncherOption("My Assignments"));assert(not assistant.ui.myAssignments.practice and #assistant.ui.myAssignments.entries>0,"member personal tracker required a separate test join")
assert(assistant.ui.myAssignments.summary:GetText():find("GROUP TEST",1,true),"member tracker not labelled as a group test")
for _,a in ipairs(clients) do
 a._env.UnitIsConnected=function() return true end;a._env.UnitIsDeadOrGhost=function() return false end
 a._env.UnitIsVisible=function() return true end;a._env.UnitInRange=function() return true,true end
 a._env.C_UnitAuras={GetAuraDataByIndex=function() return nil end}
 a._env.C_Secrets={ShouldSpellAuraBeSecret=function() return false end}
end
assistant:RefreshBuffReminders();assert(assistant.ui.buffReminders:IsShown() and assistant.buffReminderReport.count>0,"shared test blocked real-party buff reminders")
assert(not host:AutoInviteContext(),"shared assignment test permitted auto invites")
assert(not host:SaveAssignmentTemplate("Do not save test") and not host:SaveProfile("Do not save test"),"shared test could overwrite saved profiles")
assert(host.Encode(host._env.NauseRaidToolsDB.raidAssignments)==saved,"test edit overwrote saved raid setup")
member.assignmentBoard=nil;now=now+4;member:RefreshAssignments(true);pump()
assert(member:AssignmentBoard().test and member:MarkerBoardRow(member:AssignmentBoard(),"raid","buff",nil,nil,"fortitude").player==names[2],"late test member recovery lost test flag or assignments")
local oldTest=host.Copy(host:AssignmentBoard())
assert(not assistant:EndAssignmentTest(),"assistant ended the leader's test")
assert(host:EndAssignmentTest());pump()
assert(not member:AssignmentBoard().test and not assistant:AssignmentBoard().test,"test end did not reach members")
assert(host.Encode(host:AssignmentPlan(host:AssignmentBoard()))==host.Encode(previous),"ending test did not restore original jobs")
local endedEpoch=member:AssignmentBoard().epoch
member:Packet(names[1],{kind="raidAssignments7",protocol=member.protocol,op="state",data=oldTest},"PARTY")
assert(not member:AssignmentBoard().test and member:AssignmentBoard().epoch==endedEpoch,"retired test snapshot returned after test ended")
-- A host reload during testing uses a fresh epoch and the previous saved normal plan.
assert(host:OpenAssignmentTest());pump();local testEpoch=host:AssignmentBoard().epoch
host.assignmentBoard=nil;host.assignmentTestRestore=nil
local restored=host:AssignmentBoard();assert(not restored.test and restored.epoch>testEpoch,"reload revived a test or reused its epoch")
host:PublishAssignments();pump();assert(not member:AssignmentBoard().test and member:AssignmentBoard().epoch==restored.epoch,"reload recovery did not replace remote test")
local malformed=host:AssignmentPlan();malformed.test="yes";assert(not host:CleanAssignmentPlan(malformed),"invalid test marker accepted")
-- Raid groups use the same shared test path; a leadership change retires the old test.
for index,a in ipairs(clients) do
 local name=names[index]
 function a:Name(unit) if unit=="player" then return name end;return names[tonumber((unit or ""):match("raid(%d+)"))] end
 a._env.IsInRaid=function() return true end;a.state=nil;a:RefreshRoster()
end
assert(host:OpenAssignmentTest());pump();assert(member:AssignmentBoard().test,"raid Test Raid did not propagate")
for _,a in ipairs(clients) do
 a._env.UnitIsGroupLeader=function(unit) return a:Name(unit)==names[2] end
 a:RefreshRoster();assert(not (a:AssignmentBoard() or {}).test,"leadership change retained old leader test")
end
assert(not host:EndAssignmentTest(),"former leader ended assignments after losing authority")
print("Raid assignments native transport: 480 jobs across encounters, delegated LC authority, linked assistant edits, late sync, party/LC coexistence, shared party/raid tests, real buff reminders and restore/reload/leadership passed")
