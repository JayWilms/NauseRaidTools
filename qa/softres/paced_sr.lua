local baseline,companion=...
local make=assert(loadfile(companion.."/qa/softres/improvements_client.lua"))(baseline,companion)
local results={}
for _,mode in ipairs({"snapshot","delta"}) do
    local a,e,s=make("Leader-Realm");local peer,pe,ps=make("Raider-Realm")
    local now,epoch=0,1800000000
    for _,env in ipairs({e,pe}) do env.GetTime=function() return now end;env.GetServerTime=function() return epoch+math.floor(now) end end
    local roster={};local names={"Leader-Realm","Raider-Realm"}
    for i=1,38 do names[#names+1]=string.format("Player%02d-Realm",i) end
    for _,name in ipairs(names) do roster[name]=true end
    a.roster=a.Copy(roster);peer.roster=a.Copy(roster)
    local fragments,bytes,last,peak=0,0,0,0
    local original=peer.Packet
    function peer:Packet(sender,p)
        if p.kind=="nrt-sr-experiment-5" then
            return original(self,sender,{kind="nrt-sr-experiment-6",protocol=19,action="snapshot",data={state=p.data,sequence=p.data.revision+1}})
        end
        return original(self,sender,p)
    end
    e.C_ChatInfo.SendAddonMessage=function(prefix,message,channel,target)
        fragments=fragments+1;bytes=bytes+#message;last=now
        peer:Receive(prefix,message,channel,a.me)
        return 0
    end
    a.Send=a.WireSend
    s.session=s:New(a.me,"paced-raid",3);s.session.generation=1
    for _,name in ipairs(names) do assert(s:Reserve(s.session,name,{279259,279259,279260},"in-game")) end
    s.session.locked=true;s.session.rollDuration=0;assert(s:StartRound(s.session,279259,a.roster))
    if mode=="snapshot" then
        function s:Publish()
            self:Save();local state=self:PublicState();state.reservationVersions=nil;state.reservationEpoch=nil
            assert(a:Send({kind="nrt-sr-experiment-5",protocol=19,action="snapshot",data=state},nil,{priority=2,key="sr-snapshot:nil"}))
        end
    end
    s:Publish()
    local function tick()
        if mode~="snapshot" then s.syncTicker._scripts.OnUpdate(nil,.05) end
        local queued=a:NetworkQueueStats();peak=math.max(peak,queued)
        a:PumpSender();now=now+.05
    end
    for _=1,4000 do tick();if a:NetworkQueueStats()==0 and not s.syncDue then break end end
    assert(ps.session and ps.session.round,"initial actual-wire snapshot did not arrive")
    fragments,bytes,peak=0,0,0;local start=now
    for roll=1,2 do for i,name in ipairs(names) do
        assert(s:AcceptRoll(s.session,name,10+(i+roll)%85,1,100,a.roster))
        s.session.revision=s.session.revision+1;s:Publish();tick()
    end end
    local burstEnd=now
    for _=1,8000 do
        tick()
        if a:NetworkQueueStats()==0 and not s.syncDue then break end
    end
    assert(ps.session and #ps.session.round.attempts==80,"paced final roll log did not converge")
    assert(s.Same(s.session.round,ps.session.round),"paced final round differs")
    results[mode]={fragments=fragments,bytes=bytes,tail=math.max(0,last-burstEnd),peak=peak,duration=last-start}
    print(string.format("PACED %s: 40-player roster / 80 native rolls in %.1fs; %d native fragments / %d bytes including headers; peak %d queued fragments; final-update tail %.2fs",mode,burstEnd-start,fragments,bytes,peak,math.max(0,last-burstEnd)))
end
assert(results.delta.bytes<results.snapshot.bytes,"coalesced deltas used more native bytes")
assert(results.delta.tail<results.snapshot.tail,"coalesced deltas made final update slower")
print("PACED SR PASS: current NRT encoder, compression, fragmentation, sender pacing/coalescing and receiver reconstruction; no native game timing claim")
