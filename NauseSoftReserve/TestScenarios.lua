local _,S=...
local A=S.base
local scenarios={
    {"normal","Normal run","Practice the normal reservation, roll and award flow."},
    {"tie","Tied rolls","Lock reservations and queue the first loot copy. Two players tie; close rolls, then reroll to get a clear winner."},
    {"invalid","No valid rolls","Lock and queue the first copy. Only passed/invalid attempts are seeded. Do not add rolls; wait 5 seconds for No eligible winner."},
    {"stacked","Stacked reserves","Choose at least 2 reserves, lock, then queue the first copy. Multiple SR rolls beat a higher MS roll; an extra attempt is invalid."},
    {"delivery","Pending delivery","Starts with three pending awards, duplicate item copies and short trade timers. Use Awards and Timer to review simulated deliveries."},
    {"import","Import examples","Opens Import with a valid sample. Load an unknown-player or out-of-scope example to check blocked imports. Nothing is applied automatically."},
}
local function definition(key)
    for _,row in ipairs(scenarios) do if row[1]==key then return row end end
    return scenarios[1]
end
function S:TestScenarioPlayers()
    local players,others={A.me},{}
    for name in pairs(A.roster) do
        local _,offline=self:PlayerPresentation(name)
        if name~=A.me and not offline then others[#others+1]=name end
    end
    table.sort(others);for _,name in ipairs(others) do players[#players+1]=name end
    return players
end
function S:LayoutTestScenarios()
    local f=self.setup;if not f or not f.confirm then return end
    local active=self.test and self.testSetup
    if active and not f.testScenarioLabel then
        f.testScenarioLabel=self:UILabel(f,"Test scenario",20,-482,575,true)
        f.testScenario=self:UIDropdownButton(f,"",20,-505,575,function()
            if not S.testSetup then return false,"Reopen test setup to change the scenario." end
            local choices={};for _,row in ipairs(scenarios) do choices[#choices+1]={row[2],row[1]} end
            S:SelectMenu(f.testScenario,choices,function(value) if S.testSetup then S.testScenario=value;S:LayoutTestScenarios() end end)
            return true
        end)
        f.testScenarioHelp=self:UILabel(f,"",20,-543,575);f.testScenarioHelp:SetHeight(60);self:SetTextRole(f.testScenarioHelp,"muted")
    end
    f:SetHeight(active and 690 or 575)
    f.confirm:ClearAllPoints();f.confirm:SetPoint("TOPLEFT",20,active and -630 or -515)
    f.cancel:ClearAllPoints();f.cancel:SetPoint("TOPLEFT",400,active and -630 or -515)
    if f.testScenarioLabel then
        f.testScenarioLabel:SetShown(active and true or false);f.testScenario:SetShown(active and true or false);f.testScenarioHelp:SetShown(active and true or false)
        if active then local row=definition(self.testScenario);f.testScenario:SetText(row[2]);f.testScenarioHelp:SetText(row[3]) end
    end
end
local renderSetup=S.RenderPugSetup
function S:RenderPugSetup(...) local result=renderSetup(self,...);self:LayoutTestScenarios();return result end
local publish,announce=S.Publish,S.Announce
function S:Publish(...) if self.testScenarioSeeding then return end;return publish(self,...) end
function S:Announce(...) if self.testScenarioSeeding then return end;return announce(self,...) end
function S:PrepareTestScenario(state)
    if not self.test or not self.testSetup then return false,"Open test setup first." end
    local key=definition(self.testScenario)[1];self.testScenario=key
    if key=="normal" or key=="import" then return true end
    local players=self:TestScenarioPlayers();local item=self.testItems[1].id
    if key=="tie" then
        if #players<2 then return false,"The tied-roll scenario needs at least two connected group members." end
        for i=1,2 do self:Reserve(state,players[i],{item},"test-scenario") end
    elseif key=="stacked" then
        if state.limit<2 then return false,"Choose at least 2 reserves for the stacked-reserve scenario." end
        local picks={};for i=1,state.limit do picks[i]=item end;self:Reserve(state,A.me,picks,"test-scenario")
        if players[2] then self:Reserve(state,players[2],{},"test-scenario") end
    elseif key=="invalid" then state.rollDuration=5
    elseif key=="delivery" then
        state.locked=true;self.testScenarioSeeding=true
        for i=1,3 do
            state.lootEntries[i].seconds=i==1 and 60 or i==2 and 240 or 3600
            local ok,why=self:QueuePugLoot(i)
            if ok then ok,why=self:CloseRound(state,A.roster) end
            if ok then ok,why=self:RecordWinner(state,A.roster,A.Client:ServerTime()) end
            if not ok then self.testScenarioSeeding=nil;return false,why end
        end
        self.testScenarioSeeding=nil
    end
    return true
end
local simulate=S.SimulateTestRolls
function S:SimulateTestRolls(round)
    if not self.test or not self:IsHost() or not round or round.closed then return simulate(self,round) end
    local key=self.testScenario
    if not key or key=="normal" or key=="import" then return simulate(self,round) end
    local players=self:TestScenarioPlayers()
    local function roll(player,value,high) if player then self:AcceptRoll(self.session,player,value,1,high or 100,A.roster) end end
    if key=="tie" then
        if round.tiebreak then
            local tied={};for name in pairs(round.tiePool) do tied[#tied+1]=name end;table.sort(tied)
            for i,name in ipairs(tied) do roll(name,i==1 and 90 or 60,round.tier=="OS" and 99 or 100) end
        else roll(players[1],85);roll(players[2],85) end
    elseif key=="invalid" then
        round.passed[A.me]=true;roll(A.me,80);roll(players[2] or A.me,50,200)
    elseif key=="stacked" then
        local cap=round.eligible[A.me] or 1
        for i=1,cap do roll(A.me,i==2 and 73 or 42) end
        roll(A.me,100);roll(players[2],99)
    elseif key=="delivery" then roll(players[2] or A.me,90) end
end
local confirm=S.ConfirmPugSetup
function S:ConfirmPugSetup(...)
    local pending=self.testSetup;local ok,why=confirm(self,...)
    if ok and pending and self.test then
        local row=definition(self.testScenario);self:Print("TEST SCENARIO — "..row[2]..": "..row[3])
        if self.testScenario=="delivery" then local award=self:LatestAward();self:ShowAwardQueue(award and award.id)
        elseif self.testScenario=="import" then self:ShowImport();self:LoadTestImportExample("valid") end
    end
    return ok,why
end
local stop=S.StopTest
function S:StopTest(...)
    local ok,why=stop(self,...)
    if ok then self.testScenario=nil;self.testScenarioSeeding=nil;self:LayoutTestScenarios() end
    return ok,why
end
local function base64(bytes)
    local alphabet="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";local out={}
    for i=1,#bytes,3 do
        local a,b,c=bytes:byte(i,i+2);local n=a*65536+(b or 0)*256+(c or 0)
        for shift=18,0,-6 do
            local index=math.floor(n/2^shift)%64+1
            out[#out+1]=(shift==6 and not b or shift==0 and not c) and "=" or alphabet:sub(index,index)
        end
    end
    return table.concat(out)
end
function S:LoadTestImportExample(kind)
    if not self.test or not self:IsHost() or self.testSetup then return false,"Import examples are only available in an active hosted test." end
    if not self.importUI then local ok,why=self:ShowImport();if not ok then return false,why end end
    local item=self.testItems[1].id;local player=A.me
    if kind=="unknown" then
        player="Unknown-TestPlayer";while A.roster[player] do player=player.."X" end
    elseif kind=="outside" then
        item=nil;local provider=A:ItemLibrary();local rows=provider and provider:Search({max=1000000}) or {}
        for _,row in ipairs(rows) do
            local id=type(row)=="table" and (tonumber(row.id) or (type(row.link)=="string" and tonumber(row.link:match("item:(%d+)")))) or tonumber(row)
            if self.Integer(id,1,2147483647) and not self:ScopeAllows(self.session,id) then item=id;break end
        end
        if not item then return false,"No out-of-scope item is available. Start a test with fewer dungeons/raids selected." end
    elseif kind~="valid" then return false,"Choose a valid test example." end
    local data={metadata={id="nrt-test-example"},softreserves={{name=player,items={{id=item}}}}}
    local text=base64(self.Deflate:CompressZlib(self.JSON.encode(data)))
    self.importPreview=nil;self.importUI.input:SetText(text);return self:PreviewImport()
end
local showImport=S.ShowImport
function S:ShowImport(...)
    local ok,why=showImport(self,...);local f=self.importUI
    if ok and self.test and f and not f.testExample then
        f.testExample=self:UIDropdownButton(f,"Load test example",470,-215,210,function()
            S:SelectMenu(f.testExample,{{"Valid reservations","valid"},{"Unknown player","unknown"},{"Outside selected content","outside"}},function(value)
                local _,message=S:LoadTestImportExample(value);if message then S:Print(message) end
            end);return true
        end)
    end
    if f and f.testExample then f.testExample:SetShown(self.test==true) end
    return ok,why
end
local overview=S.RenderSessionSetup
function S:RenderSessionSetup(...)
    overview(self,...)
    if self.test and self.testScenario and self:IsHost() and self.sessionSetup then
        self.sessionSetup.status:SetText(self.sessionSetup.status:GetText().." · "..definition(self.testScenario)[2])
    end
end
