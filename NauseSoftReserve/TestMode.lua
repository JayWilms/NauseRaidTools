local _,S=...
local A=S.base
local cacheFields={"catalogue","catalogueJobs","cataloguePosition","catalogueDB","cataloguePending","catalogueRevision","catalogueError","catalogueRetryAt","browserCache","browserCacheCount","browserOptionCache","browserDraft","browserOriginal","browserSession","browserInstance","browserBoss","browserPage","setupItemPending","atlasLibrary","selectedPugLoot","selectedAward","collector","inventory","deliveryView","paintSignatures","lootPaint","countdownPaint","shownLeaderKey","shownRollKey","localRollKey","localRollCount","localRollChoice","pendingRequest","lastReservationAck","requestStatus","requestResults","replyLimits","sentSID","sentPublic","syncDue","syncTargets","streamSequence","localLootSeq","rosterFilter"}
local baseFields={"me","leader","roster","demo","groupTest","gameLeader","rev","renderSession","selectedTracked","selectedLootKey"}
local function capture(object,keys)
    local values={};for _,key in ipairs(keys) do values[key]={value=object[key]};object[key]=nil end;return values
end
local function restore(object,values) for key,row in pairs(values) do object[key]=row.value end end
local db=S.DB
function S:DB() if self.test then return self.testDB end;return db(self) end
local save,publish,send,announce,flush=S.Save,S.Publish,S.Send,S.Announce,S.FlushSync
function S:Save(...) if self.test then self:Render();return end;return save(self,...) end
function S:Publish(...) if self.test then self:Render();return end;return publish(self,...) end
function S:Send(...) if self.test then return false end;return send(self,...) end
function S:FlushSync(...) if self.test then return end;return flush(self,...) end
function S:Announce(message) if self.test then self:Print("SOLO TEST: "..message);return end;return announce(self,message) end
local library=A.ItemLibrary
function A:ItemLibrary() if S.test then return S.testLibrary end;return library(self) end
local presentation=S.PlayerPresentation
function S:PlayerPresentation(name)
    local row=self.testPlayers and self.testPlayers[name]
    if self.test and row then return RAID_CLASS_COLORS and RAID_CLASS_COLORS[row.class],row.offline end
    return presentation(self,name)
