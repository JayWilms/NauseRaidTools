local _,S=...
local A=S.base
local function invoke(db,key,...)
    if not db or type(db[key])~="function" then return end
    local ok,value=pcall(db[key],db,...);if ok then return value end
end
function S:ScopeAllows(session,id)
    if not session.selectedInstances then return true end
    local sources=invoke(A:ItemLibrary(),"GetSources",id)
    if type(sources)~="table" then return false end
    for _,source in ipairs(sources) do if session.selectedInstances[source.instance] then return true end end
    return false
end
local reserve=S.Reserve
function S:Reserve(session,player,items,source)
    local clean,why=self:Items(items,session.limit);if not clean then return false,why end
    for _,id in ipairs(clean) do if not self:ScopeAllows(session,id) then return false,"Item "..id.." has no known source in this run's selected instances." end end
    return reserve(self,session,player,items,source)
end
local apply=S.ApplyPreview
function S:ApplyPreview(session,preview)
    if preview then for _,row in ipairs(preview.rows) do for _,id in ipairs(row.items) do
        if not self:ScopeAllows(session,id) then return false,"Import contains an item outside the selected instances: "..id end
    end end end
    return apply(self,session,preview)
end
local new=S.New
function S:New(owner,id,limit)
    local s,why=new(self,owner,id,limit)
    if s and self.pendingInstances then s.selectedInstances=A.Copy(self.pendingInstances) end
    return s,why
end
local valid=S.ValidSnapshot
function S:ValidSnapshot(s)
    if not valid(self,s) then return false end
    if s.selectedInstances then
        if type(s.selectedInstances)~="table" then return false end
        local n=0;for name,value in pairs(s.selectedInstances) do n=n+1;if n>50 or type(name)~="string" or #name>200 or value~=true then return false end end
        if n==0 then return false end
    end
    return true
