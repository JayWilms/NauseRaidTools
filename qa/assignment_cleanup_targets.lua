local root=...
local make=assert(loadfile(root.."/qa/softres/improvements_client.lua"))(root,root)
local a,e=make("Lead-Realm");local count=0;local function check(v,m) count=count+1;assert(v,m) end
e.IsInGroup=function() return false end;e.IsInRaid=function() return false end
e.GetBuildInfo=function() return "1.60.1","70959","",16001 end
a:BuildUI();a:OpenSimpleAssignmentsBoard(true);local f=a.ui.assignments;f.tabs.cleanup:GetScript("OnClick")()
local function select(control,value)
 control:GetScript("OnClick")();local menu=a.ui.settingsDropdown;check(menu and menu:IsShown(),"dropdown did not open")
 local index;for i,v in ipairs(menu.choices) do if v[2]==value then index=i end end
 check(index~=nil,"target choice missing: "..tostring(value));a:ScrollSettingsDropdown(math.max(0,index-8));menu.rows[index-(menu.offset or 0)]:GetScript("OnClick")()
end
local function row(kind,slot,scope) return a:MarkerBoardRow(a:SimpleAssignmentBoard(),scope or a:SimpleAssignmentScope(),kind,nil,nil,nil,nil,slot) end
check(f.headings[3]:GetText()=="Target" and f.tables.cleanup[1].target==f.tables.cleanup[1].coverage,"target column not exposed")
local choices={};for _,v in ipairs(a:AssignmentCleanupTargetChoices()) do choices[v[2]]=v[1] end
check(choices["1-2"] and choices["3-4"] and choices["raid"],"group coverage disappeared from target menu")
check(choices["player:TestTank01-Practice"] and choices["player:TestRogue01-Practice"] and choices["player:TestWarlock01-Practice"],"recipient menu incorrectly uses dispeller class filters")
local casterChoices={};for _,v in ipairs(a:SimpleAssignmentPlayerChoices("Unassigned",{kind="dispel"},true)) do casterChoices[v[2]]=true end
check(not casterChoices["TestRogue01-Practice"] and not casterChoices["TestWarlock01-Practice"],"assigned dispeller list lost class filtering")
local live=a:AssignmentBoard();local revision=live.revision;local sent=#a.sent
select(f.tables.cleanup[1].target,"player:TestRogue01-Practice")
check(row("dispel",1).targetPlayer=="TestRogue01-Practice" and row("dispel",1).player=="TestHealer01-Practice","recipient overwrote assigned dispeller")
check(f.tables.cleanup[1].target:GetText()=="TestRogue01 Practice","recipient label not full display name")
check(a:AssignmentTarget(row("dispel",1),"raid")=="TestRogue01 Practice" and a:AssignmentText(row("dispel",1),"raid"):find("TestRogue01 Practice",1,true),"announcement omitted recipient")
select(f.tables.cleanup[5].target,"player:TestTank01-Practice")
check(row("decurse",1).targetPlayer=="TestTank01-Practice","decurse cannot target one person")
select(f.encounter,"e1")
select(f.tables.cleanup[1].target,"player:TestWarlock01-Practice")
check(row("dispel",1,"e1").targetPlayer=="TestWarlock01-Practice" and row("dispel",1,"raid").targetPlayer=="TestRogue01-Practice","boss target override changed raid recipient")
select(f.tables.cleanup[1].target,"7-8")
check(row("dispel",1,"e1").targetPlayer=="" and row("dispel",1,"e1").target=="7-8" and row("dispel",1,"raid").targetPlayer=="TestRogue01-Practice","group selection retained or erased wrong recipient")
select(f.encounter,"raid");select(f.tables.cleanup[1].target,"3-4")
check(row("dispel",1).targetPlayer=="" and f.tables.cleanup[1].target:GetText()=="Groups 3–4","target could not switch back to groups")
local long=string.rep("A",49).."-"..string.rep("B",50)
check(a:SetSimpleAssignmentCell({kind="dispel",slot=2},"target",long),"full-length canonical recipient rejected")
check(#row("dispel",2).targetPlayer==100,"recipient was truncated")
local plan=a:AssignmentPlan(a:SimpleAssignmentBoard());local decoded=a.Decode(a.Encode(plan));local restored=a:CleanAssignmentPlan(decoded)
check(restored~=nil,"recipient invalidated template/wire roundtrip")
local found=false;for _,r in ipairs(restored.rows) do if r.kind=="dispel" and r.encounter=="raid" and r.slot==2 then found=r.targetPlayer==long end end
check(found,"recipient lost when storing plan")
local rev=a:SimpleAssignmentBoard().revision
check(not a:SetSimpleAssignmentCell({kind="buff",buff="fortitude"},"target","TestTank01-Practice"),"buff unexpectedly accepted a cleanup target")
check(not a:SetSimpleAssignmentCell({kind="dispel",slot=2},"target","|Hbad") and not a:SetSimpleAssignmentCell({kind="dispel",slot=2},"target",string.rep("A",101)),"invalid recipient accepted")
check(a:SimpleAssignmentBoard().revision==rev,"invalid recipient partially changed plan")
local bad=a:AssignmentPlan(a:SimpleAssignmentBoard());bad.rows[1].targetPlayer="TestRogue01-Practice"
check(not a:CleanAssignmentPlan(bad),"tank row accepted cleanup-only recipient field")
check(live.revision==revision and #a.sent==sent,"local recipient practice changed live state or sent messages")
print("Cleanup targets: "..count.." checks passed; any-class recipients, groups, scoped overrides, full names, announcements and persistence")
