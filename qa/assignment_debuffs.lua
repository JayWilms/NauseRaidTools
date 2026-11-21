local root=...
local make=assert(loadfile(root.."/qa/softres/improvements_client.lua"))(root,root)
local a,e=make("Lead-Realm");local count=0;local function check(v,m) count=count+1;assert(v,m) end
e.IsInGroup=function() return false end;e.IsInRaid=function() return false end
e.GetBuildInfo=function() return "1.60.1","70959","",16001 end
a:BuildUI();a:OpenSimpleAssignmentsBoard(true);local f=a.ui.assignments
local live=a:AssignmentBoard();local revision=live.revision;local sent=#a.sent
local function select(control,value)
 control:GetScript("OnClick")();local menu=a.ui.settingsDropdown;check(menu and menu:IsShown(),"dropdown did not open")
 local index;for i,v in ipairs(menu.choices) do if v[2]==value then index=i end end
 check(index~=nil,"choice missing: "..tostring(value));a:ScrollSettingsDropdown(math.max(0,index-8));menu.rows[index-(menu.offset or 0)]:GetScript("OnClick")()
end
local function row(key) return a:MarkerBoardRow(a:SimpleAssignmentBoard(),"raid","debuff",nil,nil,key) end
f.tabs.debuffs:GetScript("OnClick")()
check(#f.tables.debuffs==6 and f.tables.debuffs[1]:IsShown() and f.headings[1]:GetText()=="Debuff","debuff table missing")
check(row("elements").player=="TestWarlock01-Practice" and row("recklessness").player=="TestWarlock02-Practice","practice curse seed wrong")
check(row("faerieFire").player=="TestDruid01-Practice" and row("exposeArmor").player=="TestRogue01-Practice","practice armor seed wrong")
local expected={elements="WARLOCK",recklessness="WARLOCK",weakness="WARLOCK",tongues="WARLOCK",faerieFire="DRUID",exposeArmor="ROGUE"}
for i,key in ipairs(a.assignmentDebuffOrder) do
 local def=a.assignmentDebuffDefinitions[key];local visual=f.tables.debuffs[i]
 check(def.provider==expected[key] and visual.label:GetText()==def.label and def.icon:find("Interface/Icons/",1,true),"debuff label/icon missing")
 for _,control in ipairs(visual.controls) do
  control:GetScript("OnClick")();local choices=a.ui.settingsDropdown.choices;local found=0
  for _,choice in ipairs(choices) do if choice[2]~="" then
   check(a:AssignmentMemberInfo(choice[2],true).class==expected[key],"wrong class in "..key.." "..control.field);found=found+1
  end end
  check(found>=2,"eligible practice players missing");a:CloseSettingsDropdown()
 end
end
select(f.tables.debuffs[3].controls[1],"TestWarlock01-Practice")
select(f.tables.debuffs[3].controls[2],"TestWarlock02-Practice")
check(row("weakness").player=="TestWarlock01-Practice" and row("weakness").backup=="TestWarlock02-Practice","actor/backup menu did not assign")
check(a:AssignmentText(row("weakness"),"raid"):find("backup TestWarlock02 Practice",1,true),"announcement omitted backup")
local rev=a:SimpleAssignmentBoard().revision
check(not a:SetSimpleAssignmentCell({kind="debuff",debuff="weakness"},"player","TestMage01-Practice"),"wrong curse class accepted")
check(not a:SetSimpleAssignmentCell({kind="debuff",debuff="weakness"},"backup","TestWarlock01-Practice"),"same primary/backup accepted")
check(a:SimpleAssignmentBoard().revision==rev,"rejected debuff edit mutated plan")
select(f.tables.debuffs[3].controls[2],"")
check(row("weakness").backup=="","backup cannot clear")
local plan=a:CleanAssignmentPlan(a.Decode(a.Encode(a:AssignmentPlan(a:SimpleAssignmentBoard()))))
check(plan~=nil,"debuff failed saved/wire roundtrip")
local found=0;for _,v in ipairs(plan.rows) do if v.kind=="debuff" then found=found+1;check(expected[v.debuff]~=nil,"lost debuff identifier") end end
check(found==5,"saved plan lost debuff rows")
local copy=a:EditedAssignmentPlan(a:SimpleAssignmentBoard(),"copyEncounter",{name="Copy with debuffs"},"raid")
check(copy~=nil,"raid defaults containing debuffs cannot copy to encounter")
for _,v in ipairs(copy.rows) do if v.kind=="debuff" then check(v.encounter=="raid","debuff copied into boss scope") end end
select(f.encounter,"e1")
check(not f.tabs.debuffs:IsShown() and not f.tabs.buffs:IsShown() and f.panel=="tanks","whole-raid tabs visible on boss")
check(not a:SetSimpleAssignmentCell({kind="debuff",debuff="elements"},"player","TestWarlock02-Practice"),"boss scope accepted debuff")
select(f.encounter,"raid");f.tabs.debuffs:GetScript("OnClick")()
check(f.tabs.debuffs:IsShown() and f.tables.debuffs[1]:IsShown(),"debuff tab did not return")
a.me="TestWarlock01-Practice";f.mineButton:GetScript("OnClick")()
local mine={};for _,v in ipairs(a.ui.myAssignments.entries) do if v.row then mine[v.row.debuff]=true end end
check(mine.elements and mine.weakness and not mine.faerieFire,"personal popup did not include only assigned debuffs")
a.me="Lead-Realm"
local bad=a:AssignmentPlan(a:SimpleAssignmentBoard());for _,v in ipairs(bad.rows) do if v.kind=="debuff" then v.encounter="e1";break end end
check(not a:CleanAssignmentPlan(bad),"saved boss-specific debuff accepted")
check(live.revision==revision and #a.sent==sent,"practice debuffs wrote/sent live state")
print("Debuff assignments: "..count.." checks passed; whole raid, classes, backups, local practice, targets, persistence and copying")
