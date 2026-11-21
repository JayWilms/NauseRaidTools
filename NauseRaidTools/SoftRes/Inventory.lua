local _, namespace = ...
local S = namespace.SoftRes or namespace
local A=S.base
local function read(fn,...)
    if type(fn)~="function" then return nil,false end
    local ok,value=pcall(fn,...)
    if not ok or (issecretvalue and issecretvalue(value)) then return nil,false end
    return value,true
end
function S:InvalidateInventory() self.inventory=nil end
function S:Inventory(force)
    local now=A.Client:Uptime()
    if not force and self.inventory and now-self.inventory.at<2 then return self.inventory end
    local cache={at=now,byGUID={},items={},complete=true,scans=((self.inventoryScans or 0)+1)};self.inventoryScans=cache.scans
    if not C_Container or not C_Item or not ItemLocation then cache.complete=false;self.inventory=cache;return cache end
    for bag=0,math.min(NUM_BAG_SLOTS or 4,5) do
        local n,ok=read(C_Container.GetContainerNumSlots,bag)
        if not ok or not self.Integer(n,0,100) then cache.complete=false
        else for slot=1,n do
            local info,known=read(C_Container.GetContainerItemInfo,bag,slot)
            if not known or (info~=nil and type(info)~="table") then cache.complete=false
            elseif info then
                local loc,located=read(function() return ItemLocation:CreateFromBagAndSlot(bag,slot) end)
                local guid,readable;if located then guid,readable=read(C_Item.GetItemGUID,loc) end
                local link,linkKnown=read(function() return info.hyperlink end)
                local count,countKnown=read(function() return info.stackCount end)
                local locked,lockKnown=read(function() return info.isLocked end)
                local quality,qualityKnown=read(function() return info.quality end)
                if not readable or type(guid)~="string" or guid=="" or not linkKnown or type(link)~="string" or not countKnown or not lockKnown or not qualityKnown then cache.complete=false
                else
                    local e={guid=guid,link=link,bag=bag,slot=slot,count=count,locked=locked,quality=quality,item=tonumber(link:match("item:(%d+)"))}
                    if cache.byGUID[guid] then cache.complete=false else cache.byGUID[guid]=e;cache.items[#cache.items+1]=e end
                end
            end
        end end
    end
    self.inventory=cache;return cache
end
function S:MyItemCopies(item)
    local out={}
    for _,e in ipairs(self:Inventory().items) do if e.item==item and e.count==1 and not e.locked then out[#out+1]=e end end
    return out
end
function S:ScanInventoryLoot(c)
    if not self.session or not A.Client:InRaid() or not A.roster[A.me] then return end
    A.PrimeLootBagSnapshot(c)
    local inventory=self:Inventory();local now=A.Client:Uptime();local server=A.Client:ServerTime()
    local known={};for _,entry in ipairs(self.session.lootEntries or {}) do known[entry.guid]=entry end
    local samples={}
    for _,e in ipairs(inventory.items) do
        local old=known[e.guid];local evidence=c.pendingLootItems and c.pendingLootItems[tostring(e.item)]
        local first=c.lootBagFirstSeen[e.guid] or now;c.lootBagFirstSeen[e.guid]=first
        local pending=evidence and evidence.expires>=now and (evidence.claims[e.guid] or (evidence.remaining>0 and first>=evidence.at-5))
        local retired=self.session.retiredLootGUIDs and self.session.retiredLootGUIDs[e.guid]
        if not retired and (old or (e.count==1 and c:ShouldCollectLoot(e.quality))) then
            local ok,kind,seconds=pcall(function() return c:ReadTradeTimer(e.bag,e.slot,ItemLocation:CreateFromBagAndSlot(e.bag,e.slot)) end)
            if not ok then kind,seconds="unknown",nil;inventory.complete=false end
            if e.count~=1 then kind,seconds="unknown",nil end
            if old or kind=="timed" or pending then
                if not old and kind~="timed" and pending and not evidence.claims[e.guid] then evidence.claims[e.guid]=true;evidence.remaining=evidence.remaining-1 end
                local changed=not old or old.kind~=kind or (kind=="timed" and math.abs((old.seconds or 0)-math.max(0,server-(old.observedAt or 0))-(seconds or 0))>120)
                if changed or server-(old and old.observedAt or 0)>=30 then
                    samples[#samples+1]={guid=e.guid,link=e.link,kind=kind,seconds=seconds}
                end
            end
        end
    end
    if inventory.complete then for guid,entry in pairs(known) do
        if entry.holder==A.me and not inventory.byGUID[guid] and entry.kind~="missing" then samples[#samples+1]={guid=guid,link=entry.link,kind="missing"} end
    end end
    if #samples>0 and #samples<=80 then self:ReportPugLoot(samples) end
end
-- Bag coordinates are only a cache hint. The baseline always checks the exact
-- GUID and current tradability again immediately before offering an item.
local find=A.FindTradeItem
function A:FindTradeItem(entry,...)
    if not S.session or not entry or not entry.guid then return find(self,entry,...) end
    local e=S:Inventory().byGUID[entry.guid]
    local function location(copy)
        if not copy or not C_Item or not ItemLocation then return end
        local loc,ok=read(function() return ItemLocation:CreateFromBagAndSlot(copy.bag,copy.slot) end)
        if not ok then return end
        local id,known=read(C_Item.GetItemGUID,loc)
        if known and id==entry.guid then return loc end
    end
    local loc=location(e)
    if not loc then e=S:Inventory(true).byGUID[entry.guid];loc=location(e) end
    if not loc then return nil,nil,"This exact item copy is not in readable carried bags." end
    local info,ok=read(C_Container.GetContainerItemInfo,e.bag,e.slot)
    if not ok or type(info)~="table" then return nil,nil,"Item information is unavailable." end
    local link,linked=read(function() return info.hyperlink end)
    local locked,lockKnown=read(function() return info.isLocked end)
    local count,countKnown=read(function() return info.stackCount end)
    if not linked or not lockKnown or not countKnown or locked or count~=1 or not self:EquipmentLink(link)
        or link:match("item:(%d+)")~=entry.link:match("item:(%d+)") then return nil,nil,"Item is locked, stacked, restricted or changed." end
    local worked,kind,seconds=pcall(self.ReadTradeTimer,self,e.bag,e.slot,loc)
    if not worked or (kind~="unbound" and not (kind=="timed" and type(seconds)=="number" and seconds>0)) then
        return nil,nil,"Current trade eligibility could not be verified."
    end
    return e.bag,e.slot
end
local frame=CreateFrame("Frame");S.inventoryEvents=frame
for _,event in ipairs({"BAG_UPDATE_DELAYED","ITEM_LOCK_CHANGED","PLAYER_ENTERING_WORLD","TRADE_PLAYER_ITEM_CHANGED","TRADE_CLOSED"}) do pcall(frame.RegisterEvent,frame,event) end
frame:SetScript("OnEvent",function() S:InvalidateInventory() end)
