local _, namespace = ...
local S = namespace.SoftRes or namespace
local A=S.base
local KIND="nrt-sr-experiment-6"
local fields={id=true,owner=true,generation=true,revision=true,limit=true,locked=true,reserves=true,sources=true,history=true,round=true,
    raidName=true,selectedInstances=true,rollDuration=true,rollSerial=true,awardSerial=true,lootEntries=true,lootSequences=true,
    nextLootID=true,pugQueue=true,retiredLootGUIDs=true,autoCollectLoot=true,reservationVersions=true,reservationEpoch=true}
local function same(a,b)
    if type(a)~=type(b) then return false end
    if type(a)~="table" then return a==b end
    for k,v in pairs(a) do if not same(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end
    return true
end
S.Same=same
local private={candidateTiers=true,rollLog=true,candidates=true,passed=true,eligible=true,audit=true}
function S:PublicState()
    local s=self.session;local out={}
    for k in pairs(fields) do if k~="history" and s[k]~=nil then out[k]=A.Copy(s[k]) end end
    out.history={};local linked={}
    for _,entry in ipairs(s.lootEntries or {}) do if entry.award then linked[entry.award]=true end end
    for i,h in ipairs(s.history) do if i>#s.history-10 or h.status=="pending" or linked[h.id] then
        local v={};for k,x in pairs(h) do if not private[k] then v[k]=A.Copy(x) end end;out.history[#out.history+1]=v
    end end
    return out
end
local function patchTable(old,new)
    local set,remove={},{}
    for k,v in pairs(new) do if not same(v,old[k]) then set[k]=A.Copy(v) end end
    for k in pairs(old) do if new[k]==nil then remove[#remove+1]=k end end
    return {set=set,remove=remove}
end
local roundMaps={rolls=true,passed=true,playerTiers=true,attemptCounts=true}
local topMaps={reserves=true,sources=true,reservationVersions=true,lootSequences=true}
local function applyTable(t,p)
    for _,k in ipairs(p.remove or {}) do t[k]=nil end
    for k,v in pairs(p.set or {}) do t[k]=A.Copy(v) end
end
local function shallow(t)
    local out={};for k,v in pairs(t or {}) do out[k]=v end;return out
end
function S:BuildDelta(old)
    local s=self.session;local changed,removed={},{};local rpatch;local maps={}
    -- History is privacy-filtered independently; the full session/roll log is
    -- never copied merely to publish a single native roll.
    for k in pairs(fields) do if k~="round" and k~="history" and not topMaps[k] then
        if not same(old[k],s[k]) then
            if s[k]==nil then removed[#removed+1]=k else changed[k]=A.Copy(s[k]) end
        end
    end end
    for k in pairs(topMaps) do
        local p=patchTable(old[k] or {},s[k] or {})
        if next(p.set) or #p.remove>0 then maps[k]=p end
    end
    local history={};local linked={}
    for _,entry in ipairs(s.lootEntries or {}) do if entry.award then linked[entry.award]=true end end
    for i,h in ipairs(s.history) do if i>#s.history-10 or h.status=="pending" or linked[h.id] then
        local v={};for k,x in pairs(h) do if not private[k] then v[k]=x end end;history[#history+1]=v
    end end
    if not same(old.history,history) then changed.history=A.Copy(history) end
    local r,b=s.round,old.round
    if r and b and r.item==b.item and r.epoch==b.epoch and #r.attempts>=#b.attempts then
        local before,after={},{}
        for k,v in pairs(b) do if k~="attempts" and not roundMaps[k] then before[k]=v end end
        for k,v in pairs(r) do if k~="attempts" and not roundMaps[k] then after[k]=v end end
        rpatch=patchTable(before,after);rpatch.from=#b.attempts;rpatch.append={}
        rpatch.maps={}
        for key in pairs(roundMaps) do
            local p=patchTable(b[key] or {},r[key] or {})
            if next(p.set) or #p.remove>0 then rpatch.maps[key]=p end
        end
        for i=#b.attempts+1,#r.attempts do rpatch.append[#rpatch.append+1]=A.Copy(r.attempts[i]) end
        if not next(rpatch.set) and #rpatch.remove==0 and #rpatch.append==0 and not next(rpatch.maps) then rpatch=nil end
    elseif not same(r,b) then
        if r then changed.round=A.Copy(r) else removed[#removed+1]="round" end
    end
    return {set=changed,remove=removed,round=rpatch,maps=maps}
end
function S:ApplyDelta(s,d)
    if type(d)~="table" or type(d.set)~="table" or type(d.remove)~="table" then return false end
    for k in pairs(d.set) do if not fields[k] then return false end end
    for _,k in ipairs(d.remove) do if not fields[k] then return false end end
    if d.round then
        local p=d.round;local r=s.round
        if not r or type(p)~="table" or not self.Integer(p.from,0,800) or p.from~=#r.attempts or type(p.append)~="table" or #p.append+p.from>800 then return false end
        if type(p.set)~="table" or type(p.remove)~="table" or p.set.attempts~=nil then return false end
        r=shallow(r);r.attempts=shallow(r.attempts);s.round=r
        applyTable(r,p)
        for k,map in pairs(p.maps or {}) do
            if not roundMaps[k] or type(map)~="table" then return false end
            r[k]=shallow(r[k]);applyTable(r[k],map)
        end
        for _,entry in ipairs(p.append) do r.attempts[#r.attempts+1]=A.Copy(entry) end
    end
    applyTable(s,d)
    for k,map in pairs(d.maps or {}) do
        if not topMaps[k] or type(map)~="table" then return false end
        s[k]=shallow(s[k]);applyTable(s[k],map)
    end
    return true
end
function S:Save()
    -- SavedVariables serialises the current host table on logout/reload.
    -- Archive/resume paths still copy explicitly, without a per-roll deep copy.
    if self:IsHost() then self:DB().session=self.session end
    if self.Render then self:Render() end
end
local send=S.Send
function S:Send(action,data,target)
    self.syncMetrics=self.syncMetrics or {bytes=0,messages=0,full=0,deltas=0,recovery=0}
    local m=self.syncMetrics;m.bytes=m.bytes+#A.Encode({kind=KIND,action=action,data=data});m.messages=m.messages+1
    if action=="snapshot" then m.full=m.full+1 elseif action=="delta" then m.deltas=m.deltas+1 end
    if action=="snapshot" or action=="delta" or action=="head" then
        -- The initial snapshot and every dependent delta share FIFO priority.
        return A:Send({kind=KIND,action=action,data=data},target,{priority=2})
    end
    return send(self,action,data,target)
end
function S:Publish(target)
    if not self:IsHost() then return end
    self:Save()
    if target or not self.sentPublic or self.sentSID~=self.session.id then return self:FlushSync(target) end
    self.syncDue=self.syncDue or (A.Client:Uptime()+.15)
end
function S:ValidateOutgoingSnapshot(state)
    if self:ValidSnapshot(state) then self.snapshotValidationError=nil;return true end
    local reason="Invalid session data."
    for _,entry in ipairs(type(state)=="table" and type(state.lootEntries)=="table" and state.lootEntries or {}) do
        if type(entry)=="table" and not A:EquipmentLink(entry.link) then reason="A collected item has no valid item hyperlink.";break end
    end
    self.snapshotValidationError=reason
    local key=tostring(state and state.id)..":"..tostring(state and state.revision)..":"..reason
    if self.snapshotValidationNotice~=key then
        self.snapshotValidationNotice=key;self:Print("Session sync blocked: "..reason.." Restart the test after updating both addons.")
    end
    return false
end
function S:FlushSync(target)
    if not self:IsHost() then return end
    local s=self.session
    if self.sentSID~=s.id then self.sentSID=s.id;self.sentPublic=nil;self.streamSequence=0;self.syncTargets={} end
    -- Accumulate changes while an earlier native transport batch is draining.
    -- This avoids replacing large snapshots with hundreds of queued deltas.
    if A.NetworkQueueStats and A:NetworkQueueStats()>0 then
        if target then self.syncTargets=self.syncTargets or {};self.syncTargets[target]=true end
        self.syncDue=A.Client:Uptime()+.15;return
    end
    self.syncDue=nil
    if self.sentPublic and target then
        self:FlushSync()
        -- A recovery snapshot uses the latest state and sequence, without
        -- changing the broadcast baseline used by already synced peers.
        self:Save();local state=self:PublicState()
        if not self:ValidateOutgoingSnapshot(state) then return false end
        return self:Send("snapshot",{state=state,sequence=self.streamSequence},target)
    end
    if not self.sentPublic then
        self:Save();local state=self:PublicState();local sequence=(self.streamSequence or 0)+1
        if not self:ValidateOutgoingSnapshot(state) then return false end
        if self:Send("snapshot",{state=state,sequence=sequence},target)~=false then self.sentPublic=state;self.streamSequence=sequence end
        return
    end
    local d=self:BuildDelta(self.sentPublic)
    self:Save()
    if not next(d.set) and #d.remove==0 and not d.round and not next(d.maps) then return end
    local p={sid=s.id,generation=s.generation,base=self.streamSequence,sequence=self.streamSequence+1,delta=d}
    if self:Send("delta",p,target)==false then self.sentPublic=nil;return end
    self:ApplyDelta(self.sentPublic,d);self.streamSequence=p.sequence
    if self.syncTargets and next(self.syncTargets) then self.syncDue=A.Client:Uptime()+.15 end
end
local function received()
    if S.Render then S:Render() end
    local s=S.session
    if s and s.selectedInstances and not s.locked then
        S.popupSessions=S.popupSessions or {}
        if not S.popupSessions[s.id] then S.popupSessions[s.id]=true;S:ShowBrowser() end
    end
end
function S:NeedSync()
    local now=A.Client:Uptime()
    if self.nextRecovery and now<self.nextRecovery then return end
    self.nextRecovery=now+5;self:Send("sync",{},A.leader)
end
local packet=A.Packet
function A:Packet(sender,p)
    if type(p)=="table" and p.kind==KIND and p.protocol==self.protocol and self.roster[sender] and sender==self.leader and sender~=self.me then
        local d=p.data
        if p.action=="snapshot" then
            if type(d)~="table" or not S.Integer(d.sequence,1,100000000) or not S:ValidSnapshot(d.state) then return end
            local state=d.state;local floor=S.endedByLeader and S.endedByLeader[sender] or 0
            if state.generation<=floor or (S.session and (state.generation<S.session.generation or (state.id~=S.session.id and state.generation<=S.session.generation) or (state.id==S.session.id and d.sequence<(S.receivedSequence or 0)))) then return end
            S.session=state;S.receivedSequence=d.sequence;S.nextRecovery=nil;received();return
        elseif p.action=="delta" then
            local s=S.session
            if type(d)~="table" or not S.Integer(d.sequence,1,100000000) or not S.Integer(d.base,1,100000000) then return end
            if s and d.sid==s.id and d.sequence<=(S.receivedSequence or 0) then return end
            if not s or d.sid~=s.id or d.generation~=s.generation or d.base~=S.receivedSequence or d.sequence~=d.base+1 then S:NeedSync();return end
            -- Changed containers are copied by ApplyDelta; unchanged public
            -- records remain read-only, avoiding a deep copy of every old roll.
            local candidate=shallow(s)
            local ok,valid=pcall(function() return S:ApplyDelta(candidate,d.delta) and S:ValidSnapshot(candidate) end)
            if not ok or not valid then S:NeedSync();return end
            S.session=candidate;S.receivedSequence=d.sequence;received();return
        elseif p.action=="head" then
            if type(d)=="table" and (not S.session or d.sid~=S.session.id or d.sequence~=S.receivedSequence) then S:NeedSync() end
            return
        end
    end
    return packet(self,sender,p)
end
local ticker=CreateFrame("Frame");local elapsed=0
ticker:SetScript("OnUpdate",function(_,dt)
    if not S:IsHost() then S.syncDue=nil;S.syncTargets=nil end
    if S.syncDue and A.Client:Uptime()>=S.syncDue then
        local target=S.syncTargets and next(S.syncTargets)
        if target then S.syncTargets[target]=nil end
        S:FlushSync(target)
        if S.syncTargets and next(S.syncTargets) then S.syncDue=A.Client:Uptime()+.15 end
    end
    elapsed=elapsed+dt;if elapsed<5 then return end;elapsed=0
    if S:IsHost() and (not A.NetworkQueueStats or A:NetworkQueueStats()==0) then S:Send("head",{sid=S.session.id,sequence=S.streamSequence,generation=S.session.generation}) end
end)
S.syncTicker=ticker
