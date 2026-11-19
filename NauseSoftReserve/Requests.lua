local _,S=...
local A=S.base
local KIND="nrt-sr-experiment-6"
local reserve=S.Reserve
function S:Reserve(s,player,items,source)
    local ok,why=reserve(self,s,player,items,source)
    if ok then s.reservationVersions=s.reservationVersions or {};s.reservationVersions[player]=(s.reservationVersions[player] or 0)+1 end
    return ok,why
end
local import=S.ApplyPreview
function S:ApplyPreview(s,p)
    local ok,why=import(self,s,p)
    if ok then
        s.reservationVersions=s.reservationVersions or {}
        for _,row in ipairs(p.rows) do s.reservationVersions[row.player]=(s.reservationVersions[row.player] or 0)+1 end
    end
    return ok,why
end
local valid=S.ValidSnapshot
function S:ValidSnapshot(s)
    if not valid(self,s) then return false end
    if s.reservationVersions then
        if type(s.reservationVersions)~="table" then return false end
        local n=0;for name,v in pairs(s.reservationVersions) do n=n+1;if n>40 or type(name)~="string" or #name>100 or not self.Integer(v,0,100000000) then return false end end
    end
    return true
end
local function state(s,name)
    return (s.reservationVersions or {})[name] or 0
end
function S:Request(action,data)
    local s=self.session
    if not s or s.owner~=A.leader then return false,"Sync with the raid leader first." end
    if self.pendingRequest then return false,"A request is awaiting the leader. Wait for its result or timeout." end
    if self.lastReservationAck and self.lastReservationAck.sid==s.id and self.lastReservationAck.version>state(s,A.me) then
        self:NeedSync();return false,"Accepted reservations are still synchronizing. Wait for the confirmed list."
    end
    self.requestSerial=(self.requestSerial or 0)+1
    local p={id=s.id,requestID=tostring(A.Client:ServerTime())..":"..self.requestSerial,action=action,
        reservationVersion=state(s,A.me),reservationEpoch=s.reservationEpoch or 0,original=A.Copy(s.reserves[A.me] or {}),items=A.Copy(data)}
    if action=="pass" and s.round then p.item=s.round.item;p.epoch=s.round.epoch;p.tier=s.round.tier end
    if self:IsHost() then return self:Handle(A.me,p) end
    self.pendingRequest={packet=p,untilTime=A.Client:Uptime()+10}
    self.requestStatus="Pending — waiting for the raid leader"
    if self:Send("request",p,A.leader)==false then self.pendingRequest=nil;self.requestStatus="Not sent — try again";return false,"Unable to queue request." end
    self:RenderBrowser();return true,"Request sent; awaiting acknowledgement."
