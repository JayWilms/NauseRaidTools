local baseline,companion=...
local make=assert(loadfile(companion.."/qa/softres/improvements_client.lua"))(baseline,companion)
local count=0
local function check(ok,why) count=count+1;assert(ok,why) end
local clients,queue={},{};local now=100
local names={"Leader-Realm"};for i=1,39 do names[#names+1]=string.format("P%02d-Realm",i) end
local sent={};local dropped
local function attach(name)
    local a,e,s=make(name);clients[name]={a=a,e=e,s=s}
    a.roster={};for _,n in ipairs(names) do a.roster[n]=true end
    e.GetTime=function() return now end;e.GetServerTime=function() return 1800000000+math.floor(now) end
    function a:ItemLibrary() return {GetInstances=function() return {{name="Forever Raid"}} end,GetSources=function() return {{instance="Forever Raid",boss="Boss"}} end,Search=function() return {} end} end
    a.Send=function(_,packet,target,options)
        packet.protocol=19
        local data=a.Copy(packet);queue[#queue+1]={from=name,to=target,p=data};sent[#sent+1]={p=a.Copy(data),options=options}
        return true
    end
    return a,e,s
end
local function deliver(message,name)
    local c=clients[name]
    if c and name~=message.from then c.a:Packet(message.from,c.a.Copy(message.p)) end
end
local function pump(drop)
    local n=0
    while true do
        if #queue==0 then for _,c in pairs(clients) do if c.s.syncDue then c.s:FlushSync() end end end
        if #queue==0 then break end
        n=n+1;assert(n<20000,"packet loop")
        local message=table.remove(queue,1)
        if drop and drop(message) then dropped=message
        elseif message.to then deliver(message,message.to)
        else for name in pairs(clients) do deliver(message,name) end end
    end
end
local a,e,s=attach(names[1])
for i=2,#names do attach(names[i]) end
check(#names==40,"not a 40-client fixture")
assert(s:Begin(3));pump()
for i=2,#names do
    local c=clients[names[i]];check(c.s.session and c.s.receivedSequence==1,"join snapshot missing")
    assert(c.s:Request("reserve",{279259,279259,279260}))
end
-- All clients submit against the same global revision. Each player's own
-- reservation version permits all of these independent requests to succeed.
pump()
for i=2,#names do
    local c=clients[names[i]];check(#s.session.reserves[names[i]]==3,"concurrent reservation rejected")
    check(not c.s.pendingRequest and c.s.requestStatus:find("Accepted",1,true),"request acknowledgement missing")
end
assert(s:Reserve(s.session,a.me,{279259,279259,279260},"in-game"));s:Publish();pump()
for _,c in pairs(clients) do check(c.s.Same(c.s.session.reserves,s.session.reserves),"reservations diverged") end
assert(s:Command("lock"));assert(s:Command("roll 279259"));pump()
local baselinePackets,deltaPackets={},{}
for round=1,5 do for i,name in ipairs(names) do
    local ok,why,logged=s:AcceptRoll(s.session,name,10+(i+round)%85,1,100,a.roster)
    check(ok or logged,"roll was not recorded")
    s.session.revision=s.session.revision+1;local before=#sent;s:Publish();s:FlushSync()
    for j=before+1,#sent do if sent[j].p.action=="delta" then deltaPackets[#deltaPackets+1]=a.Copy(sent[j].p) end end
    baselinePackets[#baselinePackets+1]={kind="nrt-sr-experiment-5",protocol=19,action="snapshot",data=s:PublicState()}
end end
pump()
check(#deltaPackets==200 and #s.session.round.attempts==200,"roll deltas not generated")
for _,c in pairs(clients) do
    check(c.s.Same(c.s.session.round,s.session.round),"round state diverged after 200 attempts")
    check(c.s.receivedSequence==s.streamSequence or c.a.me==a.me,"sequence diverged")
end
check(#s.session.round.rolls[names[2]]==2,"excess rolls became eligible")
-- Actual alpha55 wire encoding, compression and fragmentation, measured
-- through NetworkQueueStats; per-message reset prevents snapshot coalescing.
local function wireStats(packets)
    local fragments,bytes=0,0
    for _,p in ipairs(packets) do
        a:ResetTestTransport();assert(a.WireSend(a,a.Copy(p),nil,{priority=2}))
        local n,_,b=a:NetworkQueueStats();fragments=fragments+n;bytes=bytes+b
    end
    a:ResetTestTransport();return fragments,bytes
end
local oldFragments,oldBytes=wireStats(baselinePackets)
local newFragments,newBytes=wireStats(deltaPackets)
check(newBytes<oldBytes*.5 and newFragments<oldFragments,"wire payload did not materially improve")
print(string.format("WIRE BENCHMARK: 40 clients, 200 roll attempts; .13 full snapshots %d bytes / %d fragments; .14 deltas %d bytes / %d fragments; byte reduction %.1f%%",oldBytes,oldFragments,newBytes,newFragments,100*(1-newBytes/oldBytes)))
-- Drop an update for every peer and deliver its successor: all request a
-- snapshot and converge, despite duplicated and out-of-order updates.
assert(s:AcceptRoll(s.session,names[1],88,1,99,a.roster)==false) -- logged changed-category attempt
s.session.revision=s.session.revision+1;s:Publish()
pump(function(m) return m.p.action=="delta" end)
check(dropped~=nil,"drop fixture failed")
local lost=dropped
assert(s:Command("close"));pump()
for _,c in pairs(clients) do check(c.s.session.round.closed,"gap recovery failed") end
local victim=clients[names[2]];local revision=victim.s.session.revision
deliver(lost,names[2]);check(victim.s.session.revision==revision,"stale delta rolled state back")
local malformed=a.Copy(lost);malformed.p.data.base=victim.s.receivedSequence;malformed.p.data.sequence=malformed.p.data.base+1
malformed.p.data.delta={set={limit=99},remove={},maps={}}
local originalPicks=a.Copy(victim.s.session.reserves[names[2]])
malformed.p.data.delta.maps.reserves={set={[names[2]]={999}},remove={}}
now=now+6;deliver(malformed,names[2]);check(victim.s.session.limit==3,"malformed delta mutated client")
check(s.Same(victim.s.session.reserves[names[2]],originalPicks),"rejected delta mutated a shared reservation container")
pump()
-- Lost final update, with no successor: a heartbeat advertises the new head.
assert(s:Command("cancel"));pump(function(m) return m.p.action=="delta" end)
now=now+6;s:Send("head",{sid=s.session.id,sequence=s.streamSequence,generation=s.session.generation});pump()
for _,c in pairs(clients) do check(not c.s.session.round,"head recovery missed cancelled round") end
-- Repeated request IDs do not reserve again or advance revision.
assert(s:Command("unlock"));pump();now=now+3
local actor=names[2]
local request={id=s.session.id,requestID="replay",action="reserve",reservationVersion=s.session.reservationVersions[actor],reservationEpoch=s.session.reservationEpoch,original=a.Copy(s.session.reserves[actor]),items={279260}}
assert(s:Handle(actor,request));local after=s.session.revision
assert(s:Handle(actor,request));check(s.session.revision==after,"duplicate request changed state")
now=now+3
local stale=a.Copy(request);stale.requestID="stale"
check(not s:Handle(actor,stale),"stale same-player edit was accepted")
-- Pending requests time out without silently applying a speculative edit.
pump();local v=clients[names[3]];now=now+3
assert(v.s:Request("reserve",{279260}));queue={};now=now+11;v.s:TickRequests()
check(not v.s.pendingRequest and v.s.requestStatus:find("timed out",1,true),"request timeout not visible")
pump()
-- Chat submissions by a non-addon raider use exactly the same validation.
now=now+3;local whispers={};e.SendChatMessage=function(text,channel,_,target) whispers[#whispers+1]={text,channel,target} end
check(s:ProcessReserveChat("!unreserve 279259",names[4])==nil,"removed unreserve command was accepted")
assert(s:Reserve(s.session,names[4],{},"in-game"))
now=now+3;check(s:ProcessReserveChat("!sr 279260",names[4]),"chat reservation failed")
now=now+3;check(s:ProcessReserveChat("!mysr",names[4]),"chat query failed")
check(#whispers==2 and whispers[2][2]=="WHISPER" and whispers[2][3]==names[4],"chat did not reply privately")
now=now+3;check(not s:ProcessReserveChat("!sr Staff",names[4]),"ambiguous name accepted")
now=now+3;check(s:ProcessReserveChat("!sr 279259","Outsider-Realm")==nil,"outsider changed reservations")
assert(s:Command("lock"));now=now+3;check(not s:ProcessReserveChat("!sr 279259",names[4]),"chat bypassed lock")
-- Uncached metadata remains pending, then enters the browser on native data arrival.
local available=false
function a:ItemLibrary() return {Search=function() return {{id=900001}} end,GetName=function() return available and "Delayed Staff" or nil end,GetSources=function() return {{instance="Forever Raid",boss="Boss"}} end} end
assert(s:StartCatalogue());s:CatalogueStep()
check(s.cataloguePending[900001] and not s.catalogue[900001],"missing metadata was discarded")
available=true;s.catalogueEvents._scripts.OnEvent(nil,"GET_ITEM_INFO_RECEIVED",900001,true)
check(s.catalogue[900001] and not s.cataloguePending[900001],"loaded item did not recover")
local rows=s:BrowserResults(nil,nil,"Delayed");check(#rows==1 and rows==s:BrowserResults(nil,nil,"Delayed"),"search results not cached")
-- Strict deadlines and no automatic award remain unchanged.
assert(s:Command("roll 279260"));local deadline=s.session.round.deadline
s:ShowBrowser();s:Render()
local browserPaints,lootPaints=0,0
local browserRender,lootRender=s.RenderBrowser,a.RenderLootWindows
s.RenderBrowser=function(self,...) browserPaints=browserPaints+1;return browserRender(self,...) end
a.RenderLootWindows=function(self,...) lootPaints=lootPaints+1;return lootRender(self,...) end
assert(s:AcceptRoll(s.session,actor,50,1,100,a.roster));s.session.revision=s.session.revision+1;s:Publish()
check(browserPaints==0 and lootPaints==0,"a native roll repainted unrelated reservation/trade windows")
s.browser.search:SetText("Delayed");s.browser.search._scripts.OnTextChanged()
s.browser.search:SetText("Delayed St");s.browser.search._scripts.OnTextChanged()
check(browserPaints==0,"search input was not debounced")
now=now+.2;s.catalogueEvents._scripts.OnUpdate(nil,.2)
check(browserPaints==1,"debounced search did not repaint once")
local pendingBefore=s:PublicState();local sequenceBefore=s.streamSequence
-- The bounded publisher accumulates concurrent changes without one queued
-- delta per roll. Flushing produces one revision chain, not skipped bases.
for i=1,3 do
    s:AcceptRoll(s.session,names[i+4],60+i,1,100,a.roster);s.session.revision=s.session.revision+1;s:Publish()
end
check(s.streamSequence==sequenceBefore and s.syncDue~=nil,"publication did not batch short bursts")
s:FlushSync();check(s.streamSequence==sequenceBefore+1,"batch flush did not produce one next sequence")
e.GetServerTime=function() return deadline end
check(not s:AcceptRoll(s.session,actor,100,1,100,a.roster) and s.session.round.closed,"deadline equality accepted")
check(#s.session.history==0,"countdown auto-awarded")
assert(s:Command("cancel"))
print("IMPROVEMENTS PASS: "..count.." assertions; communication, 40-client convergence, loss/replay, requests, chat, item loading and deadlines")
