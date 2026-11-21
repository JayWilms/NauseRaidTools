local root=...
local make=assert(loadfile(root.."/qa/softres/improvements_client.lua"))(root,root)
local a,e,s=make("Leader-Realm")
local count=0
local function check(ok,message) count=count+1;assert(ok,message) end
e.C_Item={GetItemInfo=function(id)
    if id==279259 then return "Fixture Staff","|cffa335ee|Hitem:279259::::::::|h[Fixture Staff]|h|r" end
end}
check(a:ItemLibrary()==nil,"missing provider fabricated a catalogue")
e.AtlasLoot={ItemDB={Storage={AtlasLootClassic_DungeonsAndRaids={Bad={name="Bad",items={}}}}}}
check(a:ItemLibrary()==nil,"empty catalogue accepted")
local loads=0
e.AtlasLoot={ItemDB={Storage={}}}
e.C_AddOns={LoadAddOn=function(module)
    loads=loads+1
    e.AtlasLoot.ItemDB.Storage[module]={
        Raid={name="Fixture Raid|cffffffff|Ticon:18|t|r",items={
            {name="First Boss",[1]={{1,279259},{2,279259},{3,"Currency"},{4,-1}},[2]={{1,279259}}},
            {name="Second Boss",[1]={{1,279259},{2,279260}}},
        }}
    }
    return true
end}
local library=a:ItemLibrary()
check(library and loads==1,"AtlasLoot module did not load")
check(#library:Search()==2 and #library:GetInstances()==1,"catalogue IDs were not deduplicated")
check(library:GetInstances()[1].name=="Fixture Raid","AtlasLoot decoration leaked into instance name")
check(#library:GetSources(279259)==2,"difficulty duplicates became extra bosses")
check(library:GetName(279259)=="Fixture Staff" and library:GetName(279260)==nil,"native item name lookup failed")
a:BuildUI()
e.SlashCmdList.NAUSERAIDTOOLS("softres")
check(s.setup and not s.session,"opening setup started a session")
check(s.setupKnown["Fixture Raid"],"AtlasLoot instance unavailable in setup")
s.setupSelection={["Fixture Raid"]=true}
s.setup.limit:SetText("2")
assert(s:ConfirmPugSetup())
check(s.session and not a.state,"SR and council overlapped at startup")
check(not a:ShowRaidSetup(false),"guild wizard opened during SR")
check(not a:ApplyRaidSetupDraft({},nil,true),"guild draft applied during SR")
check(not a:RestoreSession({}),"guild restore overlapped SR")
check(not a:BeginRecovery("x","y","z"),"guild recovery began during SR")
check(s:Reserve(s.session,a.me,{279259,279259},"in-game"),"stacked reservation rejected")
check(not s:Reserve(s.session,a.me,{987654},"in-game"),"item outside selected content accepted")
-- Real setup rendering: separate item hover targets, all six slots and paging.
s:RenderSessionSetup()
local setup=s.sessionSetup
local playerRow
for _,row in ipairs(setup.rows) do if row.name:GetText()==a.me then playerRow=row end end
check(playerRow and playerRow.items[1].text:GetText():find("Fixture Staff",1,true),"setup did not resolve item names")
e.GameTooltip={SetOwner=function(self,owner) self.owner=owner end,SetHyperlink=function(self,link) self.link=link end,Show=function(self) self.shown=true end,Hide=function(self) self.shown=false end,IsOwned=function(self,owner) return self.owner==owner end}
playerRow.items[1]:GetScript("OnEnter")(playerRow.items[1])
check(e.GameTooltip.link=="item:279259" and e.GameTooltip.shown,"reservation hover showed wrong item")
playerRow.items[1]:GetScript("OnLeave")()
check(not e.GameTooltip.shown,"reservation tooltip remained visible")
s.session.limit=6
assert(s:Reserve(s.session,a.me,{279259,279259,279259,279259,279259,279260},"in-game"))
e.C_Item.RequestLoadItemDataByID=function(id) e.requestedItem=id end
s:RenderSessionSetup()
check(playerRow.items[6]:IsShown() and playerRow.items[6].text:GetText()=="Item 279260" and e.requestedItem==279260,"uncached sixth reservation missing or not requested")
e.C_Item.GetItemInfo=function(id) return id==279260 and "Loaded Ring" or "Fixture Staff" end
s.catalogueEvents:GetScript("OnEvent")(s.catalogueEvents,"ITEM_DATA_LOAD_RESULT",279260,true)
check(playerRow.items[6].text:GetText()=="Loaded Ring","loaded item name did not refresh setup")
local roster=a.roster;a.roster=a.Copy(roster);a.roster["A-Realm"]=true;a.roster["B-Realm"]=true
s:Render()
check(#setup.rows==6 and setup.content:GetHeight()==372 and setup.scroll:GetVerticalScrollRange()>0,"larger roster did not scroll")
s.rosterFilter="Missing";s:RenderSessionSetup()
check(setup.rows[1].name:GetText()=="A-Realm" and setup.rows[6].name:GetText()=="","missing filter did not refresh or clear rows")
s.rosterFilter="Offline";a.roster["A-Realm"]="raid6";e.UnitIsConnected=function() return false end
s:RenderSessionSetup()
check(setup.rows[1].name:GetText()=="A-Realm" and setup.rows[1].state:GetText():find("Offline",1,true),"offline filter did not use native connection state")
s.rosterFilter="All"
for i=1,14 do a.roster["Test"..i.."-Realm"]=true end
s:RenderSessionSetup()
check(setup.content:GetHeight()==20*62 and #setup.rows==20,"20-player overview did not keep every row accessible")
a.roster=roster;s.setupRosterPage=1;s.session.limit=2
assert(s:Reserve(s.session,a.me,{279259,279259},"in-game"));s:Render()
check(not playerRow.items[3]:IsShown() and playerRow.items[3].itemID==nil,"removed reservation retained hover target")
check(setup.summary:GetText():find("1/4 submitted",1,true),"submission summary counted missing raiders as submitted")
s:ShowBrowser();s:CatalogueStep();s:RenderBrowser()
check(s.browser:IsShown() and not setup:IsShown(),"reservation navigation left multiple manager windows open")
local instanceButton
for _,button in ipairs(s.browser.navigationRows) do if button.entry and button.entry.kind=="instance" and button.entry.instance=="Fixture Raid" then instanceButton=button;break end end
check(instanceButton~=nil,"instance was unavailable in the reservation sidebar")
instanceButton:GetScript("OnClick")()
check(s.browserInstance=="Fixture Raid" and s.browserBoss==nil,"sidebar did not select instance loot")
s.browserBoss="First Boss";s.browser.search:SetText("Fixture");s:RenderBrowser()
check(s.browser.rows[1].source:GetText()=="First Boss","browser source did not follow the selected boss")
s:ShowPugSetup();s:ShowBrowser()
check(s.browserInstance=="Fixture Raid" and s.browserBoss=="First Boss" and s.browser.search:GetText()=="Fixture","returning to reservations lost browsing filters")
s.browser.search:SetText("no matching fixture item");s:RenderBrowser()
check(s.browser.empty:IsShown() and not s.browser.rows[1]:IsShown(),"empty search lacked visible feedback")
s.browser.search:SetText("");s.browserBoss=nil;s:RenderBrowser()

check(s.browser.picks:GetText():find("2/2",1,true) and not s.browser.rows[1].add:IsEnabled(),"reservation cap not reflected in browser controls")
local revision=s.session.revision
s.browser.rows[1].remove:GetScript("OnClick")()
check(#s.browserDraft==1 and s.session.revision==revision,"minus control changed confirmed reserves before submission")
s:ShowPugSetup();s:ShowBrowser()
check(#s.browserDraft==1,"switching tabs discarded unsaved selections")
s:ResetBrowserDraft();s:RenderBrowser()
s:ShowPugSetup()
check(setup:IsShown() and not s.browser:IsShown(),"overview navigation did not close reservations")

assert(s:Command("lock"))
local link="|cffa335ee|Hitem:279259::::::::|h[Fixture Staff]|h|r"
local packet={sid=s.session.id,seq=1,sampledAt=e.GetServerTime(),entries={
    {guid="Item-nrt-first",link=link,kind="timed",seconds=480},
    {guid="Item-nrt-second",link=link,kind="timed",seconds=3600},
}}
assert(s:CollectPugLoot(a.me,packet))
check(not s:CollectPugLoot(a.me,packet),"duplicate report accepted")
assert(s:QueuePugLoot(1))
check(s.session.round.lootEntry==1,"wrong identical item copy was queued")
check(s.leaderRollUI.primary:GetText()=="Stop rolls","active roll lacked stop action")
assert(s:AcceptRoll(s.session,a.me,12,1,100,a.roster))
assert(s:AcceptRoll(s.session,"Raider-Realm",99,1,100,a.roster))
assert(s:Command("close"))
check(s.leaderRollUI.primary:GetText()=="Award winner","closed roll lacked award action")
local raidAnnouncements={}
e.SendChatMessage=function(message,channel) raidAnnouncements[#raidAnnouncements+1]={message=message,channel=channel} end
assert(s:Command("record"))
check(#raidAnnouncements==0,"award announced before confirmation")
check(#s.session.history==0 and a.confirmationContext,"award skipped confirmation")
check(a.ui.confirmationBody:GetText():find(link,1,true),"award confirmation did not show the tracked item name and quality colour")
local awardDialog=e.StaticPopupDialogs.NAUSE_SR_CONFIRM_AWARD
local awardContext={data=a.confirmationContext.data}
assert(a:AcceptConfirmation())
check(#raidAnnouncements==1 and raidAnnouncements[1].channel=="RAID"
    and raidAnnouncements[1].message=="[Nause SR] "..link.." awarded to Leader-Realm (SR, 12). Delivery pending.",
    "confirmed award did not announce its item, winner, tier and roll in raid")
awardDialog.OnAccept(awardContext)
check(#raidAnnouncements==1,"stale confirmation repeated an award announcement")
check(s.session.history[1].winner==a.me and s.session.history[1].guid=="Item-nrt-first","SR priority or GUID lost")
check(#s.session.reserves[a.me]==1,"SR award did not consume exactly one reservation")
check(s.leaderRollUI.primary:GetText()=="View delivery","award did not lead to delivery action")
check(s.leaderRollUI.item:GetText():find("Fixture Staff",1,true) and s.leaderRollUI.status:GetText():find("AWARDED",1,true),"recording an award lost its item context")
assert(s.leaderRollUI.primary:GetScript("OnClick")())
check(s.selectedAward==s.session.history[1].id and s.awardFilter=="pending","View delivery did not select the recorded award")
check(s.awardUI:IsShown() and not s.leaderRollUI:IsShown() and not setup:IsShown(),"award navigation left manager windows open")
check(s.awardUI.rows[1].item:GetText():find("Fixture Staff",1,true),"award list displayed only an item ID")
a:RenderLootWindows()
local loot=a.ui.lootPanels.timer
check(loot.rows[1].tracked==1 and loot.rows[1].action:GetText()=="Trade to Leader","new Loot action missing")
check(loot.rows[1].deadline:GetText()=="Trade due in 8m","new Loot deadline badge missing")
check(loot.rows[2].tracked==2,"duplicate copy disappeared")
local timer=a.ui.lootTimers
timer.compact=true
a:RenderLootTimers()
check(not timer.rows[1].srWinner:IsShown() and not timer.rows[1].srTrade:IsShown(),"compact Timer displayed expanded SR controls")
local award=s.session.history[1]
assert(s:ConfirmDelivery(award.id,award.revision))
assert(s:Command("end"))
check(not s.session and not a.state,"SR end left an active session")
a:RenderLootTimers()
check(not timer.rows[1].holderStatus:IsShown(),"ending SR broke compact Timer layout")
-- Exercise the visible tie/award handoff using real commands and confirmation.
local ta,te,ts=make("Leader-Realm");ta:BuildUI();assert(ts:Begin(2))
assert(ts:Reserve(ts.session,ta.me,{279259},"in-game"))
assert(ts:Reserve(ts.session,"Raider-Realm",{279259},"in-game"))
assert(ts:Command("lock"));assert(ts:Command("roll 279259"))
assert(ts:AcceptRoll(ts.session,ta.me,50,1,100,ta.roster))
assert(ts:AcceptRoll(ts.session,"Raider-Realm",50,1,100,ta.roster));ts:Render()
check(ts.leaderRollUI.status:GetText():find("Leading tie",1,true),"equal eligible rolls implied a single leader")
assert(ts:Command("close"))
check(ts.leaderRollUI.primary:GetText()=="Reroll tied players","closed tie offered an award instead of reroll")
assert(ts.leaderRollUI.primary:GetScript("OnClick")())
check(ts.session.round.tiebreak and ts:RollEligibilityText(ts.session.round,"Council-Realm"):find("not eligible",1,true),"tie-break did not explain nonparticipant eligibility")
local accepted,_,logged=ts:AcceptRoll(ts.session,"Council-Realm",100,1,100,ta.roster)
check(not accepted and logged,"non-tied roll entered the tie-break")
assert(ts:AcceptRoll(ts.session,ta.me,77,1,100,ta.roster))
assert(ts:AcceptRoll(ts.session,"Raider-Realm",66,1,100,ta.roster))
assert(ts:Command("close"));assert(ts.leaderRollUI.primary:GetScript("OnClick")())
check(#ts.session.history==0 and ta.confirmationContext,"tie winner skipped award confirmation")
assert(ta:AcceptConfirmation());assert(ts.leaderRollUI.primary:GetScript("OnClick")())
check(ts.awardUI:IsShown() and ts.selectedAward==ts.session.history[1].id and ts.awardUI.detail:GetText():find("Winner:",1,true),"tie winner did not lead to its delivery details")

-- The guided guild start must bypass the run chooser after setup is reviewed.
a.guidedGuildStart=nil;s.runChooser=nil
local draft=a:NewRaidSetupDraft()
assert(a:ApplyRaidSetupDraft(draft,"",true))
check(a.state and not s.session and not s.runChooser,"guided guild start opened the run chooser")
check(a.guidedGuildStart==nil,"temporary guild-start marker leaked")
check(not s:Begin(1),"SR began during a guild session")
print("NRT SR INTEGRATION PASS: "..count.." checks; AtlasLoot, native data, session exclusion, exact duplicate copies, draft start and SR priority")

