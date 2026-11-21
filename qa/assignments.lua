local root=...
local make=assert(loadfile(root.."/qa/softres/improvements_client.lua"))(root,root)
local a,e=make("Lead-Realm")
local count=0;local function check(v,m) count=count+1;assert(v,m) end
local names={"Lead-Realm","Assist-Realm","Raider-Realm"};local localIndex=1;local leader=1;local grouped=true;local time=100
local function idx(u) return u=="player" and localIndex or tonumber((u or ""):match("raid(%d+)")) end
e.IsInGroup=function() return grouped end;e.IsInRaid=function() return grouped end;e.GetNumGroupMembers=function() return grouped and 3 or 0 end
e.UnitFullName=function(u) local name=names[idx(u)];if name then return name:match("^([^-]+)%-(.+)$") end end
e.UnitIsGroupLeader=function(u) return idx(u)==leader end;e.UnitIsGroupAssistant=function(u) return idx(u)==2 end
e.UnitIsConnected=function(u) return idx(u)~=3 end;e.GetTime=function() return time end
e.GetBuildInfo=function() return "1.60.1","70959","",16001 end
local chats={};e.C_ChatInfo.SendChatMessage=function(line,channel) chats[#chats+1]={line,channel} end
a:RefreshRoster();a:BuildUI();a:ShowAdvancedAssignments()
check(a.ui.assignmentAdvanced:IsShown(),"window did not open")
check(a:CanEditAssignments() and a:CanEditAssignments(names[2]) and not a:CanEditAssignments(names[3]),"permissions")
local tank={kind="tank",role="main",player=names[3],target="Boss",note="Face away"}
check(a:EditAssignment("add",tank),"leader add")
check(not a:EditAssignment("add",tank),"duplicate accepted")
check(not a:EditAssignment("add",{kind="healer",role="group",player=names[2],target="9",note=""}),"bad group accepted")
check(a:EditAssignment("add",{kind="healer",role="group",player=names[2],target="2",note=""}),"healer add")
local b=a:AssignmentBoard();check(#b.rows==2 and b.revision==2,"board revision")
check(a.ui.assignmentAdvanced.rows[1].labels[5]:GetText()=="Offline","offline warning")
local function edit(sender,rev,id)
 a:Packet(sender,{kind="raidAssignments7",protocol=a.protocol,op="edit",data={epoch=b.epoch,revision=rev,op="remove",id=id}},"WHISPER")
end
edit(names[3],2,1);check(#b.rows==2,"member edit accepted")
edit(names[2],1,1);check(#b.rows==2,"stale assistant edit accepted")
edit(names[2],2,1);check(#b.rows==1 and b.revision==3,"assistant edit rejected")
e.NauseRaidToolsDB.profiles.Assignments={}
check(a:SaveAssignmentProfile("Assignments"),"profile save")
check(a:EditAssignment("remove",nil,b.rows[1].id) and #b.rows==0,"remove")
check(a:LoadAssignmentProfile("Assignments") and #b.rows==1,"profile restore")
check(a:AnnounceAssignments() and #chats==1 and chats[1][1]:find("Assist Realm",1,true),"manual spaced-name announcement")
a.demo=true;check(not a:EditAssignment("remove",nil,b.rows[1].id) and not a:AnnounceAssignments(),"loot test isolation")
a.demo=nil
-- Native member view: trust only the actual group leader, including delegated LC authority.
local snapshot=a.Copy(b);localIndex=3;a.me=names[3];a.leader=names[2];a.assignmentOwner=nil;a.assignmentBoard=nil
a:RefreshRoster();a.leader=names[2]
a:Packet(names[2],{kind="raidAssignments7",protocol=a.protocol,op="state",data=snapshot},"RAID")
check(a:AssignmentBoard()==nil,"nonleader snapshot accepted")
a:Packet(names[1],{kind="raidAssignments7",protocol=a.protocol,op="state",data=snapshot},"RAID")
check(a:AssignmentBoard() and #a:AssignmentBoard().rows==1,"leader snapshot rejected")
check(not a:CanEditAssignments() and not a:EditAssignment("add",tank),"member can edit")
local stale=a.Copy(snapshot);stale.revision=0;stale.rows={}
a:Packet(names[1],{kind="raidAssignments7",protocol=a.protocol,op="state",data=stale},"RAID")
check(#a:AssignmentBoard().rows==1,"stale state replaced board")
local bad=a.Copy(snapshot);bad.revision=100;bad.rows[1].note="bad|Hlink"
a:Packet(names[1],{kind="raidAssignments7",protocol=a.protocol,op="state",data=bad},"RAID")
check(a:AssignmentBoard().revision==snapshot.revision,"unsafe text accepted")
leader=2;a:RefreshRoster();check(a:AssignmentBoard()==nil,"leadership change retained old board")
grouped=false;a:RefreshRoster();check(a:CanEditAssignments() and a:AssignmentBoard().owner==a.me,"solo preparation")
-- Profile APIs include assignments, while plain older profiles remain safe to load.
localIndex=1;leader=1;grouped=true;a:RefreshRoster()
check(a:SaveProfile("Full setup"),"full profile save")
check(type(e.NauseRaidToolsDB.profiles["Full setup"].raidAssignmentPlan)=="table","full profile omitted assignment template")
a:ShowAdvancedAssignments();local ui=a.ui.assignmentAdvanced
ui.filter="mine";a:RenderAdvancedAssignments();check(not ui.rows[1]:IsShown(),"personal filter shows other players")
ui.filter="all";a:RenderAdvancedAssignments();check(ui.rows[1]:IsShown(),"all filter hides saved assignment")
-- A stale board cannot reappear after a leader changes away and back.
localIndex=3;a.me=names[3];a:RefreshRoster();a.assignmentOwner=nil;a.assignmentBoard=nil
local later=a.Copy(snapshot);later.revision=snapshot.revision+2
a:Packet(names[1],{kind="raidAssignments7",protocol=a.protocol,op="state",data=later},"RAID")
leader=2;a:RefreshRoster();a:AssignmentBoard();leader=1;a:RefreshRoster()
a:Packet(names[1],{kind="raidAssignments7",protocol=a.protocol,op="state",data=snapshot},"RAID")
check(a:AssignmentBoard()==nil,"old leader board replay accepted after leadership round trip")
print("Raid assignments: "..count.." checks passed")
