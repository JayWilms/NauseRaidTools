local baseline,companion=...
local make=assert(loadfile(companion.."/qa/softres/improvements_client.lua"))(baseline,companion)
local count=0
local function check(ok,why) count=count+1;assert(ok,why) end
local function fixture()
    local a,e,s=make("Leader-Realm");local now=100
    e.GetTime=function() return now end;e.GetServerTime=function() return 1800000000+math.floor(now) end
    assert(s:Begin(1));s.session.locked=true
    assert(s:StartRound(s.session,279259,a.roster));assert(s:AcceptRoll(s.session,"Raider-Realm",99,1,100,a.roster))
    assert(s:CloseRound(s.session,a.roster));assert(s:RecordWinner(s.session,a.roster,e.GetServerTime()))
    local h=s.session.history[1];h.holder=a.me;h.guid="Item-delivery-1"
    local link="|cffa335ee|Hitem:279259::::::::|h[Fixture Staff]|h|r"
    local present=true;local readable=true;local slots={};local cursor=false;local partner="Raider"
    e.ItemLocation={CreateFromBagAndSlot=function(_,bag,slot) return {bag=bag,slot=slot} end}
    e.C_Container={GetContainerNumSlots=function(bag) if not readable then error("unreadable") end;return bag==0 and 1 or 0 end,
        GetContainerItemInfo=function() if present then return {hyperlink=link,stackCount=1,isLocked=false,quality=4} end end,
        PickupContainerItem=function() cursor=true end}
    e.C_Item={GetItemGUID=function() return present and h.guid or nil end,IsBound=function() return false end}
    e.TradeFrame=e.CreateFrame("Frame");e.TradeFrame:Show();e.UnitFullName=function() return partner,"Realm" end
    e.GetTradePlayerItemLink=function(slot) return slots[slot] end
    e.CursorHasItem=function() return cursor end;e.ClickTradeButton=function(slot) slots[slot]=link;cursor=false end
    e.ERR_TRADE_COMPLETE="Trade complete";e.ERR_TRADE_CANCELLED="Trade cancelled"
    a.roster["Raider-Realm"]="raid2";a.WinnerInTradeRange=function() return true end
    local function event(name,...) s.deliveryEvents._scripts.OnEvent(nil,name,...) end
    event("TRADE_SHOW")
    assert(s:TradeAward(h,true))
    local f={a=a,e=e,s=s,h=h,event=event,slots=slots}
    f.present=function(v) present=v end;f.readable=function(v) readable=v end;f.partner=function(v) partner=v end
    f.time=function(v) now=v end
    return f
