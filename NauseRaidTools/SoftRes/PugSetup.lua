local _, namespace = ...
local S = namespace.SoftRes or namespace
local A=S.base
local function invoke(db,key,...)
    if not db or type(db[key])~="function" then return end
    local ok,value=pcall(db[key],db,...);if ok then return value end
end
function S:ScopeAllows(session,id)
    if not session.selectedInstances then return true end
    local shared=self.catalogueHostSID==session.id and self.catalogue and self.catalogue[id]
    local sources=shared and shared.sources or invoke(A:ItemLibrary(),"GetSources",id)
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
local preview=S.Preview
function S:Preview(text,session,resolve)
    local result,why=preview(self,text,session,resolve)
    if result and session.selectedInstances then
        for _,row in ipairs(result.rows) do for _,id in ipairs(row.items) do
            if not self:ScopeAllows(session,id) then result.issues[#result.issues+1]="Item "..id.." is outside the selected dungeons/raids." end
        end end
    end
    return result,why
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
    local worked,started,message=pcall(choose,self,"SoftRes Run",limit)
    self.pendingInstances=nil
    if not worked then self:Print("SoftRes setup could not complete; inspect the active session before retrying.");return false end
    if not started then return false,message end
    self.popupSessions=self.popupSessions or {};self.popupSessions[self.session.id]=true
    self.setup:Hide();self:Print("SoftRes Run started. "..limit.." shared reserves per player across "..n.." selected instances.")
    return true
end
local levelFilters={{"All level ranges","all"},{"Levels 10-19",10},{"Levels 20-29",20},{"Levels 30-39",30},{"Levels 40-49",40},{"Levels 50-59",50},{"Levels 60+",60},{"Level unavailable","unknown"}}
local function levelKey(name)
    return tostring(name or ""):lower():gsub("^the%s+",""):gsub("[^%w]",""):gsub("stormwindstockades","stockade"):gsub("stockades$","stockade"):gsub("alcazislandprison","alcazprison")
end
function S:ReadSetupLevelRange(row)
    local low,high=tonumber(row.minLevelSuggestion),tonumber(row.maxLevelSuggestion)
    if not self.Integer(low,1,1000) then low=tonumber(row.minLevel) end
    if not self.Integer(high,1,1000) then high=tonumber(row.maxLevel) end
    if not self.Integer(low,1,1000) then low=nil end
    if not self.Integer(high,1,1000) then high=nil end
    local range=row.levelRange
    if type(range)=="string" then local a,b=range:match("(%d+)%D+(%d+)");low=low or tonumber(a);high=high or tonumber(b)
    elseif type(range)=="table" then
        if range[3]~=nil then
            -- AtlasLoot: { minimum entry, recommended minimum, recommended maximum }.
            -- Match ContentProto:GetName(), which displays values 2 and 3.
            low,high=tonumber(range[2]),tonumber(range[3])
        else low=low or tonumber(range[1]);high=high or tonumber(range[2]) end
    end
    local raid=row.isRaid==true or (tonumber(row.maxNumPlayers) or 0)>5
    if self.Integer(low,1,1000) and not self.Integer(high,1,1000) and raid then high=low end
    if self.Integer(low,1,1000) and self.Integer(high,low,1000) then return {min=low,max=high,raid=raid} end
end
function S:NativeSetupLevelInfo()
    local names,maps={},{}
    local function merge(target,key,range)
        if not key then return end
        local old=target[key]
        if old then old.min=math.min(old.min,range.min);old.max=math.max(old.max,range.max);old.raid=old.raid or range.raid
        else target[key]={min=range.min,max=range.max,raid=range.raid} end
    end
    -- Read the client's activity suggestions, without joining or filtering a queue.
    -- Forever's raid category is 114; 3 supports clients using the older category.
    for _,category in ipairs({2,114,3}) do
        local ok,ids=A.Client:Call("C_LFGList.GetAvailableActivities",category)
        for _,id in ipairs(ok and type(ids)=="table" and ids or {}) do
            local valid,info=A.Client:Call("C_LFGList.GetActivityInfoTable",id)
            local range=valid and type(info)=="table" and self:ReadSetupLevelRange(info)
            if range then
                range.raid=range.raid or category~=2
                if type(info.fullName)=="string" then merge(names,levelKey(info.fullName),range) end
                if type(info.shortName)=="string" and info.shortName~="" then merge(names,levelKey(info.shortName),range) end
                if self.Integer(info.mapID,1,1000000) then merge(maps,info.mapID,range) end
            end
        end
    end
    return names,maps
end
function S:RefreshPugSetup()
    local rows=invoke(A:ItemLibrary(),"GetInstances");local names,maps=self:NativeSetupLevelInfo()
    local atlasLevels={};local atlas=self.AtlasItemLibrary and self:AtlasItemLibrary()
    for _,row in ipairs(invoke(atlas,"GetInstances") or {}) do
        local range=self:ReadSetupLevelRange(row)
        if range then atlasLevels[levelKey(row.name)]=range end
    end
    self.setupInstances={};self.setupKnown={};self.setupLevels={}
    for _,row in ipairs(type(rows)=="table" and rows or {}) do
        if type(row)=="table" and type(row.name)=="string" and not self.setupKnown[row.name] then
            self.setupKnown[row.name]=true;self.setupInstances[#self.setupInstances+1]=row.name
            local key=levelKey(row.name)
            local range=atlasLevels[key] or self:ReadSetupLevelRange(row) or maps[row.mapID] or names[key]
            if not range and #key>=8 then
                -- A catalogue can combine wings that the game lists separately.
                for activity,value in pairs(names) do if activity:sub(1,#key)==key then
                    if range then range.min=math.min(range.min,value.min);range.max=math.max(range.max,value.max);range.raid=range.raid or value.raid
                    else range={min=value.min,max=value.max,raid=value.raid} end
                end end
            end
            self.setupLevels[row.name]=range
        end
    end
    table.sort(self.setupInstances,function(a,b)
        local x,y=self.setupLevels[a],self.setupLevels[b]
        if (x and x.min or 10000)~=(y and y.min or 10000) then return (x and x.min or 10000)<(y and y.min or 10000) end
        if (x and x.max or 10000)~=(y and y.max or 10000) then return (x and x.max or 10000)<(y and y.max or 10000) end
        return a<b
    end)
    self:RenderPugSetup()
end
function S:SetupInstanceLabel(name)
    local range=self.setupLevels and self.setupLevels[name]
    return (range and ((range.min==range.max and ("Level "..range.min) or ("Levels "..range.min.."-"..range.max)).." · ") or "Level unavailable · ")..name..(range and range.raid and " (Raid)" or "")
end
function S:FilteredSetupInstances()
    local rows={};local filter=self.setupLevelFilter or "all"
    for _,name in ipairs(self.setupInstances or {}) do
        local range=self.setupLevels and self.setupLevels[name]
        if filter=="all" or (filter=="unknown" and not range)
            or (type(filter)=="number" and range and range.min<=(filter==60 and 1000 or filter+9) and range.max>=filter) then rows[#rows+1]=name end
    end
    return rows
end
function S:OpenSetupInstanceMenu()
    local f=self.setup;local choices={}
    for _,name in ipairs(self:FilteredSetupInstances()) do choices[#choices+1]={((self.setupSelection or {})[name] and "[x] " or "[ ] ")..self:SetupInstanceLabel(name),name} end
    if #choices==0 then return false,"No dungeons/raids match this level range. Choose another range or Refresh." end
    if not A.ui then A:BuildUI() end
    A:OpenSettingsDropdown(f.instance,choices,function(name)
        if S.setupKnown[name] then S.setupSelection[name]=not S.setupSelection[name] or nil;S:RenderPugSetup() end
    end,575)
    return true
end
function S:RenderPugSetup()
    local f=self.setup;if not f then return end
    local rows=self:FilteredSetupInstances();local selected={}
    for _,name in ipairs(self.setupInstances or {}) do if (self.setupSelection or {})[name] then selected[#selected+1]=self:SetupInstanceLabel(name) end end
    local filterName="All level ranges";for _,row in ipairs(levelFilters) do if row[2]==(self.setupLevelFilter or "all") then filterName=row[1] end end
    f.levelRange:SetText(filterName);f.instance:SetText(#rows==0 and "No matching dungeons/raids" or "Choose dungeons / raids")
    f.instance:SetEnabled(#rows>0);f.clear:SetEnabled(next(self.setupSelection or {})~=nil)
    f.status:SetText(#(self.setupInstances or {})==0 and "Loot catalogue unavailable. Enable AtlasLoot Forever with Dungeons and Raids, or ItemDB, then Refresh." or (#selected.." selected · "..#rows.." matching dungeons/raids · Listed by level"))
    f.selected:SetText(#selected>0 and table.concat(selected,"\n") or "Nothing selected. Choose a level range, then add a dungeon or raid above.")
    f.selectedContent:SetHeight(math.max(110,f.selected:GetStringHeight()+8));f.selectedScroll:SetVerticalScroll(math.min(f.selectedScroll:GetVerticalScroll(),math.max(0,f.selectedContent:GetHeight()-f.selectedScroll:GetHeight())))
    if A.RefreshScrollChrome then A:RefreshScrollChrome(f.selectedScroll) end
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
        f.status=label(-69);f.status:SetHeight(28)
        local function button(text,x,y,w,fn)
            local b=S:CreateUIFrame("Button",nil,f,"UIPanelButtonTemplate");b:SetSize(w,25);b:SetPoint("TOPLEFT",x,y);b:SetText(text)
            b:SetScript("OnClick",function() local yes,message=fn();if message then S:Print(message) end;S:RenderPugSetup() end);return b
        end
        label(-102):SetText("Level range")
        f.levelRange=self:UIDropdownButton(f,"",20,-122,575,function()
            S:SelectMenu(f.levelRange,levelFilters,function(value) S.setupLevelFilter=value;S:RenderPugSetup() end);return true
        end)
        label(-164):SetText("Dungeon / raid — select again to add or remove")
        f.instance=self:UIDropdownButton(f,"",20,-184,575,function() return S:OpenSetupInstanceMenu() end)
        label(-224):SetText("Selected content")
        f.selectedScroll=self:CreateUIFrame("ScrollFrame",nil,f,"UIPanelScrollFrameTemplate");f.selectedScroll:SetPoint("TOPLEFT",20,-244);f.selectedScroll:SetSize(550,122)
        f.selectedContent=self:CreateUIFrame("Frame",nil,f.selectedScroll);f.selectedContent:SetSize(530,122);f.selectedScroll:SetScrollChild(f.selectedContent)
        f.selected=self:UILabel(f.selectedContent,"",0,0,525);self:SetTextRole(f.selected,"body")
        button("Refresh",20,-377,165,function() S:RefreshPugSetup();return true end)
        f.clear=button("Clear selected",195,-377,165,function() S.setupSelection={};return true end)
        label(-421):SetText("Shared reserves per player (1-6):")
        f.limit=S:CreateUIFrame("EditBox",nil,f,"InputBoxTemplate");f.limit:SetSize(40,24);f.limit:SetPoint("TOPLEFT",360,-416);f.limit:SetAutoFocus(false);f.limit:SetNumeric(true);f.limit:SetMaxLetters(1)
        f.confirm=button("Confirm and open reservations",20,-515,360,function() return S:ConfirmPugSetup() end)
        f.cancel=button("Cancel",400,-515,195,function() f:Hide();return true end)
    end
    self.setupSelection={};self.setupLevelFilter="all";self.setupPage=1;self.setup.limit:SetText(tostring(limit or 1))
    self:RefreshPugSetup();self.setup:Show()
    if self.runChooser then self.runChooser:Hide() end
    return true
end
function S:ChooseRun(mode,limit)
    if mode=="SoftRes Run" then return self:ShowPugSetup(limit) end
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
