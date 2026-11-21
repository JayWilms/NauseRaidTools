local root=...
local make=assert(loadfile(root.."/qa/softres/improvements_client.lua"))(root,root)
local a,e=make("Lead-Realm");local count=0;local function check(v,m) count=count+1;assert(v,m) end
local grouped=false;local localName="Lead-Realm";local names={"Lead-Realm","Tank-Realm","Healer-Realm","Priest-Realm","Mage-Realm","Warlock-Realm","Rogue-Realm"}
local function name(unit) if unit=="player" then return localName end;return names[tonumber((unit or ""):match("raid(%d+)"))] end
e.IsInGroup=function() return grouped end;e.IsInRaid=function() return grouped end;e.GetNumGroupMembers=function() return #names end
e.UnitFullName=function(unit) local n=name(unit);if n then return n:match("^([^-]+)%-(.+)$") end end
e.UnitIsGroupLeader=function(unit) return name(unit)==names[1] end;e.UnitIsGroupAssistant=function() return false end
e.UnitIsConnected=function() return true end
local classes={[names[1]]="WARRIOR",[names[2]]="WARRIOR",[names[3]]="PRIEST",[names[4]]="PRIEST",[names[5]]="MAGE",[names[6]]="WARLOCK",[names[7]]="ROGUE"}
e.UnitClass=function(unit) local class=classes[name(unit)];return class,class end
e.GetBuildInfo=function() return "1.60.1","70959","",16001 end
local chats={};e.C_ChatInfo.SendChatMessage=function(text) chats[#chats+1]=text end
local printed={};function a:Print(text) printed[#printed+1]=text end
a:RefreshRoster();a:BuildUI();a:ShowAssignments()
local u=a.ui;local f=u.assignments;local chooser=u.assignmentChooser
check(chooser:IsShown() and not f:IsShown(),"Assignments did not open the raid chooser first")
check(#a:SimpleRaidChoices()==1 and a:SimpleRaidChoices()[1][1]=="Test Raid","empty chooser lacks Test Raid or invented saved raids")
check(chooser.new:IsEnabled() and chooser.help:GetText():find("No saved raids",1,true),"empty chooser does not offer New Raid")
local function select(control,value)
 check(control:IsEnabled(),"test tried selecting a disabled control")
 control:GetScript("OnClick")()
 local menu=u.settingsDropdown;check(menu and menu:IsShown(),"dropdown did not open")
 local index;for i,choice in ipairs(menu.choices) do if choice[2]==value then index=i end end
 check(index~=nil,"dropdown does not contain requested member/value: "..tostring(value))
 a:ScrollSettingsDropdown(math.max(0,index-8))
 local visible=index-(menu.offset or 0);menu.rows[visible]:GetScript("OnClick")()
end
chooser.new:GetScript("OnClick")();u.assignmentNameDialog.name:SetText("Guild Raid");u.assignmentNameDialog.confirm:GetScript("OnClick")()
check(f:IsShown() and not chooser:IsShown() and not f.practice,"new raid did not open the simple board")
local b=a:AssignmentBoard();check(b.raidName=="Guild Raid" and e.NauseRaidToolsDB.assignmentTemplates["Guild Raid"],"new raid was not saved in chooser")
check(#f.tables.tanks==8 and #f.tables.cc==8 and #f.tables.buffs==6,"marker and buff tables missing rows")
grouped=true;a:RefreshRoster()
local skull=f.tables.tanks[1];check(skull.marker==8 and skull.label:GetText()=="Skull","marker order does not start with skull")
check(#skull.controls==3,"tank row does not have tank and two healer dropdowns")
select(skull.controls[1],names[1]);select(skull.controls[2],names[3]);select(skull.controls[3],names[4])
local tank=a:MarkerBoardRow(b,"raid","tank",8);local h1=a:MarkerBoardRow(b,"raid","healer",8,1);local h2=a:MarkerBoardRow(b,"raid","healer",8,2)
check(tank.player==names[1] and h1.player==names[3] and h2.player==names[4] and h1.link==tank.id and h2.link==tank.id,"tank/healer assignment did not preserve marker links")
select(skull.controls[1],names[2]);check(a:AssignmentTarget(h1,"raid"):find("Tank Realm",1,true),"healers did not follow tank replacement")
select(skull.controls[2],"");check(a:MarkerBoardRow(b,"raid","healer",8,1).player=="","clear dropdown did not unassign healer")
f.tabs.cc:GetScript("OnClick")()
local ccPlayers={names[7],names[6],names[5]}
for i,kind in ipairs({"interrupt","banish","sheep"}) do select(f.tables.cc[1].controls[i],ccPlayers[i]);check(a:MarkerBoardRow(b,"raid",kind,8).player==ccPlayers[i],"CC marker assignment missing") end
f.tabs.buffs:GetScript("OnClick")();local fort=f.tables.buffs[2]
check(fort.buff=="fortitude" and fort.label:GetText()=="Power Word: Fortitude","buff labels not based on native raid buff definitions")
select(fort.controls[1],names[3]);select(fort.controls[2],names[4]);select(fort.coverage,"1-4")
local buff=a:MarkerBoardRow(b,"raid","buff",nil,nil,"fortitude")
check(buff.player==names[3] and buff.backup==names[4] and buff.target=="1-4","buff player/backup/coverage were not saved")
local rev=b.revision;select(fort.controls[2],names[3]);check(b.revision==rev,"buff backup can duplicate primary")
check(#chats==0,"selecting players automatically announced assignments")
f.save:GetScript("OnClick")();check(#e.NauseRaidToolsDB.assignmentTemplates["Guild Raid"].rows==#b.rows,"Save Raid omitted cells")
-- Reopening saved raids goes through the same chooser and retains all assignments.
a:ShowAssignments();select(chooser.raid,"plan:Guild Raid");chooser.open:GetScript("OnClick")();a:AcceptConfirmation()
check(f:IsShown() and a:AssignmentBoard().raidName=="Guild Raid" and not chooser:IsShown(),"saved raid load did not return to simple board")
b=a:AssignmentBoard();check(a:MarkerBoardRow(b,"raid","banish",8).player==names[6],"saved raid lost banish marker")
a:ShowAssignmentNameDialog("save");u.assignmentNameDialog.name:SetText("Guild Raid copy");u.assignmentNameDialog.confirm:GetScript("OnClick")()
check(b.raidName=="Guild Raid copy" and e.NauseRaidToolsDB.assignmentTemplates["Guild Raid copy"].raidName=="Guild Raid copy","Save As retained the wrong internal raid name")
-- Every marker and buff entry uses the common player dropdown, including long practice lists.
a:OpenSimpleAssignmentsBoard(true)
check(f.practice and a:SimpleAssignmentBoard().raidName=="Test Raid","Test Raid not offered/opened")
check(not f.save:IsEnabled() and not e.NauseRaidToolsDB.assignmentTemplates["Test Raid"],"Test Raid can overwrite saved raids")
local liveRev=b.revision;local liveCount=#b.rows;local savedCount=0;for _ in pairs(e.NauseRaidToolsDB.assignmentTemplates) do savedCount=savedCount+1 end
local sent=#a.sent;local chatCount=#chats
local practiceNames=a:SimpleAssignmentPlayerChoices();check(#practiceNames>=21,"practice dropdown does not include a rehearsal roster")
f.tabs.tanks:GetScript("OnClick")();select(f.tables.tanks[1].controls[1],"TestTank03-Practice")
check(a:MarkerBoardRow(a:SimpleAssignmentBoard(),"raid","tank",8).player=="TestTank03-Practice","practice member dropdown did not save locally")
f.announce:GetScript("OnClick")()
check(b.revision==liveRev and #b.rows==liveCount and #a.sent==sent and #chats==chatCount,"practice edits/preview changed live state or sent messages")
check(#printed>0 and printed[#printed]:find("Test",1,true),"practice announcement did not produce local preview")
check(not a:SaveSimpleAssignmentRaid("Test data"),"practice data can be saved to a real raid")
-- A dropdown opened before another officer's update cannot overwrite that update.
a:OpenSimpleAssignmentsBoard(false);b=a:AssignmentBoard();f.tabs.tanks:GetScript("OnClick")()
local control=f.tables.tanks[1].controls[1];control:GetScript("OnClick")();local menu=u.settingsDropdown;local callback=menu.action
a:EditAssignment("raidName",{name="Officer update"});rev=b.revision;callback(names[1]);check(b.revision==rev,"stale dropdown overwrote newer plan")
a:CloseSettingsDropdown()
-- Encounter overrides stay isolated and healer links follow the matching target marker.
a:SimpleEncounterAction("encounterAdd","Encounter A");local alpha=b.activeEncounter
select(f.tables.tanks[1].controls[1],names[1]);check(a:MarkerBoardRow(b,alpha,"tank",8).player==names[1] and a:MarkerBoardRow(b,"raid","tank",8).player==names[2],"marker override changed the whole raid")
check(a:AssignmentTarget(a:MarkerBoardRow(b,alpha,"healer",8,2),alpha):find("Lead Realm",1,true),"inherited marker healer did not follow encounter tank")
-- Members can view the live tables and practise locally, but cannot change the shared plan.
grouped=true;localName=names[3];a:RefreshRoster();a.assignmentOwner=names[1];a.assignmentBoard=b;a:OpenSimpleAssignmentsBoard(false)
check(not f.tables.tanks[1].controls[1]:IsEnabled() and not f.tables.buffs[1].controls[1]:IsEnabled() and not chooser.new:IsEnabled(),"member can edit live cells or create shared raids")
check(not a:SetSimpleAssignmentCell({kind="tank",marker=8},"player",names[3]),"member edit bypassed dropdown permissions")
a:OpenSimpleAssignmentsBoard(true)
sent=#a.sent;chatCount=#chats;select(f.tables.tanks[1].controls[2],"TestHealer06-Practice")
check(#a.sent==sent and #chats==chatCount,"group member practice leaked to the group")
-- Smaller screens retain scrollable tables and footer controls.
local oldHeight=e.UIParent.GetHeight;e.UIParent.GetHeight=function() return 530 end;a:RenderAssignments()
check(f:GetHeight()==506 and f.scroll:GetHeight()==236,"compact board does not fit a smaller screen")
e.UIParent.GetHeight=oldHeight
print("Simple assignment board: "..count.." checks passed; chooser, markers, member dropdowns, buffs, saves, overrides, test isolation and permissions")
