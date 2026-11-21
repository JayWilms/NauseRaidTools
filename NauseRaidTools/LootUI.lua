local _, A = ...
function A:IsCompletedUtilityAssignment(entry)
    local item=entry and entry.item and self:ItemByID(entry.item)
    return item and item.automaticAssignment and item.status=="awarded"
        and (item.awardReason=="Disenchant" or item.awardReason=="Guild Bank")
        and entry.delivery=="delivered" and item.winner~=nil and entry.deliveredTo==item.winner
end

function A:LootQueueStatus(entry, item, remaining, early)
    if entry.delivery == "delivered" then return 6, "Delivered" end
    if item and item.status == "awarded" and item.winner then
        if entry.delivery == "review" or remaining == 0 then return 1, "Review delivery" end
        if entry.manual or entry.holder == item.winner then return 2, "Confirm delivery" end
        return remaining and remaining <= early and 1 or 3, "Trade to " .. self:DisplayName(item.winner)
    end
    if self:LootSuggestion(entry) then return 2, "Council suggestion" end
    if self:CanQueueTrackedLoot(entry) then return 4, "Queue for council" end
    return 5, item and item.status == "open" and "Responses open" or "Awaiting award"
end

function A:OpenLootSuggestionMenu(row,operation,label)
    local s=self.state
    local entry=s and self:TrackedByID(row.tracked)
    if not entry then return end
    local tracked,guid,sid=entry.id,entry.guid,s.id
    GameTooltip:Hide()
    self:OpenSettingsDropdown(row,{{label,operation}},function(op)
        if A.state and A.state.id==sid then A:Act(op,{tracked=tracked,guid=guid}) end
    end,200)
end

function A:LootHolderInfo(holder)
    if type(holder)~="string" or holder=="" then return "Unknown", "Holder not confirmed" end
    local unit=self.roster[holder]
    local status,color
    if type(unit)=="string" then
        local ok,connected=self.Client:Call("UnitIsConnected",unit)
        if ok and (connected==false or connected==0) then status="Offline" end
        local ok,_,class=self.Client:Call("UnitClass",unit)
        if ok and type(class)=="string" and type(RAID_CLASS_COLORS)=="table" then color=RAID_CLASS_COLORS[class] end
    elseif not unit then status="Not in raid" end
    if self:IsSoloTest() and type(RAID_CLASS_COLORS)=="table" then
        local fixtureClass=holder=="Warrior-Test" and "WARRIOR" or holder=="Priest-Test" and "PRIEST"
        if fixtureClass then color=RAID_CLASS_COLORS[fixtureClass] end
    end
    return self:DisplayName(holder),status,color
end

function A:MoveLootPage(direction)
    if not self.ui or not self.ui.lootPanels or not self:CanViewLoot() then return end
    local panel=self.ui.lootPanels.deliveries
    self:ScrollLootList(panel.scroll,direction*(panel.visibleRows or 6)*44)
    panel.page=math.floor((panel.scroll:GetVerticalScroll() or 0)/((panel.visibleRows or 6)*44))

end

