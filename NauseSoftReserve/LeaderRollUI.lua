local _,S=...
local A=S.base
function S:RenderLeaderRolls(force)
    if not self:IsHost() then if self.leaderRollUI then self.leaderRollUI:Hide() end;return end
    local s=self.session;local r=s.round
    if not self.leaderRollUI and not r and not force then return end
    if not self.leaderRollUI then
        local f=S:CreateUIFrame("Frame","NausePugRollTable",UIParent,"BasicFrameTemplateWithInset");self.leaderRollUI=f
        f:SetSize(850,650);f:SetPoint("CENTER");f:SetMovable(true);f:EnableMouse(true);f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart",f.StartMoving);f:SetScript("OnDragStop",f.StopMovingOrSizing)
        if f.TitleText then f.TitleText:SetText("Nause Raid Tools - SR Results") end
        table.insert(UISpecialFrames,"NausePugRollTable")
        local function label(parent,x,y,w,font)
            local l=parent:CreateFontString(nil,"OVERLAY",font or "GameFontNormal");l:SetPoint("TOPLEFT",x,y);l:SetWidth(w);l:SetJustifyH("LEFT");return l
        end
        local function button(text,x,y,w,fn)
            local b=S:CreateUIFrame("Button",nil,f,"UIPanelButtonTemplate");b:SetPoint("TOPLEFT",x,y);b:SetSize(w,26);b:SetText(text)
            b:SetScript("OnClick",function() local ok,why=fn();if why then S:Print(why) end;S:RenderLeaderRolls() end);return b
        end
        self:InstallManagerNavigation(f,"Rolls")
        f.item=label(f,20,-92,810);f.status=label(f,20,-120,810)
        f.primary=S:UIButton(f,"Stop rolls",20,-526,210,function()
            local round=S.session and S.session.round
            if round and not round.closed then return S:Command("close") end
            if round and #round.winners>1 then return S:Command("reroll") end
            if round then return S:Command("record") end
            S:ShowAwardQueue();return true
        end,true)
        f.input=S:CreateUIFrame("EditBox",nil,f,"InputBoxTemplate");f.input:SetPoint("TOPLEFT",20,-174);f.input:SetSize(485,24);f.input:SetAutoFocus(false)
        f.input:SetScript("OnEscapePressed",function(e) e:ClearFocus() end)
        self:UIPlaceholder(f.input,"Item ID or item link")
        f.add=button("Add item",530,-174,135,function() return S:Command("roll "..f.input:GetText()) end)
        f.stop=button("Stop rolls",680,-174,135,function() return S:Command("close") end);f.stop:Hide()
        local headers={"Player","Roll","Type","Has SR","Note"};local xs={20,280,345,410,480};local ws={250,60,60,65,335}
        for i,text in ipairs(headers) do label(f,xs[i],-216,ws[i]):SetText(text) end
        f.rows={}
        for i=1,8 do
            local row={};f.rows[i]=row
            for col=1,5 do row[col]=label(f,xs[col],-244-(i-1)*27,ws[col],"GameFontHighlightSmall") end
        end
        button("Previous",20,-486,100,function() S.rollTablePage=math.max(1,(S.rollTablePage or 1)-1);return true end)
        button("Next",130,-486,100,function() S.rollTablePage=(S.rollTablePage or 1)+1;return true end)
        f.page=label(f,250,-492,560)
        f.award=f.primary
        button("Clear / cancel item",245,-526,180,function() return S:Command("cancel") end)
        button("Awards / Trade",635,-526,195,function() S:ShowAwardQueue();return true end)
        f.ms=button("MS",20,-570,115,function() return S:ClickNativeRoll("MS",f.key) end)
        f.os=button("OS",145,-570,115,function() return S:ClickNativeRoll("OS",f.key) end)
        f.pass=button("Pass",270,-570,115,function() if f.key~=S:RollKey() then return false,"Item changed." end;return S:Request("pass") end)
        label(f,405,-577,410):SetText("One roll window. Repeats are shown; invalid rolls cannot win.")
        f.itemHover=S:CreateUIFrame("Frame",nil,f);f.itemHover:SetPoint("TOPLEFT",20,-88);f.itemHover:SetSize(810,25);f.itemHover:EnableMouse(true)
        f.itemHover:SetScript("OnEnter",function() if f.link and GameTooltip then GameTooltip:SetOwner(f.itemHover,"ANCHOR_RIGHT");GameTooltip:SetHyperlink(f.link);GameTooltip:Show() end end)
        f.itemHover:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
    end
    local f=self.leaderRollUI;f.key=self:RollKey()
    if self.rollUI then self.rollUI:Hide() end
    local link
    local db=A.ItemLibrary and A:ItemLibrary()
    if r and db and type(db.GetLink)=="function" then local ok,v=pcall(db.GetLink,db,r.item);if ok then link=v end end
    f.link=r and (link or ("item:"..r.item));f.item:SetText(r and (link or self:ReservationItemText(r.item)) or "Add an item ID or item link to send MS / OS / Pass to the raid.")
    local sorted=self:RankedRolls(s,A.roster)
    local top=sorted[1]
    f.status:SetText(not r and "No active item" or (r.closed and (#r.winners>1 and "TIE — reroll tied players only" or (#r.winners==1 and ("WINNER: "..r.winners[1].." — "..r.tier.." "..r.best) or "No eligible winner")) or ((r.tiebreak and "TIE-BREAK" or "ROLLING — MS /100, OS /99")..(top and top.valid and (" | Leading: "..top.player.." — "..top.tier.." "..top.value) or ""))))
    local pages=math.max(1,math.ceil(#sorted/8));self.rollTablePage=math.min(self.rollTablePage or 1,pages)
    for i,row in ipairs(f.rows) do
        local entry=sorted[(self.rollTablePage-1)*8+i]
        local texts=entry and {entry.player..(entry.additional>0 and (" ("..entry.additional..")") or ""),tostring(entry.value),entry.tier,entry.hasSR and "Yes" or "—",entry.note~="" and entry.note or "Eligible"} or {"","","","",""}
        for col,l in ipairs(row) do l:SetText(texts[col]);l:SetTextColor(entry and entry.valid and .90 or .50,entry and entry.valid and .91 or .52,entry and entry.valid and .93 or .56) end
        if entry then local c=S:PlayerPresentation(entry.player);if c and entry.valid then row[1]:SetTextColor(c.r,c.g,c.b) end end
    end
    f.page:SetText("Page "..self.rollTablePage.."/"..pages.." — "..#sorted.." roll entries; valid SR > MS > OS, highest roll first")
    f.input:SetEnabled(not r);f.add:SetEnabled(not r)
    f.primary:SetText(not r and "View delivery" or (not r.closed and "Stop rolls" or (#r.winners>1 and "Reroll tied players" or (#r.winners==0 and "No eligible rolls" or "Award winner"))))
    f.primary:SetEnabled(not r or not r.closed or #r.winners>0)
    f.status:SetTextColor(r and r.closed and .55 or .90,r and r.closed and .87 or .91,r and r.closed and .65 or .93)
    if self.rollTablePage==1 and sorted[1] and sorted[1].valid then
        f.rows[1][2]:SetTextColor(1,.82,.25)
    end
    if force or (r and self.shownLeaderKey~=f.key) then self.shownLeaderKey=f.key;f:Show() end
end
local render=S.Render
function S:Render(...) render(self,...);self:RenderLeaderRolls() end
