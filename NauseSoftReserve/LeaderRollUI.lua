local _,S=...
local A=S.base
function S:LatestAward()
    for i=#(self.session and self.session.history or {}),1,-1 do
        local award=self.session.history[i]
        if award.id and award.status~="cancelled" then return award end
    end
end
function S:LeadingRollPlayers(rows)
    local top=rows[1];local names,seen={},{}
    if top and top.valid then
        for _,entry in ipairs(rows) do
            if entry.valid and entry.tier==top.tier and entry.value==top.value and not seen[entry.player] then
                seen[entry.player]=true;names[#names+1]=entry.player
            end
        end
    end
    table.sort(names);return names
end
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
        f.icon=f:CreateTexture(nil,"ARTWORK");f.icon:SetPoint("TOPLEFT",20,-92);f.icon:SetSize(36,36)
        f.item=label(f,64,-92,766);f.item:SetHeight(22);f.item:SetMaxLines(1);f.item:SetWordWrap(false)
        f.status=label(f,64,-118,766);f.status:SetHeight(20);f.status:SetMaxLines(1);f.status:SetWordWrap(false)
        f.explanation=label(f,20,-208,810,"GameFontHighlightSmall");f.explanation:SetHeight(28);S:SetTextRole(f.explanation,"muted")
        f.primary=S:UIButton(f,"Stop rolls",20,-526,210,function()
            local round=S.session and S.session.round
            if round and not round.closed then return S:Command("close") end
            if round and #round.winners>1 then return S:Command("reroll") end
            if round then return S:Command("record") end
            local award=S:LatestAward();return S:ShowAwardQueue(award and award.id)
        end,true)
        f.input=S:CreateUIFrame("EditBox",nil,f,"InputBoxTemplate");f.input:SetPoint("TOPLEFT",20,-174);f.input:SetSize(485,24);f.input:SetAutoFocus(false)
        f.input:SetScript("OnEscapePressed",function(e) e:ClearFocus() end)
        self:UIPlaceholder(f.input,"Item ID or item link")
        f.add=button("Add item",530,-174,135,function() return S:Command("roll "..f.input:GetText()) end)
        f.stop=button("Stop rolls",680,-174,135,function() return S:Command("close") end);f.stop:Hide()
        local headers={"Player","Roll","Type","Has SR","Note"};local xs={20,280,345,410,480};local ws={250,60,60,65,335}
        for i,text in ipairs(headers) do local header=label(f,xs[i],-244,ws[i]);header:SetText(text);S:SetTextRole(header,"heading") end
        f.scroll=self:CreateUIFrame("ScrollFrame",nil,f,"UIPanelScrollFrameTemplate");f.scroll:SetPoint("TOPLEFT",20,-266);f.scroll:SetSize(788,229)
        f.content=self:CreateUIFrame("Frame",nil,f.scroll);f.content:SetSize(788,1);f.scroll:SetScrollChild(f.content)
        f.scroll:HookScript("OnVerticalScroll",function(_,offset) if not S.rollScrollRendering then S.rollScrollOffset=offset;S:RenderLeaderRolls() end end)
        f.rows={};local innerX={0,260,325,390,460};ws[5]=320
        for i=1,11 do
            local row={};f.rows[i]=row
            row.frame=S:CreateUIFrame("Frame",nil,f.content);row.frame:SetSize(788,24);row.frame:EnableMouseWheel(true)
            row.frame:SetScript("OnMouseWheel",function(_,delta) local fn=f.scroll:GetScript("OnMouseWheel");if fn then fn(f.scroll,delta) end end)
            row.shade=row.frame:CreateTexture(nil,"BACKGROUND");row.shade:SetAllPoints()
            for col=1,5 do
                row[col]=label(row.frame,innerX[col],-4,ws[col],"GameFontHighlightSmall")
                row[col]:SetHeight(18);row[col]:SetMaxLines(1);row[col]:SetWordWrap(false)
            end
        end
        f.page=label(f,20,-503,810,"GameFontHighlightSmall");S:SetTextRole(f.page,"muted")
        f.award=f.primary
        f.cancel=button("Clear / cancel item",245,-526,180,function() return S:Command("cancel") end)
        button("Awards",635,-526,195,function() S:ShowAwardQueue();return true end)
        f.ms=button("MS",20,-570,115,function() return S:ClickNativeRoll("MS",f.key) end)
        f.os=button("OS",145,-570,115,function() return S:ClickNativeRoll("OS",f.key) end)
        f.pass=button("Pass",270,-570,115,function() if f.key~=S:RollKey() then return false,"Item changed." end;return S:Request("pass") end)
        local help=label(f,405,-577,410);help:SetText("One roll window. Repeats are shown; invalid rolls cannot win.");S:SetTextRole(help,"muted")
        f.itemHover=S:CreateUIFrame("Frame",nil,f);f.itemHover:SetPoint("TOPLEFT",20,-88);f.itemHover:SetSize(810,48);f.itemHover:EnableMouse(true)
        f.itemHover:SetScript("OnEnter",function() if f.link and GameTooltip then GameTooltip:SetOwner(f.itemHover,"ANCHOR_RIGHT");GameTooltip:SetHyperlink(f.link);GameTooltip:Show() end end)
        f.itemHover:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
    end
    local f=self.leaderRollUI;f.key=self:RollKey()
    if self.rollUI then self.rollUI:Hide() end
    local last=self:LatestAward();local item=r and r.item or (last and last.item)
    local link;local db=A.ItemLibrary and A:ItemLibrary()
    if item and db and type(db.GetLink)=="function" then local ok,v=pcall(db.GetLink,db,item);if ok then link=v end end
    f.link=item and (link or ("item:"..item));f.item:SetFontObject(item and "GameFontNormalLarge" or "GameFontHighlight")
    f.item:SetText(item and self:ReservationItemText(item,link) or "Queue loot or add an item to start rolling.")
    local ok,icon;if item then ok,icon=A.Client:Call("C_Item.GetItemIconByID",item) end
    f.icon:SetShown(item~=nil);f.icon:SetTexture(ok and icon or "Interface/Icons/INV_Misc_QuestionMark")
    local sorted=self:RankedRolls(s,A.roster);local leaders=self:LeadingRollPlayers(sorted);local top=sorted[1]
    local status,explanation,role
    if not r then
        status=last and ("AWARDED: "..self:PlayerText(last.winner).." — "..last.tier.." "..last.roll.." · "..self:AwardStatusText(last.status)) or "No active item"
        explanation=last and "Award recorded. View delivery opens this award; delivery is tracked separately." or "Queue an item from Loot, or enter an item ID/link above. Only one item rolls at a time."
        role=last and "ready" or "muted"
    elseif r.closed then
        if #r.winners>1 then
            status="TIED: "..self:RollWinnerText(r.winners,2).." — "..r.tier.." "..r.best
            explanation="Start a tie-break for these "..#r.winners.." players. Each gets one roll; other players cannot enter."
            role="attention"
        elseif #r.winners==1 then
            status="WINNER: "..self:PlayerText(r.winners[1]).." — "..r.tier.." "..r.best
            explanation="Review the winner, then Award winner. Confirming records the award; delivery is tracked separately."
            role="ready"
        else
            status="No eligible winner";explanation="No valid rolls remain. Clear/cancel this item, then queue it again if needed.";role="attention"
        end
    else
        status=(r.tiebreak and "TIE-BREAK" or "ROLLING")..(#leaders>0 and ((#leaders>1 and " · Leading tie: " or " · Leading: ")..self:RollWinnerText(leaders,2).." — "..top.tier.." "..top.value) or " · Waiting for eligible rolls")
        if r.tiebreak then
            local tied={};for name in pairs(r.tiePool) do tied[#tied+1]=name end;table.sort(tied)
            explanation="Tied players: "..self:RollWinnerText(tied,3)..". One roll each with /roll "..(r.tier=="OS" and 99 or 100).."."
        else explanation="Priority: Soft Reserve > Main Spec > Off Spec. Reservers get one roll per reserve; their best valid roll counts." end
        role=r.tiebreak and "attention" or "body"
    end
    f.status:SetText(status);self:SetTextRole(f.status,role);f.explanation:SetText(explanation)
    local scrollKey=self:RollKey() or ("idle:"..s.id)
    if self.rollScrollKey~=scrollKey then self.rollScrollKey=scrollKey;self.rollScrollOffset=0 end
    self.rollScrollRendering=true
    local first;first,self.rollScrollOffset=self:UpdateListScroll(f.scroll,f.content,#sorted,25,self.rollScrollOffset)
    local winners={};if r and r.closed then for _,name in ipairs(r.winners) do winners[name]=true end end
    for i,row in ipairs(f.rows) do
        local entry=sorted[first+i-1]
        row.frame:SetShown(entry~=nil);row.frame:ClearAllPoints();row.frame:SetPoint("TOPLEFT",0,-(first+i-2)*25)
        local leading=entry and entry.valid and top and entry.tier==top.tier and entry.value==top.value
        local note
        if entry then
            if not entry.valid then note="Invalid · "..entry.note
            elseif r.closed and winners[entry.player] and leading then note=#r.winners>1 and "Tied · Reroll required" or "Winner · Ready to award"
            elseif leading then note=#leaders>1 and "Tied for lead" or "Leading"
            elseif entry.tier=="SR" then note="Eligible · Soft reserve"
            elseif entry.tier=="MS" then note="Eligible · Behind valid SR rolls"
            else note="Eligible · Behind valid SR and MS rolls" end
        end
        local texts=entry and {entry.player..(entry.additional>0 and (" (roll "..(entry.additional+1)..")") or ""),tostring(entry.value),entry.tier,entry.hasSR and "Yes" or "—",note} or {"","","","",""}
        for col,l in ipairs(row) do l:SetText(texts[col]);self:SetTextRole(l,entry and entry.valid and "body" or "muted") end
        if entry then local c=S:PlayerPresentation(entry.player);if c and entry.valid then row[1]:SetTextColor(c.r,c.g,c.b) end end
        if leading then self:SetTextRole(row[2],"heading");row.shade:SetColorTexture(.32,.26,.10,.45)
        else row.shade:SetColorTexture(1,1,1,entry and (i%2==0 and .045 or .015) or 0) end
    end
    self.rollScrollRendering=nil
    f.page:SetText(#sorted.." roll entries · Scroll to browse · Valid SR > MS > OS, highest roll first")
    f.input:SetEnabled(not r);f.add:SetEnabled(not r);f.cancel:SetEnabled(r~=nil)
    f.primary:SetText(not r and (last and "View delivery" or "Queue an item") or (not r.closed and "Stop rolls" or (#r.winners>1 and "Reroll tied players" or (#r.winners==0 and "No eligible rolls" or "Award winner"))))
    f.primary:SetEnabled(not r and last~=nil or (r~=nil and (not r.closed or #r.winners>0)))
    if force or (r and self.shownLeaderKey~=f.key) then self.shownLeaderKey=f.key;f:Show() end
end
local render=S.Render
function S:Render(...) render(self,...);self:RenderLeaderRolls() end