function A:BuildLootUI(u, window, text, button, edit)
    local panel = {page = 0}
    u.lootPanels = {timer = panel, deliveries = panel}
    local w = window("NauseRaidToolsTrade", "Nause Raid Tools - Loot", 820, 440)
    panel.window = w
    local function wheel(_,delta) A:ScrollLootList(panel.scroll,-delta*44) end
    w.nrtWheelEnabled=true;w:EnableMouseWheel(true);w:SetScript("OnMouseWheel",wheel)
    panel.summary = text(w, "", 11, 20, -43, 710)
    panel.empty=text(w,"No loot collected yet.\nEligible items will appear here when holders report them.",13,45,-170,670)
    panel.empty:SetHeight(85);panel.empty:SetJustifyH("CENTER");panel.empty:SetJustifyV("TOP")
    panel.itemHeader=text(w, "Item", 11, 24, -70, 265)
    panel.holderHeader=text(w, "Holder", 11, 380, -70, 105)
    panel.actionHeader=text(w, "Next action", 11, 508, -70, 215)
    panel.scroll=self:CreateScrollFrame(w)
    panel.scroll:SetPoint("TOPLEFT",18,-88);panel.scroll:SetSize(762,264)
    panel.child=CreateFrame("Frame",nil,panel.scroll);panel.child:SetSize(762,1);panel.scroll:SetScrollChild(panel.child)
    panel.rows = {}
    for i=1,80 do
        local row = button(panel.child, "", 0, -(i-1)*44, 724, function(self,mouse)
            if mouse=="RightButton" then
                if A:IsMaster() and A:LootSuggestion(A:TrackedByID(self.tracked)) then
                    A:OpenLootSuggestionMenu(self,"dismissLootSuggestion","Dismiss Suggestion")
                end
                return
            end
            A.selectedTracked=self.tracked;A:RenderLootWindows()
        end)
        row:RegisterForClicks("LeftButtonUp","RightButtonUp")
        row:SetHeight(42); row:SetNormalTexture(""); row:SetPushedTexture("")
        self:StyleDataRow(row,i)
        row.icon=row:CreateTexture(nil,"ARTWORK"); row.icon:SetPoint("TOPLEFT",4,-4); row.icon:SetSize(34,34)
        row.caption=text(row,"",11,46,-4,220); row.caption:SetHeight(26); row.caption:SetMaxLines(2)
        row.detail=text(row,"",9,46,-30,220); row.detail:SetMaxLines(1)
        row.holder=text(row,"",11,380,-8,70); row.holder:SetMaxLines(1);row.holder:SetWordWrap(false)
        row.holderMeasure=text(row,"",11,0,0);row.holderMeasure:Hide()
        row.holderStatus=text(row,"",9,380,-26,105); row.holderStatus:SetMaxLines(1)
        row.action=text(row,"",11,490,-7,125);row.action:SetMaxLines(1);row.action:SetWordWrap(false)
        row.deadline=text(row,"",9,490,-25,125);row.deadline:SetMaxLines(1)
        row.trade=button(row,"",624,-8,88,function() end)
        row.tradeLabel=text(row.trade,"Trade",11,0,-6,88); row.tradeLabel:SetJustifyH("CENTER"); row.trade:GetFontString():Hide()
        for _,surface in ipairs({row,row.trade}) do
            surface:EnableMouseWheel(true);surface:SetScript("OnMouseWheel",wheel)
        end
        panel.rows[i]=row
    end
    panel.previous=button(w,"<",20,-365,35,function() A:MoveLootPage(-1) end)
    panel.next=button(w,">",60,-365,35,function() A:MoveLootPage(1) end)
    self:StyleRailArrow(panel.previous,-1);self:StyleRailArrow(panel.next,1)
    panel.pageLabel=text(w,"",10,110,-373,280)
    panel.queueAll=button(w,"Queue all",410,-365,105,function() A:QueueTrackedLoot() end)
    u.manageLoot=button(w,"Manage",525,-365,100,function() A:ShowLootManagement() end)
    u.manageLoot:Hide();u.manageLoot:SetEnabled(false)
    panel.manage=window("NauseRaidToolsDeliveryManagement","Loot management",820,290)
    panel.close=button(w,"Close",635,-365,100,function() w:Hide() end)
    panel.footer=text(w,"/nrt loot reopens this window. Closing keeps tracking active.",10,20,-407,710)
    local m=panel.manage
    panel.selectionIcon=m:CreateTexture(nil,"ARTWORK")
    panel.selectionIcon:SetPoint("TOPLEFT",20,-55);panel.selectionIcon:SetSize(32,32)
    panel.selection=text(m,"",11,62,-55,738); panel.selection:SetHeight(45)
    panel.queue=button(m,"Queue item",20,-110,130,function() if A.selectedTracked then A:QueueTrackedLoot(A.selectedTracked) end end)
    panel.attach=button(m,"Attach selected loot",160,-110,150,function() A:Act("queueLoot",{tracked=A.selectedTracked,item=A.selectedItem,attach=true}) end)
    panel.delivered=button(m,"Confirm delivered",320,-110,160,function() A:ReviewDelivery("confirmDelivery") end)
    panel.reopen=button(m,"Reopen delivery",490,-110,150,function() A:ReviewDelivery("reopenDelivery") end)
    panel.holder=edit(m,25,-175,250,"Correct holder (full name)")
    panel.setHolder=button(m,"Set holder",290,-175,130,function() A:ReviewDelivery("lootHolder",panel.holder:GetText()) end)
    panel.auto=button(m,"",440,-175,250,function() A:Act("autoCollect") end)
    text(m,"Select an item in the trade list first. Confirm delivery only after the recipient has received it.",11,20,-235,780)
