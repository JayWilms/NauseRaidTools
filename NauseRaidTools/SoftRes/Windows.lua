local _, namespace = ...
local S = namespace.SoftRes or namespace
local A=S.base
local function label(f,x,y,w)
    local l=f:CreateFontString(nil,"OVERLAY","GameFontNormal");l:SetPoint("TOPLEFT",x,y);l:SetWidth(w);l:SetJustifyH("LEFT");return l
end
local function window(name,title,w,h)
    local f=S:CreateUIFrame("Frame",name,UIParent,"BasicFrameTemplateWithInset")
    f:SetSize(w,h);f:SetPoint("CENTER");f:SetClampedToScreen(true);f:SetMovable(true);f:EnableMouse(true);f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart",f.StartMoving);f:SetScript("OnDragStop",f.StopMovingOrSizing)
    if f.TitleText then f.TitleText:SetText(title) end
    table.insert(UISpecialFrames,name);return f
end
local function button(f,text,x,y,w,fn)
    local b=S:CreateUIFrame("Button",nil,f,"UIPanelButtonTemplate");b:SetSize(w,26);b:SetPoint("TOPLEFT",x,y);b:SetText(text)
    b:SetScript("OnClick",function() local ok,why=fn();if why then S:Print(why) end;S:Render() end);return b
end
function S:CreateRosterRow(parent,index)
    local y=-(index-1)*62
    local row={name=self:UILabel(parent,"",0,y,440),state=self:UILabel(parent,"",470,y,310),items={}}
    for n=1,6 do
        local item=self:CreateUIFrame("Button",nil,parent);row.items[n]=item
        item:SetPoint("TOPLEFT",((n-1)%3)*260,y-18-math.floor((n-1)/3)*19);item:SetSize(250,18)
        item.icon=item:CreateTexture(nil,"ARTWORK");item.icon:SetPoint("LEFT");item.icon:SetSize(16,16)
        item.text=self:UILabel(item,"",20,0,230);item.text:SetHeight(18);item.text:SetWordWrap(false);item.text:SetMaxLines(1)
        item:SetScript("OnEnter",function(b)
            if b.itemID and GameTooltip then GameTooltip:SetOwner(b,"ANCHOR_RIGHT");GameTooltip:SetHyperlink("item:"..b.itemID);GameTooltip:Show() end
        end)
        item:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
        item:SetScript("OnHide",function(b) if GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(b) then GameTooltip:Hide() end end)
    end
    return row
