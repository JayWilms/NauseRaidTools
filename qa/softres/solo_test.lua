local root=...
local make=assert(loadfile(root.."/qa/softres/improvements_client.lua"))(root,root)
local a,e,s=make("Leader-Realm")
local count=0
local function check(value,message) count=count+1;assert(value,message) end
e.IsInRaid=function() return false end;e.IsInGroup=function() return false end
function a:Name(unit) if unit=="player" then return "Leader-Realm" end end
local nativeRolls,chat,bagCalls=0,0,0
e.RandomRoll=function() nativeRolls=nativeRolls+1 end
e.SendChatMessage=function() chat=chat+1 end
e.C_Container={GetContainerNumSlots=function() bagCalls=bagCalls+1;error("No real bags in test") end}
e.NauseSoftReserveDB={schema=1,generation=9,history={{sentinel=true}},session={id="saved-real-run"},rollDuration=30}
local before=a.Encode(e.NauseSoftReserveDB)
a:BuildUI()
check(a.ui.softResTest~=nil and a.ui.lootCouncilTest~=nil,"paired settings test buttons missing")
check(a.ui.softResTest:GetWidth()==a.ui.lootCouncilTest:GetWidth(),"test buttons have different widths")
local start=a:Name("player")
local ok,why=e.SlashCmdList.NAUSERAIDTOOLS("softres test");assert(ok,why)
check(s.test and a.demo and a.state==nil and s:IsHost(),"test needed raid authority or manufactured a council session")
check(a.ui.softResTest:GetText()=="End SoftRes test" and not a.ui.lootCouncilTest:IsEnabled(),"SoftRes test did not update paired controls")
local players=0;for _ in pairs(a.roster) do players=players+1 end
check(players==20 and #s.session.lootEntries==10,"wrong fixture roster or loot size")
check(s.session.lootEntries[1].guid~=s.session.lootEntries[2].guid and s.session.lootEntries[1].link==s.session.lootEntries[2].link,"duplicate copies not separately represented")
check(s.sessionSetup:IsShown() and s.sessionSetup.status:GetText():find("SOLO TEST",1,true),"test was not visibly labelled")
check(s.sessionSetup.summary:GetText():find("16/20 submitted",1,true),"fixture submission states missing")
check(a.ui.lootPanels.timer.window.title:GetText():find("SOLO TEST",1,true),"Loot window was not labelled as a test")
s:Render();s:Render()
check(not s.sessionSetup.status:GetText():find("SOLO TEST · SOLO TEST",1,true),"test banner duplicated while rendering")
check(#s:BrowserResults()==8,"test required an external catalogue")
s:ShowBrowser();check(s.browser.rows[1].entry~=nil,"fixture browser unavailable")
check(not a:StartDemo(),"council test overlapped SoftRes test")
check(not s:CollectPugLoot(a.me,{}),"real bag report accepted in test")
s.sharedLootEvents:GetScript("OnEvent")(s.sharedLootEvents,"BAG_UPDATE_DELAYED")
s.sharedLootEvents:GetScript("OnUpdate")(s.sharedLootEvents,2)
check(bagCalls==0,"test scanned real bags")
assert(s:Command("lock"));assert(s:QueuePugLoot(1))
check(s.session.round and s.session.round.lootEntry==1 and #s.session.round.attempts>10,"sample players did not roll automatically")
assert(s:ClickNativeRoll("MS",s:RollKey()))
check(nativeRolls==0 and #(s.session.round.rolls[a.me] or {})==1,"test roll used native RandomRoll")
assert(s:Command("close"))
local passes=0
while #s.session.round.winners>1 and passes<10 do assert(s:Command("reroll"));assert(s:Command("close"));passes=passes+1 end
check(#s.session.round.winners==1,"sample rolls could not resolve")
local round=s.session.round;local winner=round.winners[1];local reserved=#(s.session.reserves[winner] or {})
assert(s:Command("record"));assert(a:AcceptConfirmation())
local award=s.session.history[1]
check(award and award.guid==s.session.lootEntries[1].guid,"test award lost exact copy")
check(award.tier~="SR" or #(s.session.reserves[winner] or {})==reserved-1,"test award did not consume a reserve")
assert(s:TradeAward(award,false))
check(award.status=="delivered" and award.deliveryMethod=="solo-test","test delivery did not complete locally")
local _,_,blocked=a:FindTradeItem({guid=award.guid,link="item:"..award.item})
check(blocked~=nil and s:DeliveryView()==nil,"test enabled physical trade tracking")
s:Save();s:Publish();s:FlushSync();s:Send("snapshot",{})
s:ProcessReserveChat("!reserve 279259",a.me)
check(a.Encode(e.NauseSoftReserveDB)==before,"test changed real saved session or history")
check(#a.sent==0 and nativeRolls==0 and chat==0 and bagCalls==0,"test produced external side effects")
assert(e.SlashCmdList.NAUSERAIDTOOLS("softres leave-test"))
check(not s.test and not s.session and not a.demo and a.me==start,"exit did not restore live context")
check(a.Encode(e.NauseSoftReserveDB)==before,"exit changed saved data")
check(a.ui.itemToolsButton:GetText()=="Add loot","exit left SoftRes Loot controls installed")
assert(s:StartTest());assert(s:StartTest())
check(s.test and #s.session.history==0,"restart retained test awards")
e.IsInGroup=function() return true end
s.events:GetScript("OnEvent")(s.events,"GROUP_ROSTER_UPDATE")
check(not s.test and not s.session and not a.demo,"joining a group left test context active")
check(not a:IsSoloTest(),"group join retained solo transport isolation")
e.IsInGroup=function() return false end
s.session={id="real-run"}
check(not s:StartTest() and s.session.id=="real-run","test replaced a live SR session")
s.session=nil
a.state={id="council"};check(not s:StartTest(),"test replaced a council session");a.state=nil
e.SlashCmdList.NAUSESR("test");check(s.test,"/nrtsr test alias failed");e.SlashCmdList.NAUSERAIDTOOLS("leave-test")
check(not s.test and not a.demo,"standard leave-test command did not stop SR test")
check(a.Encode(e.NauseSoftReserveDB)==before,"restart/auto-exit changed saved data")
check(a.ui.lootCouncilTest:IsEnabled() and a.ui.softResTest:IsEnabled(),"test buttons remained disabled after exit")
a.ui.lootCouncilTest:GetScript("OnClick")()
check(a.demo and a.state and not s.test,"Loot Council button did not start existing solo simulation")
check(a.ui.lootCouncilTest:GetText()=="End Loot Council test" and not a.ui.softResTest:IsEnabled(),"council test did not update paired controls")
a.ui.lootCouncilTest:GetScript("OnClick")()
check(not a.demo and not a.state and a.ui.lootCouncilTest:GetText()=="Start Loot Council test","Loot Council button did not exit simulation")
a.state={id="real-council"};a:RefreshTestControls()
check(not a.ui.lootCouncilTest:IsEnabled() and not a.ui.softResTest:IsEnabled(),"test buttons enabled during a live session")
check(not a:ToggleCouncilTest() and a.state.id=="real-council","test action replaced a live council session")
a.state=nil;s.session={id="real-sr"};a:RefreshTestControls()
check(not a:ToggleCouncilTest() and s.session.id=="real-sr","test action replaced a live SR session")
s.session=nil;a:RefreshTestControls()
print("SOLO SOFTRES PASS: "..count.." checks; 20 players, local catalogue, rolls, awards, delivery, no external side effects, restart and group-join cleanup")
