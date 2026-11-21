local root=...
local make=assert(loadfile(root.."/qa/softres/improvements_client.lua"))(root,root)
local count=0
local function check(value,message) count=count+1;assert(value,message) end
local function run(mode)
    local names={"Leader-Realm","Raider-Realm","Third-Realm"};local clients,queue={},{};local now=100;local native=0
    local function attach(name)
        local a,e,s=make(name);local confirm=assert(loadfile(root.."/qa/softres/test_catalogue.lua"))(a,e);local c={a=a,e=e,s=s};clients[name]=c
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
        if name~=names[1] then e.LibStub=nil;e.AtlasLoot=nil end
        c.confirm=function(...) return confirm(s,...) end
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
    assert(host.s:StartTest());check(not host.s.session,"group test published before choosing content");assert(host.confirm());pump()
    for _,c in pairs(clients) do
        check(c.s.testGroup and c.s.test and c.a.groupTest and c.a.demo and not c.a.state,mode.." test context missing")
        c.s:CatalogueStep()
        local n=0;for _ in pairs(c.a.roster) do n=n+1 end
        check(n==3 and #c.s:BrowserResults()==8,mode.." used fake roster or external catalogue")
        if c~=host then check(c.a:ItemLibrary()==nil and c.s.catalogueHostSID==host.s.session.id,mode.." member required a local loot database") end
        check(c.s.session.id==host.s.session.id and c.a.Encode(c.e.NauseSoftReserveDB)==c.saved,mode.." snapshot not shared or overwrote save")
    end
    check(host.s.sessionSetup.status:GetText():find("GROUP TEST",1,true),"group test mislabeled")
    local notices={};local originalAnnounce=host.s.Announce;local sessionBefore=host.a.Encode(host.s.session)
    host.s.Announce=function(self,message,channel) notices[#notices+1]={message=message,channel=channel};return originalAnnounce(self,message,channel) end
    host.s.sessionSetup.announce:GetScript("OnClick")()
    check(#notices==3 and notices[1].message:find("OPEN",1,true) and notices[2].message:find("!removesr",1,true)
        and notices[2].message:find("!mysr",1,true) and notices[3].message:find("x2",1,true),"open-session announcement omitted reservation instructions")
    for _,notice in ipairs(notices) do check(notice.channel==mode and #("[Nause SR] "..notice.message)<=255,"session announcement used the wrong channel or exceeded chat length") end
    check(not peer.s:AnnounceSession(),"nonhost could announce the session")
    check(host.a.Encode(host.s.session)==sessionBefore,"announcing changed the session")
    host.s.session.locked=true;notices={};assert(host.s:AnnounceSession())
    check(#notices==2 and notices[1].message:find("LOCKED",1,true) and not notices[2].message:find("!sr ",1,true),"locked-session announcement invited reservation changes")
    host.s.session.locked=false
    local reservesBefore=host.a.Copy(host.s.session.reserves)
    host.s.session.reserves[names[2]]={host.s.testItems[1].id}
    host.s.session.reserves[names[3]]=nil
    host.s.session.reserves["Departed-Realm"]={}
    notices={};host.s.sessionSetup.announceMissing:GetScript("OnClick")()
    check(#notices==1 and notices[1].message:find(names[2].." (1 missing)",1,true)
        and notices[1].message:find(names[3].." (2 missing)",1,true)
        and not notices[1].message:find(names[1],1,true) and not notices[1].message:find("Departed",1,true),"missing SR announcement omitted partial picks or included full/departed players")
    check(not peer.s:AnnounceMissingReservations(),"nonhost announced missing SRs")
    host.s.session.history[#host.s.session.history+1]={winner=names[2],consumed=true}
    local missing=host.s:MissingReservations()
    check(#missing==1 and missing[1].name==names[3],"awarded SR slot was incorrectly announced as missing")
    table.remove(host.s.session.history)
    host.s.session.reserves[names[3]]={host.s.testItems[1].id,host.s.testItems[1].id}
    host.s.session.reserves[names[2]]={host.s.testItems[1].id,host.s.testItems[1].id}
    notices={};assert(host.s:AnnounceMissingReservations())
    check(#notices==1 and notices[1].message:find("No missing SRs",1,true),"full raid lacked an all-submitted announcement")
    host.s.session.reserves=reservesBefore
    host.s.Announce=originalAnnounce

    local whispers={}
    host.e.SendChatMessage=function(message,channel,language,target)
        check(channel=="WHISPER" and target==names[2] and message:find("[Nause SR] TEST: ",1,true)==1,"group test sent an unlabelled/public reservation response")
        whispers[#whispers+1]=message
    end
    local whisperItem=host.s.testItems[1]
    local chatEvent=host.s.chatEvents:GetScript("OnEvent")
    check(host.s:ResolveReservationChatItem(whisperItem.link)==whisperItem.id,"full item hyperlink stopped resolving")
    local catalogue=host.s.catalogue;host.s.catalogue={}
    for _,decorated in ipairs({whisperItem.link,
        "|TInterface/Icons/INV_Misc_QuestionMark:16|t"..whisperItem.link,
        "|cnITEM_QUALITY3_COLOR:|Hitem:"..whisperItem.id..":0|hCustom display label|h|r",
        "|Hitem:"..whisperItem.id..":0|h[|A:quality-icon:16:16|aDifferent display name]|h"}) do
        local parsed=host.s:ParseReservationChatItems(decorated.." "..decorated,2)
        check(parsed and #parsed==2 and parsed[1]==whisperItem.id and parsed[2]==whisperItem.id,
            "decorated addon item link depended on its display name or local catalogue")
    end
    host.s.catalogue=catalogue
    check(host.s:ResolveReservationChatItem("Unknown item name")==nil,"unknown name reserved an arbitrary item")
    host.s.catalogue[2147483646]={id=2147483646,name=whisperItem.name,sources=host.s.catalogue[whisperItem.id].sources}
    local scope=host.s.ScopeAllows;host.s.ScopeAllows=function() return true end
    check(host.s:ResolveReservationChatItem(whisperItem.name)==nil,"ambiguous name selected an arbitrary item")
    host.s.ScopeAllows=scope;host.s.catalogue[2147483646]=nil
    chatEvent(host.s.chatEvents,"CHAT_MSG_WHISPER","!sr ["..whisperItem.name.."]",names[2]);pump()
    check(#(host.s.session.reserves[names[2]] or {})==1 and #whispers==1,"group test did not accept a non-addon reservation whisper")
    check(whispers[1]:find("["..whisperItem.name.."]",1,true),"reservation confirmation used IDs instead of item names")
    now=now+3
    chatEvent(host.s.chatEvents,"CHAT_MSG_WHISPER","!mysr",names[2])
    check(#whispers==2 and whispers[2]:find("["..whisperItem.name.."]",1,true),"reserve query omitted item names")
    local stacked=host.s:ReservationChatReplies({whisperItem.id,whisperItem.id},"Confirmed: ",2)
    check(#stacked==1 and stacked[1]:find("["..whisperItem.name.."] x2 (2/2)",1,true),"stacked reserves lost their item name or quantity")
    local originalName=host.s.ReservationChatName
    host.s.ReservationChatName=function(_,id) return "[Long item "..id.." "..string.rep("a",70).."]" end
    local longReplies=host.s:ReservationChatReplies({1,2,3,4,5,6},"Confirmed: ",6)
    check(#longReplies>1,"long reserve lists were not split")
    for _,reply in ipairs(longReplies) do check(#("[Nause SR] TEST: "..reply)<=240 and reply:find(" (6/6)",1,true),"long reply lost its total or exceeded chat length") end
    local fullReply=table.concat(longReplies," ")
    for id=1,6 do check(fullReply:find(host.s:ReservationChatName(id),1,true),"long reply cut off an item name") end
    host.s.ReservationChatName=originalName
    now=now+3
    for _,legacy in ipairs({"!reserve ","!unreserve ","!myreserves "}) do
        chatEvent(host.s.chatEvents,"CHAT_MSG_WHISPER",legacy..whisperItem.name,names[2])
    end
    check(#host.s.session.reserves[names[2]]==1 and #whispers==2,"removed chat commands were still accepted")
    chatEvent(host.s.chatEvents,"CHAT_MSG_WHISPER","!removesr "..whisperItem.name:upper(),names[2]);pump()
    check(#host.s.session.reserves[names[2]]==0 and #whispers==3,"removesr did not remove a named reservation")
    now=now+3
    chatEvent(host.s.chatEvents,"CHAT_MSG_WHISPER","!mysr",names[2])
    check(#whispers==4 and whispers[4]:find("no confirmed reserves",1,true),"group test reserve query did not reply")
    chatEvent(host.s.chatEvents,"CHAT_MSG_WHISPER","!sr "..whisperItem.id,"Outsider-Realm")
    check(#whispers==4,"outsider whisper received a test response")
    now=now+3
    chatEvent(host.s.chatEvents,"CHAT_MSG_WHISPER","!sr "..whisperItem.id.." x2",names[2]);pump()
    now=now+3
    chatEvent(host.s.chatEvents,"CHAT_MSG_WHISPER","!removesr ["..whisperItem.name.."] x2",names[2]);pump()
    check(#host.s.session.reserves[names[2]]==0,"removesr x2 did not remove both stacked reservations")
    now=now+3
    local ok,why=host.s:ProcessReserveChat("!removesr "..whisperItem.id,names[2])
    check(ok==false and why=="That item is not reserved by you.","removesr accepted an item the player did not reserve")
    for _,input in ipairs({whisperItem.link.." "..whisperItem.link,
        "["..whisperItem.name.."] ["..whisperItem.name.."]",
        whisperItem.name.." "..whisperItem.name}) do
        now=now+3;assert(host.s:ProcessReserveChat("!sr "..input,names[2]));pump()
        check(#host.s.session.reserves[names[2]]==2,"repeating an item did not add two reserves")
        now=now+3;assert(host.s:ProcessReserveChat("!removesr "..input,names[2]));pump()
        check(#host.s.session.reserves[names[2]]==0,"repeating an item did not remove two reserves")
    end
    now=now+3
    check(not host.s:ProcessReserveChat("!sr ["..whisperItem.name.."] [Unknown item]",names[2])
        and #host.s.session.reserves[names[2]]==0,"partly invalid multi-item command saved a partial reservation")
    now=now+3
    check(not host.s:ProcessReserveChat("!sr "..whisperItem.link.." "..whisperItem.link.." "..whisperItem.link,names[2])
        and #host.s.session.reserves[names[2]]==0,"repeated links bypassed the reserve limit")
    host.e.SendChatMessage=function() error("No test announcements or real trades") end
    now=now+3
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
    now=now+6;peer.e.SlashCmdList.NAUSERAIDTOOLS("softres");pump()
    check(peer.s.testGroup and peer.s.session.id==activeID,"opening nrtsr did not rejoin the leader's active group test")
    check(peer.s.browser.scope:GetText():find("Fixture Dungeon",1,true) and peer.s.catalogueHostSID==activeID,"joined member could not see selected content and shared loot")
    -- Losing a delta must recover using the isolated sync path.
    local dropped=false
    host.s.session.lootEntries[2].seconds=280;host.s.session.revision=host.s.session.revision+1;host.s:Publish();host.s:FlushSync()
    pump(function(m) if m.p.action=="delta" and not dropped then dropped=true;return true end end)
    now=now+6;host.s:Send("head",{sid=activeID,sequence=host.s.streamSequence,generation=host.s.session.generation});pump()
    check(peer.s.session.lootEntries[2].seconds==280,"lost delta did not recover in test transport")
    assert(host.s:StartTest());pump()
    check(not host.s.session and not peer.s.session and not third.s.session,"group restart published before choosing content")
    assert(host.confirm({["Fixture Dungeon"]=true},3));pump()
    for _,c in pairs(clients) do
        check(c.s.session.limit==3 and c.s.session.selectedInstances["Fixture Dungeon"] and not c.s.session.selectedInstances["Fixture Raid"],"group test did not share the leader's content and reserve limit")
    end
    check(host.s.session.id~=activeID and peer.s.session.id==host.s.session.id and #host.s.session.history==0,"host restart did not reset all clients")
    check(peer.s.browser.scope:GetText()=="Content: Fixture Dungeon","reservation header did not update when the selected dungeon changed")
    host.a:LeaveTest();pump()
    for _,c in pairs(clients) do check(not c.s.test and not c.s.session and not c.a.demo and c.a.Encode(c.e.NauseSoftReserveDB)==c.saved,"host exit failed to clean up or preserve data") end
    -- Active real sessions refuse an incoming test.
    peer.a.state={id="real-council"}
    assert(host.s:StartTest());check(not host.s.session,"group test published before choosing content");assert(host.confirm());pump()
    check(not peer.s.test and peer.a.state.id=="real-council","incoming test replaced real session")
    peer.a.state=nil
    now=now+6;assert(peer.s:StartTest());pump();check(peer.s.testGroup,"late join failed")
    for _,c in pairs(clients) do c.leader=names[3] end
    for _,c in pairs(clients) do c.s.events:GetScript("OnEvent")(c.s.events,"GROUP_ROSTER_UPDATE") end;pump()
    for _,c in pairs(clients) do check(not c.s.test and not c.a.demo,"leadership change retained test") end
    for _,c in pairs(clients) do c.leader=names[1] end
    for _,c in pairs(clients) do c.a:RefreshRoster() end
    assert(host.s:StartTest());check(not host.s.session,"group test published before choosing content");assert(host.confirm());pump()
    -- Scripted presets must converge through the same isolated group transport.
    host.a:LeaveTest();pump()
    for _,scenario in ipairs({"tie","invalid","stacked","delivery","import"}) do
        assert(host.s:StartTest());host.s.testScenario=scenario
        assert(host.confirm({["Fixture Dungeon"]=true},3));pump()
        if scenario=="tie" or scenario=="invalid" or scenario=="stacked" then
            assert(host.s:Command("lock"));assert(host.s:QueuePugLoot(1));pump()
            check(peer.s.session.round and #peer.s.session.round.attempts==#host.s.session.round.attempts,"scripted results did not reach group members")
            if scenario=="invalid" then
                now=now+6;assert(host.s:ExpireRound());pump()
                check(peer.s.session.round.closed and #peer.s.session.round.winners==0,"group no-valid scenario did not close without a winner")
            else
                assert(host.s:Command("close"));pump()
                if scenario=="tie" then
                    check(#peer.s.session.round.winners==2,"group tie was not shared")
                    assert(host.s:Command("reroll"));pump();assert(host.s:Command("close"));pump()
                end
                assert(host.s:Command("record"));assert(host.a:AcceptConfirmation());pump()
                check(#peer.s.session.history==1 and peer.s.session.history[1].status=="pending","scripted group winner was not recorded")
            end
        elseif scenario=="delivery" then
            check(#peer.s.session.history==3 and peer.s.session.lootEntries[1].seconds==60,"group delivery preset did not share awards and timers")
            assert(host.s:TradeAward(host.s.session.history[1],false));pump()
            check(peer.s.session.history[1].status=="delivered","scripted group delivery did not synchronize")
        else
            check(host.s.importPreview and #host.s.importPreview.issues==0,"group import sample was not valid")
            assert(host.s:ApplyImport());pump()
            check(#peer.s.session.reserves[names[1]]==1 and not peer.s:LoadTestImportExample("valid"),"group import did not sync or a participant could load host examples")
        end
        host.a:LeaveTest();pump()
        for _,c in pairs(clients) do check(not c.s.test and c.a.Encode(c.e.NauseSoftReserveDB)==c.saved,"group scenario changed saved data or failed cleanup") end
    end
    assert(host.s:StartTest());assert(host.confirm());pump()
    for _,c in pairs(clients) do c.grouped=false;c.s.events:GetScript("OnEvent")(c.s.events,"GROUP_ROSTER_UPDATE") end;pump()
    for _,c in pairs(clients) do check(not c.s.test and not c.a.demo and c.a.Encode(c.e.NauseSoftReserveDB)==c.saved,"disband retained test or changed data") end
end
run("PARTY");run("RAID")
print("GROUP SOFTRES PASS: "..count.." checks; party/raid, leader start, participant join, reservations, native rolls, simulated delivery, loss recovery and cleanup")
