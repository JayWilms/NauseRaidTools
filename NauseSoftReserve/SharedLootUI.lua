local _,S=...
local A=S.base
local saved={};local dirty=false
local function bind(control,event,fn)
    if not saved[control] then saved[control]={shown=control:IsShown(),text=control.GetText and control:GetText(),scripts={}} end
    local memory=saved[control]
    if not memory.scripts[event] then local old=control:GetScript(event);memory.scripts[event]={value=type(old)=="function" and old or nil} end
    control:SetScript(event,fn);dirty=true
end
function S:RestoreSharedLootUI()
    if not dirty then return end
    for control,info in pairs(saved) do
        for event,v in pairs(info.scripts) do control:SetScript(event,v.value) end
        if type(info.text)=="string" then control:SetText(info.text) end
        if type(info.shown)=="boolean" then control:SetShown(info.shown) end
    end
    if A.ui and A.ui.lootPanels and A.ui.lootPanels.timer.srAuto then A.ui.lootPanels.timer.srAuto:Hide() end
    dirty=false
end
local canView=A.CanViewLoot
function A:CanViewLoot()
    if S.session then
        if self:IsLeader() then return true end
        for _,entry in ipairs(S.session.lootEntries or {}) do if entry.holder==self.me then return true end end
        return false
    end
    return canView(self)
end
local show=A.ShowLootWindow
function A:ShowLootWindow(mode)
    if not S.session then return show(self,mode) end
    if not self:CanViewLoot() then self:Print("PuG loot is available to the leader and reported holders.");return end
    self:BuildUI();self:RenderLootWindows();self.ui.lootPanels.timer.window:Show()
end
local manage=A.ShowLootManagement
function A:ShowLootManagement()
    if not S.session then return manage(self) end
    local entry=S:LootEntry(S.selectedPugLoot)
    if not entry or (not S:IsHost() and entry.holder~=self.me) then self:Print("Select your collected copy, or manage it as leader.");return end
    self:BuildUI();self:RenderLootWindows();self.ui.lootPanels.timer.manage:Show();self:FocusWindow(self.ui.lootPanels.timer.manage);self.ui.lootPanels.timer.window:Hide()