end
function S:Handle(sender,p)
    if not self:IsHost() or not A.roster[sender] or type(p)~="table" or p.id~=self.session.id or type(p.requestID)~="string" or #p.requestID>100 then return false,"No matching authenticated request." end
    self.requestResults=self.requestResults or {};local now=A.Client:Uptime()
    local owner=self.requestResults[sender]
    if not owner or owner.sid~=p.id then owner={sid=p.id,results={},order={}};self.requestResults[sender]=owner end
    if owner.results[p.requestID] then local r=owner.results[p.requestID];return r.ok,r.why end
    local s=self.session;local ok,why
    if owner.last and now-owner.last<.5 then return false,"Requests are arriving too quickly. Wait and retry." end
    owner.last=now
    if p.action=="reserve" then
        if p.reservationEpoch~=(s.reservationEpoch or 0) or p.reservationVersion~=state(s,sender) or not self.Same(p.original,s.reserves[sender] or {}) then
            ok,why=false,"Your confirmed reservations changed. Sync and reset your draft."
        else ok,why=self:Reserve(s,sender,p.items,"in-game") end
    elseif p.action=="pass" then
        local r=s.round
        if not r or r.closed or p.item~=r.item or p.epoch~=r.epoch then ok,why=false,"The item round changed. Reopen the roll prompt."
        elseif r.deadline and A.Client:ServerTime()>=r.deadline then self:ExpireRound();ok,why=false,"The roll deadline has passed."
        else r.passed[sender]=true;r.rolls[sender]=nil;s.revision=s.revision+1;ok=true end
    else ok,why=false,"Unknown request." end
    owner.results[p.requestID]={ok=ok==true,why=why};owner.order[#owner.order+1]=p.requestID
    if #owner.order>24 then owner.results[table.remove(owner.order,1)]=nil end
    if ok then self:Publish() end
    return ok,why
end
local packet=A.Packet
function A:Packet(sender,p)
    if type(p)=="table" and p.kind==KIND and p.protocol==self.protocol and self.roster[sender] then
        if p.action=="request" and S:IsHost() then
            local d=p.data;local ok,why=S:Handle(sender,d)
            if type(d)=="table" and type(d.requestID)=="string" and #d.requestID<=100 then
                S.replyLimits=S.replyLimits or {};local now=self.Client:Uptime()
                if S.replyLimits[sender] and now-S.replyLimits[sender]<.5 then return end
                S.replyLimits[sender]=now
                S:Send("request-result",{sid=S.session.id,requestID=d.requestID,ok=ok==true,message=why or "Accepted",
                    action=d.action,version=state(S.session,sender),picks=A.Copy(S.session.reserves[sender] or {})},sender)
            end
            return
        elseif p.action=="request-result" and sender==self.leader then
            local d=p.data;local pending=S.pendingRequest;local s=S.session
            if type(d)~="table" or not pending or not s or d.sid~=s.id or d.requestID~=pending.packet.requestID or type(d.ok)~="boolean" then return end
            S.pendingRequest=nil
            S.requestStatus=d.ok and "Accepted by the raid leader" or ("Rejected: "..tostring(d.message):sub(1,180))
            if d.ok and d.action=="reserve" and S.Integer(d.version,0,100000000) and S:Items(d.picks,s.limit) then
                -- Acknowledgements can arrive before or after a newer snapshot.
                S.lastReservationAck={sid=s.id,version=d.version,picks=A.Copy(d.picks)}
            end
            S:Print(S.requestStatus);S:RenderBrowser();return
        end
    end
    return packet(self,sender,p)
end
local render=S.RenderBrowser
function S:RenderBrowser(...)
    render(self,...)
    if self.browser and self.requestStatus then self.browser.help:SetText(self.requestStatus) end
end
function S:TickRequests()
    for name in pairs(self.requestResults or {}) do if not A.roster[name] then self.requestResults[name]=nil end end
    for name in pairs(self.replyLimits or {}) do if not A.roster[name] then self.replyLimits[name]=nil end end
    local ack=self.lastReservationAck
    if ack and (not self.session or ack.sid~=self.session.id or ack.version<=state(self.session,A.me)) then self.lastReservationAck=nil end
    local p=self.pendingRequest
    if p and self.session and p.packet.id==self.session.id then
        local confirmed=p.packet.action=="reserve" and state(self.session,A.me)>p.packet.reservationVersion and self.Same(self.session.reserves[A.me],p.packet.items)
        local r=self.session.round
        confirmed=confirmed or (p.packet.action=="pass" and r and p.packet.epoch==r.epoch and r.passed[A.me])
        if confirmed then self.pendingRequest=nil;self.requestStatus="Accepted — confirmed by synchronized state";self:RenderBrowser();p=nil end
    end
    if p and (not self.session or self.session.id~=p.packet.id) then self.pendingRequest=nil;self.requestStatus=nil
    elseif p and A.Client:Uptime()>=p.untilTime then
        self.pendingRequest=nil;self.requestStatus="Unconfirmed — request timed out. Sync before submitting again."
        self:Print(self.requestStatus);self:NeedSync();self:RenderBrowser()
    end
end
local ticker=CreateFrame("Frame");local elapsed=0
ticker:SetScript("OnUpdate",function(_,dt) elapsed=elapsed+dt;if elapsed>=.25 then elapsed=0;S:TickRequests() end end)
