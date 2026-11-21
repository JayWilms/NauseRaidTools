local root=...
local make=assert(loadfile(root.."/qa/softres/improvements_client.lua"))(root,root)
local a,e=make("Lead-Realm")
local count=0;local function check(v,m) count=count+1;assert(v,m) end
e.IsInGroup=function() return false end;e.IsInRaid=function() return false end
e.UnitFullName=function(unit) if unit=="player" then return "Lead","Realm" end end
e.InCombatLockdown=function() return false end
a:RefreshRoster();a:BuildUI();a:StartDemo()
local u=a.ui;local p=u.lootPanels.timer
check(rawget(u,"responsePrevious")==nil and rawget(u,"responseNext")==nil,"Response item navigation buttons remain")
check(u.candidatePrev==u.playerPagePrevious and u.candidateNext==u.playerPageNext,"Voting created duplicate item navigation")
-- Exercise full capacity, including duplicate item names with distinct copy IDs.
local seed=a.state.trackedLoot[1]
for i=#a.state.trackedLoot+1,80 do
 local copy={};for k,v in pairs(seed) do copy[k]=v end
 copy.id=i;copy.guid="scroll-copy-"..i;a.state.trackedLoot[i]=copy
end
a:RenderLootWindows()
check(p.count==80 and p.child:GetHeight()==3520,"Loot capacity truncated")
check(p.rows[80]:IsShown() and p.rows[80].tracked==80,"last copy missing or wrong identity")
check(not p.previous:IsShown() and not p.next:IsShown() and not p.pageLabel:IsShown(),"Loot pagination remains")
a:ScrollLootList(p.scroll,99999)
check(p.scroll:GetVerticalScroll()==3520-p.scroll:GetHeight(),"Loot cannot scroll to last copy")
local offset=p.scroll:GetVerticalScroll();a:RenderLootWindows()
check(p.scroll:GetVerticalScroll()==offset,"Loot refresh reset scroll")
p.rows[80]:GetScript("OnClick")(p.rows[80],"LeftButton")
check(a.selectedTracked==80,"last row selected wrong copy")
-- Voting contains every session item and keeps the callback independent of scroll.
a:QueueTrackedLoot(1)
local item=assert(a.state.items[1],"fixture item was not queued")
for i=#a.state.items+1,40 do local copy={};for k,v in pairs(item) do copy[k]=v end;copy.id=i;a.state.items[i]=copy end
a:Render();a:ScrollLootList(u.votingItemRail,99999)
check(u.itemButtons[40].itemID==40 and u.itemButtons[40]:IsShown(),"Voting last item absent")
check(u.votingItemChild:GetHeight()==1720,"Voting height not all items")
check(not u.itemPrev:IsShown() and not u.itemNext:IsShown() and not u.itemPages:IsShown(),"Voting pagination remains")
u.itemButtons[40]:GetScript("OnClick")(u.itemButtons[40])
check(a.selectedItem==40,"Voting scrolled click selected wrong item")
check(u.votingItemRail:GetVerticalScroll()==1720-u.votingItemRail:GetHeight(),"selected last item not revealed")
a:ScrollLootList(u.votingItemRail,-86);offset=u.votingItemRail:GetVerticalScroll();a:Render()
check(u.votingItemRail:GetVerticalScroll()==offset,"manual Voting scroll snapped back")
-- Response item eligibility is independent of rail scrolling.
local rows={};for i,v in ipairs(a.state.items) do rows[i]={item=v,status="Eligible"} end
a.popupItem=40;a:RenderResponseRail(rows,0)
check(u.responseItemButtons[40].itemID==40 and u.responseItemButtons[40]:IsShown(),"Response last item absent")
local clicked
a.HandleResponseItemModifiedClick=function() return false end
a.SelectResponseItem=function(_,id) clicked=id end
u.responseItemButtons[40]:GetScript("OnClick")()
check(clicked==40,"Response scrolled click selected wrong item")
local pitch=u.responseRailPitch or 43
check(u.responseRail:GetVerticalScroll()==40*pitch-u.responseRail:GetHeight(),"Response selected item not revealed")
check(not u.responseRailPrevious:IsShown() and not u.responseRailNext:IsShown() and not u.responseRailPage:IsShown(),"Response pagination remains")
a:ScrollLootList(u.responseRail,-pitch);offset=u.responseRail:GetVerticalScroll();a:RenderResponseRail(rows,0)
check(u.responseRail:GetVerticalScroll()==offset,"Response refresh reset manual scrolling")
for i=40,3,-1 do rows[i]=nil end
a:RenderResponseRail(rows,0)
check(u.responseRail:GetVerticalScroll()==0 and not u.responseItemButtons[3]:IsShown(),"Response shrink retained stale rows/offset")
check(not u.responseRail.nrtScrollChrome.rail:IsShown(),"short list retains scrollbar")
-- Class colours must also resolve self outside a roster (solo practice).
e.RAID_CLASS_COLORS={WARRIOR={r=.78,g=.61,b=.43},PALADIN={r=.96,g=.55,b=.73}}
e.UnitClass=function(unit) if unit=="player" then return "Warrior","WARRIOR" end end
a.roster={}
check(a:AssignmentPlayerColor(a.me,true)==e.RAID_CLASS_COLORS.WARRIOR,"solo player loses class colour")
local found=false
for _,choice in ipairs(a:SimpleAssignmentPlayerChoices("Unassigned",{kind="tank"},true)) do
 if choice[2]==a.me then found=choice[3]==e.RAID_CLASS_COLORS.WARRIOR end
end
check(found,"assignment dropdown lacks real self class colour")
-- Dropdown rows reuse labels: reset neutral options after a coloured player.
local owner=e.CreateFrame("Button",nil,u.main);owner:SetSize(200,26)
a:OpenSettingsDropdown(owner,{{"Lead Realm",a.me,e.RAID_CLASS_COLORS.WARRIOR}},function() end)
local menu=u.settingsDropdown;local label=menu.rows[1].label
label.SetTextColor=function(self,r,g,b) self.testColor={r,g,b} end
a:RenderSettingsDropdown()
check(label.testColor[1]==.78 and label.testColor[2]==.61,"menu player class colour missing")
menu.choices={{"Unassigned",""}};a:RenderSettingsDropdown()
check(label.testColor[1]==.9 and label.testColor[2]==.91,"reused neutral choice retained class colour")
print("LC scroll: "..count.." checks passed; full capacities, exact identities, selection visibility, refresh, shrinking and class colour")
