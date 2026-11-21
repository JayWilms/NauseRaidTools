local root=...
local make=assert(loadfile(root.."/qa/softres/improvements_client.lua"))(root,root)
local a,e=make("Lead-Realm");local count=0;local function check(v,m) count=count+1;assert(v,m) end
e.IsInGroup=function() return false end;e.IsInRaid=function() return false end
e.GetBuildInfo=function() return "1.60.1","70959","",16001 end
a:BuildUI();a:OpenSimpleAssignmentsBoard(true)
local u=a.ui;local f=u.assignments;local b=a:SimpleAssignmentBoard()
local wanted={"Lucifron","Magmadar","Gehennas","Garr","Baron Geddon","Shazzrah","Sulfuron Harbinger","Golemagg the Incinerator","Majordomo Executus","Ragnaros"};local boss={}
for index,enc in ipairs(b.encounters) do boss[enc.name]=enc.id;check(wanted[index]==enc.name,"Molten Core boss names/order wrong") end
check(#b.encounters==10 and b.nextEncounter==11,"full Molten Core practice route missing")
local n=0;for _ in pairs(a.assignmentPracticePlayers) do n=n+1 end
check(n==20 and a.assignmentPracticePlayers["TestHunter01-Practice"]=="HUNTER" and a.assignmentPracticePlayers["TestHunter02-Practice"]=="HUNTER","test roster lacks hunters or changed size")
check(a:CleanAssignmentPlan(b),"seeded boss plan invalid")
local function select(control,value)
 check(control:IsEnabled(),"requested control is disabled")
 control:GetScript("OnClick")();local menu=u.settingsDropdown;check(menu and menu:IsShown(),"dropdown did not open")
 local index;for i,v in ipairs(menu.choices) do if v[2]==value then index=i end end
 check(index~=nil,"dropdown option missing: "..tostring(value));a:ScrollSettingsDropdown(math.max(0,index-8));menu.rows[index-(menu.offset or 0)]:GetScript("OnClick")()
end
local function row(kind,slot,scope) return a:MarkerBoardRow(a:SimpleAssignmentBoard(),scope or a:SimpleAssignmentScope(),kind,nil,nil,nil,nil,slot) end
for _,pair in ipairs({"1-2","3-4","5-6","7-8","1-4","5-8","raid","1","8"}) do
 check(a:ValidAssignmentCoverage(pair),"valid coverage rejected")
 local found=false;for _,v in ipairs(a:AssignmentCoverageChoices()) do if v[2]==pair then found=true end end
 check(found,"valid pair absent from choices")
end
for _,value in ipairs({"0","9","2-3","8-9","1-8","","1-2-3"}) do check(not a:ValidAssignmentCoverage(value),"unsupported coverage accepted") end
f.tabs.cleanup:GetScript("OnClick")()
check(#f.tables.cleanup==8,"whole raid needs four dispel and four decurse group slots")
for slot,pair in ipairs({"1-2","3-4","5-6","7-8"}) do
 check(row("dispel",slot,"raid").target==pair and row("decurse",slot,"raid").target==pair,"whole raid seed group split wrong")
 check(f.tables.cleanup[slot].controls[1].field=="player" and f.tables.cleanup[slot].coverage~=nil,"player/group controls missing")
end
local live=a:AssignmentBoard();local liveRev=live.revision;local sent=#a.sent
for _,name in ipairs(wanted) do
 select(f.encounter,boss[name])
 check(a:SimpleAssignmentScope()==boss[name],"boss selector did not change scope")
 for _,tab in ipairs({"tanks","cc","cleanup"}) do f.tabs[tab]:GetScript("OnClick")();check(f.tables[tab][1]:IsShown(),"required boss job table hidden") end
 check(#f.tables.tanks[1].controls==3 and #f.tables.cc[1].controls==4,"boss lacks tank/healers or kick/sheep/banish/tranq cells")
 check(f.tables.cc[1].controls[4].cell.kind=="tranq","fourth CC column is not tranq")
end
select(f.encounter,boss.Magmadar);f.tabs.cc:GetScript("OnClick")()
check(a:MarkerBoardRow(a:SimpleAssignmentBoard(),boss.Magmadar,"tranq",8).player=="TestHunter01-Practice","raid-wide tranq did not inherit into boss")
select(f.tables.cc[1].controls[4],"TestHunter02-Practice")
check(a:MarkerBoardRow(a:SimpleAssignmentBoard(),boss.Magmadar,"tranq",8).player=="TestHunter02-Practice","hunter dropdown not applied")
check(not a:SetSimpleAssignmentCell({kind="tranq",marker=8},"player","TestMage01-Practice"),"non-hunter can tranq")
select(f.encounter,boss.Lucifron);f.tabs.cleanup:GetScript("OnClick")()
select(f.tables.cleanup[1].coverage,"3-4")
check(row("dispel",1,boss.Lucifron).target=="3-4" and row("dispel",1,"raid").target=="1-2","boss coverage changed raid defaults")
select(f.tables.cleanup[5].controls[1],"TestDruid01-Practice");select(f.tables.cleanup[5].coverage,"5-6")
check(row("decurse",1,boss.Lucifron).player=="TestDruid01-Practice" and row("decurse",1,boss.Lucifron).target=="5-6","boss decurse assignment not saved")
check(row("decurse",1,"raid").player=="TestMage01-Practice","boss decurse changed whole raid player")
check(not a:SetSimpleAssignmentCell({kind="dispel",slot=1},"player","TestHealer03-Practice"),"shaman incorrectly offered as friendly magic dispeller")
check(not a:SetSimpleAssignmentCell({kind="decurse",slot=1},"backup","TestWarlock01-Practice"),"warlock incorrectly accepted as decurse backup")
local rev=a:SimpleAssignmentBoard().revision
for _,slot in ipairs({0,5,1.5,"1"}) do check(not a:SetSimpleAssignmentCell({kind="dispel",slot=slot},"coverage","1-2"),"invalid cleanup slot accepted") end
check(a:SimpleAssignmentBoard().revision==rev,"invalid slot partially mutated plan")
select(f.encounter,"raid");f.tabs.buffs:GetScript("OnClick")()
for _,pair in ipairs({"1-2","3-4","5-6","7-8"}) do
 select(f.tables.buffs[1].coverage,pair)
 check(a:MarkerBoardRow(a:SimpleAssignmentBoard(),"raid","buff",nil,nil,"intellect").target==pair,"buff group pair not applied")
end
local plan=a:AssignmentPlan(a:SimpleAssignmentBoard());check(a:CleanAssignmentPlan(plan),"boss/coverage plan fails template validation")
check(a:AssignmentTarget(row("dispel",2,"raid"),"raid")=="Groups 3–4","announcement did not describe group range")
check(live.revision==liveRev and #a.sent==sent,"test boss assignments leaked into live state or transport")
print("Boss assignment jobs: "..count.." checks passed; ten Molten Core bosses, all requested jobs, class rules, group pairs, scope isolation and local practice")
