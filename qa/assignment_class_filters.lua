local root=...
local make=assert(loadfile(root.."/qa/softres/improvements_client.lua"))(root,root)
local a,e=make("Lead-Realm");local count=0;local function check(v,m) count=count+1;assert(v,m) end
local data={{"Lead-Realm","WARRIOR","TANK"},{"Warrior-Realm","WARRIOR","DAMAGER"},{"Holy-Realm","PALADIN","HEALER"},{"Prot-Realm","PALADIN","TANK"},{"Ret-Realm","PALADIN","DAMAGER"},{"Resto-Realm","DRUID","HEALER"},{"Bear-Realm","DRUID","TANK"},{"Cat-Realm","DRUID","DAMAGER"},{"Priest-Realm","PRIEST","HEALER"},{"Shadow-Realm","PRIEST","DAMAGER"},{"Shaman-Realm","SHAMAN","HEALER"},{"Elemental-Realm","SHAMAN","DAMAGER"},{"Mage-Realm","MAGE","DAMAGER"},{"Warlock-Realm","WARLOCK","DAMAGER"},{"Rogue-Realm","ROGUE","DAMAGER"},{"Hunter-Realm","HUNTER","DAMAGER"},{"UnknownPriest-Realm","PRIEST","NONE"},{"UnknownDruid-Realm","DRUID","NONE"},{"Missing-Realm",nil,"NONE"}}
local byName={};for _,d in ipairs(data) do byName[d[1]]=d end
local function member(unit) if unit=="player" then return data[1] end;return data[tonumber((unit or ""):match("raid(%d+)"))] end
e.IsInGroup=function() return true end;e.IsInRaid=function() return true end;e.GetNumGroupMembers=function() return #data end
e.UnitFullName=function(unit) local d=member(unit);if d then return d[1]:match("^([^-]+)%-(.+)$") end end
e.UnitIsGroupLeader=function(unit) return member(unit)==data[1] end;e.UnitIsGroupAssistant=function(unit) return member(unit)==data[2] end
e.UnitClass=function(unit) local d=member(unit);if d then return d[2],d[2] end end
e.UnitGroupRolesAssigned=function(unit) local d=member(unit);return d and d[3] end
e.GetBuildInfo=function() return "1.60.1","70959","",16001 end
a:RefreshRoster();a:BuildUI();a:OpenSimpleAssignmentsBoard(false)
local rules={
 tank={WARRIOR=true,PALADIN=true,DRUID=true},healer={PRIEST=true,PALADIN=true,SHAMAN=true,DRUID=true},
 interrupt={ROGUE=true,SHAMAN=true,MAGE=true,WARRIOR=true,WARLOCK=true},banish={WARLOCK=true},sheep={MAGE=true},tranq={HUNTER=true},dispel={PRIEST=true,PALADIN=true},decurse={MAGE=true,DRUID=true}}
local function choices(cell,practice)
 local list={};for _,choice in ipairs(a:SimpleAssignmentPlayerChoices("Unassigned",cell,practice)) do list[choice[2]]=choice[1] end;return list
end
for kind,classes in pairs(rules) do
 local list=choices({kind=kind},false);check(list[""]~=nil,"unassigned disappeared")
 for _,d in ipairs(data) do
  local role=d[3];local expected=d[2]~=nil and classes[d[2]]==true
  check((list[d[1]]~=nil)==expected,kind.." has wrong candidate: "..d[1])
 end
end
-- Native Damage/Healer role flags do not remove tank-capable classes from planned tank jobs.
local tanks=choices({kind="tank"},false)
check(tanks["Warrior-Realm"] and tanks["Ret-Realm"] and tanks["Cat-Realm"],"damage-role tank classes are hidden")
check(not tanks["Rogue-Realm"] and not tanks["Warlock-Realm"] and not tanks["Mage-Realm"],"tank class filter was lost")
check(a:SetSimpleAssignmentCell({kind="tank",marker=1},"player","Warrior-Realm"),"native Damage warrior cannot be assigned as tank")
check(a:ApplyAssignmentEdit("boardCell",{kind="tank",marker=1,value="Ret-Realm",encounter="raid"}),"host rejected a damage-role tank-capable class")
check(a:SetSimpleAssignmentCell({kind="tank",marker=1},"player",""),"tank assignment could not clear")
check(a:ApplyAssignmentEdit("remove",nil,a:MarkerBoardRow(a:AssignmentBoard(),"raid","tank",1).id),"tank regression setup did not clean up")
local providers={intellect="MAGE",fortitude="PRIEST",mark="DRUID",kings="PALADIN",might="PALADIN",wisdom="PALADIN"}
for buff,provider in pairs(providers) do
 local list=choices({kind="buff",buff=buff},false)
 for _,d in ipairs(data) do check((list[d[1]]~=nil)==(d[2]==provider),buff.." provider class is wrong") end