end
local f=fixture()
f.event("TRADE_ACCEPT_UPDATE",1,1)
check(f.s.deliveryView.acceptedTrade~=nil,"native acceptance did not capture exact offer")
f.present(false);f.event("UI_INFO_MESSAGE",0,"Trade complete")
check(f.h.status=="delivered" and f.h.deliveryMethod=="automatic-trade","successful proven trade not recorded")
local revision=f.h.revision;f.event("UI_INFO_MESSAGE",0,"Trade complete")
check(f.h.revision==revision,"duplicate native success advanced award")
check(not f.a.state and #f.e.NauseRaidToolsDB.history==0,"SR receipt altered council state/history")
-- Bag disappearance alone is not success.
f=fixture();f.present(false);f.event("BAG_UPDATE_DELAYED")
check(f.h.status=="pending","bag disappearance alone marked delivered")
-- Native success without an accepted exact offer is not success.
f=fixture();f.present(false);f.event("UI_INFO_MESSAGE",0,"Trade complete")
check(f.h.status=="pending","success without offer acceptance marked delivered")
-- Native success while the GUID is still present remains pending, then
-- completes when delayed native bag data catches up.
f=fixture();f.event("TRADE_ACCEPT_UPDATE",1,1);f.event("UI_INFO_MESSAGE",0,"Trade complete")
check(f.h.status=="pending","success while GUID present marked delivered")
f.present(false);f.event("BAG_UPDATE_DELAYED")
check(f.h.status=="delivered","delayed GUID disappearance not verified")
-- Unreadable bags are unknown, not evidence of absence.
f=fixture();f.event("TRADE_ACCEPT_UPDATE",1,1);f.readable(false);f.present(false);f.event("UI_INFO_MESSAGE",0,"Trade complete")
check(f.h.status=="pending","unreadable inventory marked delivered")
f.time(112);f.s.deliveryEvents._scripts.OnUpdate(nil,.3)
check(f.h.status=="pending" and not next(f.s.deliveryView.pendingTradeReceipts),"unknown proof did not expire for review")
f=fixture();f.event("TRADE_ACCEPT_UPDATE",1,1);f.event("TRADE_REQUEST_CANCEL");f.present(false);f.event("UI_INFO_MESSAGE",0,"Trade complete")
check(f.h.status=="pending","cancelled trade marked delivered")
f=fixture();f.event("TRADE_ACCEPT_UPDATE",1,1);f.event("UI_ERROR_MESSAGE",0,"Trade cancelled");f.present(false);f.event("UI_INFO_MESSAGE",0,"Trade complete")
check(f.h.status=="pending","failed trade marked delivered")
f=fixture();f.partner("Other");f.event("TRADE_ACCEPT_UPDATE",1,1);f.present(false);f.event("UI_INFO_MESSAGE",0,"Trade complete")
check(f.h.status=="pending","wrong recipient marked delivered")
f=fixture();f.event("TRADE_ACCEPT_UPDATE",1,1);f.slots[1]=nil;f.event("TRADE_PLAYER_ITEM_CHANGED",1);f.present(false);f.event("UI_INFO_MESSAGE",0,"Trade complete")
check(f.h.status=="pending","removed offer marked delivered")
f=fixture();f.event("TRADE_ACCEPT_UPDATE",1,1);f.h.revision=f.h.revision+1;f.present(false);f.event("UI_INFO_MESSAGE",0,"Trade complete")
check(f.h.status=="pending","corrected award accepted old receipt")
f=fixture();f.event("TRADE_ACCEPT_UPDATE",1,1);f.event("TRADE_CLOSED");f.e.TradeFrame:Hide();f.present(false);f.event("UI_INFO_MESSAGE",0,"Trade complete")
check(f.h.status=="delivered","close-before-success ordering lost final proof")
f=fixture();f.event("TRADE_ACCEPT_UPDATE",1,1);f.event("TRADE_CLOSED");f.e.TradeFrame:Hide();f.time(112);f.present(false);f.event("UI_INFO_MESSAGE",0,"Trade complete")
check(f.h.status=="pending","expired acceptance marked delivered")
-- Host accepts only the recorded holder, GUID, recipient and award revision.
f=fixture();local r={sid=f.s.session.id,tracked=f.h.id,guid=f.h.guid,expectedWinner=f.h.winner,expectedRevision=f.h.revision,expectedAwardRevision=f.h.revision,token="fixture-token",completedAt=f.e.GetServerTime()}
check(not f.s:ReceiveDelivery("Raider-Realm",r),"nonholder forged delivery")
r.guid="Item-wrong-guid";check(not f.s:ReceiveDelivery(f.a.me,r),"wrong GUID receipt accepted")
r.guid=f.h.guid;r.expectedWinner="Other-Realm";check(not f.s:ReceiveDelivery(f.a.me,r),"wrong winner receipt accepted")
r.expectedWinner=f.h.winner;r.expectedRevision=99;check(not f.s:ReceiveDelivery(f.a.me,r),"stale receipt accepted")
r.expectedRevision=f.h.revision;assert(f.s:ReceiveDelivery(f.a.me,r));revision=f.h.revision
assert(f.s:ReceiveDelivery(f.a.me,r));check(f.h.revision==revision,"duplicate holder receipt not idempotent")
-- Inventory lookup reuses the index but validates a moved GUID and native
-- tradability afresh before every actual offer.
f=fixture();local s=f.s;s:InvalidateInventory();s:MyItemCopies(279259);local scans=s.inventoryScans
s:MyItemCopies(279259);check(s.inventoryScans==scans,"unchanged bag lookup rescanned")
s.inventoryEvents._scripts.OnEvent(nil,"BAG_UPDATE_DELAYED");s:MyItemCopies(279259)
check(s.inventoryScans==scans+1,"bag event did not invalidate cache")
local c=s:LootCollector();c.ReadTradeTimer=function() return "timed",3600 end
s:ScanInventoryLoot(c)
check(#s.session.lootEntries==1 and s.session.lootEntries[1].guid==f.h.guid,"shared inventory collector lost the exact copy")
f.a.ReadTradeTimer=function() return "unknown" end
check(not s:TradeAward(f.h,true),"unknown tradability accepted from cache")
print("DELIVERY PASS: "..count.." assertions; native success + exact GUID, cancellation/failure, stale evidence, delayed/unreadable bags, duplicate/auth guards and cache invalidation")
