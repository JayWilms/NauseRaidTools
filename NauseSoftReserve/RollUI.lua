local _,S=...
local A=S.base
function S:RollWinnerText(winners,maximum)
    local names={};for i,name in ipairs(winners or {}) do
        if not maximum or i<=maximum then names[#names+1]=self:PlayerText(name) end
    end
    if maximum and #(winners or {})>maximum then names[#names+1]="+"..(#winners-maximum).." more" end
    return table.concat(names,", ")
end
function S:RollEligibilityText(round,player)
    if round.passed[player] then return "You passed this item. Your rolls cannot win." end
    if round.tiebreak then
        if not round.tiePool[player] then return "Only tied players can roll in this tie-break. You are not eligible." end
        return "You are in the tie-break. Roll once with /roll "..(round.tier=="OS" and 99 or 100).."."
    end
    local count=round.eligible[player] or 0
    if count>0 then return "You have "..count.." soft reserve"..(count==1 and "" or "s")..": choose MS (/100) for up to "..count.." SR roll"..(count==1 and "" or "s")..", or OS (/99) for one off-spec roll. Your best valid roll counts." end
    return "No soft reserve: choose MS (/100) or OS (/99). One roll; valid SR rolls take priority."
end
function S:RollKey()
    local s=self.session;local r=s and s.round
    return r and (s.id..":"..r.item..":"..r.tier..":"..tostring(r.epoch or 0))
end
function S:RollAllowance(choice)
    local s=self.session;local r=s and s.round
    if not r or r.closed or not A.roster[A.me] or r.passed[A.me] then return 0 end
    local tier=choice=="OS" and "OS" or ((r.eligible[A.me] or 0)>0 and "SR" or "MS")
    if r.tiebreak and (not r.tiePool[A.me] or tier~=r.tier) then return 0 end
    if r.playerTiers[A.me] and r.playerTiers[A.me]~=tier then return 0 end
    if self.localRollKey==self:RollKey() and self.localRollChoice and self.localRollChoice~=choice then return 0 end
    local cap=r.tiebreak and 1 or (tier=="SR" and r.eligible[A.me] or 1)
    local observed=#(r.rolls[A.me] or {})
    local issued=self.localRollKey==self:RollKey() and self.localRollCount or 0
    return math.max(0,cap-math.max(observed,issued))
end
function S:ClickNativeRoll(choice,key)
    if key~=self:RollKey() then return false,"The roll changed. Use the current window." end
    if self:RollAllowance(choice)<1 then return false,"You have passed, are not eligible for this tie-break, or have used your allowed rolls." end
    if type(RandomRoll)~="function" then return false,"Native rolling is unavailable on this client. Use the matching /roll command." end
    local expected=choice=="OS" and 99 or 100
    local r=self.session.round;local used=math.max(self.localRollKey==key and self.localRollCount or 0,#(r.rolls[A.me] or {}))
    local ok=pcall(RandomRoll,1,expected)
    if not ok then return false,"Native roll failed; no result was recorded by this button." end
    self.localRollKey=key;self.localRollCount=used+1;self.localRollChoice=choice
    self:RenderRollWindow();return true
end
function S:RenderRollWindow()
    local s=self.session;local r=s and s.round
    if not r then if self.rollUI then self.rollUI:Hide() end;return end
    if not self.rollUI then
        local f=S:CreateUIFrame("Frame","NauseSRRollWindow",UIParent,"BasicFrameTemplateWithInset");self.rollUI=f
        f:SetSize(500,285);f:SetPoint("CENTER");f:SetMovable(true);f:EnableMouse(true);f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart",f.StartMoving);f:SetScript("OnDragStop",f.StopMovingOrSizing)
        if f.TitleText then f.TitleText:SetText("Nause Raid Tools - Item Roll") end
        table.insert(UISpecialFrames,"NauseSRRollWindow")
        local function label(y) local l=f:CreateFontString(nil,"OVERLAY","GameFontNormal");l:SetPoint("TOPLEFT",20,y);l:SetWidth(460);l:SetJustifyH("LEFT");return l end
        f.item=label(-45);f.item:ClearAllPoints();f.item:SetPoint("TOPLEFT",62,-45);f.item:SetWidth(418);f.item:SetHeight(24);f.item:SetMaxLines(1);f.item:SetWordWrap(false);f.item:SetFontObject("GameFontNormalLarge")
        f.icon=f:CreateTexture(nil,"ARTWORK");f.icon:SetPoint("TOPLEFT",20,-40);f.icon:SetSize(32,32)
        f.status=label(-75);f.status:SetHeight(20);f.status:SetMaxLines(1)
        f.details=label(-105);f.details:SetHeight(38)
        f.result=label(-150);f.result:SetHeight(30);f.result:SetMaxLines(2)
        f:SetScript("OnEnter",function() if f.link and GameTooltip then GameTooltip:SetOwner(f,"ANCHOR_RIGHT");GameTooltip:SetHyperlink(f.link);GameTooltip:Show() end end)
        f:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
        local function button(text,x,callback)
            local b=S:CreateUIFrame("Button",nil,f,"UIPanelButtonTemplate");b:SetSize(145,30);b:SetPoint("TOPLEFT",x,-210);b:SetText(text)
            b:SetScript("OnClick",function() local ok,why=callback();if why then S:Print(why) end;S:RenderRollWindow() end);return b
        end
        f.ms=button("MS",20,function() return S:ClickNativeRoll("MS",f.key) end)
        f.os=button("OS",177,function() return S:ClickNativeRoll("OS",f.key) end)
        f.pass=button("Pass",334,function()
            if f.key~=S:RollKey() then return false,"The roll changed." end
            return S:Request("pass")
        end)
    end
    local f=self.rollUI;local key=self:RollKey()
    local db=A.ItemLibrary and A:ItemLibrary();local link
    if db and type(db.GetLink)=="function" then local ok,value=pcall(db.GetLink,db,r.item);if ok then link=value end end
    f.link=link or ("item:"..r.item);f.item:SetText(self:ReservationItemText(r.item,link))
    f.status:SetText((r.tiebreak and r.tier or "SR > MS > OS — one roll window")..(r.tiebreak and " — tie-break" or "")..(r.closed and " — CLOSED" or " — OPEN"))
    local ok,icon=A.Client:Call("C_Item.GetItemIconByID",r.item);f.icon:SetTexture(ok and icon or "Interface/Icons/INV_Misc_QuestionMark")
    f.details:SetText(self:RollEligibilityText(r,A.me))
    local mine=r.rolls[A.me] or {};local text={};for _,v in ipairs(mine) do text[#text+1]=tostring(v) end
    f.result:SetText(r.passed[A.me] and "You passed this round." or (r.closed and ((r.winners and #r.winners>0) and ((#r.winners>1 and "Tied: " or "Winner: ")..self:RollWinnerText(r.winners,2).." — "..r.best) or "No valid winner. Leader can cancel/restart this item.") or (#text>0 and ("Your recorded rolls: "..table.concat(text,", ")) or "Waiting for a native roll. MS: 1–100. OS: 1–99.")))
    self:SetTextRole(f.details,"muted")
    self:SetTextRole(f.status,r.tiebreak and "attention" or "body")
    self:SetTextRole(f.result,r.closed and (r.winners and #r.winners==1 and "ready" or "attention") or "body")
    f.ms:SetEnabled(self:RollAllowance("MS")>0 and type(RandomRoll)=="function")
    f.os:SetEnabled(self:RollAllowance("OS")>0 and type(RandomRoll)=="function")
    f.pass:SetEnabled(not r.closed and not r.passed[A.me] and A.roster[A.me]~=nil)
    f.key=key
    if self.shownRollKey~=key then self.shownRollKey=key;if not self:IsHost() then f:Show() end end
end
local render=S.Render
function S:Render(...)
    render(self,...);self:RenderRollWindow()
end
