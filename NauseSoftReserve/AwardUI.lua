local _,S=...
local A=S.base
StaticPopupDialogs.NAUSE_SR_CHANGE_AWARD={text="%s\n\nClose any open trade for this item first. Confirming delivery records a manual confirmation, not automatic trade verification.",button1="Confirm",button2="Cancel",timeout=0,whileDead=true,hideOnEscape=true,
 OnAccept=function(dialog)
    local d=dialog.data
    if not d or not S.session or d.sid~=S.session.id then S:Print("Session changed.");return end
    local ok,why
    if d.action=="delivered" then ok,why=S:ConfirmDelivery(d.id,d.revision)
    else ok,why=S:AmendAward(d.id,d.revision,d.target,d.reason) end
    if why then S:Print(why) end
 end}
function S:AwardListRows(filter)
    local rows={}
    for i=#(self.session and self.session.history or {}),1,-1 do
        local award=self.session.history[i]
        if award.id and (filter=="all" or award.status==filter) then rows[#rows+1]=award end
    end
    return rows
end
function S:ResetAwardView()
    local id=self.session and self.session.id
    if self.awardViewSession~=id then
        self.awardViewSession=id;self.awardFilter="pending";self.awardScrollOffset=0;self.awardListKey=nil;self.selectedAward=nil
        if self.awardUI then self.awardUI.correctionsOpen=nil end
    end
end
function S:SelectAwardFilter(filter)
    if filter~="pending" and filter~="delivered" and filter~="all" then return false end
    self.awardFilter=filter;self.awardScrollOffset=0;self.selectedAward=nil
    if self.awardUI then self.awardUI.correctionsOpen=nil end
    self:RenderAwardQueue();return true
end
function S:AwardItemText(award)
    local entry=award.lootEntry and self.LootEntry and self:LootEntry(award.lootEntry)
    return self:ReservationItemText(award.item,entry and entry.link)
end
function S:ShowAwardQueue(id)
    self:ResetAwardView()
    if id then
        local award=self:AwardByID(id)
        if not award then return false,"Award changed. Review the current award list." end
        if self.selectedAward~=id and self.awardUI then self.awardUI.target:SetText("");self.awardUI.reason:SetText("");self.awardUI.correctionsOpen=nil end
        self.selectedAward=id;self.awardFilter=award.status=="cancelled" and "all" or award.status
        self.awardListKey=tostring(self.awardViewSession)..":"..self.awardFilter
        for i,row in ipairs(self:AwardListRows(self.awardFilter)) do if row.id==id then self.awardScrollOffset=(i-1)*42;break end end
    end
    if not self.awardUI then
        local f=S:CreateUIFrame("Frame","NausePugAwards",UIParent,"BasicFrameTemplateWithInset");self.awardUI=f
        f:SetSize(850,650);f:SetPoint("CENTER");f:SetMovable(true);f:EnableMouse(true);f:RegisterForDrag("LeftButton");f:SetScript("OnDragStart",f.StartMoving);f:SetScript("OnDragStop",f.StopMovingOrSizing)
        table.insert(UISpecialFrames,"NausePugAwards")
        local function label(parent,x,y,w,heading) return S:UILabel(parent,"",x,y,w,heading) end
        local function button(text,x,y,w,fn)
            return S:UIButton(f,text,x,y,w,function() local ok,why=fn();S:RenderAwardQueue();return ok,why end)
        end
        local function selected() return S:AwardByID(S.selectedAward) end
        local function amend(action)
            local award=selected();if not award or not S:IsHost() then return false,"Select an award as the leader." end
            local target=action=="correct" and A:Resolve(f.target:GetText()) or nil
            if action=="correct" and not target then return false,"Choose a current raid player." end
            local message=S:AwardItemText(award).."\nWinner: "..S:PlayerText(award.winner).."\n\n"..(action=="delivered" and "Confirm this item was received by the recorded winner?" or "Cancel/correct this pending award and adjust the consumed SR?")
            local popup=S:ShowConfirmation("NAUSE_SR_CHANGE_AWARD",message)
            if popup then popup.data={sid=S.session.id,id=award.id,revision=award.revision,action=action,target=target,reason=f.reason:GetText()} end
            return popup~=nil
        end
        self:InstallManagerNavigation(f,"Awards")
        f.summary=label(f,20,-92,810);f.filters={}
        for i,choice in ipairs({{"Pending","pending"},{"Delivered","delivered"},{"All","all"}}) do
            local value=choice[2];f.filters[i]=button(choice[1],20+(i-1)*145,-120,135,function() return S:SelectAwardFilter(value) end);f.filters[i].filter=value
        end
        local xs,ws={42,282,437,509,659},{230,145,62,140,120}
        for i,text in ipairs({"Item","Winner","Result","Holder","Status"}) do label(f,20+xs[i],-160,ws[i],true):SetText(text) end
        f.scroll=self:CreateUIFrame("ScrollFrame",nil,f,"UIPanelScrollFrameTemplate");f.scroll:SetPoint("TOPLEFT",20,-184);f.scroll:SetSize(788,260)
        f.content=self:CreateUIFrame("Frame",nil,f.scroll);f.content:SetSize(788,1);f.scroll:SetScrollChild(f.content)
        f.scroll:HookScript("OnVerticalScroll",function(_,offset) if not S.awardScrollRendering then S.awardScrollOffset=offset;S:RenderAwardQueue() end end)
        f.rows={}
        for i=1,8 do
            local row=S:CreateUIFrame("Button",nil,f.content,"UIPanelButtonTemplate");f.rows[i]=row;row:SetSize(788,40);row:SetText("")
            row.icon=row:CreateTexture(nil,"ARTWORK");row.icon:SetPoint("TOPLEFT",4,-4);row.icon:SetSize(32,32)
            row.item=label(row,xs[1],-11,ws[1]);row.winner=label(row,xs[2],-11,ws[2]);row.result=label(row,xs[3],-11,ws[3]);row.holder=label(row,xs[4],-11,ws[4]);row.status=label(row,xs[5],-11,ws[5])
            for _,text in ipairs({row.item,row.winner,row.result,row.holder,row.status}) do text:SetHeight(18);text:SetMaxLines(1);text:SetWordWrap(false) end
            row:SetScript("OnClick",function() if S.selectedAward~=row.award then f.target:SetText("");f.reason:SetText("") end;S.selectedAward=row.award;f.correctionsOpen=nil;S:RenderAwardQueue() end)
            row:EnableMouseWheel(true);row:SetScript("OnMouseWheel",function(_,delta) local fn=f.scroll:GetScript("OnMouseWheel");if fn then fn(f.scroll,delta) end end)
        end
        f.empty=label(f,40,-282,760);f.empty:SetHeight(50);f.empty:SetJustifyH("CENTER");self:SetTextRole(f.empty,"muted")
        self:UISection(f,-459)
        f.detailIcon=f:CreateTexture(nil,"ARTWORK");f.detailIcon:SetPoint("TOPLEFT",20,-474);f.detailIcon:SetSize(36,36)
        f.detailName=label(f,64,-470,766);f.detailName:SetFontObject("GameFontNormalLarge");f.detailName:SetHeight(23);f.detailName:SetMaxLines(1);f.detailName:SetWordWrap(false)
        f.detail=label(f,64,-499,766);f.detail:SetHeight(34);f.detail:SetMaxLines(2)
        f.primary=button("Select an award",20,-542,230,function()
            local award=selected();if not award or award.status~="pending" then return false,"Select a pending award." end
            if not award.holder then return S:ClaimCopy(award) end
            return S:TradeAward(award,A:TradePartner()==award.winner)
        end);f.primary:SetBackdropBorderColor(.75,.57,.18,1)
        f.confirmDelivered=button("Confirm delivered",265,-542,225,function() return amend("delivered") end)
        f.hint=label(f,20,-575,810);f.hint:SetHeight(14);f.hint:SetMaxLines(1);self:SetTextRole(f.hint,"muted")
        self:UISection(f,-594)
        f.correctionToggle=button("Correct / cancel award...",20,-605,220,function() f.correctionsOpen=not f.correctionsOpen;return true end)
        local correctionHelp=label(f,20,-642,810);correctionHelp:SetText("Winner correction: player name on the left, required reason on the right.");self:SetTextRole(correctionHelp,"muted")
        f.target=S:CreateUIFrame("EditBox",nil,f,"InputBoxTemplate");f.target:SetSize(190,24);f.target:SetPoint("TOPLEFT",20,-666);f.target:SetAutoFocus(false)
        f.reason=S:CreateUIFrame("EditBox",nil,f,"InputBoxTemplate");f.reason:SetSize(390,24);f.reason:SetPoint("TOPLEFT",230,-666);f.reason:SetAutoFocus(false);f.reason:SetMaxLetters(160)
        local correct=button("Correct winner",20,-708,195,function() return amend("correct") end)
        local cancel=button("Cancel award",225,-708,195,function() return amend("cancel") end)
        f.correctionControls={f.target,f.reason,correctionHelp,correct,cancel}
        for _,control in ipairs(f.correctionControls) do control:Hide() end
        local elapsed=0
        f:SetScript("OnUpdate",function(_,dt)
            elapsed=elapsed+dt;if elapsed<.25 then return end;elapsed=0
            local key=tostring(A:TradePartner())..":"..tostring(A.Client:Combat())
            if f.deliveryControlKey~=key then f.deliveryControlKey=key;S:RenderAwardQueue() end
        end)
    end
    self.awardUI:Show();self:RenderAwardQueue();return true
end
function S:RenderAwardQueue()
    local f=self.awardUI;if not f then return end
    self:ResetAwardView();local filter=self.awardFilter or "pending";local rows=self:AwardListRows(filter)
    local total,pending=0,0
    for _,award in ipairs(self.session and self.session.history or {}) do if award.id then total=total+1;if award.status=="pending" then pending=pending+1 end end end
    f.summary:SetText(self:ColoredText(pending.." awaiting delivery",pending>0 and "attention" or "muted").." · "..total.." recorded awards · "..#rows.." shown")
    for _,control in ipairs(f.filters) do
        local active=control.filter==filter;control:SetBackdropColor(active and .19 or .08,active and .16 or .09,active and .09 or .11,1)
        control:SetBackdropBorderColor(active and .75 or .20,active and .57 or .22,active and .18 or .26,1)
    end
    local key=tostring(self.awardViewSession)..":"..filter
    if self.awardListKey~=key then self.awardListKey=key;self.awardScrollOffset=0 end
    self.awardScrollRendering=true
    local first;first,self.awardScrollOffset=self:UpdateListScroll(f.scroll,f.content,#rows,42,self.awardScrollOffset)
    for i,row in ipairs(f.rows) do
        local award=rows[first+i-1];row:SetShown(award~=nil);row.award=award and award.id
        row:ClearAllPoints();row:SetPoint("TOPLEFT",0,-(first+i-2)*42)
        if award then
            row.item:SetText(self:AwardItemText(award));row.winner:SetText(self:PlayerText(award.winner));row.result:SetText(award.tier.." "..award.roll);row.holder:SetText(self:PlayerText(award.holder))
            row.status:SetText(award.status=="pending" and "Awaiting delivery" or award.status=="delivered" and "Delivered" or "Cancelled")
            self:SetTextRole(row.status,award.status=="pending" and "attention" or award.status=="delivered" and "ready" or "muted")
            local selected=award.id==self.selectedAward
            row:SetBackdropColor(selected and .19 or .08,selected and .16 or .09,selected and .09 or .11,1)
            row:SetBackdropBorderColor(selected and .75 or .20,selected and .57 or .22,selected and .18 or .26,1)
            local ok,icon=A.Client:Call("C_Item.GetItemIconByID",award.item);row.icon:SetTexture(ok and icon or "Interface/Icons/INV_Misc_QuestionMark")
        end
    end
    self.awardScrollRendering=nil
    f.empty:SetShown(#rows==0);f.empty:SetText(filter=="pending" and "No pending deliveries. Use Delivered or All to review recorded awards." or filter=="delivered" and "No delivered awards yet." or "No awards recorded yet.")
    local award=self:AwardByID(self.selectedAward);local pendingAward=award and award.status=="pending"
    local host=self:IsHost();local owned=pendingAward and award.holder==A.me
    f.detailIcon:SetShown(award~=nil)
    if award then local ok,icon=A.Client:Call("C_Item.GetItemIconByID",award.item);f.detailIcon:SetTexture(ok and icon or "Interface/Icons/INV_Misc_QuestionMark") end
    f.detailName:SetText(award and self:AwardItemText(award) or "Select an award")
    f.detail:SetText(award and ("Winner: "..self:PlayerText(award.winner).." · "..award.tier.." "..award.roll.." · "..self:AwardStatusText(award.status).."\nHolder: "..self:PlayerText(award.holder)) or "Choose an item above to review its delivery.")
    local canTrade=owned and award.guid and award.winner~=A.me and not A.Client:Combat()
    local claim=pendingAward and not award.holder
    f.primary:SetText(not award and "Select an award" or not pendingAward and (award.status=="delivered" and "Delivered" or "Cancelled") or claim and "I hold this copy" or canTrade and (A:TradePartner()==award.winner and "Offer exact copy" or "Open trade") or owned and award.winner==A.me and "Already held" or owned and A.Client:Combat() and "Unavailable in combat" or owned and "Copy not identified" or "Waiting for holder")
    f.primary:SetEnabled((claim or canTrade) and true or false)
    f.confirmDelivered:SetShown(pendingAward and host and true or false);f.confirmDelivered:SetEnabled(pendingAward and host and award.holder~=nil and award.guid~=nil or false)
    f.hint:SetText(not award and "Select a pending award to see the available delivery actions." or not pendingAward and "Delivery actions are complete for this award." or not award.holder and "The player holding the physical item must identify their copy." or owned and award.winner==A.me and "The winner already holds this copy. Confirm delivery after checking it." or owned and A.Client:Combat() and "Finish combat before opening or offering a trade." or owned and "Review the trade before both players accept. Delivery is tracked separately." or "The recorded holder must trade this item to the winner.")
    f.correctionToggle:SetEnabled(pendingAward and host and true or false)
    if not pendingAward or not host then f.correctionsOpen=nil end
    for _,control in ipairs(f.correctionControls) do control:SetShown(f.correctionsOpen and true or false) end
    local height=f.correctionsOpen and 750 or 650
    if f:GetHeight()~=height then f:SetHeight(height);if A.ClampWindowPosition then A:ClampWindowPosition(f) end end
end
local render=S.Render
function S:Render(...) render(self,...);self:RenderAwardQueue() end
local show=S.Show
function S:Show(...)
    show(self,...)
    if not self.ui.awards then
        local b=S:CreateUIFrame("Button",nil,self.ui,"UIPanelButtonTemplate");self.ui.awards=b;b:SetPoint("TOPLEFT",600,-62);b:SetSize(130,24);b:SetText("Awards / Trade");b:SetScript("OnClick",function() S:ShowAwardQueue() end)
        -- Replace the management window's Record winner callback through Command("record").
    end
end

function S:ShowCopyPicker(h,copies)
    if self.copyPicker then self.copyPicker:Hide() end
    local f=S:CreateUIFrame("Frame",nil,UIParent,"BasicFrameTemplateWithInset");self.copyPicker=f
    f:SetSize(590,math.min(#copies,12)*28+85);f:SetPoint("CENTER");f:SetFrameStrata("DIALOG")
    if f.TitleText then f.TitleText:SetText("Nause Raid Tools - Select Item Copy") end
    local sid,id,revision=self.session.id,h.id,h.revision
    for i=1,math.min(#copies,12) do
        local copy=copies[i]
        local b=S:CreateUIFrame("Button",nil,f,"UIPanelButtonTemplate");b:SetPoint("TOPLEFT",15,-35-(i-1)*28);b:SetSize(560,25)
        b:SetText("Bag "..tostring(copy.bag).." / slot "..tostring(copy.slot).." — "..copy.guid)
        b:SetScript("OnClick",function() local ok,why=S:SendCopyClaim(id,revision,copy.guid,sid);if why then S:Print(why) end;if ok then f:Hide() end end)
    end
    f:Show();return true,"Select the physical copy to assign (up to 12 shown)."
end
