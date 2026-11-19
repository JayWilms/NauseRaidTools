local _,S=...
local A=S.base
local cacheFields={"catalogue","catalogueJobs","cataloguePosition","catalogueDB","cataloguePending","catalogueRevision","catalogueError","catalogueRetryAt","browserCache","browserCacheCount","browserOptionCache","browserDraft","browserOriginal","browserSession","browserViewSession","browserInstance","browserBoss","browserPage","browserMode","browserSidebarDefaulted","browserListKey","browserItemOffset","browserSearchReturnMode","setupItemPending","setupSelection","setupInstances","setupKnown","setupLevels","setupLevelFilter","setupPage","atlasLibrary","selectedPugLoot","selectedAward","awardFilter","awardViewSession","awardScrollOffset","awardListKey","rollScrollKey","rollScrollOffset","collector","inventory","deliveryView","paintSignatures","lootPaint","countdownPaint","shownLeaderKey","shownRollKey","localRollKey","localRollCount","localRollChoice","pendingRequest","lastReservationAck","requestStatus","requestResults","replyLimits","sentSID","sentPublic","syncDue","syncTargets","streamSequence","localLootSeq","rosterFilter","receivedSequence","nextRecovery","endedByLeader","lastEnded","syncLimits","popupSessions"}
local baseFields={"me","leader","roster","demo","groupTest","gameLeader","rev","renderSession","selectedTracked","selectedLootKey"}
local function capture(object,keys)
    local values={};for _,key in ipairs(keys) do values[key]={value=object[key]};object[key]=nil end;return values
end
local function restore(object,values) for key,row in pairs(values) do object[key]=row.value end end
local db=S.DB
function S:DB() if self.test then return self.testDB end;return db(self) end
local save,publish,send,announce,flush=S.Save,S.Publish,S.Send,S.Announce,S.FlushSync
function S:Save(...) if self.test then self:Render();return end;return save(self,...) end
function S:Publish(...) if self.test and not self.testGroup then self:Render();return end;return publish(self,...) end
function S:Send(...) if self.test and not self.testGroup then return false end;return send(self,...) end
function S:FlushSync(...) if self.test and not self.testGroup then return end;return flush(self,...) end
function S:Announce(message) if self.test then self:Print((self.testGroup and "GROUP TEST: " or "SOLO TEST: ")..message);return end;return announce(self,message) end
local library=A.ItemLibrary
function A:ItemLibrary() if S.test then return S.testLibrary end;return library(self) end
local presentation=S.PlayerPresentation
function S:PlayerPresentation(name)
    local row=self.testPlayers and self.testPlayers[name]
    if self.test and row then return RAID_CLASS_COLORS and RAID_CLASS_COLORS[row.class],row.offline end
    return presentation(self,name)
