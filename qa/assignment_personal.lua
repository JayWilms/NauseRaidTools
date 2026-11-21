local root=...
local make=assert(loadfile(root.."/qa/softres/improvements_client.lua"))(root,root)
local a,e=make("Lead-Realm");local checks=0;local function check(v,m) checks=checks+1;assert(v,m) end
e.IsInGroup=function() return false end;e.IsInRaid=function() return false end
a:BuildUI();a:OpenSimpleAssignmentsBoard(true);local main=a.ui.assignments
local board=a:SimpleAssignmentBoard();local plan=a:AssignmentPlan(board)
local me="TestWarlock01-Practice";a.me=me
-- Use jobs from several tabs, boss overrides and an optional backup.
check(a:EditMarkerBoardCell(plan,{kind="debuff",debuff="elements",value=me}),"curse setup failed")
check(a:EditMarkerBoardCell(plan,{kind="banish",marker=8,value=me}),"banish setup failed")
check(a:EditMarkerBoardCell(plan,{kind="interrupt",marker=7,value=me,encounter="e1"}),"boss kick setup failed")
check(a:EditMarkerBoardCell(plan,{kind="debuff",debuff="tongues",value="TestWarlock02-Practice"}),"backup setup failed")
check(a:EditMarkerBoardCell(plan,{kind="debuff",debuff="tongues",field="backup",value=me}),"backup assignment failed")
plan.owner=board.owner;plan.epoch=board.epoch;plan.revision=board.revision+1;a.assignmentPracticeBoard=plan
local live=a:AssignmentBoard();local before=live.revision;local sent=#a.sent
check(main.mineButton:GetText()=="My Assignments","personal view button still cycles ambiguously")
main.mineButton:GetScript("OnClick")();local f=a.ui.myAssignments
check(f:IsShown() and not main:IsShown() and f.section=="raid","personal popup did not open on Whole raid")
f.section="all";a:RenderMyAssignments()
local headings={};local mine={};local count=0
for _,entry in ipairs(f.entries) do
 if entry.heading then headings[entry.scope]=true else
  check(entry.row.player==me or entry.row.backup==me,"another player's job included")
  check(not (mine[entry.row.id] and mine[entry.row.id].scope==entry.scope),"job repeated within a boss");mine[entry.row.id]=entry;count=count+1
 end
end
check(headings.raid and headings.e1 and headings.e2 and count>=4,"popup did not combine raid jobs and bosses")
local crossPlan=a:AssignmentPlan(plan)
check(a:EditMarkerBoardCell(crossPlan,{kind="interrupt",marker=7,value=me,encounter="raid"}),"whole-raid Cross setup failed")
local wholeCross,tranqsCross=false,false
for _,entry in ipairs(a:PersonalAssignmentEntries(crossPlan,me,"all")) do
 if entry.row and entry.row.kind=="interrupt" and entry.row.marker==7 then
  if entry.scope=="raid" then wholeCross=true end
  if entry.scope=="e2" then tranqsCross=true end
 end
end
check(wholeCross and tranqsCross,"whole-raid Cross was omitted from tranqs in the combined list")
check(a:EditMarkerBoardCell(crossPlan,{kind="interrupt",marker=7,value="TestRogue02-Practice",encounter="e2"}),"boss override setup failed")
local keptRaid,removedBoss=false,true
for _,entry in ipairs(a:PersonalAssignmentEntries(crossPlan,me,"all")) do
 if entry.row and entry.row.kind=="interrupt" and entry.row.marker==7 then
  if entry.scope=="raid" then keptRaid=true end
  if entry.scope=="e2" then removedBoss=false end
 end