end
function A:ShowLootWindow(mode)
    if not self:CanViewLoot() then self:Print("Loot tracking requires an active leader, master looter, or holder of an awarded item."); return end
    self:BuildUI()
    if self.ui.itemTools and self.ui.itemTools:IsShown() then return end
    if self.ui.popup:GetWidth()+self.ui.lootPanels.timer.window:GetWidth()+64>UIParent:GetWidth() then self.ui.popup:Hide() end
    self.ui.lootPanels.timer.window:Show(); self:RenderLootWindows()
end

function A:ReviewDelivery(op, target)
    local entry = self.state and self.state.trackedLoot and self:TrackedByID(self.selectedTracked or 0)
    if not entry or not self:IsMaster() then return end
    local item = entry.item and self:ItemByID(entry.item)
    local data = {sid = self.state.id, op = op, tracked = entry.id, expectedRevision = entry.deliveryRevision,
        expectedWinner = item and item.winner, expectedAwardRevision = item and (item.awardRevision or 1), target = target}
    local message
    if op == "lootHolder" then
        data.target = self:Resolve(target)
        if not data.target then self:Print("Enter an unambiguous current raid member."); return end
        message = "Change the recorded holder from " .. self:FullDisplayName(entry.holder) .. " to " .. self:FullDisplayName(data.target) .. "?\nThis changes tracking only and clears the old timer reading."
    elseif not item or not item.winner then return
    elseif op == "confirmDelivery" then message = "Confirm that " .. self:FullDisplayName(item.winner) .. " actually received this item?\nThis records your manual confirmation; it does not perform a trade."
    else message = "Reopen delivery to " .. self:FullDisplayName(item.winner) .. "?\nThe earlier confirmation stays in the delivery log. This does not move the item." end
    if self.demo then message = self:TestLabel().." - simulated change only.\n\n" .. message end
    local dialog = A:ShowConfirmation("NAUSERAIDTOOLS_DELIVERY", entry.link, message)
    if dialog then dialog.data = data end
end

