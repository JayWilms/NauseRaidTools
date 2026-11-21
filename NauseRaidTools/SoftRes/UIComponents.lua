local _, namespace = ...
local S = namespace.SoftRes or namespace
local A=S.base
S.uiColors={body={.90,.91,.93},muted={.60,.63,.68},heading={1,.82,.25},attention={1,.72,.35},ready={.58,.78,.65}}
function S:SetTextRole(label,role)
    local c=self.uiColors[role] or self.uiColors.body;label:SetTextColor(c[1],c[2],c[3])
end
function S:ColoredText(text,role)
    local c=self.uiColors[role] or self.uiColors.body
    return string.format("|cff%02x%02x%02x%s|r",math.floor(c[1]*255+.5),math.floor(c[2]*255+.5),math.floor(c[3]*255+.5),text)
end
function S:PlayerText(name)
    if not name then return self:ColoredText("Not reported","muted") end
    local c=self:PlayerPresentation(name)
    name=self:DisplayPlayerName(name)
    if c then return string.format("|cff%02x%02x%02x%s|r",math.floor(c.r*255+.5),math.floor(c.g*255+.5),math.floor(c.b*255+.5),name) end
    return self:ColoredText(name,"body")
end
function S:AwardStatusText(status)
    if status=="pending" then return self:ColoredText("Awarded · Awaiting delivery","attention") end
    if status=="delivered" then return self:ColoredText("Delivered","ready") end
    if status=="cancelled" then return self:ColoredText("Cancelled","muted") end
    return self:ColoredText(status or "Unknown status","muted")
end
function S:ReservationItemText(id,fallback)
    local ok,name,link,quality=A.Client:Call("C_Item.GetItemInfo",id)
    local entry=self.catalogue and self.catalogue[id]
    if not ok or type(name)~="string" or name=="" then name=entry and entry.name;link=entry and entry.link end
    if not name then
        self.setupItemPending=self.setupItemPending or {}
        if not self.setupItemPending[id] then
            self.setupItemPending[id]=true
            if C_Item and type(C_Item.RequestLoadItemDataByID)=="function" then pcall(C_Item.RequestLoadItemDataByID,id) end
        end
    end
    local text=link or fallback or name or ("Item "..id)
    local color=ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    if color and color.hex and not text:find("|c",1,true) then text=color.hex..text.."|r" end
    return text
end

function S:UILabel(parent,text,x,y,width,heading)
    local t=parent:CreateFontString(nil,"OVERLAY",heading and "GameFontNormal" or "GameFontHighlightSmall")
    t:SetPoint("TOPLEFT",x,y);t:SetWidth(width);t:SetJustifyH("LEFT");t:SetText(text)
    self:SetTextRole(t,heading and "heading" or "body")
    return t
end
function S:UIButton(parent,text,x,y,width,fn,primary)
    local b=self:CreateUIFrame("Button",nil,parent,"UIPanelButtonTemplate");b:SetPoint("TOPLEFT",x,y);b:SetSize(width,26);b:SetText(text)
    if primary then b:SetBackdropBorderColor(.75,.57,.18,1);b:SetBackdropColor(.19,.16,.09,1) end
    b:SetScript("OnClick",function() local ok,why=fn();if why then S:Print(why) end;return ok end)
    return b
end
function S:UIDropdownButton(parent,text,x,y,width,fn)
    local b=self:UIButton(parent,text,x,y,width,fn)
    local arrow=b:CreateTexture(nil,"ARTWORK");arrow:SetTexture("Interface\\AddOns\\NauseRaidTools\\Assets\\Chevron")
    arrow:SetSize(12,12);arrow:SetPoint("RIGHT",-9,0);arrow:SetVertexColor(.78,.80,.84,1)
    local caption=b:GetFontString()
    if caption then caption:ClearAllPoints();caption:SetPoint("LEFT",8,0);caption:SetPoint("RIGHT",-30,0);caption:SetJustifyH("LEFT") end
    return b
