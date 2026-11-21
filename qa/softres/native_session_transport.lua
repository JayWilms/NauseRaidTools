local root=...
local make=assert(loadfile(root.."/qa/softres/improvements_client.lua"))(root,root)
local now,wire=100,{}
local refused=0
local clients={};local names={"Leader-Realm","Raider-Realm"}
for index,name in ipairs(names) do
    local a,e,s=make(name)
    local confirm=assert(loadfile(root.."/qa/softres/test_catalogue.lua"))(a,e)
    e.GetTime=function() return now end;e.GetServerTime=function() return 1800000000+math.floor(now) end
    e.GetBuildInfo=function() return "1.60.1","1","1",16001 end
    e.IsInRaid=function() return false end;e.IsInGroup=function() return true end
    e.GetNumGroupMembers=function() return 2 end
    function a:Name(unit) if unit=="player" then return name elseif unit=="party1" then return names[3-index] end end
    e.UnitIsGroupLeader=function(unit) return a:Name(unit)==names[1] end
    e.C_ChatInfo.SendAddonMessage=function(prefix,message,channel,target)
        if refused==0 then refused=refused+1;return 11 end -- Client lockdown: retry the same fragment.
        wire[#wire+1]={from=name,prefix=prefix,message=message,channel=channel,target=target};return 0
    end
    a.Send=a.WireSend
    if index==1 then
        local lib=e.LibStub("LibItemDB-1.0",true)
        lib.GetLink=function(self,id) return "["..self:GetName(id).."]" end -- Native provider's observed name-only result.
    end
    if index==2 then e.LibStub=nil;e.AtlasLoot=nil end
    a:RefreshRoster();a:BuildUI()
    clients[index]={a=a,e=e,s=s,confirm=function(...) return confirm(s,...) end,packets={}}
    local packet=a.Packet
    a.Packet=function(self,sender,p,...) clients[index].packets[#clients[index].packets+1]=p.kind..":"..tostring(p.action);return packet(self,sender,p,...) end
end
local host,member=clients[1],clients[2]
assert(host.s:StartTest());assert(host.confirm({["Fixture Dungeon"]=true}))
assert(host.s:ValidSnapshot(host.s:PublicState()),"host created an invalid snapshot from a provider's plain item name")
for _,entry in ipairs(host.s.session.lootEntries) do assert(host.a:EquipmentLink(entry.link),"name-only provider result was not turned into an item link") end
local validState=host.s:PublicState();local invalidState=host.a.Copy(validState);invalidState.lootEntries[1].link="[Tail Spike]"
assert(not host.s:ValidateOutgoingSnapshot(invalidState) and host.s.snapshotValidationError,"invalid host snapshot was not blocked with an explanation")
assert(host.s:ValidateOutgoingSnapshot(validState) and not host.s.snapshotValidationError,"valid host snapshot remained blocked")
for _,c in ipairs(clients) do c.e.InCombatLockdown=function() return true end end
assert(host.a:Send({kind="presenceProbe",check="blocked-during-combat",scope=false},nil,{priority=0}))
member.e.SlashCmdList.NAUSERAIDTOOLS("softres")
for step=1,1500 do
    now=now+.2
    for _,c in ipairs(clients) do c.s:CatalogueStep();c.s.syncTicker:GetScript("OnUpdate")(c.s.syncTicker,.2);c.a:PumpSender() end
    local batch=wire;wire={}
    for _,m in ipairs(batch) do for _,c in ipairs(clients) do
        if c.a.me~=m.from and (not m.target or c.a.me==m.target) then
            c.a:Receive(m.prefix,m.message,m.channel,m.from:gsub("-"," "))
        end
    end end
    if member.s.session and member.s.catalogueHostSID==host.s.session.id then break end
end
assert(member.s.session,"native transport did not deliver the session; host packets="..table.concat(host.packets,",").."; member packets="..table.concat(member.packets,",").."; host metrics="..host.a.Encode(host.a.networkMetrics).."; member metrics="..member.a.Encode(member.a.networkMetrics))
assert(member.s.catalogueHostSID==host.s.session.id,"native transport did not deliver the host catalogue")
assert(member.s.browser.scope:GetText()=="Content: Fixture Dungeon","native session omitted selected dungeon")
assert(member.s:PlayerText("Leader-Realm"):find("Leader Realm",1,true),"SoftRes player labels retained surname dashes")
assert(member.a:Resolve("Leader Realm")=="Leader-Realm" and member.s.session.owner=="Leader-Realm","display-name formatting changed routing/session keys")
assert(refused==1 and (host.a.networkMetrics.sendFailures or 0)+(member.a.networkMetrics.sendFailures or 0)>=1,"lockdown refusal was not exercised")
for _,c in ipairs(clients) do for _,kind in ipairs(c.packets) do assert(kind~="presenceProbe:nil","combat exception released unrelated council traffic") end end
assert(host.a:NetworkQueueStats()>=1,"unrelated council traffic did not remain paused during combat")
print("NATIVE SR TRANSPORT PASS: real encode, compression, fragmentation, sender pacing, receive, combat delivery, lockdown retry, council isolation, test discovery and catalogue; elapsed "..(now-100))