end
check(keptRaid and removedBoss,"boss reassignment did not replace just that boss's inherited duty")
local found={};for _,entry in pairs(mine) do if entry.row.debuff~="" then found[entry.row.debuff]=entry end end
check(found.elements and found.tongues and found.tongues.backup,"backup duties omitted")
local backupLabel=false;for _,visual in ipairs(f.rows) do if visual.label:GetText()=="Backup: Curse of Tongues" then backupLabel=true end end
check(backupLabel,"backup duty not clearly labelled")
-- Main category selection/closing does not close or filter the personal view.
main.panel="cleanup";a:RenderAssignments();check(f:IsShown() and #f.entries>count,"main category filtered personal popup")
main:Hide();a:RenderAssignments();check(f:IsShown(),"closing editor closed personal popup")
-- It follows fresh plans while the editor is closed, without opening a dropdown.
local changed=a:AssignmentPlan(plan);check(a:EditMarkerBoardCell(changed,{kind="debuff",debuff="elements",value="TestWarlock02-Practice"}),"refresh edit failed")
changed.owner=plan.owner;changed.epoch=plan.epoch;changed.revision=plan.revision+1;a.assignmentPracticeBoard=changed
a:RenderAssignments();local removed=true;for _,v in ipairs(f.entries) do if v.row and v.row.debuff=="elements" then removed=false end end
check(removed and f:IsShown(),"personal view did not refresh after reassignment")
-- Buffing belongs only to Whole raid, for both primary players and backups.
local buffs=a:AssignmentPlan(a.assignmentPracticeBoard)
check(a:EditMarkerBoardCell(buffs,{kind="buff",buff="intellect",value="TestMage01-Practice",encounter="raid"}),"buff setup failed")
check(a:EditMarkerBoardCell(buffs,{kind="buff",buff="intellect",field="backup",value="TestMage02-Practice",encounter="raid"}),"buff backup setup failed")
for _,player in ipairs({"TestMage01-Practice","TestMage02-Practice"}) do
 local found=false
 for _,entry in ipairs(a:PersonalAssignmentEntries(buffs,player,"all")) do
  if entry.row and entry.row.kind=="buff" then check(entry.scope=="raid","buff inherited into boss in combined list");found=true end
 end
 check(found,"whole-raid buff omitted from personal list")
 for _,entry in ipairs(a:PersonalAssignmentEntries(buffs,player,"e2")) do
  check(not entry.row or entry.row.kind~="buff","buff appeared in selected boss")
 end
end
-- Compact rows omit duplicate marker targets, while the section dropdown uses effective boss jobs.
local compact=false;for _,visual in ipairs(f.rows) do
 if visual:IsShown() and visual.label:GetText()=="Banish" then
  compact=visual:GetHeight()==36 and not visual.detail:IsShown()
 end
end
check(compact and f:GetWidth()==400 and f:GetHeight()<=340,"simple duty retained bloated space")
local function selectSection(value)
 f.sectionMenu:GetScript("OnClick")();local menu=a.ui.settingsDropdown;local index
 for i,v in ipairs(menu.choices) do if v[2]==value then index=i end end
 check(index~=nil,"section choice missing");a:ScrollSettingsDropdown(math.max(0,index-8));menu.rows[index-(menu.offset or 0)]:GetScript("OnClick")()
end
selectSection("raid")
check(f.section=="raid" and f.sectionMenu:GetText()=="Raid-Wide Assignments","whole-raid selection failed")
for _,entry in ipairs(f.entries) do if entry.row then check(entry.row.encounter=="raid","boss duty appeared in raid defaults") end end
selectSection("e1")
local boss,defaults=false,false
for _,entry in ipairs(f.entries) do if entry.row then
 check(entry.scope=="e1","boss selection included unrelated boss")
 if entry.row.kind=="interrupt" and entry.row.marker==7 then boss=true end
 if entry.row.kind=="debuff" and entry.row.debuff=="tongues" then defaults=true end
end end
check(boss and defaults,"boss view lost boss-specific jobs or inherited raid duties")
local override=false
for _,visual in ipairs(f.rows) do if visual:IsShown() and visual.override:IsShown() and visual.label:GetText()=="Interrupt" then
 override=visual.override:GetText()=="Override"
end end
check(override,"boss-specific change lacks override label or separate target")
check(f.jobHeader==nil and f.targetHeader==nil and f.close==nil,"tracker columns/close-button cleanup missing")
local scopes=a:PersonalAssignmentChoices(a.assignmentPracticeBoard)
check(scopes[1][2]=="all" and scopes[2][2]=="raid" and #scopes==12,"section dropdown omitted raid/bosses")
-- Deleting the selected encounter returns to All rather than leaving an invalid filter.
local removed=a:AssignmentPlan(a.assignmentPracticeBoard)
for index,enc in ipairs(removed.encounters) do if enc.id=="e1" then table.remove(removed.encounters,index);break end end
for index=#removed.rows,1,-1 do if removed.rows[index].encounter=="e1" then table.remove(removed.rows,index) end end
removed.activeEncounter="raid";removed.owner=plan.owner;removed.epoch=plan.epoch;removed.revision=plan.revision+2;a.assignmentPracticeBoard=removed
a:RenderMyAssignments();check(f.section=="all" and f.sectionMenu:GetText()=="All Assignments","removed encounter left a stale section")
-- Native window resize support and scrolling retain readable rows/footer.
a:ResizeReadableWindow(f,420,280)
check(f:GetWidth()==420 and f.scroll:GetWidth()==372 and f.scroll:GetHeight()==160,"resize did not adjust popup content")
check(f.content:GetHeight()>f.scroll:GetHeight(),"long personal list did not overflow for scrolling")
f.scroll:GetScript("OnMouseWheel")(f.scroll,-1);check(f.scroll:GetVerticalScroll()>0,"personal list could not scroll")
a.me="Nobody-Realm";a:RenderAssignments();check(#f.entries==0 and f.empty:IsShown(),"empty personal view not explained")
check(live.revision==before and #a.sent==sent,"personal view changed or sent assignments")
-- Native Escape dismisses registered special frames, while the persistent personal view stays open.
local escapeFrames={};for _,name in ipairs(e.UISpecialFrames) do escapeFrames[name]=true end
check(not escapeFrames.NauseRaidToolsMyAssignments,"personal window was registered to close on Escape")
check(escapeFrames.NauseRaidToolsAssignmentBoard,"editor unexpectedly stopped closing on Escape")
main:Show()
for _,entry in ipairs(a.windowFrames) do if escapeFrames[entry.name] then entry.frame:Hide() end end
check(f:IsShown() and not main:IsShown(),"Escape dismissed personal assignments with the editor")
f.closeButton:GetScript("OnClick")();check(not f:IsShown(),"personal window did not close")
-- Healing follows effective tank names, groups repeated tank markers and keeps boss overrides.
a.IsForever=function() return true end
a.me="TestHealer01-Practice"
local healing=a:AssignmentPlan(a.assignmentPracticeBoard)
for _,marker in ipairs({8,7}) do
 check(a:EditMarkerBoardCell(healing,{kind="tank",marker=marker,value="TestTank01-Practice",encounter="raid"}),"tank setup")
 check(a:EditMarkerBoardCell(healing,{kind="healer",marker=marker,seat=1,value=a.me,encounter="raid"}),"healer setup")
end
check(a:EditMarkerBoardCell(healing,{kind="tank",marker=8,value="TestTank02-Practice",encounter="e2"}),"boss tank override")
local function healingRows(scope)
 local list={};for _,entry in ipairs(a:PersonalAssignmentEntries(healing,a.me,scope)) do
  if entry.row and entry.row.kind=="healer" then list[#list+1]=entry end
 end;return list
end
local raidHeals=healingRows("raid")
check(#raidHeals==1 and #raidHeals[1].markers==2,"same tank markers not grouped")
check(a:PersonalAssignmentLabel(raidHeals[1],healing,true):find("TestTank01 Practice",1,true),"healer cannot see tank name")
local bossHeals=healingRows("e2")
check(#bossHeals==2,"boss tank override did not split distinct tank recipients")
local foundTank=false
for _,entry in ipairs(bossHeals) do
 if entry.row.marker==8 then foundTank=a:PersonalAssignmentLabel(entry,healing,true):find("TestTank02 Practice",1,true)~=nil end
end
check(foundTank,"inherited healer ignored boss tank override")
check(a:EditMarkerBoardCell(healing,{kind="tank",marker=8,value="",encounter="e2"}),"clear boss tank")
for _,entry in ipairs(healingRows("e2")) do
 if entry.row.marker==8 then check(a:PersonalAssignmentLabel(entry,healing,true)=="Heal Unassigned Tank","unfilled tank misleadingly shows prior name") end
end
-- Buff/cleanup rows display coverage or class-coloured target names beside their icon.
e.RAID_CLASS_COLORS={WARRIOR={r=.78,g=.61,b=.43}}
local buff=a:NormaliseAssignmentRow({kind="buff",role="buff",buff="intellect",target="1-2",job="Arcane Intellect"})
check(a:PersonalAssignmentLabel({row=buff,scope="raid"},healing,true)==a:AssignmentCoverageLabel("1-2"),"buff lacks group coverage")
local cleanup=a:NormaliseAssignmentRow({kind="dispel",role="dispel",targetPlayer="TestTank01-Practice",job="Magic dispel"})
local name=a:PersonalAssignmentLabel({row=cleanup,scope="raid"},healing,true)
check(name:find("TestTank01 Practice",1,true) and name:find("|cff",1,true),"cleanup target lacks class colour")
a.assignmentPracticeBoard=healing;f.practice=true;f.section="raid";f:Show();a:RenderMyAssignments()
local merged
for _,visual in ipairs(f.rows) do if visual:IsShown() and visual.label:GetText():find("Heal ",1,true)==1 then merged=visual end end
check(merged and merged.markerIcons[1]:IsShown() and merged.target==nil,"compact healing row missing grouped icon or retains target column")
f.section="e2";a:RenderMyAssignments()
for _,visual in ipairs(f.rows) do
 if visual:IsShown() and visual.label:GetText():find("Heal ",1,true)==1 then
  check(not visual.markerIcons or not visual.markerIcons[1] or not visual.markerIcons[1]:IsShown(),"reused row retained grouped marker")
 end
end
print("Personal assignments: "..checks.." checks passed; all categories, boss jobs, backups, inherited raid duties, boss overrides, persistent view, refresh, resize and scroll")