end
function S:UpdateListScroll(scroll,content,count,stride,offset)
    local height=math.max(1,count*stride);content:SetHeight(height)
    local maximum=math.max(0,height-scroll:GetHeight())
    offset=math.max(0,math.min(offset or 0,maximum));scroll:SetVerticalScroll(offset)
    if A.RefreshScrollChrome then A:RefreshScrollChrome(scroll) end
    return math.floor(offset/stride)+1,offset
end
function S:UISection(parent,y,width)
    local line=parent:CreateTexture(nil,"ARTWORK");line:SetPoint("TOPLEFT",20,y);line:SetSize(width or 810,1)
    line:SetColorTexture(.20,.22,.26,1);return line
end
function S:SelectMenu(owner,choices,fn)
    if not A.ui then A:BuildUI() end
    A:OpenSettingsDropdown(owner,choices,fn,250)
end
function S:PlayerPresentation(name)
    local unit=A.roster[name];local offline=not unit;local color
    if type(unit)=="string" then
        local ok,connected=A.Client:Call("UnitIsConnected",unit)
        offline=ok and (connected==false or connected==0) or false
        local valid,_,class=A.Client:Call("UnitClass",unit)
        if valid and RAID_CLASS_COLORS then color=RAID_CLASS_COLORS[class] end
    end
    return color,offline
end
function S:RefreshManagerNavigation()
    local host=self:IsHost();local canViewLoot=host
    for _,entry in ipairs(self.session and self.session.lootEntries or {}) do
        if entry.holder==A.me then canViewLoot=true;break end
    end
    for frame in pairs(self.managerFrames or {}) do
        local visible=0
        for i,b in ipairs(frame.srTabs) do
            local shown=host or i==2;b:SetShown(shown)
            if shown then
                b:ClearAllPoints();b:SetPoint("TOPLEFT",20+visible*155,-42);visible=visible+1
            end
        end
        frame.srLoot:SetEnabled(self.session~=nil and canViewLoot)
        frame.srTimer:SetEnabled(self.session~=nil)
        if not host and frame.srPage~="Reservations" then frame:Hide() end
    end
end
function S:InstallManagerNavigation(f,key)
    if f.srTabs then return end
    self.managerFrames=self.managerFrames or {};self.managerFrames[f]=true
    f.srTabs={};f.srPage=key
    if f.TitleText then f.TitleText:SetText("Nause Raid Tools - SoftRes - "..key) end
    local choices={{"Overview",function() return S:ShowPugSetup() end},{"Reservations",function() S:ShowBrowser();return true end},
        {"Rolls",function() return S:ShowResults() end},{"Awards",function() S:ShowAwardQueue();return true end}}
    for i,choice in ipairs(choices) do
        local b=self:UIButton(f,choice[1],20+(i-1)*155,-42,145,choice[2],choice[1]==key);f.srTabs[i]=b
        if choice[1]==key then b:SetDisabledFontObject("GameFontNormalSmall");b:SetEnabled(false) end
    end
    f.srLoot=self:UIButton(f,"Loot",640,-42,90,function() A:ShowLootWindow("timer");return true end)
    f.srTimer=self:UIButton(f,"Timer",740,-42,90,function() A:ShowLootTimers();return true end)
    self:UISection(f,-78)
    f:HookScript("OnShow",function()
        A:CloseSettingsDropdown()
        for other in pairs(S.managerFrames) do
            if other~=f and other:IsShown() then
                local point,relative,relativePoint,x,y=other:GetPoint()
                if point then f:ClearAllPoints();f:SetPoint(point,relative,relativePoint,x,y) end
                other:Hide()
            end
        end
        S:RefreshManagerNavigation()
    end)
    f:HookScript("OnHide",function() A:CloseSettingsDropdown() end)
end

function S:UIPlaceholder(edit,text)
    local hint=self:UILabel(edit,text,8,-6,edit:GetWidth()-16);hint:SetTextColor(.50,.53,.58)
    local function update() hint:SetShown(edit:GetText()=="") end
    edit:HookScript("OnTextChanged",update);update();return hint
end
