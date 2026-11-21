local root=...
local make=assert(loadfile(root.."/qa/softres/improvements_client.lua"))(root,root)
local count=0;local function check(value,message) count=count+1;assert(value,message) end
local host,he,s=make("Leader-Realm");local peer,pe,member=make("Raider-Realm")
local now,queue=100,{}
local lib={}
function lib:IsReady() return true end
function lib:Search() local ids={};for id=1,30 do ids[#ids+1]=id end;return ids end
function lib:GetName(id) return "Host Item "..id end
function lib:GetLink(id) return "|cffa335ee|Hitem:"..id.."::::::::|h[Host Item "..id.."]|h|r" end
function lib:GetSources(id) return {{instance=id<=25 and "Selected Dungeon" or "Other Dungeon",boss="Host Boss"}} end
he.LibStub=function() return lib end;pe.LibStub=nil;pe.AtlasLoot=nil
pe.C_Item={GetItemInfo=function() return nil end}
for _,c in ipairs({{host,he,s},{peer,pe,member}}) do
    local a,e,sr=table.unpack(c)
    e.GetTime=function() return now end;e.GetServerTime=function() return 1800000000+now end
    a.roster={[host.me]="raid1",[peer.me]="raid2"};a.leader=host.me;a.gameLeader=host.me
    a.Send=function(_,packet,target) packet.protocol=a.protocol;queue[#queue+1]={from=a.me,p=a.Copy(packet),target=target};return true end
    a:BuildUI()
end
local function pump()
    for loops=1,100 do
        s:CatalogueStep()
        if s.syncDue then s:FlushSync() end
        if #queue==0 and not s.catalogueJobs and #(s.hostCatalogueQueue or {})==0 then return end
        local batch=queue;queue={}
        -- Deliver chunks out of order to exercise complete-list assembly.
        for i=#batch,1,-1 do
            local m=batch[i]
            if m.from==host.me then peer:Packet(m.from,m.p) else host:Packet(m.from,m.p) end
        end
    end
    error("catalogue transport did not settle")
end
assert(s:Begin(2));s.session.selectedInstances={["Selected Dungeon"]=true};assert(s:StartCatalogue());s:Publish();pump()
check(member.session and member.catalogueHostSID==s.session.id and peer:ItemLibrary()==nil,"member without AtlasLoot failed to receive host catalogue")
check(#member:BrowserResults()==25 and member.catalogue[26]==nil,"host shared unselected instance items or lost a catalogue batch")
check(member.catalogue[1].name=="Host Item 1" and member.catalogue[1].sources[1].boss=="Host Boss","shared catalogue lost item names or bosses")
check(member:ScopeAllows(member.session,1) and not member:ScopeAllows(member.session,26),"shared sources did not enforce selected content")
member:ShowBrowser();check(member.browser.rows[1].name:GetText():find("Host Item",1,true),"member browser did not show host-provided names")
assert(member:Request("reserve",{1,1}));pump()
check(#s.session.reserves[peer.me]==2 and not member.pendingRequest,"member without a loot database could not submit reserves")
now=now+6;assert(member:StartCatalogue())
local pending=member.hostCatalogueRequest
local function packet(sender,data)
    peer:Packet(sender,{kind="nrt-sr-experiment-6",protocol=peer.protocol,action="catalogue-batch",data=data})
end
local valid={sid=s.session.id,generation=s.session.generation,request=pending.serial,part=1,parts=1,entries={{id=1,name="Forged",sources={{instance="Selected Dungeon",boss="Boss"}}}}}
packet(peer.me,valid)
check(member.hostCatalogueRequest.received==0,"nonhost replaced shared catalogue")
local stale=host.Copy(valid);stale.sid="old-session";packet(host.me,stale)
check(member.hostCatalogueRequest.received==0,"stale-session catalogue was accepted")
local invalid=host.Copy(valid);invalid.entries[1].sources[1].instance="Other Dungeon";packet(host.me,invalid)
check(member.hostCatalogueRequest.received==0,"out-of-scope catalogue row was accepted")
pump();check(member.catalogueHostSID==s.session.id and #member:BrowserResults()==25 and member.catalogue[1].name=="Host Item 1","refresh did not restore the host's complete catalogue")
-- Reproduce opening the reservation browser before any session was received.
member.session=nil;member.catalogue=nil;member.catalogueHostSID=nil;now=now+6
peer.RefreshRoster=function() peer.roster={[host.me]="raid1",[peer.me]="raid2"};peer.leader=host.me end
pe.SlashCmdList.NAUSERAIDTOOLS("softres")
check(member.sessionDiscoveryStatus and not member.test,"opening an empty browser did not request the leader's session")
pump()
check(member.session and member.catalogueHostSID==s.session.id and member.browser.scope:GetText()=="Content: Selected Dungeon",
    "opening nrtsr failed to discover the live session, content and host loot")
print("HOST CATALOGUE PASS: "..count.." checks; no member database, multi-batch live sync, selected content, names/bosses, submissions, refresh and sender/session validation")
