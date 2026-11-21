local _, namespace = ...
local S = namespace.SoftRes or namespace
local A=S.base
local LIVE,TEST="nrt-sr-experiment-6","nrt-sr-group-test-1"
local batchSize,maxItems=12,6000
local function text(value,max)
    return type(value)=="string" and #value>0 and #value<=max and not value:find("[%c|]")
end
function S:RequestHostCatalogue(force)
    local session=self.session
    if not session or self:IsHost() then return false end
    local now=A.Client:Uptime();local request=self.hostCatalogueRequest
    if request and request.sid==session.id and now-request.at<5 then return true end
    if not force and self.catalogueHostSID==session.id then return true end
    self.hostCatalogueSerial=(self.hostCatalogueSerial or 0)+1
    self.hostCatalogueRequest={sid=session.id,generation=session.generation,serial=self.hostCatalogueSerial,at=now,batches={},received=0}
    if self.catalogueHostSID~=session.id then self.catalogue={};self.catalogueHostSID=nil;self:InvalidateCatalogue() end
    self.catalogueJobs=nil;self.cataloguePending=nil;self.catalogueDB=nil;self.catalogueError=nil
    self.hostCatalogueWaiting="Waiting for the host's loot catalogue..."
    return self:Send("catalogue-request",{sid=session.id,generation=session.generation,request=self.hostCatalogueSerial},session.owner)
