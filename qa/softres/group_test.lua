local root=...
local make=assert(loadfile(root.."/qa/softres/improvements_client.lua"))(root,root)
local count=0
local function check(value,message) count=count+1;assert(value,message) end
local function run(mode)
    local names={"Leader-Realm","Raider-Realm","Third-Realm"};local clients,queue={},{};local now=100;local native=0
    local function attach(name)
        local a,e,s=make(name);local c={a=a,e=e,s=s};clients[name]=c
        c.grouped=true;c.leader=names[1]
        e.IsInGroup=function() return c.grouped end;e.IsInRaid=function() return c.grouped and mode=="RAID" end
        e.GetTime=function() return now end;e.GetServerTime=function() return 1800000000+math.floor(now) end
        function a:Name(unit)
            if unit=="player" then return name end
            local n=tonumber(unit:match("raid(%d+)"));if n and c.grouped then return names[n] end
            n=tonumber(unit:match("party(%d+)"));if n and c.grouped then local others={};for _,peer in ipairs(names) do if peer~=name then others[#others+1]=peer end end;return others[n] end
        end
        e.GetNumGroupMembers=function() return #names end
        e.UnitIsGroupLeader=function(unit) return a:Name(unit)==c.leader end
        e.UnitIsConnected=function() return true end
        e.RandomRoll=function(low,high) native=native+1;queue[#queue+1]={roll=string.format("%s rolls 91 (%d-%d)",name,low,high)} end
        e.SendChatMessage=function() error("No test announcements or real trades") end
        e.NauseSoftReserveDB={schema=1,generation=45,session={id="saved-real-session"},history={{untouched=name}}}
        c.saved=a.Encode(e.NauseSoftReserveDB)
        a.Send=function(_,p,target)
            p.protocol=a.protocol;queue[#queue+1]={from=name,p=a.Copy(p),to=target};return true
        end
        a:RefreshRoster();a:BuildUI();return c
    end
    local host=attach(names[1]);local peer=attach(names[2]);local third=attach(names[3])
    local function pump(drop)
        local loops=0
        while true do
            if #queue==0 then for _,c in pairs(clients) do if c.s.syncDue then c.s:FlushSync() end end end
            if #queue==0 then break end
            loops=loops+1;assert(loops<1000,"test packet loop")
            local m=table.remove(queue,1)
            if m.roll then
                for _,c in pairs(clients) do c.s.events:GetScript("OnEvent")(c.s.events,"CHAT_MSG_SYSTEM",m.roll) end
            elseif not drop or not drop(m) then
                for name,c in pairs(clients) do if name~=m.from and (not m.to or name==m.to) then c.a:Packet(m.from,c.a.Copy(m.p)) end end
            end
        end
    end
    check(peer.a.ui.softResTest:IsEnabled(),mode.." member test button unavailable")
    assert(peer.s:StartTest());pump()
    check(not peer.s.test and not host.s.test,mode.." ordinary member created a host session")
    assert(host.s:StartTest());pump()
    for _,c in pairs(clients) do
        check(c.s.testGroup and c.s.test and c.a.groupTest and c.a.demo and not c.a.state,mode.." test context missing")
        c.s:CatalogueStep()
        local n=0;for _ in pairs(c.a.roster) do n=n+1 end
        check(n==3 and #c.s:BrowserResults()==8,mode.." used fake roster or external catalogue")
        check(c.s.session.id==host.s.session.id and c.a.Encode(c.e.NauseSoftReserveDB)==c.saved,mode.." snapshot not shared or overwrote save")
    end
    check(host.s.sessionSetup.status:GetText():find("GROUP TEST",1,true),"group test mislabeled")
    assert(peer.s:Request("reserve",{host.s.testItems[1].id,host.s.testItems[1].id}));pump()
    check(#host.s.session.reserves[names[2]]==2 and not peer.s.pendingRequest,"group reservation acknowledgement failed")
    assert(host.s:Command("lock"));assert(host.s:QueuePugLoot(1));pump()
    check(#host.s.session.round.attempts==0,"shared test generated fake player rolls")
    assert(peer.s:ClickNativeRoll("MS",peer.s:RollKey()));pump()
    check(native==1 and host.s.session.round.rolls[names[2]][1]==91,"group button did not track native result")
    local fragments=0
    host.e.C_ChatInfo.SendAddonMessage=function(prefix,message,channel,target)
        fragments=fragments+1;peer.a:Receive(prefix,message,channel,host.a.me);return 0
    end
    host.a:ResetTestTransport();peer.s.receivedSequence=0
    assert(host.a.WireSend(host.a,{kind="nrt-sr-group-test-1",action="snapshot",data={state=host.s:PublicState(),sequence=host.s.streamSequence}},names[2],{priority=2}))
    local ticks=0
    while host.a:NetworkQueueStats()>0 do ticks=ticks+1;assert(ticks<3000,"native test transport stalled");now=now+.05;host.a:PumpSender() end
    check(fragments>0 and peer.s.receivedSequence==host.s.streamSequence,"test transport failed native encode/fragment/reassembly")
    for _,c in pairs(clients) do check(c.s.session.round.rolls[names[2]][1]==91,"group result did not synchronize") end
    assert(host.s:Command("close"));pump()
    assert(host.s:Command("record"));assert(host.a:AcceptConfirmation());pump()
    local award=host.s.session.history[1]
    check(award.winner==names[2] and #host.s.session.reserves[names[2]]==1,"shared SR award failed")
    assert(host.s:TradeAward(award,false));pump()
    check(peer.s.session.history[1].status=="delivered","simulated delivery not synchronized")
    local activeID=host.s.session.id
    local stale={kind="nrt-sr-group-test-1",action="snapshot",protocol=19,data={state=host.s:PublicState(),sequence=host.s.streamSequence}}
    peer.a:Packet(names[3],peer.a.Copy(stale))
    check(peer.s.session.id==activeID,"ordinary member spoofed host")
    peer.a:LeaveTest();pump()
    check(not peer.s.test and host.s.testGroup and third.s.testGroup,"member exit ended everyone else's test")
    peer.a:Packet(names[1],peer.a.Copy(stale));check(not peer.s.test,"queued snapshot rejoined a member who left")
    now=now+6;assert(peer.s:StartTest());pump()
    check(peer.s.testGroup and peer.s.session.id==activeID,"explicit participant rejoin failed")
    -- Losing a delta must recover using the isolated sync path.
    local dropped=false
    host.s.session.lootEntries[2].seconds=280;host.s.session.revision=host.s.session.revision+1;host.s:Publish();host.s:FlushSync()
    pump(function(m) if m.p.action=="delta" and not dropped then dropped=true;return true end end)
    now=now+6;host.s:Send("head",{sid=activeID,sequence=host.s.streamSequence,generation=host.s.session.generation});pump()
    check(peer.s.session.lootEntries[2].seconds==280,"lost delta did not recover in test transport")
    assert(host.s:StartTest());pump()
    check(host.s.session.id~=activeID and peer.s.session.id==host.s.session.id and #host.s.session.history==0,"host restart did not reset all clients")
    host.a:LeaveTest();pump()
    for _,c in pairs(clients) do check(not c.s.test and not c.s.session and not c.a.demo and c.a.Encode(c.e.NauseSoftReserveDB)==c.saved,"host exit failed to clean up or preserve data") end
    -- Active real sessions refuse an incoming test.
    peer.a.state={id="real-council"}
    assert(host.s:StartTest());pump()
    check(not peer.s.test and peer.a.state.id=="real-council","incoming test replaced real session")
    peer.a.state=nil
    now=now+6;assert(peer.s:StartTest());pump();check(peer.s.testGroup,"late join failed")
    for _,c in pairs(clients) do c.leader=names[3] end
    for _,c in pairs(clients) do c.s.events:GetScript("OnEvent")(c.s.events,"GROUP_ROSTER_UPDATE") end;pump()
    for _,c in pairs(clients) do check(not c.s.test and not c.a.demo,"leadership change retained test") end
    for _,c in pairs(clients) do c.leader=names[1] end
    for _,c in pairs(clients) do c.a:RefreshRoster() end
    assert(host.s:StartTest());pump()
    for _,c in pairs(clients) do c.grouped=false;c.s.events:GetScript("OnEvent")(c.s.events,"GROUP_ROSTER_UPDATE") end;pump()
    for _,c in pairs(clients) do check(not c.s.test and not c.a.demo and c.a.Encode(c.e.NauseSoftReserveDB)==c.saved,"disband retained test or changed data") end
end
run("PARTY");run("RAID")
print("GROUP SOFTRES PASS: "..count.." checks; party/raid, leader start, participant join, reservations, native rolls, simulated delivery, loss recovery and cleanup")
