local _, namespace = ...
local S = namespace.SoftRes or namespace
local A=S.base
local record=S.RecordWinner
function S:RecordWinner(session,roster,time)
    if #session.history>=500 then return false,"Session award limit reached. Preserve history before starting a new run." end
    local frozen=A.Copy(session.round)
    local ok,why=record(self,session,roster,time);if not ok then return false,why end
    session.awardSerial=(session.awardSerial or 0)+1
    local h=session.history[#session.history]
    h.id=session.id..":award:"..session.awardSerial;h.revision=1;h.status="pending";h.consumed=h.tier=="SR"
    h.candidateTiers=A.Copy(frozen.playerTiers);h.rollLog=A.Copy(frozen.attempts);h.candidates=frozen.rolls;h.passed=frozen.passed;h.eligible=frozen.eligible;h.audit={}
    return true
end
function S:AwardByID(id)
    for _,h in ipairs(self.session and self.session.history or {}) do if h.id==id then return h end end
end
local function reserveCount(session,name,id)
    local n=0;for _,v in ipairs(session.reserves[name] or {}) do if v==id then n=n+1 end end;return n
end
function S:AmendAward(id,revision,target,reason)
    if not self:IsHost() then return false,"Only the hosting leader can amend awards." end
    local h=self:AwardByID(id);local s=self.session
    if not h or h.revision~=revision or h.status~="pending" then return false,"Award changed or is no longer pending. Reopen it." end
    if type(reason)~="string" or #reason<1 or #reason>160 then return false,"Enter a reason (1–160 bytes)." end
    if target then
        if (h.candidateTiers and h.candidateTiers[target]~=h.tier) or target==h.winner or not A.roster[target] or not h.candidates[target] or h.passed[target] then return false,"Choose a different current raid member with a valid recorded roll in this round." end
        if h.tier=="SR" and (not h.eligible[target] or reserveCount(s,target,h.item)<1) then return false,"Corrected winner has no remaining SR for this item." end
    end
    if h.consumed and #(s.reserves[h.winner] or {})>=s.limit then return false,"Restoring the original winner's SR would exceed the current reservation limit." end
    if #h.audit>=30 then return false,"Award audit limit reached." end
    local old=h.winner
    if h.consumed then s.reserves[old]=s.reserves[old] or {};table.insert(s.reserves[old],h.item);h.consumed=false end
    if target then
        if h.tier=="SR" then for i,v in ipairs(s.reserves[target]) do if v==h.item then table.remove(s.reserves[target],i);h.consumed=true;break end end end
        h.winner=target
        local best=0;for _,v in ipairs(h.candidates[target]) do best=math.max(best,v) end;h.roll=best
    else h.status="cancelled" end
    h.audit[#h.audit+1]={action=target and "correct" or "cancel",from=old,to=target,reason=reason,by=A.me,time=A.Client:ServerTime()}
    h.holder=nil;h.guid=nil;h.revision=h.revision+1;s.revision=s.revision+1;self:Publish();return true
end
function S:BindAward(sender,id,revision,guid)
    if not self:IsHost() or not A.roster[sender] then return false,"Not authorised." end
    local h=self:AwardByID(id)
    if not h or h.status~="pending" or h.revision~=revision or h.holder then return false,"Award changed or already has a holder." end
    if type(guid)~="string" or #guid<1 or #guid>150 or guid:find("[%c|]") then return false,"Invalid item-copy GUID." end
    for _,other in ipairs(self.session.history) do if other.status~="cancelled" and other.holder==sender and other.guid==guid then return false,"This item copy is already assigned to another award." end end
    h.holder=sender;h.guid=guid;h.revision=h.revision+1;self.session.revision=self.session.revision+1
    h.audit[#h.audit+1]={action="holder-report",by=sender,time=A.Client:ServerTime()}
    self:Publish();return true
end
function S:ConfirmDelivery(id,revision)
    if not self:IsHost() then return false,"Only the leader can confirm delivery." end
    local h=self:AwardByID(id)
    if not h or h.status~="pending" or h.revision~=revision or not h.holder or not h.guid then return false,"Select a pending award with an identified holder and item copy." end
    h.status="delivered";h.revision=h.revision+1;self.session.revision=self.session.revision+1
    h.audit[#h.audit+1]={action="manual-delivery-confirmation",by=A.me,time=A.Client:ServerTime()};self:Publish();return true
end
function S:MyItemCopies(item)
    local out={}
    if not C_Container or not C_Item or not ItemLocation then return out end
    for bag=0,math.min(NUM_BAG_SLOTS or 4,5) do
        local ok,n=pcall(C_Container.GetContainerNumSlots,bag)
        if ok and self.Integer(n,0,100) then for slot=1,n do
            local good,info=pcall(C_Container.GetContainerItemInfo,bag,slot)
            if good and type(info)=="table" and info.stackCount==1 and not info.isLocked and type(info.hyperlink)=="string" and tonumber(info.hyperlink:match("item:(%d+)"))==item then
                local found,guid=pcall(function() return C_Item.GetItemGUID(ItemLocation:CreateFromBagAndSlot(bag,slot)) end)
                if found and type(guid)=="string" then out[#out+1]={guid=guid,link=info.hyperlink,bag=bag,slot=slot} end
            end
        end end
    end
    return out
end
function S:SendCopyClaim(id,revision,guid,sid)
    local h=self:AwardByID(id)
    if not h or not self.session or self.session.id~=sid or h.revision~=revision then return false,"Award changed. Reopen the copy selection." end
    local found=false;for _,copy in ipairs(self:MyItemCopies(h.item)) do if copy.guid==guid then found=true end end
    if not found then return false,"This exact item copy is no longer in your carried bags." end
    if self:IsHost() then return self:BindAward(A.me,id,revision,guid) end
    return self:Send("award-copy",{sid=sid,id=id,revision=revision,guid=guid},A.leader)
end
function S:ClaimCopy(h)
    local copies=self:MyItemCopies(h.item)
    if #copies==0 then return false,"No unlocked single-item matching copy was found in your carried bags." end
    if #copies>1 then return self:ShowCopyPicker(h,copies) end
    return self:SendCopyClaim(h.id,h.revision,copies[1].guid,self.session.id)
end

local packet=A.Packet
function A:Packet(sender,p)
    if type(p)=="table" and p.kind=="nrt-sr-experiment-6" and p.protocol==self.protocol and p.action=="award-copy" then
        if S:IsHost() and self.roster[sender] and type(p.data)=="table" and p.data.sid==S.session.id then
            local ok,why=S:BindAward(sender,p.data.id,p.data.revision,p.data.guid)
            if not ok then S:Send("notice",why,sender) end
        end
        return
    end
    return packet(self,sender,p)
end
function S:TradeAward(h,place)
    if not h or h.status~="pending" or h.holder~=A.me or not h.guid then return false,"Only the reported holder can trade this pending item copy." end
    if A.Client:Combat() then return false,"Finish combat before trading." end
    local link="item:"..h.item
    -- Reuse the baseline's exact GUID lookup and its bag/lock/stack/trade-time checks.
    local bag,slot,why=A:FindTradeItem({guid=h.guid,link=link})
    if not bag then return false,why end
    if not place then
        if not A:WinnerInTradeRange(h.winner) then return false,"Winner must be online and in trade range." end
        local ok=A.Client:Invoke(InitiateTrade,A.roster[h.winner]);return ok,ok and "Trade opened. Use Offer exact copy after checking the partner." or "Trade API unavailable."
    end
    if A:TradePartner()~=h.winner then return false,"The trade partner is not this award's winner." end
    if type(GetTradePlayerItemLink)~="function" or type(CursorHasItem)~="function" or type(ClickTradeButton)~="function" then return false,"Trade placement APIs unavailable." end
    if CursorHasItem() then return false,"Clear your cursor first." end
    local free
    for i=1,6 do if not GetTradePlayerItemLink(i) then free=i;break end end
    if not free then return false,"The trade window has no free item slot." end
    local ok=A.Client:Invoke(C_Container and C_Container.PickupContainerItem,bag,slot)
    if not ok or not CursorHasItem() then return false,"Could not pick up the exact item copy." end
    ok=A.Client:Invoke(ClickTradeButton,free)
    return ok,ok and "Review the offer. Both players must accept manually; delivery is not yet confirmed." or "Could not offer item; check your cursor."
end
function S:ReviewPugAward()
    if not self:IsHost() then return false,"Only the hosting leader can award." end
    local r=self.session.round
    if not r or not r.closed or #r.winners~=1 then return false,"Close rolling and resolve ties before confirming an award." end
    local entry=r.lootEntry and self.LootEntry and self:LootEntry(r.lootEntry)
    local link=entry and entry.link
    if not link and A.ItemLibrary then
        local library=A:ItemLibrary()
        if library and type(library.GetLink)=="function" then
            local ok,value=pcall(library.GetLink,library,r.item)
            if ok and type(value)=="string" then link=value end
        end
    end
    local item=self:ReservationItemText(r.item,link)
    local popup=S:ShowConfirmation("NAUSE_SR_CONFIRM_AWARD",self:PlayerText(r.winners[1]),item)
    if popup then popup.data={sid=self.session.id,key=self:RollKey(),winner=r.winners[1],roll=r.best,itemText=item} end
    return popup~=nil
end
StaticPopupDialogs.NAUSE_SR_CONFIRM_AWARD={text="Confirm %s as winner of:\n%s\n\nThis records the award and consumes one SR for an SR win. Delivery will be tracked separately.",button1="Confirm award",button2="Cancel",timeout=0,whileDead=true,hideOnEscape=true,
 OnAccept=function(dialog)
    local d=dialog.data;local r=S.session and S.session.round
    if not d or not S:IsHost() or S.session.id~=d.sid or S:RollKey()~=d.key or not r or not r.closed or #r.winners~=1 or r.winners[1]~=d.winner or r.best~=d.roll then S:Print("Award changed. Review it again.");return end
    -- Capture this round before recording can advance to the next queued item.
    local message=(d.itemText or S:ReservationItemText(r.item)).." awarded to "..S:DisplayPlayerName(r.winners[1]).." ("..r.tier..", "..r.best.."). Delivery pending."
    local ok,why=S:RecordWinner(S.session,A.roster,A.Client:ServerTime())
    if ok then S:Publish();S:Announce(message) else S:Print(why) end
 end}
local command=S.Command
function S:Command(text)
    if text=="record" then return self:ReviewPugAward() end
    if text=="end" and self.session then for _,h in ipairs(self.session.history) do if h.id and h.status=="pending" then return false,"Resolve pending awards before ending this run." end end end
    return command(self,text)
end
