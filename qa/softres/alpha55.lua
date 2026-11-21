local baseline,companion=...
local client=assert(loadfile(companion.."/qa/softres/alpha55_client.lua"))(baseline)
local a,env=client("Leader-Realm")
local count=0
local function check(ok,why) count=count+1;assert(ok,why) end
-- Improve mock native primitives without replacing application behaviour.
local function patchEnvironment(env)
local create=env.CreateFrame
env.CreateFrame=function(...)
    local f=create(...)
    f.Show=function(self)
        local was=self:IsShown();self._shown=true
        local scripts=rawget(self,"_scripts");if not was and scripts and scripts.OnShow then scripts.OnShow(self) end
    end
    f.Hide=function(self)
        local was=self:IsShown();self._shown=false
        local scripts=rawget(self,"_scripts");if was and scripts and scripts.OnHide then scripts.OnHide(self) end
    end
    f.GetScript=function(self,event) local scripts=rawget(self,"_scripts");return scripts and scripts[event] end
    f.GetVerticalScroll=function(self) return rawget(self,"_offset") or 0 end
    f.SetVerticalScroll=function(self,value) self._offset=value end
    f.GetStringWidth=function(self) return #self:GetText()*6 end
    f.GetFrameLevel=function() return 10 end
    f.GetFrameStrata=function() return "DIALOG" end
    f.countdown=false;f.srWinner=false;f.srTrade=false;f.nrtMoving=false;f.nrtResizing=false;f.nrtCollapsed=false;f.resizeGrip=false
    return f
end
env.UIParent.GetWidth=function() return 1920 end
env.UIParent.GetHeight=function() return 1080 end
env.UIParent.GetEffectiveScale=function() return 1 end
env.GetCursorPosition=function() return 500,500 end
env.IsMouseButtonDown=function() return false end
env.RANDOM_ROLL_RESULT="%s rolls %d (%d-%d)"
env.RandomRoll=function() end
end
patchEnvironment(env)
a.ShowConfirmation=a.RealShowConfirmation
local s={}
for line in io.lines(companion.."/NauseRaidTools/NauseRaidTools.toc") do
    if line:match("^SoftRes/.*%.lua$") then assert(loadfile(companion.."/NauseRaidTools/"..line,"t",env))("NauseRaidTools",a) end
