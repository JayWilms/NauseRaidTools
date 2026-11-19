local root=...
local make=assert(loadfile(root.."/qa/softres/improvements_client.lua"))(root,root)
local a,e,s=make("Leader-Realm");local confirm=assert(loadfile(root.."/qa/softres/test_catalogue.lua"))(a,e)
local count=0;local function check(value,message) count=count+1;assert(value,message) end
e.IsInRaid=function() return false end;e.IsInGroup=function() return false end
function a:Name(unit) if unit=="player" then return "Leader-Realm" end end
e.NauseSoftReserveDB={schema=1,history={{untouched=true}},session={id="saved-session"}}
local saved=a.Encode(e.NauseSoftReserveDB)
a:BuildUI();assert(s:StartTest());s.testScenario="delivery";assert(confirm(s))
for i=4,10 do assert(s:QueuePugLoot(i));assert(s:CloseRound(s.session,a.roster));assert(s:RecordWinner(s.session,a.roster,a.Client:ServerTime())) end
assert(s:SelectAwardFilter("pending"));s:ShowAwardQueue()
local f=s.awardUI
check(#s:AwardListRows("pending")==10 and f.rows[1].award==s.session.history[10].id,"pending awards were not listed newest first")
check(f.rows[1].item:GetText()~="" and f.rows[1].winner:GetText()~="" and f.rows[1].status:GetText()=="Awaiting delivery","award columns omitted item, winner or status")
assert(s:SelectAwardFilter("delivered"));check(f.empty:IsShown() and not f.rows[1]:IsShown(),"empty delivered filter retained stale rows")
assert(s:SelectAwardFilter("pending"))
f.scroll:SetVerticalScroll(100000);f.scroll:GetScript("OnVerticalScroll")(f.scroll,100000)
check(s.awardScrollOffset==f.content:GetHeight()-f.scroll:GetHeight(),"award scrolling did not clamp to the end")
local oldest=s.session.history[1];local row
for _,candidate in ipairs(f.rows) do if candidate.award==oldest.id then row=candidate;break end end
check(row~=nil,"oldest award was unreachable by scrolling")
row:GetScript("OnClick")()
check(s.selectedAward==oldest.id and f.detailName:GetText()==s:AwardItemText(oldest) and f.primary:IsEnabled(),"selected award lost its item or relevant trade action")
e.InCombatLockdown=function() return true end;s:RenderAwardQueue()
check(not f.primary:IsEnabled(),"trade action remained enabled during combat")
e.InCombatLockdown=function() return false end;s:RenderAwardQueue()
f.confirmDelivered:GetScript("OnClick")()
check(oldest.status=="pending" and a.confirmationContext,"manual delivery skipped confirmation")
assert(a:AcceptConfirmation())
check(oldest.status=="delivered" and #s:AwardListRows("pending")==9 and not f.primary:IsEnabled() and not f.confirmDelivered:IsShown(),"completed award kept pending delivery controls")
assert(s:ShowAwardQueue(oldest.id))
check(s.awardFilter=="delivered" and f.rows[1].award==oldest.id,"opening an exact delivered award selected the wrong view")
assert(s:SelectAwardFilter("pending"));f.rows[1]:GetScript("OnClick")()
f.correctionToggle:GetScript("OnClick")()
check(f:GetHeight()==750 and f.target:IsShown(),"correction controls did not expand into available space")
f.reason:SetText("Old reason");f.rows[2]:GetScript("OnClick")()
check(f:GetHeight()==650 and not f.target:IsShown() and f.reason:GetText()=="","switching awards retained correction state")
assert(s:StopTest())

-- Fill the supported log limit; every entry must be reachable with a small row pool.
assert(s:StartTest());assert(confirm(s));assert(s:Command("lock"));assert(s:QueuePugLoot(1))
for i=1,20 do a.roster[string.format("Extra%02d-Test",i)]=true end
for name in pairs(a.roster) do for i=1,20 do s:AcceptRoll(s.session,name,i,1,100,a.roster) end end
s:RenderLeaderRolls();local rolls=s.leaderRollUI
check(#s.session.round.attempts==800 and #rolls.rows==11,"roll list did not retain the full log with a bounded row pool")
rolls.scroll:SetVerticalScroll(100000);rolls.scroll:GetScript("OnVerticalScroll")(rolls.scroll,100000)
check(s.rollScrollOffset==rolls.content:GetHeight()-rolls.scroll:GetHeight(),"roll scrolling did not clamp to the end")
check(rolls.rows[1][5]:GetText():find("Invalid",1,true),"invalid attempts at the end of the log were unreachable")
assert(s:Command("close"))
check(s.rollScrollOffset==0 and rolls.status:GetText()~="","closing the round did not return to the leading results")
assert(s:Command("cancel"));assert(s:QueuePugLoot(1))
check(s.rollScrollOffset==0 and rolls.scroll:GetVerticalScroll()==0,"a new round inherited the old scroll position")
assert(s:StopTest());check(a.Encode(e.NauseSoftReserveDB)==saved,"scrolling/award practice changed saved data")
print("AWARD/ROLL LISTS PASS: "..count.." checks; pending/delivered filters, exact selection, delivery controls, corrections, scrolling and all 800 roll attempts")
