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
function S:ShowAwardQueue()
    if not self.awardUI then
        local f=S:CreateUIFrame("Frame","NausePugAwards",UIParent,"BasicFrameTemplateWithInset");self.awardUI=f
        f:SetSize(850,650);f:SetPoint("CENTER");f:SetMovable(true);f:EnableMouse(true);f:RegisterForDrag("LeftButton");f:SetScript("OnDragStart",f.StartMoving);f:SetScript("OnDragStop",f.StopMovingOrSizing)
        if f.TitleText then f.TitleText:SetText("Nause Raid Tools - SR Awards / Trade") end
        table.insert(UISpecialFrames,"NausePugAwards")
        local function label(y) local l=f:CreateFontString(nil,"OVERLAY","GameFontNormal");l:SetPoint("TOPLEFT",20,y);l:SetWidth(810);l:SetJustifyH("LEFT");return l end
        local function button(text,x,y,w,fn)
            local b=S:CreateUIFrame("Button",nil,f,"UIPanelButtonTemplate");b:SetPoint("TOPLEFT",x,y);b:SetSize(w,25);b:SetText(text);b:SetScript("OnClick",function() local ok,why=fn();if why then S:Print(why) end;S:RenderAwardQueue() end);return b
        end
        local function selected() return S:AwardByID(S.selectedAward) end
        local function amend(action)
            local h=selected();if not h or not S:IsHost() then return false,"Select an award as the leader." end
            local target=action=="correct" and A:Resolve(f.target:GetText()) or nil
            if action=="correct" and not target then return false,"Choose a current raid player." end
            local popup=S:ShowConfirmation("NAUSE_SR_CHANGE_AWARD",action=="delivered" and "Confirm that this exact item was received by the recorded winner?" or "Cancel/correct this pending award and adjust the consumed SR?")
            if popup then popup.data={sid=S.session.id,id=h.id,revision=h.revision,action=action,target=target,reason=f.reason:GetText()} end
            return popup~=nil
        end
        self:InstallManagerNavigation(f,"Awards")
        f.summary=label(-92);f.rows={}
        for i=1,10 do f.rows[i]=button("",20,-122-(i-1)*27,810,function() S.selectedAward=f.rows[i].award;return true end) end
        button("Previous",20,-400,100,function() S.awardPage=math.max(1,(S.awardPage or 1)-1);return true end)
        button("Next",130,-400,100,function() S.awardPage=(S.awardPage or 1)+1;return true end)
        f.detail=label(-443)
        button("I hold this copy",20,-480,195,function() local h=selected();if not h then return false,"Select an award." end;return S:ClaimCopy(h) end)
        button("Open trade",225,-480,195,function() return S:TradeAward(selected(),false) end)
        button("Offer exact copy",430,-480,195,function() return S:TradeAward(selected(),true) end)
        button("Confirm delivered",635,-480,195,function() return amend("delivered") end)
        f.target=S:CreateUIFrame("EditBox",nil,f,"InputBoxTemplate");f.target:SetSize(190,24);f.target:SetPoint("TOPLEFT",20,-554);f.target:SetAutoFocus(false)
        f.reason=S:CreateUIFrame("EditBox",nil,f,"InputBoxTemplate");f.reason:SetSize(390,24);f.reason:SetPoint("TOPLEFT",230,-554);f.reason:SetAutoFocus(false);f.reason:SetMaxLetters(160)
        local correctionHelp=label(-533);correctionHelp:SetText("Winner correction: player name on the left, required reason on the right.")
        local correct=button("Correct winner",20,-598,195,function() return amend("correct") end)
        local cancel=button("Cancel award",225,-598,195,function() return amend("cancel") end)
        f.correctionControls={f.target,f.reason,correctionHelp,correct,cancel}
        for _,control in ipairs(f.correctionControls) do control:Hide() end
        button("Correct / cancel award…",20,-520,220,function()
            f.correctionsOpen=not f.correctionsOpen
            for _,control in ipairs(f.correctionControls) do control:SetShown(f.correctionsOpen) end
            return true
        end)
    end
    self.awardUI:Show();self:RenderAwardQueue()
end
function S:RenderAwardQueue()
    local f=self.awardUI;if not f then return end
    local rows={};for _,h in ipairs(self.session and self.session.history or {}) do if h.id then rows[#rows+1]=h end end
    local pages=math.max(1,math.ceil(#rows/10));self.awardPage=math.min(self.awardPage or 1,pages)
    local pending=0;for _,award in ipairs(rows) do if award.status=="pending" then pending=pending+1 end end
    f.summary:SetText(pending.." awaiting delivery · "..#rows.." recorded awards · Page "..self.awardPage.."/"..pages)
    for i,b in ipairs(f.rows) do
        local h=rows[#rows-((self.awardPage-1)*10+i)+1];b:SetShown(h~=nil);b.award=h and h.id
        if h then b:SetText((h.id==self.selectedAward and "> " or "")..S:ReservationItemText(h.item).." → "..h.winner.." | "..h.tier.." "..h.roll.." | "..h.status.." | "..(h.holder or "holder unknown")) end
    end
    local h=self:AwardByID(self.selectedAward)
    f.detail:SetText(h and ("Winner: "..h.winner.." · Holder: "..(h.holder or "Not reported").." · "..h.status) or "Select an award to manage its delivery.")
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
