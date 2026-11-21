local root=...
local make=assert(loadfile(root.."/qa/softres/improvements_client.lua"))(root,root)
local count=0
local function check(value,message) count=count+1;assert(value,message) end
local function client()
    local a,e,s=make("Leader-Realm");local confirm=assert(loadfile(root.."/qa/softres/test_catalogue.lua"))(a,e)
    local now=100
    e.IsInRaid=function() return false end;e.IsInGroup=function() return false end
    function a:Name(unit) if unit=="player" then return "Leader-Realm" end end
    e.GetTime=function() return now end;e.GetServerTime=function() return 1800000000+math.floor(now) end
    e.RandomRoll=function() error("Scripted solo scenario used native RandomRoll") end
    e.SendChatMessage=function() error("Scripted scenario sent real chat") end
    e.C_Container={GetContainerNumSlots=function() error("Scripted scenario scanned real bags") end}
    e.NauseSoftReserveDB={schema=1,generation=12,session={id="saved-live"},history={{untouched=true}}}
    local saved=a.Encode(e.NauseSoftReserveDB);a:BuildUI()
    local function start(key,limit)
        assert(s:StartTest());s.testScenario=key
        return confirm(s,{["Fixture Dungeon"]=true},limit or 2)
    end
    local function finish()
        assert(s:StopTest());check(a.Encode(e.NauseSoftReserveDB)==saved and #a.sent==0,"scenario changed real data or sent solo traffic")
        check(s.setup:GetHeight()==575 and not s.setup.testScenario:IsShown() and not s.testScenario,"scenario controls remained in normal setup")
    end
    return a,e,s,start,finish,function(seconds) now=now+seconds end
end
local a,e,s,start,finish,advance=client()
assert(start("tie"));assert(s:Command("lock"));assert(s:QueuePugLoot(1))
check(#s.session.round.attempts==2 and s.session.round.attempts[1].value==s.session.round.attempts[2].value,"tie preset did not produce equal valid rolls")
assert(s:Command("close"));check(#s.session.round.winners==2,"tie scenario did not require a reroll")
local tiedNames=a.Copy(s.session.round.winners)
local tieMessages={};local originalAnnounce=s.Announce
s.Announce=function(self,message) tieMessages[#tieMessages+1]=message;return originalAnnounce(self,message) end
s:AnnounceTiedPlayers(s.session.round,false)
assert(s:Command("reroll"))
check(tieMessages[1]:find("Tied players (SR 85): ",1,true) and tieMessages[2]:find("Reroll players: ",1,true),"tie and reroll announcements omitted their player lists")
for _,name in ipairs(tiedNames) do
    check(tieMessages[1]:find(name,1,true) and tieMessages[2]:find(name,1,true),"tie announcement omitted an eligible tied player")
end
s.Announce=originalAnnounce
assert(s:Command("close"))
check(#s.session.round.winners==1,"scripted tie-break failed to produce a winner")
assert(s:Command("record"));check(#s.session.history==0 and a.confirmationContext,"tie preset bypassed award confirmation")
assert(a:AcceptConfirmation());finish()

assert(start("invalid"));assert(s:Command("lock"));assert(s:QueuePugLoot(1))
check(s.session.round.duration==5 and #s.session.round.attempts==2,"no-valid preset did not set a short timer and logged attempts")
for _,row in ipairs(s.session.round.attempts) do check(not row.valid,"no-valid preset contained an eligible roll") end
local closedItem=s:LootEntry(s.session.round.lootEntry).link
local expiryMessage
local announce=s.Announce
s.Announce=function(self,message) expiryMessage=message;return announce(self,message) end
advance(6);assert(s:ExpireRound())
check(expiryMessage and expiryMessage:find("Rolling closed for "..closedItem,1,true),"expiry announcement used an ID instead of the collected item link")
s.Announce=announce
check(s.session.round.closed and #s.session.round.winners==0 and not s.leaderRollUI.primary:IsEnabled(),"expiry offered an award without a winner")
finish()

assert(s:StartTest());s.testScenario="stacked";s.setupSelection={["Fixture Dungeon"]=true};s.setup.limit:SetText("1")
check(not s:ConfirmPugSetup() and s.testSetup and not s.session,"stacked scenario accepted one reserve or left a partial session")
assert(s:StopTest())
assert(start("stacked",3));assert(s:Command("lock"));assert(s:QueuePugLoot(1))
local ranked=s:RankedRolls(s.session,a.roster)
check(ranked[1].player==a.me and ranked[1].tier=="SR" and ranked[1].value==73,"stacked SR did not beat a higher MS roll")
local invalid,higherMS=false,false
for _,row in ipairs(ranked) do invalid=invalid or (not row.valid and row.value==100);higherMS=higherMS or (row.valid and row.tier=="MS" and row.value==99) end
check(invalid and higherMS,"stacked preset omitted the extra attempt or higher MS result")
assert(s:Command("close"));assert(s:Command("record"));assert(a:AcceptConfirmation())
check(#s.session.reserves[a.me]==2,"stacked scenario consumed more than one reserve")
finish()

assert(start("delivery"))
check(#s.session.history==3 and not s.session.round and s.awardUI:IsShown(),"delivery preset did not open three pending awards")
check(s.session.lootEntries[1].link==s.session.lootEntries[2].link and s.session.lootEntries[1].guid~=s.session.lootEntries[2].guid,"delivery preset lost duplicate-copy identity")
check(s.session.lootEntries[1].seconds==60 and s.session.lootEntries[2].seconds==240,"delivery preset omitted short timers")
for _,award in ipairs(s.session.history) do check(award.status=="pending" and award.guid and award.holder==a.me,"delivery preset made an incomplete award") end
assert(s:TradeAward(s.session.history[1],false));check(s.session.history[1].status=="delivered","delivery preset did not use simulated delivery")
finish()

assert(start("import"))
check(s.importUI:IsShown() and s.importPreview and #s.importPreview.issues==0 and #s.session.reserves[a.me]==2,"valid sample was not previewed or was automatically applied")
assert(s:LoadTestImportExample("unknown"));check(#s.importPreview.issues>0 and not s.importUI.apply:IsEnabled(),"unknown-player sample was not blocked")
assert(s:LoadTestImportExample("outside"));check(#s.importPreview.issues>0 and not s.importUI.apply:IsEnabled(),"out-of-scope sample was not blocked in preview")
check(not s:ApplyImport() and #s.session.reserves[a.me]==2,"blocked import changed reservations")
assert(s:LoadTestImportExample("valid"));assert(s:ApplyImport());check(#s.session.reserves[a.me]==1,"valid import did not replace the selected player's picks")
assert(s:Command("lock"));assert(s:LoadTestImportExample("valid"))
check(not s.importUI.apply:IsEnabled() and not s:ApplyImport(),"locked test accepted an import")
finish()
check(not s:LoadTestImportExample("valid"),"test examples were available outside testing")
print("SOFTRES SCENARIOS PASS: "..count.." checks; ties, timer expiry, invalid rolls, stacked SR, duplicate pending awards and real import codec/validation")