end
function S:RenderSharedLootUI()
    local u=A.ui;if not u or not u.lootPanels then return end
    local p=u.lootPanels.timer;local s=self.session;local rows={};local pending=0
    A:LayoutReadableWindow(p.window);local visible=p.visibleRows or 6
    bind(p.manage,"OnShow",function(f)
        local entry=S:LootEntry(S.selectedPugLoot)
        if not entry or (not S:IsHost() and entry.holder~=A.me) then f:Hide();return end
        A:RefreshWindowChrome(f);A:FocusWindow(f)
    end)
    if self.sharedLootSID~=s.id then self.sharedLootSID=s.id;self.selectedPugLoot=nil;p.page=0;p.manage:Hide() end
    for _,entry in ipairs(s.lootEntries or {}) do
        local h=self:LootAward(entry)
        if h and h.status=="pending" then pending=pending+1 end
        if self:IsHost() or entry.holder==A.me then rows[#rows+1]=entry end
    end
    local function priority(entry)
        local award=S:LootAward(entry)
        if award and award.status=="delivered" then return 6 end
        if award and award.status=="pending" then
            local remaining=A:TradeRemaining(entry)
            return remaining and remaining<=A:WarningSettings().early and 1 or 3
        end
        return entry.status=="collected" and 4 or 5
    end
    table.sort(rows,function(a,b)
        local ap,bp=priority(a),priority(b)
        if ap~=bp then return ap<bp end
        return a.id<b.id
    end)
    p.count=#rows;p.page=math.min(p.page,math.max(0,math.ceil(#rows/visible)-1))
    p.summary:SetText("PuG Run — "..#rows.." collected copies | "..pending.." pending awards | "..#(s.pugQueue or {}).." queued | Queue starts SR / MS / OS rolling")
    p.empty:SetShown(#rows==0);p.empty:SetText("No loot collected yet.\nUses the same holder bag reports as Guild Run; fresh eligible drops appear after looting. Manual item entry remains available.")
    local discovered=false;self.seenPugLoot=self.seenPugLoot or {}
    for _,entry in ipairs(rows) do if not self.seenPugLoot[s.id..":"..entry.id] then self.seenPugLoot[s.id..":"..entry.id]=true;discovered=true end end
    if discovered and A:LootWindowAutoOpen() then p.window:Show() end
    for i,row in ipairs(p.rows) do
        local entry=rows[p.page*visible+i];row:SetShown(entry~=nil and i<=visible);row.tracked=entry and entry.id
        bind(row,"OnClick",function() if row.tracked then S.selectedPugLoot=row.tracked;A:RenderLootWindows() end end)
        bind(row,"OnEnter",function()
            local e=S:LootEntry(row.tracked);if not e or not GameTooltip then return end
            GameTooltip:SetOwner(row,"ANCHOR_RIGHT");GameTooltip:SetHyperlink(e.link);GameTooltip:AddLine("Reported holder: "..e.holder,1,1,1);GameTooltip:Show()
        end)
        if entry then
            local h=self:LootAward(entry);local remaining,label=A:TradeRemaining(entry)
            row.icon:SetTexture(A:ItemIcon(entry));row.caption:SetText(A:FitTimerItemName(entry.link,row.holderMeasure,row.caption:GetWidth()));row.caption:SetTextColor(1,1,1)
            row.detail:SetText((self.selectedPugLoot==entry.id and "Selected | " or "")..entry.status)
            local name,status,color=A:LootHolderInfo(entry.holder);row.holder:SetText(A:FitTimerItemName(name,row.holderMeasure,row.holder:GetWidth()));row.holderStatus:SetText(status or "")
            row.holder:SetTextColor(color and color.r or 1,color and color.g or 1,color and color.b or 1)
            local cfg=A:WarningSettings()
            row.action:SetText(h and (h.status=="delivered" and "Delivered" or "Trade to "..A:DisplayName(h.winner))
                or entry.status=="rolling" and "Rolling now" or entry.status=="collected" and "Queue for rolls" or "Queued")
            local due=h and h.status=="pending" and remaining and remaining<=cfg.early
            row.deadline:SetText(due and (remaining==0 and "Timer elapsed" or remaining<60 and "Trade due in <1m"
                or "Trade due in "..math.floor(remaining/60).."m") or "")
            row.deadline:SetTextColor(1,due and remaining<=cfg.urgent and .3 or .7,.2)
            row.tradeLabel:SetText(h and (h.status=="delivered" and "Delivered" or (h.winner==h.holder and "Already held" or "Trade")) or (entry.status=="collected" and "Queue" or "Queued"))
            row.tradeLabel:SetTextColor(1,0.82,0.35)
            row.trade:Show()
            row.trade:SetEnabled(h and h.status=="pending" and h.holder==A.me and h.winner~=A.me or (not h and self:IsHost() and entry.status~="rolling"))
            local id,guid,sid,awardID,revision=entry.id,entry.guid,s.id,h and h.id,h and h.revision
            bind(row.trade,"OnClick",function()
                if not S.session or S.session.id~=sid then return end
                local current=S:LootEntry(id);if not current or current.guid~=guid then S:Print("Loot copy changed.");return end
                local award=S:LootAward(current)
                if awardID then
                    if not award or award.id~=awardID or award.revision~=revision then S:Print("Award changed. Review this row again.");return end
                    local ok,why=S:TradeAward(award,false);if why then S:Print(why) end
                else local ok,why=S:QueuePugLoot(id);if why then S:Print(why) end end
            end)
        end
    end
    bind(p.queueAll,"OnClick",function() local ok,why=S:QueuePugLoot();if why then S:Print(why) end end)
    p.queueAll:SetEnabled(self:IsHost() and s.locked and #rows>0)
    local entry=self:LootEntry(self.selectedPugLoot);local h=self:LootAward(entry)
    u.manageLoot:SetShown(self:IsHost() or (entry and entry.holder==A.me) or false);u.manageLoot:SetEnabled(entry~=nil)
    if not entry or (not self:IsHost() and entry.holder~=A.me) then p.manage:Hide() end
    p.previous:SetEnabled(p.page>0);p.next:SetEnabled((p.page+1)*visible<#rows);A:RefreshRailArrow(p.previous);A:RefreshRailArrow(p.next)
    p.pageLabel:SetText("Page "..(p.page+1).." / "..math.max(1,math.ceil(#rows/visible)))
    p.selectionIcon:SetShown(entry~=nil);if entry then p.selectionIcon:SetTexture(A:ItemIcon(entry)) end
    p.selection:SetText(entry and (entry.link.." | Reported holder: "..entry.holder.."\nPuG Run: Queue opens one shared SR / MS / OS roll; delivery is confirmed separately.") or "Select collected loot first.")
    if u.itemToolsButton then
        bind(u.itemToolsButton,"OnClick",function() if S:ShowResults() then S.leaderRollUI.input:SetFocus() end end)
        u.itemToolsButton:SetText("Add item");u.itemToolsButton:SetEnabled(self:IsHost())
    end
    bind(p.queue,"OnClick",function() local ok,why=S:QueuePugLoot(S.selectedPugLoot);if why then S:Print(why) end end);p.queue:SetText("Roll item");p.queue:SetEnabled(self:IsHost() and entry~=nil and not h)
    bind(p.attach,"OnClick",function() S:ArchivePugLoot() end);p.attach:SetText("Archive delivered");p.attach:SetShown(true);p.attach:SetEnabled(self:IsHost())
    bind(p.delivered,"OnClick",function()
        local award=S:LootAward(S:LootEntry(S.selectedPugLoot));if not award then return end
        local popup=S:ShowConfirmation("NAUSE_SR_CHANGE_AWARD","Confirm that the exact collected item reached "..award.winner.."?")
        if popup then popup.data={sid=s.id,id=award.id,revision=award.revision,action="delivered"} end
    end);p.delivered:SetEnabled(self:IsHost() and h~=nil and h.status=="pending")
    bind(p.reopen,"OnClick",function() end);p.reopen:Hide()
    bind(p.holder,"OnEnter",function() end);p.holder:Hide();if p.holder.hint then bind(p.holder.hint,"OnEnter",function() end);p.holder.hint:Hide() end
    bind(p.setHolder,"OnClick",function()
        local award=S:LootAward(S:LootEntry(S.selectedPugLoot));if not award then return end
        local ok,why
        if award.holder==A.me then ok,why=S:TradeAward(award,true) else ok,why=S:ClaimCopy(award) end
        if why then S:Print(why) end
    end)
    p.setHolder:SetText(h and h.holder==A.me and "Offer exact copy" or "I hold this copy")
    p.setHolder:SetEnabled(h~=nil and h.status=="pending" and (not h.holder or h.holder==A.me))
    bind(p.auto,"OnClick",function()
        if not S:IsHost() then return end
        s.autoCollectLoot=s.autoCollectLoot==false;s.revision=s.revision+1;S:Publish()
    end);A:SetSettingsToggle(p.auto,s.autoCollectLoot~=false);p.auto:SetEnabled(self:IsHost())
    if not p.srAuto then
        p.srAuto=S:CreateUIFrame("Button",nil,p.manage,"UIPanelButtonTemplate");p.srAuto:SetSize(250,26);p.srAuto:SetPoint("TOPLEFT",440,-175)
        p.srAuto:SetScript("OnClick",function() if S:IsHost() then local run=S.session;run.autoCollectLoot=run.autoCollectLoot==false;run.revision=run.revision+1;S:Publish() end end)
    end
    p.srAuto:Show();p.srAuto:SetText("SR collection: "..(s.autoCollectLoot~=false and "On" or "Off"));p.srAuto:SetEnabled(self:IsHost())
end
local render=A.RenderLootWindows
function A:RenderLootWindows()
    if S.session then if self.ui and self.ui.lootPanels then S:RenderSharedLootUI() end;return end
    S:RestoreSharedLootUI();return render(self)
end
local srRender=S.Render
function S:Render(...) srRender(self,...);A:RenderLootWindows() end
local settings=A.RenderSettings
function A:RenderSettings(...)
    local result=settings(self,...)
    if S.session then self:RenderLootWindows() end
    return result
end
