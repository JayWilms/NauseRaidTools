local _,S=...
local A=S.base
local KIND="nrt-sr-experiment-6"
function S:LootEntry(id)
    for _,entry in ipairs(self.session and self.session.lootEntries or {}) do if entry.id==id then return entry end end
end
function S:LootAward(entry)
    return entry and entry.award and self:AwardByID(entry.award)
end
function S:CollectPugLoot(sender,p)
    local s=self.session
    if not self:IsHost() or not A.roster[sender] or type(p)~="table" or p.sid~=s.id then return false,"No matching PuG run." end
    s.lootEntries=s.lootEntries or {};s.lootSequences=s.lootSequences or {}
    local now=A.Client:ServerTime()
    if not self.Integer(p.seq,1,100000000) or p.seq<=(s.lootSequences[sender] or 0) or not self.Integer(p.sampledAt,now-120,now+5) or type(p.entries)~="table" or #p.entries<1 or #p.entries>10 then return false,"Stale or invalid loot report." end
    local clean,seen,newCount={}, {},0
    for _,value in ipairs(p.entries) do
        if type(value)~="table" or type(value.guid)~="string" or #value.guid<6 or #value.guid>100 or not value.guid:match("^Item%-[%w%-]+$") or seen[value.guid] then return false,"Invalid or repeated item GUID." end
        seen[value.guid]=true
        local link=A:EquipmentLink(value.link)
        if not link or (value.kind~="timed" and value.kind~="unbound" and value.kind~="unknown" and value.kind~="missing") or (value.kind=="timed" and not self.Integer(value.seconds,0,604800)) then return false,"Invalid item/timer data." end
        local old
        for _,entry in ipairs(s.lootEntries) do if entry.guid==value.guid then old=entry;break end end
        if old and old.holder~=sender then return false,"Only the recorded holder may refresh that copy." end
        if old and old.link:match("item:(%d+)")~=link:match("item:(%d+)") then return false,"A GUID's item identity changed." end
        if not old and value.kind=="missing" then return false,"Unknown missing copy." end
        if not (s.retiredLootGUIDs and s.retiredLootGUIDs[value.guid]) and (old or s.autoCollectLoot~=false) then
            if not old then newCount=newCount+1 end
            clean[#clean+1]={old=old,guid=value.guid,link=link,kind=value.kind,seconds=value.seconds}
        end
    end
    if #s.lootEntries+newCount>80 then return false,"80 collected copies reached. Archive delivered loot through Manage." end
    for _,v in ipairs(clean) do
        local e=v.old
        if not e then
            s.nextLootID=(s.nextLootID or 0)+1
            e={id=s.nextLootID,guid=v.guid,link=v.link,holder=sender,status="collected"};s.lootEntries[#s.lootEntries+1]=e
        end
        e.link=v.link;e.kind=v.kind;e.seconds=v.kind=="timed" and v.seconds or nil;e.maxSeconds=math.max(e.maxSeconds or 1,e.seconds or 1);e.observedAt=math.min(now,p.sampledAt);e.verifiedHolder=true
    end
    s.lootSequences[sender]=p.seq;s.revision=s.revision+1;self:Publish();return true
end
function S:LootCollector()
    if not self.session then return end
    if not self.collector or self.collector.sid~=self.session.id then
        self.collector=setmetatable({sid=self.session.id,pendingLootLinks={},
            ShouldCollectLoot=function(c,quality) return c.state.autoCollect and type(quality)=="number" and quality>=3 end,
            IsNativeAutomaticRecipient=function() return false end,
            CorpseReservation=function() return false end,
            SendLootSamples=function(_,samples) S:ReportPugLoot(samples) end},{__index=A})
    end
    local c=self.collector
    c.me=A.me;c.roster=A.roster;c.leader=A.leader
    c.state={id=self.session.id,trackedLoot=self.session.lootEntries or {},autoCollect=self.session.autoCollectLoot~=false,retiredGUIDs=self.session.retiredLootGUIDs or {}}
    return c
end
function S:ReportPugLoot(samples)
    local s=self.session;if not s or not A.roster[A.me] then return end
    local batch={}
    local function packet(entries)
        return {kind=KIND,action="pug-loot",protocol=A.protocol,data={sid=s.id,seq=math.max(S.localLootSeq or 0,(s.lootSequences or {})[A.me] or 0)+1,sampledAt=A.Client:ServerTime(),entries=entries}}
    end
    local function send()
        if #batch==0 then return end
        local p=packet(batch);S.localLootSeq=p.data.seq
        if S:IsHost() then local ok,why=S:CollectPugLoot(A.me,p.data);if not ok then S:Print(why) end else A:Send(p,A.leader) end
        batch={}
    end
    for _,sample in ipairs(samples) do
        batch[#batch+1]=sample
        if #batch>10 or #A.Encode(packet(batch))>1200 then batch[#batch]=nil;send();batch={sample} end
        if #A.Encode(packet(batch))>1200 then batch={};self:Print("An item report exceeds the safe message size.") end
    end
    send()
end
local packet=A.Packet
function A:Packet(sender,p)
    if type(p)=="table" and p.kind==KIND and p.action=="pug-loot" then
        if p.protocol~=self.protocol or not self.roster[sender] then return end
        local ok,why=S:CollectPugLoot(sender,p.data);if not ok and S:IsHost() then S:Send("notice",why,sender) end;return
    end
    return packet(self,sender,p)
end
function S:QueuePugLoot(id)
    if not self:IsHost() then return false,"Only the PuG leader can queue loot." end
    local s=self.session
    if not s.locked then return false,"Lock reservations before queueing loot." end
    if A.Client:Combat() then return false,"Finish combat before releasing loot." end
    s.pugQueue=s.pugQueue or {};local add={}
    for _,entry in ipairs(s.lootEntries or {}) do if (not id or entry.id==id) and entry.status=="collected" and entry.kind~="missing" then add[#add+1]=entry end end
    if id and #add==0 then local e=self:LootEntry(id);if not e or e.status~="queued" then return false,"Select an available collected item." end end
    for _,e in ipairs(add) do e.status="queued";s.pugQueue[#s.pugQueue+1]=e.id end
    s.revision=s.revision+1;self:Publish()
    return self:StartNextPugLoot()
end
function S:StartNextPugLoot()
    local s=self.session
    if not self:IsHost() or s.round or #(s.pugQueue or {})==0 then return true end
    if A.Client:Combat() then return false,"Queued loot is waiting until you leave combat and queue/start it again." end
    if not self.RollPattern(RANDOM_ROLL_RESULT) then return false,"Roll-message format unavailable. Queued loot was not released." end
    local e=self:LootEntry(s.pugQueue[1])
    if not e or e.status~="queued" or e.kind=="missing" then return false,"First queued copy needs a fresh holder reading; review it before continuing." end
    local ok,why=self:StartRound(s,tonumber(e.link:match("item:(%d+)")),A.roster)
    if not ok then return false,why end
    table.remove(s.pugQueue,1);s.round.lootEntry=e.id;e.status="rolling"
    s.revision=s.revision+1;self:Publish();self:Announce(e.link.." — MS /roll 100, OS /roll 99; SR checked automatically. "..(s.round.deadline and (s.round.duration.." seconds.") or "Leader closes manually."));return true
end
local record=S.RecordWinner
function S:RecordWinner(s,roster,time)
    local entry=s.round and s.round.lootEntry and self:LootEntry(s.round.lootEntry)
    if entry then
        for _,h in ipairs(s.history) do if h.status~="cancelled" and h.holder==entry.holder and h.guid==entry.guid then return false,"This physical copy is already assigned to an award." end end
    end
    local ok,why=record(self,s,roster,time);if not ok then return false,why end
    if entry then
        local h=s.history[#s.history];entry.award=h.id;entry.status="awarded";h.lootEntry=entry.id
        if entry.kind~="missing" then h.holder=entry.holder;h.guid=entry.guid;h.audit[#h.audit+1]={action="collected-holder",by=entry.holder,time=time} end
    end
    local nextOK,message=self:StartNextPugLoot();if not nextOK then self:Print(message) end
    return true
end
local command=S.Command
function S:Command(text)
    if self:IsHost() and text=="cancel" and self.session and self.session.round and self.session.round.lootEntry then
        local e=self:LootEntry(self.session.round.lootEntry);if e then e.status="collected" end
    end
    return command(self,text)
end
function S:ArchivePugLoot()
    if not self:IsHost() then return false,"Only the leader may archive delivered copies." end
    local s=self.session;local keep={};s.retiredLootGUIDs=s.retiredLootGUIDs or {}
    for _,entry in ipairs(s.lootEntries or {}) do local h=self:LootAward(entry);if h and h.status=="delivered" then s.retiredLootGUIDs[entry.guid]=true else keep[#keep+1]=entry end end
    s.lootEntries=keep;s.revision=s.revision+1;self:Publish();return true
end
local amend=S.AmendAward
function S:AmendAward(id,revision,target,reason)
    local h=self:AwardByID(id);local e=h and h.lootEntry and self:LootEntry(h.lootEntry)
    local ok,why=amend(self,id,revision,target,reason)
    if ok and e then
        if not target then e.award=nil;e.status="collected"
        elseif e.kind~="missing" then h.holder=e.holder;h.guid=e.guid end
        self.session.revision=self.session.revision+1;self:Publish()
    end
    return ok,why
end
local valid=S.ValidSnapshot
function S:ValidSnapshot(s)
    if not valid(self,s) then return false end
    if s.lootEntries~=nil then
        if type(s.lootEntries)~="table" or #s.lootEntries>80 then return false end
        local ids,guids={},{}
        for _,entry in ipairs(s.lootEntries) do
            if type(entry)~="table" or not self.Integer(entry.id,1,10000) or ids[entry.id] or type(entry.guid)~="string" or #entry.guid<6 or #entry.guid>100 or not entry.guid:match("^Item%-[%w%-]+$") or guids[entry.guid] or type(entry.holder)~="string" or #entry.holder>100 or not A:EquipmentLink(entry.link) or (entry.status~="collected" and entry.status~="queued" and entry.status~="rolling" and entry.status~="awarded") then return false end
            if entry.kind~="timed" and entry.kind~="unbound" and entry.kind~="unknown" and entry.kind~="missing" then return false end
            if entry.kind=="timed" and not self.Integer(entry.seconds,0,604800) then return false end
            if not self.Integer(entry.observedAt,0,100000000000) then return false end
            ids[entry.id]=true;guids[entry.guid]=true
        end
        if s.pugQueue then
            if type(s.pugQueue)~="table" or #s.pugQueue>80 then return false end
            local seen={};for _,id in ipairs(s.pugQueue) do if not ids[id] or seen[id] then return false end;seen[id]=true end
        end
    end
    return true
end
local events=S:CreateUIFrame("Frame");S.sharedLootEvents=events
for _,event in ipairs({"BAG_UPDATE_DELAYED","CHAT_MSG_LOOT","PLAYER_ENTERING_WORLD"}) do events:RegisterEvent(event) end
events:SetScript("OnEvent",function(_,event,...)
    local c=S:LootCollector();if c then A.LootEvent(c,event,...);c.scanLootSoon=true end
end)
local elapsed=0;local nextScan=0
events:SetScript("OnUpdate",function(_,dt)
    elapsed=elapsed+dt;if elapsed<1 then return end;elapsed=0
    if not S.session or not A.Client:ClockReady() then return end
    local c=S:LootCollector();local now=A.Client:Uptime()
    if now>=nextScan and (c.scanLootSoon or now>=(c.nextScan or 0)) then c.scanLootSoon=false;nextScan=now+2;c.nextScan=now+20;if S.ScanInventoryLoot then S:ScanInventoryLoot(c) else A.ScanLoot(c) end end
    A:RenderLootWindows()
end)