function A:RenderLootWindows()
    if not self.ui or not self.ui.lootPanels then return end
    self:RenderLootTimers()
    local panel=self.ui.lootPanels.timer
    local selected=self:TrackedByID(self.selectedTracked or 0)
    if self:IsCompletedUtilityAssignment(selected) then self.selectedTracked=nil;selected=nil end
    self.ui.manageLoot:SetShown(self:IsMaster())
    self.ui.manageLoot:SetEnabled(self:IsMaster() and selected~=nil)
    if not self:IsMaster() or not selected then panel.manage:Hide() end
    if not self:CanViewLoot() then
        panel.window:Hide(); panel.manage:Hide(); return
    end
    local s=self.state
    if panel.discoverySID~=s.id then panel.discoverySID=s.id;panel.discoveryID=0;panel.page=0;panel.scroll:SetVerticalScroll(0) end
    local newest=panel.discoveryID or 0
    for _,entry in ipairs(s.trackedLoot or {}) do
        if not self:IsCompletedUtilityAssignment(entry) then newest=math.max(newest,entry.id) end
    end
    if newest>(panel.discoveryID or 0) and self:LootWindowAutoOpen()
        and (not self.ui.itemTools or not self.ui.itemTools:IsShown()) then panel.window:Show() end
    panel.discoveryID=newest
    local rows={}
    local cfg=self:WarningSettings()
    local attention,completedAssignments=0,0
    for _, entry in ipairs(s.trackedLoot or {}) do
        if self:IsLeader() or self:IsMaster() or entry.holder==self.me then
            if self:IsCompletedUtilityAssignment(entry) then completedAssignments=completedAssignments+1
            else
                local item=entry.item and self:ItemByID(entry.item)
                local remaining=self:TradeRemaining(entry)
                local priority,action=self:LootQueueStatus(entry,item,remaining,cfg.early)
                rows[#rows+1]={entry=entry,item=item,remaining=remaining,priority=priority,action=action}
                if priority<=4 then attention=attention+1 end
            end
        end
    end
    table.sort(rows,function(a,b)
        if a.priority~=b.priority then return a.priority<b.priority end
        if a.priority==1 or a.priority==3 then
            local at,bt=a.remaining or math.huge,b.remaining or math.huge
            if at~=bt then return at<bt end
        end
        return a.entry.id<b.entry.id
    end)
    panel.count,panel.page=#rows,math.min(panel.page,math.max(0,math.ceil(#rows/(panel.visibleRows or 6))-1))
    panel.empty:SetShown(#rows==0)
    panel.empty:SetText(s.autoCollect==false and "No loot collected yet.\nAutomatic collection is off in Settings > Council." or "No loot collected yet.\nEligible items will appear here when holders report them.")
    if #rows==0 and completedAssignments>0 then panel.empty:SetText("No active loot to show.\nCompleted Disenchant and Guild Bank assignments are retained in Loot History.") end
    local capacity=(#s.items>=35 or #(s.trackedLoot or {})>=70) and (" | Active capacity: "..#s.items.."/40 items, "..#(s.trackedLoot or {}).."/80 copies (archive confirmed deliveries)") or ""
    panel.summary:SetText((self.demo and (self:TestLabel().." | ") or "").."Needs attention: "..attention..
        " | Tracked: "..#rows..(completedAssignments>0 and (" | "..completedAssignments.." automatic deliveries in History") or "")..
        capacity.." | "..(s.archivedCount or 0).." archived")
    if self.demo then panel.empty:SetText("No simulated loot.\nRun Settings > Advanced > Loot Council Test to prepare a fresh Forever loot set.") end
    for i,row in ipairs(panel.rows) do
        local work=rows[i]
        local entry=work and work.entry
        row:SetShown(entry~=nil);row.tracked=entry and entry.id
        if entry then
            local item,remaining=work.item,work.remaining
            local awarded=item and item.status=="awarded" and item.winner
            local pending=awarded and entry.delivery~="delivered"
            local level=pending and self:TradeWarningLevel(entry)
            row.icon:SetTexture(self:ItemIcon(entry)); row.caption:SetText(entry.link)
            if level=="urgent" then row.caption:SetTextColor(1,0.3,0.2)
            elseif level=="early" then row.caption:SetTextColor(1,0.7,0.2)
            else row.caption:SetTextColor(1,1,1) end
            local suggestion=self:IsMaster() and self:LootSuggestion(entry)
            row.detail:SetText(suggestion and ("Suggested by "..suggestion.first) or entry.nativeReceipt and ("Master Loot record • Quantity "..(entry.quantity or 1)) or entry.manual and "Manual item - holder and timer unverified" or self.demo and (not entry.item and "Simulated loot - queue to open responses" or "Simulated loot - Manage tests delivery") or (self.selectedTracked==entry.id and "Selected" or ""))
            local holder,status,color=self:LootHolderInfo(entry.holder)
            row.holder:SetText(self:FitTimerItemName(holder,row.holderMeasure,row.holder:GetWidth()))
            row.holder:SetTextColor(color and color.r or 1,color and color.g or 1,color and color.b or 1)
            row.holderStatus:SetText(status or "")
            row.holderStatus:SetTextColor(1,0.7,0.3)
            row.action:SetText(work.action)
            local due=pending and remaining and remaining<=cfg.early
            row.deadline:SetText(due and (remaining==0 and "Timer elapsed" or
                (remaining<60 and "Trade due in <1m" or "Trade due in "..math.floor(remaining/60).."m")) or "")
            local urgent=due and remaining<=cfg.urgent
            row.deadline:SetTextColor(1,urgent and 0.3 or 0.7,0.2)
            local inTrade=pending and self:EntryInTrade(entry,item.winner)
            local inRange=pending and entry.holder==self.me and self:WinnerInTradeRange(item.winner)
            local queueable=self:CanQueueTrackedLoot(entry) and self:IsMaster() and (not self.demo or entry.demo)
            local needsReview=pending and (entry.delivery=="review" or remaining==0 or entry.manual or entry.holder==item.winner)
            local trade=pending and not self.demo and not entry.manual
                and not inTrade and entry.holder==self.me and item.winner~=self.me
            local manage=needsReview and self:IsMaster() and not trade and not inTrade
            local canTrade=queueable or manage or trade
            row.tradeLabel:SetText(manage and "Manage" or (inTrade and "In trade" or
                (trade and "Trade" or (queueable and "Queue" or ""))))
            row.trade:SetShown(canTrade or inTrade or false)
            row.trade:SetEnabled(canTrade or false)
            row.trade:GetFontString():Hide()
            if canTrade and inRange then row.tradeLabel:SetTextColor(0.2,1,0.2)
            elseif canTrade then row.tradeLabel:SetTextColor(0.84,0.86,0.89)
            else row.tradeLabel:SetTextColor(0.50,0.52,0.55) end
            row.trade:SetScript("OnClick",function()
                self.selectedTracked=entry.id
                if manage then self:ShowLootManagement()
                elseif trade then self:StartTrade(entry.id)
                elseif queueable then self:QueueTrackedLoot(entry.id) end
                self:RenderLootWindows()
            end)
        end
    end
    local entry=s.trackedLoot and self:TrackedByID(self.selectedTracked or 0)
    local item=entry and entry.item and self:ItemByID(entry.item)
    local master=self:IsMaster()
    local unqueued,seen=0,{}
    for _,value in ipairs(s.trackedLoot or {}) do
        if self:CanQueueTrackedLoot(value) and not seen[value.guid] then unqueued=unqueued+1;seen[value.guid]=true end
    end
    panel.queueAll:SetEnabled(master and not s.masterBlocked and unqueued>0 and #s.items+unqueued<=40)
    panel.selectionIcon:SetShown(entry~=nil)
    if entry then panel.selectionIcon:SetTexture(self:ItemIcon(entry)) end
    panel.selection:SetText(entry and (entry.link.." | Holder: "..(entry.holder~="" and self:FullDisplayName(entry.holder) or "Unknown").." | "..(entry.delivery or "Unawarded").."\n"..(entry.delivery=="review" and "Award changed after delivery: arrange transfer and confirm again." or "Confirm delivery after the recipient receives the item.")) or "Select an item in Loot / Trade first.")
    panel.queue:SetEnabled(master and entry and self:CanQueueTrackedLoot(entry))
    local selected=self:ItemByID(self.selectedItem or 0)
    panel.attach:SetEnabled(master and entry and self:CanQueueTrackedLoot(entry) and selected and not selected.lootGUID and selected.link==entry.link)
    panel.delivered:SetEnabled(master and item and item.status=="awarded" and entry.delivery~="delivered")
    panel.reopen:SetEnabled(master and entry and (entry.delivery=="delivered" or entry.delivery=="review"))
    panel.setHolder:SetEnabled(master and entry~=nil)
    panel.auto:SetEnabled(self:IsLeader());self:SetSettingsToggle(panel.auto,s.autoCollect~=false)
    panel.previous:Hide();panel.next:Hide();panel.pageLabel:Hide()
    self:SizeLootScroll(panel.scroll,panel.child,#rows,44)

end

-- Timer keeps exact countdowns, with delivery actions limited to the item holder.
-- Shorten display text only; the original item link and identity stay intact.
function A:FitTimerItemName(link,measure,width)
    link=type(link)=="string" and link or "Unknown item"
    local name=(link:match("|h(.-)|h") or link):gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r","")
    local color=link:match("|c(%x%x%x%x%x%x%x%x)")
    local function measured(value)
        measure:SetText(value)
        local ok,size=pcall(measure.GetStringWidth,measure)
        if ok and type(size)=="number" and size==size and size>=0 then return size end
        return #value*6
    end
    local value=name
    if measured(name)>width then
        -- Boundaries preserve complete UTF-8 characters when adding an ellipsis.
        local ends={0}
        for i=1,#name do
            local nextByte=name:byte(i+1)
            if not nextByte or nextByte<128 or nextByte>=192 then ends[#ends+1]=i end
        end
        local low,high=0,#ends-1
        while low<high do
            local mid=math.ceil((low+high)/2)
            if measured(name:sub(1,ends[mid+1]).."...")<=width then low=mid else high=mid-1 end
        end
        value=name:sub(1,ends[low+1]).."..."
    end
    return color and ("|c"..color..value.."|r") or value
end

function A:BuildLootTimerUI(u,window,text,button)
    local p={rows={}}
    u.lootTimers=p
    p.window=window("NauseRaidToolsTimer","Nause Raid Tools - Timer",600,320,nil,false)
    p.itemHeader=text(p.window,"Item",11,24,-50,210)
    p.timeHeader=text(p.window,"Trade time",11,250,-50,145)
    p.holderHeader=text(p.window,"Holder / winner",11,420,-50,155)
    p.empty=text(p.window,"No loot timers to show.",13,24,-170,550)
    p.empty:SetJustifyH("CENTER")
    p.scroll=self:CreateScrollFrame(p.window)
    p.scroll:SetPoint("TOPLEFT",18,-68);p.scroll:SetSize(546,232)
    p.child=CreateFrame("Frame",nil,p.scroll)
    p.child:SetSize(546,1);p.scroll:SetScrollChild(p.child)
    -- Active tracking is bounded at 80 copies. Keep each physical copy in the
    -- scroll child so mouse wheel and scrollbar expose the complete list.
    for i=1,80 do
        local row=CreateFrame("Button",nil,p.child)
        row:SetPoint("TOPLEFT",0,-(i-1)*44);row:SetSize(546,42);row:EnableMouse(false)
        row:RegisterForClicks("RightButtonUp")
        row:EnableMouseWheel(true)
        row:SetScript("OnMouseWheel",function(_,delta) p.scroll:GetScript("OnMouseWheel")(p.scroll,delta) end)
        row:SetScript("OnClick",function(self)
            local entry=A:TrackedByID(self.tracked)
            if A:CanSuggestLoot(entry,A.me) then
                local suggestion=A:LootSuggestion(entry)
                if not suggestion or not suggestion.members[A.me] then
                    A:OpenLootSuggestionMenu(self,"suggestLoot","Suggest for Council")
                end
            end
        end)
        row:SetScript("OnEnter",function(self)
            local entry=A:TrackedByID(self.tracked)
            if not A:CanSuggestLoot(entry,A.me) then return end
            A:SetHoveredItem(self,entry.link)
            local suggestion=A:LootSuggestion(entry)
            GameTooltip:AddLine(suggestion and suggestion.members[A.me] and "You suggested this item." or "Right-click to suggest for council.",1,0.8,0.4)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave",function() GameTooltip:Hide() end)
        self:StyleDataRow(row,i)
        row.icon=row:CreateTexture(nil,"ARTWORK");row.icon:SetPoint("TOPLEFT",4,-4);row.icon:SetSize(34,34)
        row.caption=text(row,"",11,46,-13,170);row.caption:SetHeight(16);row.caption:SetMaxLines(1);row.caption:SetWordWrap(false)
        row.measure=text(row,"",11,0,0);row.measure:Hide()
        row.bar=CreateFrame("StatusBar",nil,row);row.bar:SetPoint("TOPLEFT",232,-12);row.bar:SetSize(145,18)
        row.bar:SetStatusBarTexture("Interface/TargetingFrame/UI-StatusBar")
        row.countdown=row.bar:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        row.countdown:SetPoint("CENTER");row.countdown:SetWidth(141);row.countdown:SetMaxLines(1)
        row.holder=text(row,"",11,402,-7,155);row.holder:SetMaxLines(1)
        row.holderStatus=text(row,"",9,402,-25,155);row.holderStatus:SetMaxLines(1)
        row.trade=button(row,"Trade",0,-8,60,function() A:StartTrade(row.tracked) end)
        row.trade:Hide()
        row.trade:EnableMouseWheel(true)
        row.trade:SetScript("OnMouseWheel",row:GetScript("OnMouseWheel"))
        p.rows[i]=row
    end
    self:LayoutLootTimer()
end

function A:LayoutLootTimer()
    local p=self.ui.lootTimers
    local w,h=p.window:GetWidth(),p.window:GetHeight()
    local width=w-54
    local compact=self:LootWindowLayout("timer")=="Compact"
    local oldStride,offset=p.rowStride or 44,p.scroll:GetVerticalScroll()
    p.compact,p.rowStride=compact,compact and 32 or 44
    p.scroll:SetSize(width,math.max(p.rowStride,h-88));p.child:SetWidth(width)
    local timeWidth=math.min(145,math.max(100,w*.23))
    local itemWidth=compact and math.max(60,width-timeWidth-50) or math.max(90,w-475)
    local timeX=itemWidth+(compact and 44 or 62)
    local holderX=timeX+timeWidth+16
    local holderWidth=math.max(40,width-holderX-8)
    p.holderWidth=holderWidth
    p.itemHeader:SetWidth(itemWidth+30)
    p.timeHeader:ClearAllPoints();p.timeHeader:SetPoint("TOPLEFT",p.window,"TOPLEFT",18+timeX,-50);p.timeHeader:SetWidth(timeWidth)
    p.holderHeader:SetShown(not compact)
    p.holderHeader:ClearAllPoints();p.holderHeader:SetPoint("TOPLEFT",p.window,"TOPLEFT",18+holderX,-50);p.holderHeader:SetWidth(holderWidth)
    for _,header in ipairs({p.itemHeader,p.timeHeader,p.holderHeader}) do header:SetTextColor(.80,.74,.57) end
    p.empty:ClearAllPoints();p.empty:SetPoint("TOPLEFT",24,-math.floor((h+20)/2));p.empty:SetWidth(w-48)
    for i,row in ipairs(p.rows) do
        row:ClearAllPoints();row:SetPoint("TOPLEFT",0,-(i-1)*p.rowStride);row:SetSize(width,p.rowStride-2)
        row.icon:SetSize(compact and 22 or 34,compact and 22 or 34)
        row.caption:ClearAllPoints();row.caption:SetPoint("TOPLEFT",compact and 34 or 46,compact and -7 or -13);row.caption:SetWidth(itemWidth)
        row.bar:ClearAllPoints();row.bar:SetPoint("TOPLEFT",timeX,compact and -6 or -12);row.bar:SetWidth(timeWidth);row.countdown:SetWidth(timeWidth-4)
        row.holder:SetShown(not compact);row.holderStatus:SetShown(not compact)
        row.holder:ClearAllPoints();row.holder:SetPoint("TOPLEFT",holderX,-7);row.holder:SetWidth(holderWidth)
        row.holderStatus:ClearAllPoints();row.holderStatus:SetPoint("TOPLEFT",holderX,-25);row.holderStatus:SetWidth(holderWidth)
        row.trade:ClearAllPoints();row.trade:SetPoint("TOPLEFT",width-64,-8)
        if compact then row.trade:Hide() end
    end
    self:ClampLootTimerScroll(false,offset*p.rowStride/oldStride)
end

function A:ClampLootTimerScroll(reset,offset)
    local p=self.ui.lootTimers
    local height=math.max(1,(p.count or 0)*p.rowStride-2)
    p.child:SetHeight(height)
    local maximum=math.max(0,height-p.scroll:GetHeight())
    p.scroll:SetVerticalScroll(reset and 0 or math.min(offset or p.scroll:GetVerticalScroll(),maximum))
    self:RefreshScrollChrome(p.scroll,maximum)
end

function A:ShowLootTimers()
    self:BuildUI();self:RenderLootTimers();self.ui.lootTimers.window:Show()
end

function A:RenderLootTimers()
    local p=self.ui and self.ui.lootTimers
    if not p then return end
    local sid=self.state and self.state.id
    local reset=p.sid~=sid
    p.sid=sid
    local rows={}
    for _,entry in ipairs(self.state and self.state.trackedLoot or {}) do
        if entry.delivery~="delivered" then
            local remaining,label=self:TradeRemaining(entry)
            rows[#rows+1]={entry=entry,remaining=remaining,label=label}
        end
    end
    table.sort(rows,function(a,b)
        local at,bt=a.remaining or math.huge,b.remaining or math.huge
        return at==bt and a.entry.id<b.entry.id or at<bt
    end)
    p.count=#rows
    p.empty:SetShown(#rows==0)
    p.empty:SetText(self.demo and "No demo loot timers yet. Award an item in Voting first." or "No loot timers to show.")
    self:ClampLootTimerScroll(reset)
    local cfg=self:WarningSettings()
    for i,row in ipairs(p.rows) do
        local timer=rows[i]
        local entry=timer and timer.entry
        row:SetShown(entry~=nil);row.tracked=entry and entry.id
        row.trade:Hide()
        row:EnableMouse(self.CanSuggestLoot and self:CanSuggestLoot(entry,self.me) and true or false)
        if entry then
            row.icon:SetTexture(self:ItemIcon(entry))
            local key=entry.link..":"..row.caption:GetWidth()
            if row.captionKey~=key then
                row.caption:SetText(self:FitTimerItemName(entry.link,row.measure,row.caption:GetWidth()))
                row.captionKey=key
            end
            local remaining,label=timer.remaining,timer.label
            row.bar:SetMinMaxValues(0,entry.maxSeconds or entry.seconds or 1);row.bar:SetValue(remaining or 0)
            if remaining==nil then row.bar:SetStatusBarColor(0.35,0.35,0.38)
            elseif remaining<=cfg.urgent then row.bar:SetStatusBarColor(0.85,0.15,0.15)
            elseif remaining<=cfg.early then row.bar:SetStatusBarColor(0.95,0.6,0.1)
            else row.bar:SetStatusBarColor(0.2,0.65,0.3) end
            row.countdown:SetText(label)
            if not p.compact then
                local holder,status,color=self:LootHolderInfo(entry.holder)
                row.holder:SetText(holder);row.holder:SetTextColor(color and color.r or 1,color and color.g or 1,color and color.b or 1)
                local item=entry.item and self:ItemByID(entry.item)
                local winner=item and item.status=="awarded" and item.winner
                local ownsCopy=entry.holder==self.me
                local canSeeWinner=winner and (ownsCopy or self:IsLeader() or self:IsMaster())
                local canTrade=winner and ownsCopy and winner~=self.me and not self.demo and not entry.manual
                local inTrade=canTrade and self:EntryInTrade(entry,winner)
                local nameWidth=math.max(35,p.holderWidth-(canTrade and 66 or 0))
                row.holder:SetWidth(nameWidth);row.holderStatus:SetWidth(nameWidth)
                row.holderStatus:SetText(canSeeWinner and ("To: "..self:DisplayName(winner))
                    or (self.demo and entry.demo and "Simulated loot / timer" or (status or "")))
                row.holderStatus:SetTextColor(1,0.7,0.3)
                row.trade:SetShown(canTrade and true or false)
                row.trade:SetText(inTrade and "In trade" or "Trade")
                row.trade:SetEnabled(not inTrade)
            end
        end
    end
end

function A:ShowLootManagement()
    if not self:IsMaster() then self:Print("Only the current master looter can manage loot delivery.");return end
    self:BuildUI()
    local entry=self.state.trackedLoot and self:TrackedByID(self.selectedTracked or 0)
    if not entry then self:Print("Select an item in Loot / Trade first.");return end
    self:RenderLootWindows()
    local panel=self.ui.lootPanels.timer
    panel.manage:Show();self:FocusWindow(panel.manage);panel.window:Hide()
end