end
s=a.SoftRes
a:ShowSettings()
local originalItemTools=a.ui.itemToolsButton:GetText()
check(a.displayName=="Nause Raid Tools" and a.protocol==19,"wrong baseline")
check(a.ui and a.ui.settingsHub,"baseline UI failed to construct")
check(env.SlashCmdList.NAUSERAIDTOOLS~=nil and env.SLASH_NAUSESR1==nil and env.SlashCmdList.NAUSESR==nil,"command routing identity")
function a:ItemLibrary() return {GetInstances=function() return {{name="Ruins of Lordaeron"},{name="Hall of Thanes"}} end,GetSources=function() return {{instance="Ruins of Lordaeron"}} end,Search=function() return {} end} end
local slash=env.SlashCmdList.NAUSERAIDTOOLS
slash("softres")
check(s.setup and s.setup.TitleText and s.setup.nrtChrome,"initial SR Setup lacks shared title chrome")
check(s.setup.lockButton and s.setup.collapseButton and s.setup.closeButton,"title controls missing")
s.setupSelection={["Ruins of Lordaeron"]=true};s.setup.limit:SetText("2");assert(s:ConfirmPugSetup())
check(s.session and s.sessionSetup and s.sessionSetup.nrtChrome and not a.state,"focused setup failed")
check(s.sessionSetup.TitleText:GetText()=="Nause Raid Tools - SoftRes - Overview","setup rebrand")
check(not s.ui,"legacy crowded management was constructed")
assert(s:Reserve(s.session,a.me,{279259,279259},"in-game"))
assert(s:Reserve(s.session,"Raider-Realm",{279259},"in-game"))
assert(s:Command("lock"))
s:ShowResults()
check(s.leaderRollUI.nrtChrome and s.leaderRollUI.input:GetBackdrop(),"Results lacks shared frame/input styling")
assert(s:Command("roll 279259"))
check(not s.sessionSetup.lock:IsEnabled(),"reservation lock remained enabled mid roll")
assert(s:AcceptRoll(s.session,a.me,50,1,100,a.roster));assert(s:AcceptRoll(s.session,"Raider-Realm",90,1,99,a.roster))
local ranked=s:RankedRolls(s.session,a.roster)
check(ranked[1].player==a.me and ranked[1].tier=="SR","SR priority changed")
assert(s:Command("close"));assert(s:Command("record"))
check(a.confirmationDialogs.NAUSE_SR_CONFIRM_AWARD and a.ui.confirmation,"SR award uses shared confirmation")
-- Test the actual shared confirmation path, not the historical static-popup shim.
check(s.session.round.closed and #s.session.history==0,"review awarded without acceptance")
local context=a.confirmationContext
if not context then
    a.ShowConfirmation=a.RealShowConfirmation;assert(s:Command("record"));context=a.confirmationContext
end
check(context and context.data and context.data.sid==s.session.id,"confirmation lost SR context")
assert(a:AcceptConfirmation())
check(#s.session.history==1 and s.session.history[1].winner==a.me,"confirmed SR award failed")
local award=s.session.history[1]
local link="|cffa335ee|Hitem:279259::::::::|h[Fixture Staff]|h|r"
assert(s:CollectPugLoot(a.me,{sid=s.session.id,seq=1,sampledAt=env.GetServerTime(),entries={{guid="Item-modern-1",link=link,kind="timed",seconds=3600}}}))
award.holder=a.me;award.guid="Item-modern-1"
s.session.lootEntries[1].award=award.id;s.session.lootEntries[1].status="awarded";s:Render()
slash("loot");local p=a.ui.lootPanels.timer
check(p.window:IsShown() and p.rows[1].action:GetText()=="Trade to Leader","shared Loot route failed")
check(p.rows[1].tradeLabel:GetText()=="Already held","self-held state lost")
for i=2,21 do assert(s:CollectPugLoot(a.me,{sid=s.session.id,seq=i,sampledAt=env.GetServerTime(),entries={{guid="Item-modern-"..i,link=link,kind="timed",seconds=3600}}})) end
p.window:SetSize(680,300);a:RenderLootWindows()
check(p.visibleRows==3 and p.count==21 and p.rows[21]:IsShown() and p.child:GetHeight()==21*44,"Loot uses fixed six rows after resize")
a:MoveLootPage(1);check(p.scroll:GetVerticalScroll()==132 and p.rows[4].tracked==4,"resized paging skipped/wrong item")
local revision=s.session.revision
p.window._scripts.OnMouseWheel(p.window,-1)
check(p.scroll:GetVerticalScroll()==176 and p.rows[5].tracked==5 and s.session.revision==revision,"wheel changed SR state")
s.selectedPugLoot=1;a:ShowLootManagement()
check(p.manage:IsShown() and not p.window:IsShown(),"Manage did not close Loot")
check(p.queue:GetText()=="Roll item" and p.attach:GetText()=="Archive delivered" and p.srAuto:IsShown(),"SoftRes Manage actions missing")
check(not p.reopen:IsShown() and not p.holder:IsShown(),"Guild-only controls leaked into PuG")
check(a.ui.itemToolsButton:GetText()=="Add item","manual fallback not routed to Results")
slash("timer");local timer=a.ui.lootTimers
check(timer.count==21 and timer.scroll and not timer.previous,"Timer did not retain alpha55 scroll list")
check(timer.rows[1].srWinner:GetText():find("Winner:",1,true),"Timer winner missing")
timer.scroll:SetVerticalScroll(80);a:RenderLootTimers()
check(timer.scroll:GetVerticalScroll()==80,"Timer refresh reset scroll")
timer.window:SetSize(440,220);a:LayoutLootTimer()
check(timer.rows[1].srWinner:GetWidth()==timer.rows[1].caption:GetWidth() and timer.rows[1].srTrade:GetWidth()<=70,"SR Timer controls ignore responsive columns")
local collector=s:LootCollector()
check(collector:ShouldCollectLoot(3) and not collector:ShouldCollectLoot(2) and not collector:IsNativeAutomaticRecipient(4),"SR collector inherited council assignment rules")
env.ItemLocation={CreateFromBagAndSlot=function(_,bag,slot) return {bag=bag,slot=slot} end}
env.C_Item={GetItemGUID=function() return "Item-native-modern" end,IsBound=function() return false end}
env.C_Container={GetContainerNumSlots=function(bag) return bag==0 and 1 or 0 end,
    GetContainerItemInfo=function() return {hyperlink=link,quality=4,stackCount=1,isLocked=false} end}
collector.ReadTradeTimer=function() return "timed",3600 end
a.ScanLoot(collector)
local native
for _,e in ipairs(s.session.lootEntries) do if e.guid=="Item-native-modern" then native=e end end
check(native and native.holder==a.me and native.verifiedHolder,"actual alpha55 bag collector failed SR report")
local pending={id="trade-fixture",revision=1,status="pending",holder=a.me,winner="Raider-Realm",guid="Item-native-modern",item=279259}
a.roster["Raider-Realm"]="raid2"
local target;a.WinnerInTradeRange=function() return true end
env.InitiateTrade=function(unit) target=unit end
assert(s:TradeAward(pending,false));check(target=="raid2" and pending.status=="pending","alpha55 exact-GUID trade opening failed")
env.TradeFrame=env.CreateFrame("Frame");env.TradeFrame:Show();env.UnitFullName=function() return "Raider","Realm" end
local cursor=false;local offered
env.CursorHasItem=function() return cursor end;env.GetTradePlayerItemLink=function() return nil end
env.C_Container.PickupContainerItem=function() cursor=true end;env.ClickTradeButton=function(slot) offered=slot;cursor=false end
assert(s:TradeAward(pending,true));check(offered==1 and pending.status=="pending","alpha55 item offering marked delivered/failed")
local before=s.session.revision
a:ToggleWindowLock(s.leaderRollUI)
check(a:WindowLocked(s.leaderRollUI) and s.session.revision==before,"window lock changed raid state")
a:ToggleWindowCollapse(s.leaderRollUI)
check(s.leaderRollUI.nrtCollapsed and s.session.revision==before,"collapse changed raid state")
a:ToggleWindowCollapse(s.leaderRollUI)
check(not s.leaderRollUI.nrtCollapsed,"Results did not expand")
assert(s:ShowImport())
check(s.importUI.nrtChrome and s.importUI.apply:GetBackdrop(),"import style not updated")
local owner=a.me;a.me="Raider-Realm"
check(not s:ShowResults() and not s:ShowPugSetup() and not s:ShowImport(),"raider got leader controls")
s:Render();check(not s.leaderRollUI:IsShown() and not s.sessionSetup:IsShown() and not s.importUI:IsShown() and not p.manage:IsShown(),"authority loss left leader windows")
slash("timer");check(timer.window:IsShown(),"raider lost public Timer")
a.me=owner;award.status="delivered";s:Render()
check(timer.count==21,"delivered award remained in Timer")
-- Snapshot/countdown integration between two actual alpha55 client instances.
assert(s:Command("roll 279259"));s:FlushSync()
local peerBase,peerEnv=client("Raider-Realm");patchEnvironment(peerEnv)
peerBase.ShowConfirmation=peerBase.RealShowConfirmation
local peer={}
for line in io.lines(companion.."/NauseRaidTools/NauseRaidTools.toc") do
    if line:match("^SoftRes/.*%.lua$") then assert(loadfile(companion.."/NauseRaidTools/"..line,"t",peerEnv))("NauseRaidTools",peerBase) end
end
peer=peerBase.SoftRes
peerBase:ShowSettings()
peerBase:Packet(a.me,{kind="nrt-sr-experiment-6",protocol=15,action="snapshot",data={state=a.Copy(s.session),sequence=s.streamSequence or 1}})
check(not peer.session,"old protocol snapshot accepted")
peerBase:Packet(a.me,{kind="nrt-sr-experiment-6",protocol=19,action="snapshot",data={state=a.Copy(s.session),sequence=s.streamSequence or 1}})
check(peer.session and peer.session.round.deadline==s.session.round.deadline,"alpha55 peers lost shared round/deadline")
check(peer.rollUI and peer.rollUI.nrtChrome and peer.rollUI:IsShown(),"raider did not receive styled roll popup")
check(not peer:ShowResults() and not peer:ShowPugSetup(),"peer accessed host windows")
local rolls=0;peerEnv.RandomRoll=function(low,high) rolls=rolls+1;check(low==1 and high==99,"OS range changed") end
assert(peer:ClickNativeRoll("OS",peer:RollKey()));check(rolls==1,"native OS button did not roll")
check(not peer:ClickNativeRoll("OS",peer:RollKey()),"duplicate pending native roll accepted")
local deadline=s.session.round.deadline;env.GetServerTime=function() return deadline end
check(not s:AcceptRoll(s.session,a.me,100,1,100,a.roster) and s.session.round.closed,"deadline-equality roll accepted")
check(#s.session.history==1,"timer auto-awarded item")
assert(s:Command("cancel"));assert(s:Command("end"))
check(not p.srAuto:IsShown() and not timer.rows[1].srWinner:IsShown(),"mode cleanup leaked companion controls")
check(a.ui.itemToolsButton:GetText()==originalItemTools,"Guild item-tools label not restored")
check(not a.state and not s.session,"session cleanup failed")
print("NRT SR UI INTEGRATION PASS: "..count.." assertions with current NRT modules and mocked native APIs")
