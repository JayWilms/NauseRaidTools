local _,S=...
local A=S.base
local TEST="nrt-sr-group-test-1"
local LIVE="nrt-sr-experiment-6"
local function testID(id) return type(id)=="string" and #id<=100 and id:match("^sr%-group%-test:")~=nil end
local transport=A.Send
function A:Send(packet,target,options)
    if S.testGroup and type(packet)=="table" then
        if packet.kind==LIVE then packet=self.Copy(packet);packet.kind=TEST
        elseif packet.kind~=TEST then return false end
    end
    return transport(self,packet,target,options)
end
local send=S.Send
function S:Send(action,data,target)
    if self.testGroup then return A:Send({kind=TEST,action=action,data=data},target,{priority=2}) end
    return send(self,action,data,target)
end
function S:StartGroupTest()
    if not A.Client:InGroup() then return false,"Join a party or raid for shared testing." end
    if A.Client:Combat() or not A.Client:ClockReady() then return false,"Start group testing after combat with client clocks available." end
    if self.session and not self.testGroup or A.state or (A.demo and not self.testGroup) or A.recoveryPending then
        return false,"End the live session or other test before starting a shared SoftRes test."
    end
    A:RefreshRoster()
    if not A:IsLeader() then
        self.ignoredGroupTests={}
        local now=A.Client:Uptime()
        if now-(self.lastGroupTestJoin or -10)>=5 then
            self.lastGroupTestJoin=now
            A:Send({kind=TEST,action="join-test",data={}},A.leader,{priority=2})
        end
        self:Print("Asked the group leader for a SoftRes test. The leader must start it; your reservations open when it arrives.")
        return true
    end
    return self:StartTest(true)
end
local stop=S.StopTest
function S:StopTest(quiet)
    if self.testGroup and self.session then
        local sid=self.session.id
        self.ignoredGroupTests=self.ignoredGroupTests or {};self.ignoredGroupTests[sid]=true
        self.ignoredGroupTestOrder=self.ignoredGroupTestOrder or {};self.ignoredGroupTestOrder[#self.ignoredGroupTestOrder+1]=sid
        if #self.ignoredGroupTestOrder>100 then self.ignoredGroupTests[table.remove(self.ignoredGroupTestOrder,1)]=nil end
        if self:IsHost() and A.Client:InGroup() then A:Send({kind=TEST,action="stop-test",data={sid=sid}},nil,{priority=2}) end
    end
    return stop(self,quiet)
end
local packet=A.Packet
function A:Packet(sender,p,...)
    if type(p)~="table" or p.kind~=TEST then
        if S.testGroup then return end
        return packet(self,sender,p,...)
    end
    if p.protocol~=self.protocol or not self.Client:InGroup() or not self.roster[sender] or sender==self.me then return end
    local d=p.data
    if p.action=="join-test" then
        if S.testGroup and S:IsHost() then
            S.groupJoinLimits=S.groupJoinLimits or {};local now=self.Client:Uptime()
            if now-(S.groupJoinLimits[sender] or -10)>=5 then S.groupJoinLimits[sender]=now;S:Publish(sender) end
        end
        return
    end
    if sender~=self.leader then
        if S.testGroup and S:IsHost() and (p.action=="request" or p.action=="sync" or p.action=="award-copy") then
            local copy=self.Copy(p);copy.kind=LIVE;return packet(self,sender,copy,...)
        end
        return
    end
    if p.action=="stop-test" then
        if S.testGroup and S.session and type(d)=="table" and d.sid==S.session.id then S:StopTest() end
        return
    end
    if p.action=="head" and not S.testGroup then
        if type(d)=="table" and testID(d.sid) and not (S.ignoredGroupTests and S.ignoredGroupTests[d.sid])
            and not S.session and not self.state and not self.demo and not self.recoveryPending then
            local now=self.Client:Uptime()
            if now-(S.lastGroupTestJoin or -10)>=5 then
                S.lastGroupTestJoin=now;self:Send({kind=TEST,action="join-test",data={}},sender,{priority=2})
            end
        end
        return
    end
    if p.action=="snapshot" then
        local state=type(d)=="table" and d.state
        if not state or not testID(state.id) or not S.Integer(d.sequence,1,100000000)
            or not S:ValidSnapshot(state) or (S.ignoredGroupTests and S.ignoredGroupTests[state.id]) then return end
        S.lastGroupTestByLeader=S.lastGroupTestByLeader or {}
        local previous=S.lastGroupTestByLeader[sender]
        if previous and (state.generation<previous.generation or (state.generation==previous.generation and state.id~=previous.id)) then return end
        if not S.testGroup then
            if S.session or self.state or self.demo or self.recoveryPending then return end
            S:PrepareTestContext(true)
            if not S.testGroup then return end
        end
        S.lastGroupTestByLeader[sender]={id=state.id,generation=state.generation}
    elseif not S.testGroup then return end
    local copy=self.Copy(p);copy.kind=LIVE
    return packet(self,sender,copy,...)
end