end
function S:RenderSessionSetup()
    local f=self.sessionSetup;if not f then return end
    if not self:IsHost() then f:Hide();return end
    local s=self.session;local instances={}
    for name in pairs(s.selectedInstances or {}) do instances[#instances+1]=name end;table.sort(instances)
    f.status:SetText(self:ColoredText(s.locked and "Locked" or "Open",s.locked and "attention" or "ready").."  ·  "..s.limit.." reserves per player  ·  Host: "..self:PlayerText(s.owner))
    f.scope:SetText(#instances>0 and table.concat(instances,", ") or s.raidName or "Saved session")
    f.lock:SetText(s.locked and "Unlock reservations" or "Lock reservations");f.lock:SetEnabled(not s.round)
    local all,seen={},{};local total,submitted,offlineCount=0,0,0
    for name in pairs(s.reserves) do all[#all+1]=name;seen[name]=true end
    for name in pairs(A.roster) do
        if not seen[name] then all[#all+1]=name end
        total=total+1;if s.reserves[name] then submitted=submitted+1 end
    end
    table.sort(all);local names={};local filter=self.rosterFilter or "All"
    for _,name in ipairs(all) do
        local _,offline=self:PlayerPresentation(name)
        if A.roster[name] and offline then offlineCount=offlineCount+1 end
        if filter=="All" or (filter=="Missing" and A.roster[name] and not s.reserves[name])
            or (filter=="Submitted" and s.reserves[name]~=nil) or (filter=="Offline" and offline) then names[#names+1]=name end
    end
    f.summary:SetText(self:ColoredText(submitted.."/"..total.." submitted","ready").."   ·   "..self:ColoredText((total-submitted).." missing",total>submitted and "attention" or "muted").."   ·   "..self:ColoredText(offlineCount.." offline","muted"))
    for _,control in ipairs(f.filters) do control:SetEnabled(control.filter~=filter) end
    for i=1,math.max(#f.rows,#names) do
        local row=f.rows[i]
        if not row then row=self:CreateRosterRow(f.content,i);f.rows[i]=row end
        local name=names[i];local picks=name and s.reserves[name]
        local color,offline;if name then color,offline=self:PlayerPresentation(name) end
        row.name:SetText(name and self:DisplayPlayerName(name) or "");row.name:SetTextColor(color and color.r or .90,color and color.g or .91,color and color.b or .93)
        row.state:SetText(name and ((not A.roster[name] and self:ColoredText("Not in raid · ","muted") or offline and self:ColoredText("Offline · ","muted") or "")..(picks and ("Submitted · "..#picks.."/"..s.limit) or "Missing submission")) or "")
        self:SetTextRole(row.state,picks and "ready" or "attention")
        for n,item in ipairs(row.items) do
            local id=picks and picks[n]
            if item.itemID~=id and GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(item) then GameTooltip:Hide() end
            item.itemID=id;item:SetShown(id~=nil);item.text:SetText(id and self:ReservationItemText(id) or "")
            local ok,icon;if id then ok,icon=A.Client:Call("C_Item.GetItemIconByID",id) end
            item.icon:SetTexture(ok and icon or "Interface/Icons/INV_Misc_QuestionMark")
        end
    end
    f.content:SetHeight(math.max(1,#names*62));f.empty:SetShown(#names==0)
    f.empty:SetText(filter=="Missing" and "Everyone has submitted their reservations." or "No players match this filter.")
    f.page:SetText(#names.." players shown · Hover an item for details")
    local max=math.max(0,f.content:GetHeight()-f.scroll:GetHeight())
    f.scroll:SetVerticalScroll(math.min(f.scroll:GetVerticalScroll(),max));A:RefreshScrollChrome(f.scroll)
end
local setup=S.ShowPugSetup
function S:ShowPugSetup(limit)
    if not self.session then
        local ok,why=setup(self,limit)
        if ok then
            if self.setup.TitleText then self.setup.TitleText:SetText("Nause Raid Tools - SR Setup") end
            if not self.setup.resume then self.setup.resume=button(self.setup,"Resume saved session",20,-480,230,function() return S:Command("resume") end) end
        end
        return ok,why
    end
    if not self:IsHost() then return false,"Only the hosting raid leader can open SoftRes Setup." end
    if self.setup then self.setup:Hide() end
    if not self.sessionSetup then
        local f=window("NausePugSessionSetup","Nause Raid Tools - SR Setup",850,650);self.sessionSetup=f
        self:InstallManagerNavigation(f,"Overview")
        f.scope=self:UILabel(f,"",20,-92,810,true);f.scope:SetHeight(30);f.scope:SetMaxLines(2)
        f.status=self:UILabel(f,"",20,-128,810)
        f.summary=self:UILabel(f,"",20,-157,810)
        f.lock=button(f,"Lock reservations",20,-188,154,function() return S:Command(S.session.locked and "unlock" or "lock") end)
        f.lock:SetBackdropBorderColor(.75,.57,.18,1)
        button(f,"My reservations",184,-188,154,function() S:ShowBrowser();return true end)
        f.import=button(f,"Import Softres.it",348,-188,154,function() return S:ShowImport() end)
        f.refresh=button(f,"Sync session",512,-188,154,function() return S:Command("sync") end)
        f.announce=button(f,"Announce",676,-188,154,function() return S:AnnounceSession() end)
        self:UISection(f,-226)
        f.filters={}
        for i,name in ipairs({"All","Missing","Submitted","Offline"}) do
            local b=button(f,name,20+(i-1)*125,-239,115,function() S.rosterFilter=name;f.scroll:SetVerticalScroll(0);S:RenderSessionSetup();return true end)
            b.filter=name;f.filters[i]=b
        end
        f.announceMissing=button(f,"Announce Missing SRs",540,-239,290,function() return S:AnnounceMissingReservations() end)
        f.scroll=A:CreateScrollFrame(f);f.scroll:SetPoint("TOPLEFT",20,-278);f.scroll:SetSize(788,260)
        f.content=self:CreateUIFrame("Frame",nil,f.scroll);f.content:SetSize(788,1);f.scroll:SetScrollChild(f.content);f.rows={}
        f.empty=self:UILabel(f,"",30,-300,750)
        f.page=self:UILabel(f,"",20,-548,810);f.page:SetTextColor(.60,.63,.68)
        self:UISection(f,-578)
        local reopen=self:UILabel(f,"/nrt softres reopens your session window.",20,-604,600)
        self:SetTextRole(reopen,"muted")
        local endRun=button(f,"End session",650,-596,180,function() S:ShowConfirmation("NAUSE_SR_END_RUN");return true end)
        endRun:SetBackdropBorderColor(.50,.25,.25,1)
        local elapsed=0
        f:SetScript("OnUpdate",function(_,dt) elapsed=elapsed+dt;if elapsed>=1 then elapsed=0;S:RenderSessionSetup() end end)
    end
    self:RenderSessionSetup();self.sessionSetup:Show();return true
end
function S:ImportSessionCurrent()
    return self:IsHost() and self.importSessionID==self.session.id
end
function S:PreviewImport()
    if not self:ImportSessionCurrent() then return false,"Session changed. Reopen the import window." end
    local preview,why=self:Preview(self.importUI.input:GetText(),self.session,function(name) return A:Resolve(name) end)
    self.importPreview=preview;self:RenderImport();return preview~=nil,why
end
function S:ApplyImport()
    if not self:ImportSessionCurrent() then return false,"Session changed. Reopen the import window." end
    local ok,why=self:ApplyPreview(self.session,self.importPreview)
    if ok then self.importPreview=nil;self.importUI.input:SetText("");self:Publish() end
    self:RenderImport();return ok,why
end
function S:RenderImport()
    local f=self.importUI;if not f then return end
    if not self:ImportSessionCurrent() then self.importPreview=nil;f:Hide();return end
    local p=self.importPreview;local lines={"Paste the Softres.it Gargul export, then Preview. URLs alone cannot be imported."}
    if p then
        lines={"Preview — replaces picks for these players only:"}
        for _,row in ipairs(p.rows) do local ids={};for _,id in ipairs(row.items) do ids[#ids+1]=tostring(id) end
            lines[#lines+1]=self:DisplayPlayerName(row.player)..": "..table.concat(ids,", ")..(row.replaces and " [replaces existing]" or " [new]")
        end
        for _,issue in ipairs(p.issues) do lines[#lines+1]="BLOCKED: "..issue end
    end
    f.output:SetText(table.concat(lines,"\n"));f.child:SetHeight(math.max(200,f.output:GetStringHeight()+10))
    f.apply:SetEnabled(p~=nil and #p.issues==0 and p.revision==self.session.revision and not self.session.locked)
end
function S:ShowImport()
    if not self:IsHost() then return false,"Only the hosting raid leader can import reservations." end
    if not self.importUI then
        local f=window("NausePugImport","Nause Raid Tools - Import Reservations",720,500);self.importUI=f
        label(f,20,-42,675):SetText("Softres.it → Gargul export")
        local scroll=S:CreateUIFrame("ScrollFrame",nil,f,"UIPanelScrollFrameTemplate");scroll:SetPoint("TOPLEFT",20,-70);scroll:SetSize(660,130)
        f.input=S:CreateUIFrame("EditBox",nil,scroll);f.input:SetSize(645,130);f.input:SetMultiLine(true);f.input:SetFontObject("ChatFontNormal");f.input:SetAutoFocus(false);f.input:SetMaxLetters(65536);scroll:SetScrollChild(f.input)
        f.input:SetScript("OnEscapePressed",function(e) e:ClearFocus() end)
        f.input:SetScript("OnTextChanged",function() S.importPreview=nil;S:RenderImport() end)
        button(f,"Preview",20,-215,140,function() return S:PreviewImport() end)
        f.apply=button(f,"Apply preview",175,-215,150,function() return S:ApplyImport() end)
        button(f,"Clear",340,-215,120,function() S.importPreview=nil;f.input:SetText("");return true end)
        local out=S:CreateUIFrame("ScrollFrame",nil,f,"UIPanelScrollFrameTemplate");out:SetPoint("TOPLEFT",20,-260);out:SetSize(660,200)
        f.child=S:CreateUIFrame("Frame",nil,out);f.child:SetSize(645,200);out:SetScrollChild(f.child);f.output=label(f.child,0,0,640)
    end
    if self.importSessionID~=self.session.id then self.importPreview=nil;self.importUI.input:SetText("") end
    self.importSessionID=self.session.id;self:RenderImport();self.importUI:Show();return true
end
function S:ShowResults()
    if not self:IsHost() then return false,"Only the hosting raid leader can open Roll Results." end
    self:RenderLeaderRolls(true);return true
end
-- Replace the legacy all-in-one entry point. Raiders retain their own browser.
function S:Show()
    if self.ui then self.ui:Hide() end
    if A:IsLeader() then return self:ShowPugSetup() end
    self:ShowBrowser();return true
end
local confirm=S.ConfirmPugSetup
function S:ConfirmPugSetup(...)
    local ok,why=confirm(self,...)
    if ok then self:ShowPugSetup() end
    return ok,why
end
local render=S.Render
function S:Render(...)
    render(self,...);self:RenderSessionSetup();self:RenderImport()
end
local command=S.Command
function S:Command(text)
    if text:match("^%s*resume%s*$") then
        local ok,why=command(self,text);if ok then self:ShowPugSetup() end;return ok,why
    end
    return command(self,text)
end
