local _, namespace = ...
local S = namespace.SoftRes or namespace
local A=NauseRaidTools
S.base=A
NauseSoftReserve=S
local KIND="nrt-sr-experiment-6"
function S:DisplayPlayerName(name)
    return A.FullDisplayName and A:FullDisplayName(name) or name
end
function S:Print(text) A:Print("SoftRes: "..tostring(text)) end
function S:DB()
    NauseSoftReserveDB=NauseSoftReserveDB or {schema=1,history={}}
    return NauseSoftReserveDB
end
function S:IsHost() return A:IsLeader() and self.session and self.session.owner==A.me end
function S:Save()
    if self:IsHost() then self:DB().session=A.Copy(self.session) end
    if self.Render then self:Render() end
end
function S:Send(action, data, target)
    return A:Send({kind=KIND,action=action,data=data},target,{priority=action=="snapshot" and 2 or 1,key=action=="snapshot" and ("sr-snapshot:"..tostring(target)) or nil})
end
function S:Publish(target)
    if not self:IsHost() then return end
    self:Save()
    local snapshot=A.Copy(self.session)
    local visible={};local linked={}
    for _,entry in ipairs(snapshot.lootEntries or {}) do if entry.award then linked[entry.award]=true end end
    for i,h in ipairs(snapshot.history) do
        if i>#snapshot.history-10 or (h.id and (h.status=="pending" or linked[h.id])) then
            h.candidateTiers=nil;h.rollLog=nil;h.candidates=nil;h.passed=nil;h.eligible=nil;h.audit=nil
            visible[#visible+1]=h
        end
    end
    snapshot.history=visible
    self:Send("snapshot",snapshot,target)
end
-- Collected-copy links remain available even when the item cache is cold.
function S:RoundItemText(round)
    local entry=round.lootEntry and self.LootEntry and self:LootEntry(round.lootEntry)
    local link=entry and entry.link
    if self.ReservationItemText then return self:ReservationItemText(round.item,link) end
    return link or ("Item "..round.item)
end
function S:AnnounceTiedPlayers(round,reroll)
    local names={}
    if reroll then for name in pairs(round.tiePool or {}) do names[#names+1]=name end
    else for _,name in ipairs(round.winners or {}) do names[#names+1]=name end end
    table.sort(names)
    local prefix=reroll and "Reroll players: " or ("Tied players ("..round.tier.." "..round.best.."): ")
    local message=prefix
    for _,name in ipairs(names) do
        name=self:DisplayPlayerName(name)
        local separator=message==prefix and "" or ", "
        -- Leave room for the raid-chat prefix and stay below the chat limit.
        if #message+#separator+#name>240 then self:Announce(message);message=prefix;separator="" end
        message=message..separator..name
    end
    if message~=prefix then self:Announce(message) end
end
function S:Announce(text,channel)
    self:Print(text)
    channel=channel or "RAID"
    local grouped=(channel=="RAID" and A.Client:InRaid()) or (channel=="PARTY" and A.Client:InGroup())
    if type(SendChatMessage)=="function" and grouped then SendChatMessage("[Nause SR] "..text,channel) end
end
function S:AnnounceSession()
    if not self:IsHost() then return false,"Only the hosting leader can announce this SoftRes run." end
    local session=self.session;local instances={}
    for name in pairs(session.selectedInstances or {}) do instances[#instances+1]=name end;table.sort(instances)
    local content=instances[1] or session.raidName or "Selected content"
    if #content>110 then content="Selected content" end
    if #instances>1 then content=content.." +"..(#instances-1).." more" end
    local host=A:DisplayName(session.owner or A.me)
    local channel=A.Client:InRaid() and "RAID" or "PARTY"
    self:Announce("SoftRes: "..content.." | "..session.limit.." reserves per player | Reservations "..(session.locked and "LOCKED." or "OPEN."),channel)
    if session.locked then
        self:Announce("Reservations are locked. Whisper "..host.." !mysr to check your confirmed reserves.",channel)
    else
        self:Announce("Whisper "..host..": !sr Item Name to reserve; !removesr Item Name to remove; !mysr to view your reserves.",channel)
        self:Announce("Item links also work. Repeat an item or add x2 for two reserves. You do not need the addon.",channel)
    end
    return true
end
function S:MissingReservations()
    local session=self.session;local rows={}
    if not session then return rows end
    for name in pairs(A.roster) do
        local used=#(session.reserves[name] or {})
        -- Won SR items consume picks; those slots were submitted, not missed.
        for _,award in ipairs(session.history or {}) do
            if award.winner==name and award.consumed then used=used+1 end
        end
        local missing=math.max(0,session.limit-used)
        if missing>0 then rows[#rows+1]={name=name,missing=missing} end
    end
    table.sort(rows,function(a,b) return a.name<b.name end)
    return rows
end
function S:AnnounceMissingReservations()
    if not self:IsHost() then return false,"Only the hosting leader can announce missing SRs." end
    local rows=self:MissingReservations();local channel=A.Client:InRaid() and "RAID" or "PARTY"
    if #rows==0 then self:Announce("No missing SRs. Everyone has used their reservation slots.",channel);return true end
    local prefix="Missing SRs: ";local message=prefix
    for _,row in ipairs(rows) do
        local label=self:DisplayPlayerName(row.name).." ("..row.missing.." missing)";local separator=message==prefix and "" or ", "
        if #message+#separator+#label>220 then self:Announce(message,channel);message=prefix;separator="" end
        message=message..separator..label
    end
    if message~=prefix then self:Announce(message,channel) end
    return true
end
function S:Begin(limit)
    if not A:IsLeader() then return false,"Only the raid leader can host reservations." end
    if A.state or A.demo or A.recoveryPending then return false,"End the Guild Run or recovery before starting a SoftRes run." end
    if not A.Client:InRaid() or not A.Client:ClockReady() or A.Client:Combat() then
        return false,"Start a SoftRes run as Raid Leader after combat with client clocks available."
    end
    if self.session then return false,"End the current SR session first." end
    if not self.Integer(limit,1,6) then return false,"Choose 1–6 reservations." end
    local db=self:DB();db.generation=(db.generation or 0)+1
    self.session=self:New(A.me,tostring(A.Client:ServerTime())..":"..tostring(math.random(100000,999999)),limit)
    if not self.session then return false,"Choose 1–6 reservations." end
    self.session.generation=db.generation;self:Publish();return true
end
function S:Request(action, data)
    local session=self.session
    if not session or session.owner~=A.leader then return false,"Sync with the raid leader first." end
    local p={id=session.id,revision=session.revision,action=action,items=data}
    if action=="pass" and session.round then p.item=session.round.item;p.epoch=session.round.epoch;p.tier=session.round.tier end
    if self:IsHost() then return self:Handle(A.me,p) end
    if not self:Send("request",p,A.leader) then return false,"Unable to queue request." end
    return true,"Request sent; wait for leader confirmation."
end
function S:Handle(sender,p)
    if not self:IsHost() or not A.roster[sender] or type(p)~="table" then return false,"Not authorised." end
    local session=self.session
    if p.id~=session.id or p.revision~=session.revision then return false,"Reservation list changed; sync and retry." end
    local ok,why
    if p.action=="reserve" then
        ok,why=self:Reserve(session,sender,p.items,"in-game")
    elseif p.action=="pass" then
        local r=session.round
        if not r or r.closed then return false,"No open roll." end
        if p.item~=r.item or p.epoch~=r.epoch or p.tier~=r.tier then return false,"Roll changed; reopen the roll window." end
        r.passed[sender]=true;r.rolls[sender]=nil;ok=true
    else return false,"Unknown request." end
    if ok then self:Publish() end
    return ok,why
end
function S:ValidSnapshot(s)
    if type(s)~="table" or s.owner~=A.leader or type(s.id)~="string" or #s.id>100 or not self.Integer(s.revision,0,100000000) or not self.Integer(s.limit,1,6) or type(s.locked)~="boolean" or type(s.reserves)~="table" or type(s.sources)~="table" or type(s.history)~="table" then return false end
    if not self.Integer(s.generation,1,100000000) or #s.history>500 then return false end
    for _,h in ipairs(s.history) do
        if type(h)~="table" or type(h.winner)~="string" or #h.winner>100 or not self.Integer(h.item,1,2147483647) or not self.Integer(h.roll,1,100) or (h.tier~="SR" and h.tier~="MS" and h.tier~="OS") then return false end
    end
    if s.raidName~=nil and (type(s.raidName)~="string" or #s.raidName>200) then return false end
    local count=0
    for name,items in pairs(s.reserves) do
        count=count+1
        if count>40 or type(name)~="string" or #name>100 or not self:Items(items,s.limit) then return false end
    end
    if s.round then
        local r=s.round
        if type(r)~="table" or not self.Integer(r.item,1,2147483647) or (r.tier~="SR" and r.tier~="MS" and r.tier~="OS") or type(r.rolls)~="table" or type(r.eligible)~="table" or type(r.passed)~="table" or type(r.closed)~="boolean" then return false end
        if r.epoch~=nil and not self.Integer(r.epoch,1,100000000) then return false end
        if r.closed and type(r.winners)~="table" then return false end
        if r.singlePool~=true or type(r.attempts)~="table" or #r.attempts>800 or type(r.playerTiers)~="table" or type(r.attemptCounts)~="table" then return false end
        for _,entry in ipairs(r.attempts) do
            if type(entry)~="table" or type(entry.player)~="string" or #entry.player>100 or not self.Integer(entry.value,0,1000000000) or not self.Integer(entry.additional,0,19) or not self.Integer(entry.serial,1,800) or type(entry.valid)~="boolean" or type(entry.note)~="string" or #entry.note>200 or (entry.tier~="SR" and entry.tier~="MS" and entry.tier~="OS" and entry.tier~="?") then return false end
        end
        if r.tiebreak and type(r.tiePool)~="table" then return false end
        local n=0
        for name,rolls in pairs(r.rolls) do
            n=n+1;if n>40 or type(name)~="string" or #name>100 or type(rolls)~="table" or #rolls>6 then return false end
            for _,roll in ipairs(rolls) do if not self.Integer(roll,1,100) then return false end end
        end
        n=0;for name,cap in pairs(r.eligible) do n=n+1;if n>40 or type(name)~="string" or #name>100 or not self.Integer(cap,1,6) then return false end end
        if r.closed then
            if not self.Integer(r.best,0,100) or #r.winners>40 then return false end
            for _,name in ipairs(r.winners) do if type(name)~="string" or #name>100 then return false end end
        end
    end
    return true
end
local originalPacket=A.Packet
function A:Packet(sender,p)
    if type(p)=="table" and p.kind==KIND then
        if p.protocol~=A.protocol or not self.roster[sender] then return end
        if p.action=="snapshot" and sender==self.leader and sender~=self.me then
            local floor=S.endedByLeader and S.endedByLeader[sender] or 0
            if S:ValidSnapshot(p.data) and p.data.generation>floor and (not S.session or p.data.generation>S.session.generation or (S.session.id==p.data.id and p.data.revision>=S.session.revision)) then S.session=p.data;if S.Render then S:Render() end end
        elseif p.action=="sync" and S:IsHost() then
            S.syncLimits=S.syncLimits or {};local now=A.Client:Uptime()
            if not S.syncLimits[sender] or now-S.syncLimits[sender]>=5 then S.syncLimits[sender]=now;S:Publish(sender) end
        elseif p.action=="request" and S:IsHost() then
            S.requestLimits=S.requestLimits or {};local now=A.Client:Uptime()
            if S.requestLimits[sender] and now-S.requestLimits[sender]<1 then return end
            S.requestLimits[sender]=now
            local ok,why=S:Handle(sender,p.data)
            S:Send("notice",ok and "Reservation request accepted." or why,sender)
        elseif p.action=="notice" and sender==self.leader and type(p.data)=="string" then S:Print(p.data:sub(1,240))
        elseif p.action=="ended" and sender==self.leader and type(p.data)=="table" and S.Integer(p.data.generation,1,100000000) then
            S.endedByLeader=S.endedByLeader or {};S.endedByLeader[sender]=math.max(S.endedByLeader[sender] or 0,p.data.generation)
            if S.session and p.data.id==S.session.id then S.session=nil;if S.Render then S:Render() end end
        end
        return
    end
    return originalPacket(self,sender,p)
end
function S:ParseItems(text)
    local ids={}
    -- Accept a single item link or a comma/space separated list of IDs.
    local link=text:match("item:(%d+)")
    if link then return {tonumber(link)} end
    for token in text:gmatch("[^,%s]+") do
        if not token:match("^%d+$") then return nil,"Use item IDs separated by spaces or commas." end
        ids[#ids+1]=tonumber(token)
    end
    return self:Items(ids,6)
end
function S:Command(text)
    local cmd,rest=text:match("^(%S*)%s*(.-)%s*$");cmd=cmd:lower()
    if cmd=="" or cmd=="show" then self:Show();return true end
    if cmd=="sync" then if self:IsHost() then self:Publish() else self:Send("sync",{},A.leader) end;return true end
    if cmd=="new" then return self:Begin(tonumber(rest) or 1) end
    if cmd=="resume" then
        if A.state then return false,"End the Guild Run before resuming a SoftRes Run." end
        if not A:IsLeader() or self.session or A.state or A.demo or A.recoveryPending then return false,"Only an idle raid leader can resume SoftRes." end
        local saved=self:DB().session
        if not self:ValidSnapshot(saved) or saved.owner~=A.me then return false,"No compatible session owned by you." end
        self.session=A.Copy(saved);self.session.round=nil;self:Publish();return true,"Resumed reservations; any interrupted roll was cancelled."
    end
    if cmd=="reserve" then local ids,why=self:ParseItems(rest);if not ids then return false,why end;return self:Request("reserve",ids) end
    if cmd=="pass" then return self:Request("pass") end
    if not self:IsHost() then return false,"Only the hosting raid leader can use this command." end
    local session=self.session;local ok,why=true,nil
    if cmd=="lock" or cmd=="unlock" then
        if session.round then return false,"Finish or cancel the active item first." end
        session.locked=cmd=="lock";session.reservationEpoch=(session.reservationEpoch or 0)+1;session.revision=session.revision+1
    elseif cmd=="roll" then
        if not self.RollPattern(RANDOM_ROLL_RESULT) then return false,"This client's random-roll message format is unavailable or unsupported. Roll tracking is disabled." end
        local ids=self:ParseItems(rest)
        if not ids or #ids~=1 then return false,"Choose one item ID." end
        ok,why=self:StartRound(session,ids[1],A.roster)
    elseif cmd=="close" then ok,why=self:CloseRound(session,A.roster)
    elseif cmd=="reroll" then ok,why=self:Reroll(session)
    elseif cmd=="next" then ok,why=self:NextTier(session)
    elseif cmd=="record" then
        local round=session.round
        ok,why=self:RecordWinner(session,A.roster,A.Client:ServerTime())
        if ok then self:Announce(self:DisplayPlayerName(round.winners[1]).." wins "..self:RoundItemText(round).." ("..round.tier..", "..round.best.."). Loot delivery is manual.") end
    elseif cmd=="cancel" then session.round=nil
    elseif cmd=="end" then
        if session.round then return false,"Finish or cancel the current roll first." end
        self:DB().history[#self:DB().history+1]=A.Copy(session)
        if #self:DB().history>20 then table.remove(self:DB().history,1) end
        self:DB().session=nil;self.session=nil;self:Send("ended",{id=session.id,generation=session.generation});self:Render();return true
    else return false,"Commands: new [1–6], reserve IDs, sync, lock, unlock, roll ID, pass, close, reroll, next, record, cancel, end, resume." end
    if ok then
        session.revision=session.revision+1;self:Publish()
        if cmd=="close" and session.round and #(session.round.winners or {})>1 then self:AnnounceTiedPlayers(session.round,false) end
        if (cmd=="roll" or cmd=="reroll" or cmd=="next") and session.round then
            local r=session.round
            if r.tiebreak then self:AnnounceTiedPlayers(r,true) end
            self:Announce(self:RoundItemText(r)..(r.tiebreak and " — tied players only" or " — SR > MS > OS")..": MS /roll 100; OS /roll 99. Reservations are checked automatically."..(r.duration and r.duration>0 and (" "..r.duration.." seconds to roll.") or " Leader closes rolling manually."))
        end
    end
    return ok,why
end
local frame=CreateFrame("Frame");S.events=frame
for _,event in ipairs({"CHAT_MSG_SYSTEM","GROUP_ROSTER_UPDATE","PLAYER_ENTERING_WORLD","LOOT_OPENED"}) do pcall(frame.RegisterEvent,frame,event) end
local function rollPattern(format)
    if type(format)~="string" or format:find("%%[1-9]%$") then return nil end
    local pattern=format:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])","%%%1")
    pattern=pattern:gsub("%%%%s","(.+)"):gsub("%%%%d","(%%d+)")
    return "^"..pattern.."$"
end
S.RollPattern=rollPattern
frame:SetScript("OnEvent",function(_,event,message)
    if event=="GROUP_ROSTER_UPDATE" or event=="PLAYER_ENTERING_WORLD" then
        if S.session and (S.session.owner~=A.leader or not A.Client:InRaid()) then S.session=nil;if S.Render then S:Render() end end
    elseif event=="CHAT_MSG_SYSTEM" and S:IsHost() and S.session.round then
        local pattern=rollPattern(RANDOM_ROLL_RESULT)
        if not pattern or type(message)~="string" then return end
        local name,value,low,high=message:match(pattern)
        local player=name and A:Resolve(name)
        if player then
            local ok,why,logged=S:AcceptRoll(S.session,player,tonumber(value),tonumber(low),tonumber(high),A.roster)
            if ok or logged then S.session.revision=S.session.revision+1;S:Publish() end
            if not ok then S:Print(name..": "..why) end
        end
    elseif event=="LOOT_OPENED" and S.session and type(GetNumLootItems)=="function" and type(GetLootSlotLink)=="function" then
        for i=1,GetNumLootItems() do
            local link=GetLootSlotLink(i);local id=link and tonumber(link:match("item:(%d+)"))
            if id then local names=S:Reservers(id);if #names>0 then S:Print(link.." — reserved by "..table.concat(A.DisplayNames and A:DisplayNames(names) or names,", ")) end end
        end
    end
end)
function S:Reservers(id)
    local names={}
    for name,ids in pairs(self.session and self.session.reserves or {}) do
        local n=0;for _,item in ipairs(ids) do if item==id then n=n+1 end end
        if n>0 then names[#names+1]=name..(n>1 and " x"..n or "") end
    end
    table.sort(names);return names
end

