local _, namespace = ...
local S = namespace.SoftRes or namespace
local A=S.base
local KIND="nrt-sr-experiment-6"
function S:DeliveryView()
    if not self.session then self.deliveryView=nil;return end
    local s=self.session
    if not self.deliveryView or self.deliveryView.sid~=s.id then
        self.deliveryView=setmetatable({sid=s.id,tradeOfferSlots={},tradeShown=false,demo=false,
            TrackedByID=function(c,id) return c.entries[id] end,
            TrackedByGUID=function(c,guid) return c.guids[guid] end,
            ItemByID=function(c,id) return c.items[id] end,
            Act=function(_,op,receipt)
                if op=="tradeReceipt" then
                    if S:IsHost() then return S:ReceiveDelivery(A.me,receipt) end
                    return S:Send("delivery-receipt",receipt,A.leader)
                end
            end},{__index=A})
    end
    local c=self.deliveryView;c.me=A.me;c.roster=A.roster;c.entries={};c.guids={};c.items={}
    for _,h in ipairs(s.history) do if h.id and h.guid and h.holder then
        local e={id=h.id,item=h.id,guid=h.guid,holder=h.holder,delivery=h.status=="delivered" and "delivered" or "pending",
            deliveryRevision=h.revision,deliveryToken=h.deliveryToken,deliveredBy=h.deliveredBy}
        c.entries[h.id]=e;c.guids[h.guid]=e;c.items[h.id]={id=h.id,status=h.status=="cancelled" and "cancelled" or "awarded",winner=h.winner,awardRevision=h.revision}
    end end
    c.state={id=s.id};return c
end
function S:ReceiveDelivery(sender,r)
    if not self:IsHost() or not A.roster[sender] or type(r)~="table" or r.sid~=self.session.id then return false end
    local h=self:AwardByID(r.tracked)
    if not h or h.holder~=sender or h.guid~=r.guid or h.winner~=r.expectedWinner then return false end
    if h.status=="delivered" and h.deliveryToken==r.token then return true end
    if h.status~="pending" or h.revision~=r.expectedRevision or h.revision~=r.expectedAwardRevision then return false end
    if type(r.token)~="string" or #r.token<1 or #r.token>120 or not self.Integer(r.completedAt,A.Client:ServerTime()-120,A.Client:ServerTime()+5) then return false end
    if #h.audit>=30 then return false end
    h.status="delivered";h.deliveryMethod="automatic-trade";h.deliveryToken=r.token;h.deliveredBy=sender
    h.audit[#h.audit+1]={action="native-trade-and-guid-report",by=sender,time=r.completedAt,token=r.token}
    h.revision=h.revision+1;self.session.revision=self.session.revision+1;self:Publish();return true
end
local trade=S.TradeAward
function S:TradeAward(h,place)
    local slot
    if place and type(GetTradePlayerItemLink)=="function" then
        for i=1,6 do local ok,link=pcall(GetTradePlayerItemLink,i);if ok and not link then slot=i;break end end
    end
    local ok,why=trade(self,h,place)
    if ok and place and slot and h and h.id then
        local c=self:DeliveryView()
        if c then
            A.RememberTradeOffer(c,{sid=self.session.id,guid=h.guid,tracked=h.id,target=h.winner,link="item:"..h.item,
                awardRevision=h.revision,deliveryRevision=h.revision},slot)
        end
    end
    return ok,why
end
local packet=A.Packet
function A:Packet(sender,p)
    if type(p)=="table" and p.kind==KIND and p.protocol==self.protocol and self.roster[sender] and p.action=="delivery-receipt" then
        if S:IsHost() then
            local ok=S:ReceiveDelivery(sender,p.data)
            if ok then S:Send("delivery-result",{sid=S.session.id,token=p.data.token,guid=p.data.guid},sender) end
        end
        return
    elseif type(p)=="table" and p.kind==KIND and p.protocol==self.protocol and p.action=="delivery-result" and sender==self.leader then
        local d=p.data;local c=S:DeliveryView()
        if c and type(d)=="table" and d.sid==S.session.id and type(d.token)=="string" and type(d.guid)=="string" and c.pendingTradeReceipts then
            c.pendingTradeReceipts[d.token..":"..d.guid]=nil
        end
        return
    end
    return packet(self,sender,p)
end
local frame=CreateFrame("Frame");S.deliveryEvents=frame
for _,event in ipairs({"TRADE_SHOW","TRADE_ACCEPT_UPDATE","TRADE_PLAYER_ITEM_CHANGED","TRADE_TARGET_ITEM_CHANGED","TRADE_MONEY_CHANGED","TRADE_REQUEST_CANCEL","TRADE_CLOSED","UI_INFO_MESSAGE","UI_ERROR_MESSAGE","BAG_UPDATE_DELAYED"}) do pcall(frame.RegisterEvent,frame,event) end
frame:SetScript("OnEvent",function(_,event,...)
    local c=S:DeliveryView();if not c then return end
    if event=="TRADE_SHOW" then c.tradeShown=false end
    if event=="TRADE_PLAYER_ITEM_CHANGED" and A:TradePartner() then
        local slot=tonumber((...))
        if slot then c.tradeOfferSlots[slot]=nil else c.tradeOfferSlots={} end
    end
    -- Execute SLT's existing acceptance/success/GUID-proof state machine against
    -- isolated SR records, never a manufactured council session on the addon.
    A.TradeCompletionEvent(c,event,...)
    if event=="TRADE_SHOW" then c.tradeShown=true elseif event=="TRADE_CLOSED" then c.tradeShown=false end
end)
local elapsed=0
frame:SetScript("OnUpdate",function(_,dt)
    elapsed=elapsed+dt;if elapsed<.25 then return end;elapsed=0
    local c=S:DeliveryView();if c then A.TickTradeCompletions(c) end
end)
