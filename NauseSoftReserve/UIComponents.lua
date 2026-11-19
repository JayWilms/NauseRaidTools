local _,S=...
local A=S.base
function S:ReservationItemText(id)
    local ok,name,link=A.Client:Call("C_Item.GetItemInfo",id)
    local entry=self.catalogue and self.catalogue[id]
    if not ok or type(name)~="string" or name=="" then name=entry and entry.name;link=entry and entry.link end
    if not name then
        self.setupItemPending=self.setupItemPending or {}
        if not self.setupItemPending[id] then
            self.setupItemPending[id]=true
            if C_Item and type(C_Item.RequestLoadItemDataByID)=="function" then pcall(C_Item.RequestLoadItemDataByID,id) end
        end
    end
    return link or name or ("Item "..id)
end

function S:UILabel(parent,text,x,y,width,heading)
    local t=parent:CreateFontString(nil,"OVERLAY",heading and "GameFontNormal" or "GameFontHighlightSmall")
    t:SetPoint("TOPLEFT",x,y);t:SetWidth(width);t:SetJustifyH("LEFT");t:SetText(text)
    if heading then t:SetTextColor(1,.82,.25) else t:SetTextColor(.90,.91,.93) end
    return t
end
function S:UIButton(parent,text,x,y,width,fn,primary)
    local b=self:CreateUIFrame("Button",nil,parent,"UIPanelButtonTemplate");b:SetPoint("TOPLEFT",x,y);b:SetSize(width,26);b:SetText(text)
    if primary then b:SetBackdropBorderColor(.75,.57,.18,1);b:SetBackdropColor(.19,.16,.09,1) end
    b:SetScript("OnClick",function() local ok,why=fn();if why then S:Print(why) end;return ok end)
    return b
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
function S:InstallManagerNavigation(f,key)
    if f.srTabs then return end
    self.managerFrames=self.managerFrames or {};self.managerFrames[f]=true
    f.srTabs={}
    local choices={{"Overview",function() return S:ShowPugSetup() end},{"Reservations",function() S:ShowBrowser();return true end},
        {"Rolls",function() return S:ShowResults() end},{"Awards",function() S:ShowAwardQueue();return true end}}
    for i,choice in ipairs(choices) do
        local b=self:UIButton(f,choice[1],20+(i-1)*155,-42,145,choice[2],choice[1]==key);f.srTabs[i]=b
        if choice[1]==key then b:SetEnabled(false) end
    end
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
        for i,b in ipairs(f.srTabs) do b:SetShown(S:IsHost() or i==2) end
    end)
    f:HookScript("OnHide",function() A:CloseSettingsDropdown() end)
end

function S:UIPlaceholder(edit,text)
    local hint=self:UILabel(edit,text,8,-6,edit:GetWidth()-16);hint:SetTextColor(.50,.53,.58)
    local function update() hint:SetShown(edit:GetText()=="") end
    edit:HookScript("OnTextChanged",update);update();return hint
end