end
function S:PrepareTestContext(group)
    local me=A:Name("player");if not me then return end
    A:BuildUI()
    local provider=library(A)
    local settings=self:DB()
    local context={group=group,base=capture(A,baseFields),cache=capture(self,cacheFields)}
    context.titles={}
    context.setupTitle=self.setup and self.setup.TitleText:GetText()
    for _,frame in ipairs({A.ui.lootPanels.timer.window,A.ui.lootTimers.window}) do
        local title=frame.title or frame.TitleText
        if title then context.titles[#context.titles+1]={label=title,text=title:GetText()} end
    end
    self.test=true;self.testGroup=group or nil;self.testContext=context;self.testDB={schema=1,history={},rollDuration=settings.rollDuration or 30}
    A.me=me;A.leader=group and context.base.leader.value or me;A.roster=group and context.base.roster.value or {[me]="player"};A.demo=true;A.groupTest=group or nil;A.gameLeader=group and context.base.gameLeader.value or false;A.rev=0
    self.testPlayers={};local names={me};local classes={"WARRIOR","PRIEST","MAGE","ROGUE","DRUID","HUNTER","PALADIN","SHAMAN","WARLOCK"}
    for i=1,(group and 0 or 19) do
        local name=string.format("Raider%02d-Test",i);names[#names+1]=name;A.roster[name]=true
        self.testPlayers[name]={class=classes[(i-1)%#classes+1],offline=i>=18}
    end
    self.testLibrary=provider;self.testItems={};context.names=names
    return me,names
end
local canChoose=S.CanChooseRun
function S:CanChooseRun()
    if self.test and self.testSetup then
        if A.Client:Combat() or not A.Client:ClockReady() then return false,"Finish combat before confirming test content." end
        if self.testGroup and (not A.Client:InGroup() or not A:IsLeader()) then return false,"Only the group leader chooses the shared test content." end
        if not self.testGroup and A.Client:InGroup() then return false,"Leave the group before confirming a solo test." end
        return true
    end
    return canChoose(self)
end
local function invoke(provider,key,...)
    if not provider or type(provider[key])~="function" then return end
    local ok,value=pcall(provider[key],provider,...);if ok then return value end
end
function S:TestContentItems(selected)
    local rows=invoke(self.testLibrary,"Search",{max=1000000});local ids,seen={},{}
    if type(rows)~="table" then return end
    for _,row in ipairs(rows) do
        local id=type(row)=="table" and (tonumber(row.id) or (type(row.link)=="string" and tonumber(row.link:match("item:(%d+)")))) or tonumber(row)
        if self.Integer(id,1,2147483647) and not seen[id] then
            for _,source in ipairs(invoke(self.testLibrary,"GetSources",id) or {}) do
                if selected[source.instance] then seen[id]=true;ids[#ids+1]=id;break end
            end
        end
    end
    table.sort(ids);local items={}
    for i=1,math.min(8,#ids) do
        local id=table.remove(ids,math.random(#ids));local name=invoke(self.testLibrary,"GetName",id) or invoke(self.testLibrary,"GetInfo",id)
        if type(name)=="table" then name=name.name end
        if type(name)~="string" or name=="" then name="Item "..id end
        local link=invoke(self.testLibrary,"GetLink",id) or ("|cffffffff|Hitem:"..id.."::::::::|h["..name.."]|h|r")
        items[#items+1]={id=id,name=name,link=link}
    end
    return items
end
local confirmSetup=S.ConfirmPugSetup
function S:ConfirmPugSetup(...)
    if not self.testSetup then return confirmSetup(self,...) end
    local ok,why=self:CanChooseRun();if not ok then return false,why end
    local selected=self.setupSelection or {};local count=0
    for name in pairs(selected) do if not self.setupKnown[name] then return false,"Refresh the dungeon/raid list." end;count=count+1 end
    if count<1 or count>50 then return false,"Select 1–50 dungeons or raids for the test." end
    local limit=tonumber(self.setup.limit:GetText())
    if not self.Integer(limit,1,6) then return false,"Choose 1–6 shared reserves per player." end
    local items=self:TestContentItems(selected)
    if not items or #items==0 then return false,"No loot was found for that content. Refresh the catalogue or choose another dungeon/raid." end
    local group=self.testGroup;local me=A.me;local names=self.testContext.names
    self.testItems=items
    self.session=self:New(me,(group and "sr-group-test:" or "sr-test:")..tostring(A.Client:ServerTime())..":"..tostring(math.random(100000,999999)),limit)
    local state=self.session
    if group then self.groupTestSerial=math.max(self.groupTestSerial or 0,A.Client:ServerTime()%99999900)+1 end
    state.generation=group and self.groupTestSerial or 1;state.selectedInstances=A.Copy(selected);state.autoCollectLoot=false;state.lootEntries={};state.pugQueue={};state.lootSequences={};state.nextLootID=10
    for i=1,(group and 1 or 16) do
        local picks={}
        if i~=16 then for n=1,limit do picks[n]=items[i==1 and 1 or ((i+n-2)%#items+1)].id end end
        self:Reserve(state,names[i],picks,group and "group-test" or "solo-test")
    end
    local now=A.Client:ServerTime()
    for i=1,10 do
        local item=items[i<=2 and 1 or ((i-2)%#items+1)]
        state.lootEntries[i]={id=i,guid="Item-SRTest-"..i,link=item.link,holder=me,status="collected",kind="timed",seconds=i==1 and 480 or i==2 and 300 or 3600+i*60,maxSeconds=7200,observedAt=now,verifiedHolder=true}
    end
    if self.PrepareTestScenario then
        local prepared,message=self:PrepareTestScenario(state)
        if prepared==false then self.session=nil;return false,message end
    end
    self.testSetup=nil;self.setup:Hide()
    self:StartCatalogue();self:CatalogueStep()
    self:ShowPugSetup();self:Publish()
    self:Print((group and "GROUP" or "SOLO").." SOFTRES TEST: selected content, "..limit.." reserves per player and 10 simulated loot copies. Awards and delivery are simulated. /nrt leave-test exits.")
    return true
end
function S:StartTest(group)
    if A.Client:InGroup() and not group then return self:StartGroupTest() end
    if A.Client:Combat() or not A.Client:ClockReady() then return false,"Start the test after combat with client clocks available." end
    if self.test then self:StopTest(true) end
    if self.session or A.state or A.demo or A.recoveryPending then return false,"End the current session, council test or recovery before starting the SoftRes test." end
    if not A:Name("player") then return false,"Player identity is not available yet." end
    if group then A:RefreshRoster();if not A:IsLeader() then return false,"Only the group leader starts a shared SoftRes test." end end
    if not library(A) then return false,"Enable AtlasLoot Forever with Dungeons and Raids, or ItemDB, to choose test content." end
    self:PrepareTestContext(group);self.testSetup=true
    local ok,why=self:ShowPugSetup(2)
    if not ok then self:StopTest(true);return false,why end
    self.setup.TitleText:SetText((group and "GROUP TEST" or "SOLO TEST").." · Choose Dungeons / Raids")
    if self.setup.resume then self.setup.resume:Hide() end
    if self.setup.srTestExitHook~=true then
        self.setup.srTestExitHook=true
        self.setup:HookScript("OnHide",function() if S.test and S.testSetup then S:StopTest() end end)
    end
    self:Render();self:Print("Choose the test dungeon/raid and reserve limit, then confirm. Cancel exits without starting a session.")
    return true
end
function S:StopTest(quiet)
    if not self.test then return false,"No SoftRes test is running." end
    local context=self.testContext
    self.session=nil;self.test=nil;self.testGroup=nil;self.testSetup=nil;self.testContext=nil;self.testDB=nil;self.testPlayers=nil;self.testLibrary=nil;self.testItems=nil
    for frame in pairs(self.managerFrames or {}) do frame:Hide() end
    for _,key in ipairs({"setup","rollUI","copyPicker","importUI","ui"}) do if self[key] then self[key]:Hide() end end
    restore(self,context.cache);restore(A,context.base)
    if self.setup then
        self.setup.TitleText:SetText(context.setupTitle or "Nause Raid Tools - SR Setup")
        if self.setup.resume then self.setup.resume:Show() end
    end
    for _,saved in ipairs(context.titles) do saved.label:SetText(saved.text) end
    if A.ui and A.ui.confirmation and A.ui.confirmation:IsShown() then A.ui.confirmation:Hide() end
    A.confirmationContext=nil
    A:RefreshRoster();self:Render();A:Render()
    if not quiet then self:Print((context.group and "Group" or "Solo").." SoftRes test ended. Real saved sessions and history were not changed.") end
    return true
end
function S:SimulateTestRolls(round)
    if not self.test or self.testGroup or not round or round.closed then return end
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
    if not self.test or self.testGroup then return nativeRoll(self,choice,key) end
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
    if ok then h.deliveryMethod=self.testGroup and "group-test" or "solo-test";return true,"Simulated delivery recorded. No real trade was opened." end
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
function S:CollectPugLoot(...) if self.test then return false,"Real bag reports are disabled during SoftRes testing." end;return collect(self,...) end
local packet=A.Packet
function A:Packet(...) if S.test and not S.testGroup then return end;return packet(self,...) end
local find=A.FindTradeItem
function A:FindTradeItem(...) if S.test then return nil,nil,"Simulated loot cannot be placed in a real trade." end;return find(self,...) end
local event=S.events:GetScript("OnEvent")
S.events:SetScript("OnEvent",function(frame,kind,...)
    if S.test then
        if kind=="GROUP_ROSTER_UPDATE" or kind=="PLAYER_ENTERING_WORLD" then
            if S.testGroup then
                A:RefreshRoster()
                if not A.Client:InGroup() or (S.session and S.session.owner or S.testContext.base.leader.value)~=A.leader then S:StopTest() else S:Render() end
            elseif A.Client:InGroup() then S:StopTest() end
        elseif S.testGroup and kind=="CHAT_MSG_SYSTEM" then return event(frame,kind,...) end
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
function A:StartDemo(...) if S.test then self:Print("Exit the SoftRes test before starting a council test.");return false end;return demo(self,...) end
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
    u.softResTest=u.addTestModeButton("SoftRes Test","Practice solo with simulated players, or share test loot and rolls with your party or raid.",125,function()
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
        for _,saved in ipairs(self.testContext.titles) do saved.label:SetText((self.testGroup and "GROUP TEST · " or "SOLO TEST · ")..saved.text) end
    end
    for frame in pairs(self.managerFrames or {}) do
        if not frame.srNormalTitle then frame.srNormalTitle=frame.TitleText:GetText() end
        frame.TitleText:SetText(self.test and ((self.testGroup and "GROUP TEST · " or "SOLO TEST · ")..frame.srNormalTitle) or frame.srNormalTitle)
    end
end
local ticker=CreateFrame("Frame");S.testTicker=ticker;local elapsed=0
ticker:SetScript("OnUpdate",function(_,dt)
    if not S.test then return end
    if (S.testGroup and not A.Client:InGroup()) or (not S.testGroup and A.Client:InGroup()) then S:StopTest();return end
    elapsed=elapsed+dt;if elapsed<1 then return end;elapsed=0
    A:RenderLootWindows();A:RenderLootTimers()
end)

local setupRender=S.RenderSessionSetup
function S:RenderSessionSetup(...)
    setupRender(self,...)
    if self.sessionSetup and self.test and not self.testSetup and self:IsHost() then self.sessionSetup.status:SetText((self.testGroup and "GROUP TEST · " or "SOLO TEST · ")..self.sessionSetup.status:GetText()) end
end
