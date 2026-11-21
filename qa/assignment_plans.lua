local root=...
local make=assert(loadfile(root.."/qa/softres/improvements_client.lua"))(root,root)
local a,e=make("Lead-Realm");local checks=0;local function check(v,m) checks=checks+1;assert(v,m) end
local grouped=false;local leader=true;local assistant=false;local names={"Lead-Realm","Tank-Realm","Healer-Realm","Backup-Realm"}
local function nameFor(unit) if unit=="player" then return a.me end;return names[tonumber((unit or ""):match("raid(%d+)"))] end
e.IsInGroup=function() return grouped end;e.IsInRaid=function() return grouped end;e.GetNumGroupMembers=function() return #names end
e.UnitFullName=function(unit) local name=nameFor(unit);if name then return name:match("^([^-]+)%-(.+)$") end end
e.UnitIsGroupLeader=function(unit) return nameFor(unit)==names[1] and leader end
e.UnitIsGroupAssistant=function(unit) return nameFor(unit)==names[4] and assistant end
e.UnitIsConnected=function(unit) return nameFor(unit)~=names[4] end
e.GetBuildInfo=function() return "1.60.1","70959","",16001 end
local chats={};e.C_ChatInfo.SendChatMessage=function(text,channel) chats[#chats+1]={text,channel} end
-- Migrate an existing tank/healer list without dropping duplicate-role targets.
e.NauseRaidToolsDB.raidAssignments={epoch=50,rows={{id=4,kind="tank",role="off",player=names[1],target="Add A",note=""},{id=7,kind="tank",role="off",player=names[2],target="Add B",note=""}}}
a.assignmentBoard=nil;a.assignmentOwner=nil;a:RefreshRoster();local b=a:AssignmentBoard()
check(b.schema==2 and #b.rows==2 and b.rows[1].slot==1 and b.rows[2].slot==2,"legacy rows were lost or overlapped")
check(b.nextRow==8 and b.activeEncounter=="raid","migration reused IDs or scope")
check(a:CommitAssignmentPlan({schema=2,raidName="Unknown raid",encounters={},activeEncounter="raid",rows={}}),"fresh plan")
check(a:EditAssignment("raidName",{name="Our custom raid"}),"custom raid name")
local function add(kind,role,player,target,options)
 local r={kind=kind,role=role,player=player or "",target=target or "",note="",encounter="raid",slot=1}
 for k,v in pairs(options or {}) do r[k]=v end
 local id=b.nextRow;local ok=a:EditAssignment("add",r);return ok,id
end
local ok,mt=add("tank","main",names[2],"Boss");check(ok,"default main tank")
local _,healer=add("healer","tank",names[3],"",{link=mt,backup=names[4]})
check(#b.rows==2 and a:AssignmentTarget(b.rows[2],"raid"):find("Tank Realm",1,true),"linked healer target")
check(not add("tank","main",names[1],"Boss"),"duplicate slot accepted")
check(not add("custom","custom","","",{job=""}),"unnamed custom job accepted")
check(not add("interrupt","interrupt",names[1],"",{backup=names[1]}),"self backup accepted")
check(not add("interrupt","interrupt","","",{slot=0}),"zero slot accepted")
check(not a:EditAssignment("encounterAdd",{name="|Hbad"}),"unsafe encounter name")
check(a:EditAssignment("encounterAdd",{name="Boss Alpha (custom)"}),"add encounter")
local alpha=b.activeEncounter;check(alpha~="raid" and #a:EffectiveAssignments(alpha)==2,"defaults not inherited")
check(not a:EditAssignment("encounterAdd",{name="boss alpha (custom)"}),"duplicate encounter name accepted")
local _,override=add("tank","main",names[1],"Boss A",{encounter=alpha})
local function find(id) for _,r in ipairs(b.rows) do if r.id==id then return r end end end
check(#a:EffectiveAssignments(alpha)==2 and a:AssignmentTarget(find(healer),alpha):find("Lead Realm",1,true),"default healer did not follow overridden tank")
check(a:AssignmentTarget(find(healer),"raid"):find("Tank Realm",1,true),"boss override changed defaults")
check(add("interrupt","interrupt","","Add A",{encounter=alpha,job="Kick rotation"}),"unfilled interrupt slot")
check(add("interrupt","interrupt",names[2],"Add A",{encounter=alpha,job="Kick rotation",slot=2,backup=names[4]}),"numbered interrupt and backup")
check(add("dispel","dispel",names[3],"Marked player",{encounter=alpha}),"dispel job")
check(add("cooldown","cooldown",names[1],"When called",{encounter=alpha}),"cooldown job")
check(add("custom","custom","","Moon",{encounter=alpha,job="Handle marked add"}),"custom job")
check(#a:EffectiveAssignments(alpha)==7 and #a:EffectiveAssignments("raid")==2,"encounter jobs leaked into defaults")
check(a:EditAssignment("encounterAdd",{name="Boss Beta (custom)"}),"second encounter")
local beta=b.activeEncounter
check(#a:EffectiveAssignments(beta)==2,"alpha jobs leaked into beta")
check(not add("healer","tank",names[3],"",{encounter=beta,slot=2,link=override}),"cross-encounter link accepted")
check(not add("healer","tank",names[3],"",{slot=2,link=override}),"default linked to encounter-specific job")
local rev=b.revision
check(not a:EditAssignment("remove",nil,mt) and b.revision==rev and find(mt),"referenced slot removed or partial mutation")
local changed=a.Copy(find(mt));changed.link=healer
check(not a:EditAssignment("update",changed,mt),"cyclic links accepted")
check(a:EditAssignment("copyEncounter",{name="Alpha copy"},alpha),"copy encounter")
local copyScope=b.activeEncounter;local copyRows=a:EffectiveAssignments(copyScope);check(#copyRows==7,"copy omitted defaults or jobs")
local copiedTank,copiedHealer
for _,r in ipairs(copyRows) do if r.role=="main" then copiedTank=r elseif r.role=="tank" then copiedHealer=r end end
check(copiedHealer.link==copiedTank.id and copiedTank.encounter==copyScope,"copy did not remap linked defaults to copied slots")
changed=a.Copy(copiedTank);changed.player=names[4];check(a:EditAssignment("update",changed,changed.id),"copied tank replacement")
check(a:AssignmentTarget(copiedHealer,copyScope):find("Backup Realm",1,true),"linked target did not update after replacement")
check(a:AssignmentTarget(find(healer),alpha):find("Lead Realm",1,true),"copy edit changed source encounter")
check(a:SaveAssignmentTemplate("Week one"),"save standalone template")
check(a:EditAssignment("raidName",{name="Temporary"}) and a:LoadAssignmentTemplate("Week one") and b.raidName=="Our custom raid","template did not restore entire plan")
check(#b.encounters==3 and #a:EffectiveAssignments(copyScope)==7,"template omitted encounters/jobs")
e.NauseRaidToolsDB.profiles.Raid={}
check(a:SaveAssignmentProfile("Raid") and e.NauseRaidToolsDB.profiles.Raid.raidAssignmentPlan.schema==2,"raid profile omitted full plan")
check(a:EditAssignment("encounterRemove",nil,alpha) and not find(override) and find(mt),"encounter removal affected defaults or retained specific jobs")
check(a:LoadAssignmentProfile("Raid") and find(override),"raid profile restore failed")
local bad=a:AssignmentPlan();bad.rows[1].link=999999;rev=b.revision
check(not a:CommitAssignmentPlan(bad) and b.revision==rev,"invalid template partially applied")
-- Scoped announcements and backup names; no chat is sent while preparing a plan.
check(#chats==0,"preparation automatically posted chat")
grouped=true;a:RefreshRoster();b=a:AssignmentBoard();a:LoadAssignmentTemplate("Week one");b=a:AssignmentBoard()
check(a:EditAssignment("activate",nil,beta),"select current encounter")
check(a:AnnounceAssignments() and #chats==2,"announcement included other encounters")
check(chats[1][1]:find("Boss Beta",1,true) and not chats[1][1]:find("Kick rotation",1,true),"announcement omitted encounter or leaked other jobs")
check(chats[2][1]:find("backup Backup Realm",1,true),"announcement omitted full backup name")
check(not a:CreateAssignmentPractice(),"practice data created in live group")
a:BuildUI();a:ShowAdvancedAssignments();local ui=a.ui.assignmentAdvanced
ui.filter="mine";a:RenderAdvancedAssignments();check(not ui.rows[1]:IsShown(),"personal view showed another player's job")
a.me=names[4];a:RefreshRoster();-- Native leader remains Lead; retain the received plan as a member.
a.assignmentOwner=names[1];a.assignmentBoard=b
ui.filter="mine";a:RenderAdvancedAssignments();check(ui.rows[1]:IsShown() and ui.rows[1].value.id==healer,"personal view omitted backup job")
check(not ui.apply:IsEnabled() and not ui.activate:IsEnabled() and not a:EditAssignment("raidName",{name="Bad"}),"member can edit metadata")
a.me=names[1];a:RefreshRoster();a.assignmentBoard=b;a.assignmentOwner=names[1];ui.filter="all";ui.viewEncounter=alpha;a:RenderAdvancedAssignments()
-- Editing an inherited row creates a boss override instead of changing the default.
local control
for _,r in ipairs(ui.rows) do if r.value and r.value.id==healer then control=r end end
check(control~=nil,"inherited healer not rendered")
control:GetScript("OnClick")();ui.note:SetText("Only for Alpha");ui.apply:GetScript("OnClick")()
check(find(healer).note=="" and #a:EffectiveAssignments(alpha)==7,"override editor changed raid-wide default")
local healerOverride
for _,r in ipairs(b.rows) do if r.encounter==alpha and r.role=="tank" then healerOverride=r end end
check(healerOverride and healerOverride.note=="Only for Alpha","boss override did not save")
a:RenderAdvancedAssignments();for _,r in ipairs(ui.rows) do if r.value and r.value.id==healerOverride.id then control=r end end
control:GetScript("OnClick")();changed=a.Copy(healerOverride);changed.note="Officer update";a:EditAssignment("update",changed,changed.id)
check(ui.stale and not ui.apply:IsEnabled(),"stale editor can overwrite a newer officer edit")
ui.slot:SetText("");ui.selected=nil;ui.editBasis=nil;ui.role="interrupt";a:RenderAdvancedAssignments();rev=b.revision;ui.apply:GetScript("OnClick")()
check(b.revision==rev,"empty slot editor silently saved as slot one")
-- Removal and load confirmations cannot apply after the plan changes.
check(a:ConfirmAssignmentAction("encounterRemove","Alpha",alpha),"remove confirmation did not open")
a:EditAssignment("raidName",{name="Changed while confirming"});a:AcceptConfirmation()
local exists=false;for _,enc in ipairs(b.encounters) do if enc.id==alpha then exists=true end end
check(exists,"stale confirmation removed an encounter")
check(a:ConfirmAssignmentAction("load","Week one","plan:Week one"),"load confirmation did not open")
a:AcceptConfirmation();check(b.raidName=="Our custom raid","confirmed template load failed")
check(a:DeleteAssignmentTemplate("Week one") and not a:LoadAssignmentTemplate("Week one"),"saved template delete")
grouped=false;a:RefreshRoster();b=a:AssignmentBoard();local before=#b.rows
check(a:CreateAssignmentPractice() and #b.rows==before+3,"fictional practice plan")
local practice=b.activeEncounter;check(a:AssignmentEncounterName(practice):find("fictional",1,true),"practice not labelled fictional")
local n=0;for _,r in ipairs(b.rows) do if r.encounter==practice then n=n+1;check(r.player=="" and r.note:find("Fictional",1,true),"practice used real players or implied real mechanics") end end
check(n==3,"practice fixture jobs missing")
-- Smaller screens keep the editor below the list without clipping the footer.
local oldHeight=e.UIParent.GetHeight;e.UIParent.GetHeight=function() return 700 end;a:RenderAdvancedAssignments()
check(ui:GetHeight()==676 and ui.scroll:GetHeight()==140,"compact screen did not reduce scrolling area")
e.UIParent.GetHeight=oldHeight
-- A blank raid and deleting a saved template do not erase other saved plans.
check(a:SaveAssignmentTemplate("Keep this raid"),"save before new raid")
check(a:ConfirmAssignmentAction("newRaid","Another custom raid"),"new raid confirmation")
a:AcceptConfirmation();check(b.raidName=="Another custom raid" and #b.rows==0 and #b.encounters==0,"new raid did not start blank")
check(a:LoadAssignmentTemplate("Keep this raid") and #b.rows>0,"new raid erased saved template")
-- Malformed version-two snapshots are rejected without running a reducer.
grouped=true;a.me=names[4];a:RefreshRoster();a.assignmentOwner=names[1];a.assignmentBoard=b
local snapshot=a.Copy(b);snapshot.owner=names[1];snapshot.epoch=nil
local success=pcall(a.Packet,a,names[1],{kind="raidAssignments7",protocol=a.protocol,op="state",data=snapshot},"RAID")
check(success and a.assignmentBoard==b,"malformed snapshot crashed or changed plan")
a:Packet(names[1],{kind="raidAssignments",protocol=a.protocol,op="state",data={rows={}}},"RAID")
check(a.assignmentBoard==b,"legacy wire traffic flattened the plan")
grouped=false;a.me=names[1];a:RefreshRoster();b=a:AssignmentBoard()
a.demo=true;rev=b.revision;check(not a:CreateAssignmentPractice() and not a:SaveAssignmentTemplate("Test") and not a:EditAssignment("encounterAdd",{name="Test"}) and b.revision==rev,"loot test isolation")
print("Raid plans: "..checks.." checks passed; defaults, encounters, linked overrides, slots, backups, templates, practice, editor and permissions")