end
function S:StartTest()
    if A.Client:InGroup() then return false,"Leave your party or raid before starting the solo SoftRes test." end
    if A.Client:Combat() or not A.Client:ClockReady() then return false,"Start the solo test after combat with client clocks available." end
    if self.test then self:StopTest(true) end
    if self.session or A.state or A.demo or A.recoveryPending then return false,"End the current session, council test or recovery before starting the SoftRes test." end
    local me=A:Name("player");if not me then return false,"Player identity is not available yet." end
    A:BuildUI()
    local settings=self:DB()
    local context={base=capture(A,baseFields),cache=capture(self,cacheFields)}
    context.titles={}
    for _,frame in ipairs({A.ui.lootPanels.timer.window,A.ui.lootTimers.window}) do
        local title=frame.title or frame.TitleText
        if title then context.titles[#context.titles+1]={label=title,text=title:GetText()} end
    end
    self.test=true;self.testContext=context;self.testDB={schema=1,history={},rollDuration=settings.rollDuration or 30}
    A.me=me;A.leader=me;A.roster={[me]="player"};A.demo=true;A.groupTest=nil;A.gameLeader=false;A.rev=0
    self.testPlayers={};local names={me};local classes={"WARRIOR","PRIEST","MAGE","ROGUE","DRUID","HUNTER","PALADIN","SHAMAN","WARLOCK"}
    for i=1,19 do
        local name=string.format("Raider%02d-Test",i);names[#names+1]=name;A.roster[name]=true
        self.testPlayers[name]={class=classes[(i-1)%#classes+1],offline=i>=18}
    end
    local items=A:TestItems();self.testItems={};local byID={}
    for i=1,8 do local row=items[i];self.testItems[i]={id=row.id,link=row.link,name=row.link:match("|h%[(.-)%]|h") or ("Test item "..i)};byID[row.id]=self.testItems[i] end
    local fixture={}
    function fixture:GetInstances() return {{name="SoftRes Test Raid"}} end
    function fixture:GetSources(id) return byID[id] and {{instance="SoftRes Test Raid",boss="Simulated Boss"}} or {} end
    function fixture:Search() local ids={};for _,item in ipairs(S.testItems) do ids[#ids+1]=item.id end;return ids end
    function fixture:GetName(id) return byID[id] and byID[id].name end
    function fixture:GetInfo(id) return self:GetName(id) end
    function fixture:GetLink(id) return byID[id] and byID[id].link end
    self.testLibrary=fixture
    self.session=self:New(me,"sr-test:"..tostring(A.Client:ServerTime())..":"..tostring(math.random(100000,999999)),2)
    local s=self.session;s.generation=1;s.selectedInstances={["SoftRes Test Raid"]=true};s.autoCollectLoot=false;s.lootEntries={};s.pugQueue={};s.lootSequences={};s.nextLootID=10
    for i=1,16 do
        local picks=i==16 and {} or {self.testItems[(i-1)%8+1].id,self.testItems[i==1 and 1 or i%8+1].id}
        self:Reserve(s,names[i],picks,"solo-test")
    end
    local now=A.Client:ServerTime()
    for i=1,10 do
        local item=self.testItems[i<=2 and 1 or ((i-2)%8+1)]
        s.lootEntries[i]={id=i,guid="Item-SRTest-"..i,link=item.link,holder=me,status="collected",kind="timed",seconds=i==1 and 480 or i==2 and 300 or 3600+i*60,maxSeconds=7200,observedAt=now,verifiedHolder=true}
    end
    self:StartCatalogue();while self.catalogueJobs do self:CatalogueStep() end
    self:ShowPugSetup();self:Render()
    self:Print("SOLO SOFTRES TEST: 20 simulated players and 10 loot copies. Review reservations, Lock reservations, then open Loot and Queue an item. Sample players roll automatically; use MS / OS to roll locally. Awards and delivery are simulated. /nrt softres leave-test exits.")
    return true
end
function S:StopTest(quiet)
    if not self.test then return false,"No solo SoftRes test is running." end
    local context=self.testContext
    self.session=nil;self.test=nil;self.testContext=nil;self.testDB=nil;self.testPlayers=nil;self.testLibrary=nil;self.testItems=nil
    for frame in pairs(self.managerFrames or {}) do frame:Hide() end
    for _,key in ipairs({"rollUI","copyPicker","importUI","ui"}) do if self[key] then self[key]:Hide() end end
    restore(self,context.cache);restore(A,context.base)
    for _,saved in ipairs(context.titles) do saved.label:SetText(saved.text) end
    if A.ui and A.ui.confirmation and A.ui.confirmation:IsShown() then A.ui.confirmation:Hide() end
    A.confirmationContext=nil
    A:RefreshRoster();self:Render();A:Render()
    if not quiet then self:Print("Solo SoftRes test ended. Real saved sessions and history were not changed.") end
    return true
end
function S:SimulateTestRolls(round)
    if not self.test or not round or round.closed then return end
    local names={};for name,player in pairs(self.testPlayers) do if not player.offline then names[#names+1]=name end end;table.sort(names)
    for i,name in ipairs(names) do
        local cap=round.tiebreak and 1 or ((round.eligible[name] or 0)>0 and round.eligible[name] or 1)
        local high=((round.eligible[name] or 0)>0 or i%3~=0) and 100 or 99
        if round.tiebreak then high=round.tier=="OS" and 99 or 100 end
        if not round.tiebreak or round.tiePool[name] then
            for n=1,cap do self:AcceptRoll(self.session,name,10+(i*17+n*11+round.item)%70,1,high,A.roster) end
        end
    end
end
local startRound=S.StartRound
function S:StartRound(...)
    local ok,why=startRound(self,...)
    if ok and self.test then self:SimulateTestRolls(self.session.round) end
    return ok,why
end
local reroll=S.Reroll
function S:Reroll(...)
    local ok,why=reroll(self,...)
    if ok and self.test then self:SimulateTestRolls(self.session.round) end
    return ok,why
end
local nativeRoll=S.ClickNativeRoll
function S:ClickNativeRoll(choice,key)
    if not self.test then return nativeRoll(self,choice,key) end
    if key~=self:RollKey() or self:RollAllowance(choice)<1 then return false,"No test roll is available for this choice." end
    local high=choice=="OS" and 99 or 100
    local ok,why=self:AcceptRoll(self.session,A.me,math.random(1,high),1,high,A.roster)
    if ok then self.session.revision=self.session.revision+1;self:Publish() end
    return ok,why
end
local trade=S.TradeAward
function S:TradeAward(h,place)
    if not self.test then return trade(self,h,place) end
    if not h then return false,"Select a test award first." end
    local ok,why=self:ConfirmDelivery(h.id,h.revision)
    if ok then h.deliveryMethod="solo-test";return true,"Simulated delivery recorded. No real trade was opened." end
    return ok,why
end
local inventory=S.Inventory
function S:Inventory(...)
    if not self.test then return inventory(self,...) end
    local view={at=A.Client:Uptime(),complete=true,items={},byGUID={}}
    for _,entry in ipairs(self.session.lootEntries or {}) do
        local item={guid=entry.guid,link=entry.link,item=tonumber(entry.link:match("item:(%d+)")),count=1,locked=false,quality=4}
        view.items[#view.items+1]=item;view.byGUID[item.guid]=item
    end
    return view
end
local delivery,chat,report,collect=S.DeliveryView,S.ProcessReserveChat,S.ReportPugLoot,S.CollectPugLoot
function S:DeliveryView(...) if self.test then return end;return delivery(self,...) end
function S:ProcessReserveChat(...) if self.test then return end;return chat(self,...) end
function S:ReportPugLoot(...) if self.test then return end;return report(self,...) end
function S:CollectPugLoot(...) if self.test then return false,"Real bag reports are disabled in the solo test." end;return collect(self,...) end
local packet=A.Packet
function A:Packet(...) if S.test then return end;return packet(self,...) end
local find=A.FindTradeItem
function A:FindTradeItem(...) if S.test then return nil,nil,"Simulated loot cannot be placed in a real trade." end;return find(self,...) end
local event=S.events:GetScript("OnEvent")
S.events:SetScript("OnEvent",function(frame,kind,...)
    if S.test then
        if (kind=="GROUP_ROSTER_UPDATE" or kind=="PLAYER_ENTERING_WORLD") and A.Client:InGroup() then S:StopTest();return end
        return
    end
    return event(frame,kind,...)
end)
for _,kind in ipairs({"OnEvent","OnUpdate"}) do
    local fn=S.sharedLootEvents:GetScript(kind)
    S.sharedLootEvents:SetScript(kind,function(...) if S.test then return end;return fn(...) end)
end
local leave,demo,group=A.LeaveTest,A.StartDemo,A.StartGroupTest
function A:LeaveTest(...) if S.test then return S:StopTest() end;return leave(self,...) end
function A:StartDemo(...) if S.test then self:Print("Exit the SoftRes solo test before starting a council test.");return false end;return demo(self,...) end
function A:StartGroupTest(...) if S.test then return false end;return group(self,...) end
local command=S.Command
function S:Command(input)
    local action=(input or ""):match("^%s*(.-)%s*$"):lower()
    if action=="test" then return self:StartTest() end
    if action=="leave-test" or action=="stop-test" or (self.test and action=="end") then return self:StopTest() end
    return command(self,input)
end
local slash=SlashCmdList.NAUSERAIDTOOLS
SlashCmdList.NAUSERAIDTOOLS=function(input)
    local command,rest=(input or ""):match("^%s*(%S*)%s*(.-)%s*$")
    if command:lower()=="softres" and rest~="" then
        local ok,why=S:Command(rest);if why then S:Print(why) end;return ok,why
    end
    return slash(input)
end
local build=A.BuildUI
function A:BuildUI(...)
    build(self,...)
    local u=self.ui
    if not u or not u.settingsPages or u.softResTest then return end
    u.softResTest=u.addTestModeButton("SoftRes Test","Try 20 simulated players, reservations, rolls, awards and delivery outside a group.",760,function()
        local ok,why;if S.test then ok,why=S:StopTest() else ok,why=S:StartTest() end
        if why then S:Print(why) end;return ok
    end)
    self:LayoutSettings();self:RefreshTestControls()
end
local render=S.Render
function S:Render(...)
    render(self,...)
    A:RefreshTestControls()
    if self.test and self.testContext then
        for _,saved in ipairs(self.testContext.titles) do saved.label:SetText("SOLO TEST · "..saved.text) end
    end
    for frame in pairs(self.managerFrames or {}) do
        if not frame.srNormalTitle then frame.srNormalTitle=frame.TitleText:GetText() end
        frame.TitleText:SetText(self.test and ("SOLO TEST · "..frame.srNormalTitle) or frame.srNormalTitle)
    end
end
local ticker=CreateFrame("Frame");S.testTicker=ticker;local elapsed=0
ticker:SetScript("OnUpdate",function(_,dt)
    if not S.test then return end
    if A.Client:InGroup() then S:StopTest();return end
    elapsed=elapsed+dt;if elapsed<1 then return end;elapsed=0
    A:RenderLootWindows();A:RenderLootTimers()
end)

local setupRender=S.RenderSessionSetup
function S:RenderSessionSetup(...)
    setupRender(self,...)
    if self.sessionSetup and self.test and self:IsHost() then self.sessionSetup.status:SetText("SOLO TEST · "..self.sessionSetup.status:GetText()) end
end