end
local list=choices({kind="interrupt"},false)
check(list["Warlock-Realm"]:find("Felhunter",1,true) and list["Warlock-Realm"]:find("Warlock Realm",1,true),"pet-only label missing or identity shortened")
local b=a:AssignmentBoard();local rev=b.revision
check(not a:SetSimpleAssignmentCell({kind="healer",marker=8},"player","Rogue-Realm") and b.revision==rev,"direct incompatible assignment passed")
check(not a:ApplyAssignmentEdit("boardCell",{kind="sheep",marker=5,value="Warlock-Realm",encounter="raid"}) and b.revision==rev,"host accepted wrong sheep class")
check(not a:ApplyAssignmentEdit("boardCell",{kind="buff",buff="fortitude",field="backup",value="Mage-Realm",encounter="raid"}),"host accepted wrong buff backup")
a:Packet(data[2][1],{kind="raidAssignments7",protocol=a.protocol,op="edit",data={epoch=b.epoch,revision=b.revision,op="boardCell",row={kind="healer",marker=8,value="Rogue-Realm",encounter="raid"}}},"WHISPER")
check(b.revision==rev,"assistant could bypass class validation")
check(a:SetSimpleAssignmentCell({kind="healer",marker=8},"player","Priest-Realm"),"eligible priest was blocked")
-- Known roles are optional, and absent APIs do not break class filtering.
e.UnitGroupRolesAssigned=nil
local listNoRoles=choices({kind="healer"},false)
check(not listNoRoles["Rogue-Realm"] and not listNoRoles["Warlock-Realm"] and listNoRoles["UnknownDruid-Realm"],"role-unknown class fallback incorrect")
check(a:SetSimpleAssignmentCell({kind="tank",marker=7},"player","UnknownDruid-Realm"),"unknown-role tank-capable druid blocked")
check(choices({kind="healer"},false)["UnknownDruid-Realm"],"planned tank role incorrectly hid a healer-capable druid")
-- Raid roster combatRole and main-tank designation are valid fallbacks.
e.GetRaidRosterInfo=function(index)
 local d=data[index]
 return d[1],0,1,60,d[2],d[2],"Zone",true,false,index==7 and "MAINTANK" or nil,false,index==3 and "HEALER" or nil
end
check(a:AssignmentMemberInfo("Bear-Realm",false).role=="TANK" and a:AssignmentMemberInfo("Holy-Realm",false).role=="HEALER","raid role fallback ignored")
e.GetRaidRosterInfo=nil
-- Stored mistakes stay visible and removable; filtering never erases a saved plan.
local invalid=a:AssignmentPlan();invalid.rows[1].player="Rogue-Realm";check(a:CommitAssignmentPlan(invalid),"older plan could not be retained")
a:RenderAssignments();local control=a.ui.assignments.tables.tanks[1].controls[2]
check(control:GetText():find("not eligible",1,true),"stored wrong-class assignment was not flagged")
check(a:SetSimpleAssignmentCell({kind="healer",marker=8},"player",""),"wrong-class saved player cannot be cleared")
-- Role changes remain valid; actual class eligibility is still rechecked on selection.
e.UnitGroupRolesAssigned=function(unit) local d=member(unit);return d and d[3] end
control:GetScript("OnClick")();local callback=a.ui.settingsDropdown.action;data[3][3]="DAMAGER";rev=b.revision
callback("Holy-Realm");check(b.revision==rev+1 and a:MarkerBoardRow(b,"raid","healer",8,1).player=="Holy-Realm","damage-role paladin was rejected as a healer")
a:CloseSettingsDropdown();control:GetScript("OnClick")();callback=a.ui.settingsDropdown.action;data[3][2]="ROGUE";rev=b.revision
callback("Holy-Realm");check(b.revision==rev,"class changed to ineligible while dropdown was open but selection succeeded")
data[3][2]="PALADIN"
data[3][3]="HEALER";a:CloseSettingsDropdown()
-- Practice data uses the same filters and includes all four healing classes.
a:OpenSimpleAssignmentsBoard(true)
local healers=choices({kind="healer"},true)
check(not healers["TestTank01-Practice"] and healers["TestTank02-Practice"] and healers["TestTank03-Practice"] and not healers["TestRogue01-Practice"] and not healers["TestWarlock01-Practice"],"practice healer menu does not filter by the four healer-capable classes")
local seen={};for name in pairs(healers) do if name~="" then local info=a:AssignmentMemberInfo(name,true);seen[info.class]=true end end
check(seen.PRIEST and seen.PALADIN and seen.SHAMAN and seen.DRUID,"practice does not represent four healing classes")
check(healers["TestDruid02-Practice"] and healers["TestPaladin01-Practice"],"damage-role practice druid/paladin excluded from healer options")
for _,kind in ipairs({"sheep","banish","interrupt"}) do
 for name in pairs(choices({kind=kind},true)) do if name~="" then check(rules[kind][a:AssignmentMemberInfo(name,true).class],"practice CC list has incompatible class") end end
end
for buff,provider in pairs(providers) do
 for name in pairs(choices({kind="buff",buff=buff},true)) do if name~="" then check(a:AssignmentMemberInfo(name,true).class==provider,"practice buff class mismatch") end end
end
print("Assignment class filters: "..count.." checks passed; all nine classes, roles, missing APIs, buffs, pet label, practice and host validation")
