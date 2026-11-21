local root=...
local make=assert(loadfile(root.."/qa/softres/improvements_client.lua"))(root,root)
local a,e=make("Lead-Realm");local n=0;local function check(v,m) n=n+1;assert(v,m) end
e.IsInGroup=function() return false end;e.IsInRaid=function() return false end
a:BuildUI();local u=a.ui
check(u.launcherButtons["My Assignments"] and not u.launcherButtons.Assignments,"launcher still exposes setup instead of personal duties")
check(u.openAssignments:GetText()=="Assignments","settings lacks assignment setup")
a:OpenSimpleAssignmentsBoard(true);u.assignments.mineButton:GetScript("OnClick")()
check(u.myAssignments.practice,"practice editor button did not open local duties")
u.myAssignments:Hide();u.launcher:Show();u.launcherButtons["My Assignments"]:GetScript("OnClick")()
check(u.myAssignments:IsShown() and not u.myAssignments.practice and u.myAssignments.section=="raid","launcher inherited local practice instead of shared raid")
check(not u.assignmentChooser:IsShown() and not u.assignments:IsShown() and not u.launcher:IsShown(),"launcher did not open personal tracker directly")
check(u.myAssignments.settings:GetText()=="Assignments","personal tracker has no settings shortcut")
u.myAssignments.settings:GetScript("OnClick")()
check(u.assignments:IsShown() and not u.assignments.practice and not u.assignmentChooser:IsShown() and not u.settingsHub:IsShown() and u.myAssignments:IsShown(),"shortcut did not directly open live assignment editor")
a:ShowSettings();a:SelectSettingsPage("Raid Tools")
u.openAssignments:GetScript("OnClick")()
check(u.assignmentChooser:IsShown(),"settings did not open raid chooser")
a:OpenSimpleAssignmentsBoard(true)
check(u.assignments.practice and #a.assignmentPracticeBoard.encounters==10,"settings no longer provides Test Raid")
local practice=a.assignmentPracticeBoard
u.assignments.mineButton:GetScript("OnClick")();u.myAssignments.section="e2";u.settingsHub:Hide()
u.myAssignments.settings:GetScript("OnClick")()
check(u.assignments:IsShown() and u.assignments.practice and a:SimpleAssignmentScope()=="e2" and a.assignmentPracticeBoard==practice,"shortcut lost practice board or selected boss")
check(not u.settingsHub:IsShown() and not u.assignmentChooser:IsShown() and u.myAssignments:IsShown(),"practice shortcut opened general settings or dismissed tracker")
-- Opening the launcher tracker while a practice editor is visible must still select live duties.
u.launcher:Show();check(a:OpenLauncherOption("My Assignments"),"launcher action failed")
check(not u.myAssignments.practice and not u.assignments:IsShown(),"visible practice editor contaminated raider shortcut")
check(not a:OpenLauncherOption("Assignments"),"removed launcher route still opens setup")
print("Assignment navigation: "..n.." checks passed; raider shortcut, Settings setup, practice isolation and fresh opening")