end
function S:HostCatalogueRows()
    local rows={};local session=self.session
    for id,entry in pairs(self.catalogue or {}) do
        local sources={}
        for _,source in ipairs(entry.sources or {}) do
            if not session.selectedInstances or session.selectedInstances[source.instance] then
                if text(source.instance,180) and text(source.boss,180) and #sources<30 then sources[#sources+1]={instance=source.instance,boss=source.boss} end
            end
        end
        if (not session.selectedInstances or #sources>0) and text(entry.name,200) then
            local link=type(entry.link)=="string" and #entry.link<=1024 and tonumber(entry.link:match("item:(%d+)"))==id and entry.link or nil
            rows[#rows+1]={id=id,name=entry.name,link=link,sources=sources}
        end
    end
    table.sort(rows,function(a,b) return a.id<b.id end)
    return rows
end
function S:ServiceHostCatalogue()
    if not self:IsHost() then return end
    local session=self.session
    if self.hostCatalogueSession~=session.id then self.hostCatalogueSession=session.id;self.hostCatalogueQueue={};self.hostCatalogueTargets={} end
    if not self.catalogue and not self.catalogueJobs then self:StartCatalogue() end
    if not self.catalogueJobs then
        local loading=false
        for _,pending in pairs(self.cataloguePending or {}) do if pending.tries<5 then loading=true;break end end
        if not loading then
            for target,request in pairs(self.hostCatalogueTargets or {}) do
                self.hostCatalogueTargets[target]=nil
                local rows=self:HostCatalogueRows()
                if #rows>maxItems or self.catalogueError then
                    self:Send("catalogue-error",{sid=session.id,generation=session.generation,request=request,
                        message=#rows>maxItems and "The selected loot list is too large. Ask the host to select fewer instances." or "The host's loot catalogue is unavailable. Ask the host to enable AtlasLoot and refresh items."},target)
                else
                    local parts=math.max(1,math.ceil(#rows/batchSize))
                    for part=1,parts do
                        local entries={};for i=(part-1)*batchSize+1,math.min(part*batchSize,#rows) do entries[#entries+1]=rows[i] end
                        self.hostCatalogueQueue[#self.hostCatalogueQueue+1]={target=target,data={sid=session.id,generation=session.generation,request=request,part=part,parts=parts,entries=entries}}
                    end
                end
            end
        end
    end
    for _=1,2 do
        if A.NetworkQueueStats and A:NetworkQueueStats()>=12 then break end
        local nextBatch=self.hostCatalogueQueue and self.hostCatalogueQueue[1];if not nextBatch then break end
        if not A.roster[nextBatch.target] or self:Send("catalogue-batch",nextBatch.data,nextBatch.target)~=false then table.remove(self.hostCatalogueQueue,1) else break end
    end
end
function S:ReceiveHostCatalogue(data)
    local request=self.hostCatalogueRequest;local session=self.session
    if not request or type(data)~="table" or data.sid~=session.id or data.generation~=session.generation or data.request~=request.serial
        or not self.Integer(data.parts,1,math.ceil(maxItems/batchSize)) or not self.Integer(data.part,1,data.parts)
        or type(data.entries)~="table" or #data.entries>batchSize or (request.parts and request.parts~=data.parts) then return false end
    local entries={}
    for _,entry in ipairs(data.entries) do
        if type(entry)~="table" or not self.Integer(entry.id,1,2147483647) or not text(entry.name,200)
            or type(entry.sources)~="table" or #entry.sources>30 then return false end
        if entry.link~=nil and (type(entry.link)~="string" or #entry.link>1024 or tonumber(entry.link:match("item:(%d+)"))~=entry.id) then return false end
        local sources={}
        for _,source in ipairs(entry.sources) do
            if type(source)~="table" or not text(source.instance,180) or not text(source.boss,180)
                or (session.selectedInstances and not session.selectedInstances[source.instance]) then return false end
            sources[#sources+1]={instance=source.instance,boss=source.boss}
        end
        if session.selectedInstances and #sources==0 then return false end
        entries[#entries+1]={id=entry.id,name=entry.name,search=entry.name:lower(),link=entry.link,sources=sources}
    end
    request.parts=data.parts
    if not request.batches[data.part] then request.batches[data.part]=entries;request.received=request.received+1 end
    self.hostCatalogueWaiting="Receiving host loot catalogue ("..request.received.."/"..request.parts..")..."
    if request.received==request.parts then
        local catalogue={}
        for part=1,request.parts do for _,entry in ipairs(request.batches[part]) do
            if catalogue[entry.id] then return false end;catalogue[entry.id]=entry
        end end
        self.catalogue=catalogue;self.catalogueHostSID=session.id;self.hostCatalogueWaiting=nil;self.hostCatalogueRequest=nil;self.catalogueError=nil
        self:InvalidateCatalogue();self:RenderBrowser()
    end
    return true
end
function S:DiscoverSession(force)
    if self.session or A.state or A.demo or A.recoveryPending or not A.Client:InGroup() then return false end
    A:RefreshRoster()
    if not A.leader or A.leader==A.me then return false end
    local now=A.Client:Uptime()
    if self.sessionDiscoveryAt and now-self.sessionDiscoveryAt<5 then return true end
    self.sessionDiscoveryAt=now;self.catalogueError=nil
    self.sessionDiscoveryStatus="Waiting for "..A:DisplayName(A.leader).."'s SoftRes session..."
    if force then self.ignoredGroupTests={} end
    -- The leader answers whichever mode is active. Do not create a local test
    -- context until an authenticated test snapshot actually arrives.
    self:Send("sync",{},A.leader)
    A:Send({kind=TEST,action="join-test",data={}},A.leader,{priority=2})
    return true
end
local showBrowser=S.ShowBrowser
function S:ShowBrowser(...)
    if not self.session then self:DiscoverSession(true) end
    return showBrowser(self,...)
end
local start=S.StartCatalogue
function S:StartCatalogue(...)
    if self.session and not self:IsHost() then return self:RequestHostCatalogue(true) end
    if not self.session and self:DiscoverSession(true) then return true end
    return start(self,...)
end
local step=S.CatalogueStep
function S:CatalogueStep(...)
    if not self.session and self.sessionDiscoveryStatus then
        if self.sessionDiscoveryAt and A.Client:Uptime()-self.sessionDiscoveryAt>=10 then
            self.sessionDiscoveryStatus="No SoftRes session received. Ask the group leader to start a run/test, check everyone has the same build, then Refresh Items."
        end
        return
    end
    if self.session and not self:IsHost() then
        if self.hostCatalogueRequest then
            if A.Client:Uptime()-self.hostCatalogueRequest.at>=120 then self:RequestHostCatalogue(true) end
        else self:RequestHostCatalogue(false) end
        return
    end
    local result=step(self,...)
    if self.session and self:IsHost() then self:ServiceHostCatalogue() end
    return result
end
local packet=A.Packet
function A:Packet(sender,p,...)
    local expected=S.testGroup and TEST or LIVE
    if type(p)=="table" and p.kind==expected and p.protocol==self.protocol
        and (p.action=="catalogue-request" or p.action=="catalogue-batch" or p.action=="catalogue-error") then
        if S.test and not S.testGroup then return end
        local session=S.session;local data=p.data
        if not session or not self.roster[sender] or type(data)~="table" or data.sid~=session.id or data.generation~=session.generation then return end
        if p.action=="catalogue-request" then
            if not S:IsHost() or not S.Integer(data.request,1,1000000000) then return end
            S.hostCatalogueLimits=S.hostCatalogueLimits or {};local now=self.Client:Uptime()
            local last=S.hostCatalogueLimits[sender]
            if last and last.sid==session.id and now-last.at<5 then return end
            S.hostCatalogueLimits[sender]={sid=session.id,at=now}
            if S.hostCatalogueSession~=session.id then S.hostCatalogueSession=session.id;S.hostCatalogueQueue={};S.hostCatalogueTargets={} end
            S.hostCatalogueTargets[sender]=data.request;S:ServiceHostCatalogue()
        elseif sender==self.leader and sender==session.owner and not S:IsHost() then
            if p.action=="catalogue-batch" then S:ReceiveHostCatalogue(data)
            elseif S.hostCatalogueRequest and data.request==S.hostCatalogueRequest.serial and text(data.message,220) then
                S.catalogueError=data.message;S.hostCatalogueWaiting=nil;S.hostCatalogueRequest=nil;S:RenderBrowser()
            end
        end
        return
    end
    local result=packet(self,sender,p,...)
    if S.session then S.sessionDiscoveryStatus=nil;S.sessionDiscoveryAt=nil end
    if S.session and not S:IsHost() and S.catalogueHostSID~=S.session.id
        and (not S.hostCatalogueRequest or S.hostCatalogueRequest.sid~=S.session.id) then S:RequestHostCatalogue(false) end
    return result
end