end
local results=S.BrowserResults
function S:BrowserResults(instance,boss,query)
    local rows=results(self,instance,boss,query)
    if not self.session or not self.session.selectedInstances then return rows end
    local out={};for _,entry in ipairs(rows) do if self:ScopeAllows(self.session,entry.id) then out[#out+1]=entry end end
    return out
end
local options=S.BrowserOptions
function S:BrowserOptions(instance)
    local rows=options(self,instance)
    if instance or not self.session or not self.session.selectedInstances then return rows end
    local out={};for _,name in ipairs(rows) do if self.session.selectedInstances[name] then out[#out+1]=name end end
    return out
end
local use=S.UseBrowserInstance
function S:UseBrowserInstance()
    if self.session and self.session.selectedInstances then return false,"Run instances are fixed at setup. The selector only changes your browsing filter." end
    return use(self)
end
local show=S.ShowBrowser
function S:ShowBrowser(...)
    if self.session and self.session.selectedInstances and not self.session.selectedInstances[self.browserInstance] then self.browserInstance=nil end
    show(self,...)
    self.browser.useForRun:SetShown(not (self.session and self.session.selectedInstances))
    if self.session and self.session.selectedInstances then
        self.browser.help:SetText("Use + / − to choose items across the selected content. Submit saves your choices.")
    end
end
local choose=S.ChooseRun
function S:ConfirmPugSetup()
    local ok,why=self:CanChooseRun();if not ok then return false,why end
    local selected=self.setupSelection or {};local n=0
    for name in pairs(selected) do if not self.setupKnown[name] then return false,"Refresh the instance list." end;n=n+1 end
    if n<1 then return false,"Select at least one dungeon or raid." end
    if n>50 then return false,"Select at most 50 instances." end
    local limit=tonumber(self.setup.limit:GetText())
    if not self.Integer(limit,1,6) then return false,"Choose 1–6 shared reserves per player." end
    self.pendingInstances=selected
    local worked,started,message=pcall(choose,self,"PuG Run",limit)
    self.pendingInstances=nil
    if not worked then self:Print("PuG setup could not complete; inspect the active session before retrying.");return false end
    if not started then return false,message end
    self.popupSessions=self.popupSessions or {};self.popupSessions[self.session.id]=true
    self.setup:Hide();self:Print("PuG Run started. "..limit.." shared reserves per player across "..n.." selected instances.")
    return true
end
function S:RefreshPugSetup()
    local rows=invoke(A:ItemLibrary(),"GetInstances")
    self.setupInstances={};self.setupKnown={}
    for _,row in ipairs(type(rows)=="table" and rows or {}) do
        if type(row.name)=="string" and not self.setupKnown[row.name] then self.setupKnown[row.name]=true;self.setupInstances[#self.setupInstances+1]=row.name end
    end
    table.sort(self.setupInstances);self:RenderPugSetup()
end
function S:RenderPugSetup()
    local f=self.setup;if not f then return end
    local rows=self.setupInstances or {};local pages=math.max(1,math.ceil(#rows/10));self.setupPage=math.min(self.setupPage or 1,pages)
    for i,b in ipairs(f.rows) do local name=rows[(self.setupPage-1)*10+i];b.instance=name;b:SetShown(name~=nil);if name then b:SetText((self.setupSelection[name] and "[X] " or "[ ] ")..name) end end
    local selected={};for name in pairs(self.setupSelection or {}) do selected[#selected+1]=name end;table.sort(selected)
    f.status:SetText(#rows==0 and "Loot catalogue unavailable. Enable AtlasLoot Forever with Dungeons and Raids, or ItemDB, then Refresh." or ("Page "..self.setupPage.."/"..pages.." — "..#selected.." selected"))
    f.selected:SetText(table.concat(selected,", "))
end
function S:ShowPugSetup(limit)
    local ok,why=self:CanChooseRun();if not ok then self:Print(why);return false,why end
    if not self.setup then
        local f=S:CreateUIFrame("Frame","NausePugSetup",UIParent,"BasicFrameTemplateWithInset");self.setup=f
        f:SetSize(620,575);f:SetPoint("CENTER");f:SetFrameStrata("DIALOG");f:SetClampedToScreen(true)
        if f.TitleText then f.TitleText:SetText("Nause Raid Tools - SR Setup") end
        table.insert(UISpecialFrames,"NausePugSetup")
        local function label(y) local l=f:CreateFontString(nil,"OVERLAY","GameFontNormal");l:SetPoint("TOPLEFT",20,y);l:SetWidth(575);l:SetJustifyH("LEFT");return l end
        label(-40):SetText("Select every instance included in this run. The reservation limit is shared.")
        f.status=label(-69);f.rows={}
        local function button(text,x,y,w,fn)
            local b=S:CreateUIFrame("Button",nil,f,"UIPanelButtonTemplate");b:SetSize(w,25);b:SetPoint("TOPLEFT",x,y);b:SetText(text)
            b:SetScript("OnClick",function() local yes,message=fn();if message then S:Print(message) end;S:RenderPugSetup() end);return b
        end
        for i=1,10 do f.rows[i]=button("",20,-95-(i-1)*27,575,function() local name=f.rows[i].instance;if name then S.setupSelection[name]=not S.setupSelection[name] or nil end;return true end) end
        button("Previous",20,-372,100,function() S.setupPage=math.max(1,S.setupPage-1);return true end)
        button("Next",125,-372,100,function() S.setupPage=S.setupPage+1;return true end)
        button("Refresh",230,-372,100,function() S:RefreshPugSetup();return true end)
        label(-410):SetText("Shared reserves per player (1–6):")
        f.limit=S:CreateUIFrame("EditBox",nil,f,"InputBoxTemplate");f.limit:SetSize(40,24);f.limit:SetPoint("TOPLEFT",360,-405);f.limit:SetAutoFocus(false);f.limit:SetNumeric(true);f.limit:SetMaxLetters(1)
        f.selected=label(-440)
        button("Confirm and open reservations",20,-515,360,function() return S:ConfirmPugSetup() end)
        button("Cancel",400,-515,195,function() f:Hide();return true end)
    end
    self.setupSelection={};self.setupPage=1;self.setup.limit:SetText(tostring(limit or 1))
    self:RefreshPugSetup();self.setup:Show()
    if self.runChooser then self.runChooser:Hide() end
    return true
end
function S:ChooseRun(mode,limit)
    if mode=="PuG Run" then return self:ShowPugSetup(limit) end
    return choose(self,mode,limit)
end
local packet=A.Packet
function A:Packet(sender,p)
    packet(self,sender,p)
    local session=S.session
    if session and session.selectedInstances and not session.locked and session.owner==self.leader then
        S.popupSessions=S.popupSessions or {}
        if not S.popupSessions[session.id] then S.popupSessions[session.id]=true;S:ShowBrowser() end
    end
end

local command=S.Command
function S:Command(text)
    local amount=text:match("^new%s*(%d*)%s*$")
    if amount then return self:ShowPugSetup(tonumber(amount) or 1) end
    return command(self,text)
end
local events=S:CreateUIFrame("Frame")
for _,event in ipairs({"GROUP_ROSTER_UPDATE","PLAYER_ENTERING_WORLD"}) do events:RegisterEvent(event) end
local queued=false
events:SetScript("OnEvent",function()
    if queued or not C_Timer or type(C_Timer.After)~="function" then return end
    queued=true;C_Timer.After(2,function()
        queued=false
        if A.Client:InRaid() and A.leader then
            if S:IsHost() then S:Publish() else S:Send("sync",{},A.leader) end
        end
    end)
end)
