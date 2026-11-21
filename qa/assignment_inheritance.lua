local root=...
local make=assert(loadfile(root.."/qa/softres/improvements_client.lua"))(root,root)
local a,e=make("Lead-Realm");local n=0;local function check(v,m) n=n+1;assert(v,m) end
e.IsInGroup=function() return false end;e.IsInRaid=function() return false end
e.GetBuildInfo=function() return "1.60.1","70959","",16001 end
a:BuildUI();a:OpenSimpleAssignmentsBoard(true);local f=a.ui.assignments
local function board() return a:SimpleAssignmentBoard() end
for _,row in ipairs(board().rows) do check(row.encounter=="raid","test seed contains an implicit boss override") end
local jobs={
 {cell={kind="tank",marker=8},initial="TestTank01-Practice",override="TestTank02-Practice",updated="TestTank03-Practice"},
 {cell={kind="healer",marker=8,seat=1},initial="TestHealer01-Practice",override="TestHealer03-Practice",updated="TestHealer04-Practice"},
 {cell={kind="healer",marker=8,seat=2},initial="TestHealer02-Practice"},
 {cell={kind="interrupt",marker=8},initial="TestRogue01-Practice",override="TestRogue02-Practice",updated="TestWarlock01-Practice"},
 {cell={kind="banish",marker=7},initial="TestWarlock01-Practice",override="TestWarlock02-Practice"},
 {cell={kind="sheep",marker=5},initial="TestMage01-Practice",override="TestMage02-Practice"},
 {cell={kind="tranq",marker=8},initial="TestHunter01-Practice",override="TestHunter02-Practice"},
 {cell={kind="dispel",slot=1},initial="TestHealer01-Practice",override="TestHealer05-Practice",updated="TestHealer06-Practice"},
 {cell={kind="decurse",slot=1},initial="TestMage01-Practice",override="TestDruid01-Practice",updated="TestMage02-Practice"},
}
local function row(job,scope)
 local c=job.cell;return a:MarkerBoardRow(board(),scope,c.kind,c.marker,c.seat,c.buff,nil,c.slot)
end
for _,enc in ipairs(board().encounters) do
 for _,job in ipairs(jobs) do
  local default=row(job,"raid");local inherited=row(job,enc.id)
  check(inherited and inherited.player==job.initial and inherited.id==default.id and inherited.encounter=="raid",job.cell.kind.." did not inherit into "..enc.name)
 end
end
f.viewEncounter="e1"
for _,job in ipairs(jobs) do if job.override then check(a:SetSimpleAssignmentCell(job.cell,"player",job.override),"manual boss override failed: "..job.cell.kind) end end
for _,job in ipairs(jobs) do
 check(row(job,"raid").player==job.initial,"boss edit changed raid-wide "..job.cell.kind)
 check(row(job,"e1").player==(job.override or job.initial),"boss override not applied")
 check(row(job,"e2").player==job.initial,"boss edit changed another boss")
end
local inheritedHealer=row(jobs[3],"e1")
check(inheritedHealer.encounter=="raid" and a:AssignmentTarget(inheritedHealer,"e1",board()):find("TestTank02 Practice",1,true),"inherited healer did not follow boss-specific tank")
f.viewEncounter="raid"
for _,job in ipairs(jobs) do if job.updated then check(a:SetSimpleAssignmentCell(job.cell,"player",job.updated),"raid-wide update failed") end end
for _,job in ipairs(jobs) do
 check(row(job,"e1").player==(job.override or job.updated or job.initial),"raid-wide update destroyed intentional boss override")
 for _,enc in ipairs(board().encounters) do if enc.id~="e1" then
  check(row(job,enc.id).player==(job.updated or job.initial),"raid-wide update failed to propagate to "..enc.name)
 end end
end
check(a:AssignmentTarget(row(jobs[3],"e2"),"e2",board()):find("TestTank03 Practice",1,true),"other bosses' healer targets did not follow updated raid tank")
local roundtrip=a:CleanAssignmentPlan(a.Decode(a.Encode(a:AssignmentPlan(board()))))
check(roundtrip and a:MarkerBoardRow(roundtrip,"e2","tank",8).player=="TestTank03-Practice" and a:MarkerBoardRow(roundtrip,"e1","tank",8).player=="TestTank02-Practice","inheritance/override lost in save or sync roundtrip")
print("Assignment inheritance: "..n.." checks passed; every boss, tanks/linked healers, interrupts, CC, tranqs, dispels/decurse, manual overrides and later default updates")
