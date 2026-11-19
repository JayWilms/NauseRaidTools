local root=...
local make=assert(loadfile(root.."/qa/softres/improvements_client.lua"))(root,root)
local a,e,s=make("Leader-Realm");local count=0
local function check(value,message) count=count+1;assert(value,message) end
local provider={}
function provider:IsReady() return true end
function provider:GetInstances() return {
    {name="A High Dungeon",minLevel=45,maxLevel=55},{name="Z Low Dungeon",levelRange="12-20"},
    {name="Map Matched",mapID=9001},{name="The Hall of Thanes"},{name="Unrated Dungeon"},
    {name="Scarlet Monastery"},{name="Test Raid"},
} end
e.LibStub=function(name) if name=="LibItemDB-1.0" then return provider end end
local activities={
    {fullName="Hall of Thanes",minLevelSuggestion=13,maxLevelSuggestion=20,mapID=3065,maxNumPlayers=5},
    {fullName="Different localized name",minLevelSuggestion=28,maxLevelSuggestion=37,mapID=9001,maxNumPlayers=5},
    {fullName="Scarlet Monastery - Graveyard",minLevelSuggestion=20,maxLevelSuggestion=30,maxNumPlayers=5},
    {fullName="Scarlet Monastery - Library",minLevelSuggestion=30,maxLevelSuggestion=40,maxNumPlayers=5},
    {fullName="Test Raid",minLevelSuggestion=60,maxLevelSuggestion=0,maxNumPlayers=20},
}
e.C_LFGList={GetAvailableActivities=function(category)
    if category==2 then return {1,2,3,4} elseif category==114 then return {5} end;return {}
end,GetActivityInfoTable=function(id) return activities[id] end}
a:BuildUI();assert(s:ShowPugSetup(2))
check(s.setupInstances[1]=="Z Low Dungeon" and s.setupInstances[#s.setupInstances]=="Unrated Dungeon","instances were alphabetized instead of ordered by level")
check(s.setupLevels["Map Matched"].min==28 and s.setupLevels["The Hall of Thanes"].max==20,"native levels did not match map IDs or normalized names")
check(s.setupLevels["Scarlet Monastery"].min==20 and s.setupLevels["Scarlet Monastery"].max==40,"combined wings lost their full level range")
check(s.setupLevels["Test Raid"].min==60 and s.setupLevels["Test Raid"].max==60 and s.setupLevels["Test Raid"].raid,"raid category or level suggestion was lost")
local function filter(index)
    s.setup.levelRange:GetScript("OnClick")()
    a.ui.settingsDropdown.rows[index]:GetScript("OnClick")()
end
filter(3)
check(s.setupLevelFilter==10 and #s:FilteredSetupInstances()==2,"level dropdown did not filter dungeons")
s.setup.instance:GetScript("OnClick")()
check(#a.ui.settingsDropdown.choices==2,"content menu included instances outside the level filter")
a.ui.settingsDropdown.rows[1]:GetScript("OnClick")()
check(s.setupSelection["Z Low Dungeon"] and s.setup.selected:GetText():find("Z Low Dungeon",1,true),"dropdown selection did not reach the selected-content panel")
filter(6);s.setup.instance:GetScript("OnClick")();a.ui.settingsDropdown.rows[2]:GetScript("OnClick")()
check(s.setupSelection["Z Low Dungeon"] and s.setupSelection["A High Dungeon"],"changing level filters discarded a selection")
filter(3);s.setup.instance:GetScript("OnClick")();a.ui.settingsDropdown.rows[1]:GetScript("OnClick")()
check(not s.setupSelection["Z Low Dungeon"] and s.setupSelection["A High Dungeon"],"selecting an existing entry did not remove just that instance")
s.setupLevelFilter=20
check(#s:FilteredSetupInstances()==4,"overlapping dungeon ranges excluded valid level boundaries")
s.setupLevelFilter="unknown";s:RenderPugSetup()
check(#s:FilteredSetupInstances()==1 and s:FilteredSetupInstances()[1]=="Unrated Dungeon","missing levels were guessed or made inaccessible")
s.setup.clear:GetScript("OnClick")();check(next(s.setupSelection)==nil,"clear selected did not clear the chosen content")
e.C_LFGList=nil;s:RefreshPugSetup();s.setupLevelFilter="all"
check(#s:FilteredSetupInstances()==7 and not s.setupLevels["Map Matched"],"missing native APIs hid or fabricated content metadata")
-- AtlasLoot's actual format has an entry requirement BEFORE the displayed range.
local atlasRanges={
    {"Gnomeregan",{19,29,38}},
    {"Scarlet Monastery - Graveyard",{20,26,36}},
    {"Scarlet Monastery - Library",{20,29,39}},
    {"Scarlet Monastery - Armory",{20,32,42}},
    {"Scarlet Monastery - Cathedral",{20,35,45}},
    {"Excavation Site: Wetlands",{20,24,29}},
    {"City of Dalaran",{24,28,33}},
    {"Hall of Thanes",{10,13,18}},
}
local storage={}
for i,row in ipairs(atlasRanges) do storage["Instance"..i]={name=row[1],LevelRange=row[2],items={{name="Fixture Boss",[1]={{1,12345+i}}}}} end
e.AtlasLoot={ItemDB={Storage={AtlasLootClassic_DungeonsAndRaids=storage}}};s.atlasLibrary=nil;e.LibStub=nil
s:RefreshPugSetup()
for _,row in ipairs(atlasRanges) do
    local range=s.setupLevels[row[1]]
    check(range and range.min==row[2][2] and range.max==row[2][3],"AtlasLoot entry requirement was used as a recommended level for "..row[1])
end
s.setupLevelFilter=20
local matches={};for _,name in ipairs(s:FilteredSetupInstances()) do matches[name]=true end
check(not matches["Scarlet Monastery - Armory"] and not matches["Scarlet Monastery - Cathedral"],"level filter included instances based on minimum entry requirements")
-- AtlasLoot remains authoritative when another provider offers different levels.
local alternate={};function alternate:IsReady() return true end
function alternate:GetInstances() return {{name="Gnomeregan",minLevel=19,maxLevel=29}} end
e.LibStub=function(name) if name=="LibItemDB-1.0" then return alternate end end
s:RefreshPugSetup()
check(s.setupLevels.Gnomeregan.min==29 and s.setupLevels.Gnomeregan.max==38,"another provider overrode AtlasLoot's displayed range")
print("SOFTRES LEVEL PICKER PASS: "..count.." checks; native/catalogue levels, map/name/wing matching, boundaries, multi-selection, removal and unknown levels")
