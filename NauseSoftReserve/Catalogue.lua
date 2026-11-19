local _,S=...
local A=S.base
local function call(db,key,...)
    if not db or type(db[key])~="function" then return end
    local ok,v=pcall(db[key],db,...);if ok then return v end
end
function S:InvalidateCatalogue()
    self.catalogueRevision=(self.catalogueRevision or 0)+1;self.browserCache=nil;self.browserOptionCache=nil
end
local start=S.StartCatalogue
function S:StartCatalogue()
    local ok,why=start(self)
    if ok then self.cataloguePending={};self.catalogueRetryAt=0;self:InvalidateCatalogue() end
    return ok,why
end
function S:LoadCatalogueItem(id)
    if not self.Integer(id,1,2147483647) then return end
    local db=self.catalogueDB
    local name=call(db,"GetName",id) or call(db,"GetInfo",id)
    if type(name)=="table" then name=name.name end
    if type(name)~="string" or name=="" then
        self.cataloguePending=self.cataloguePending or {};local p=self.cataloguePending[id] or {tries=0}
        p.tries=p.tries+1;self.cataloguePending[id]=p
        if C_Item and type(C_Item.RequestLoadItemDataByID)=="function" and p.tries<=3 then pcall(C_Item.RequestLoadItemDataByID,id) end
        return false
    end
    local entry={id=id,name=name,search=name:lower(),link=call(db,"GetLink",id),sources={}}
    for _,source in ipairs(call(db,"GetSources",id) or {}) do
        if type(source)=="table" and type(source.instance)=="string" and type(source.boss)=="string" then entry.sources[#entry.sources+1]={instance=source.instance,boss=source.boss} end
    end
    self.catalogue[id]=entry;if self.cataloguePending then self.cataloguePending[id]=nil end
    self:InvalidateCatalogue();return true
end
function S:CatalogueStep()
    if self.catalogueJobs then
        for _=1,100 do
            local row=self.catalogueJobs[self.cataloguePosition]
            if not row then self.catalogueJobs=nil;self:RenderBrowser();break end
            self.cataloguePosition=self.cataloguePosition+1
            local id=type(row)=="table" and (tonumber(row.id) or (type(row.link)=="string" and tonumber(row.link:match("item:(%d+)")))) or tonumber(row)
            if id and not self.catalogue[id] then self:LoadCatalogueItem(id) end
        end
    end
    local now=A.Client:Uptime()
    if self.cataloguePending and now>=(self.catalogueRetryAt or 0) then
        self.catalogueRetryAt=now+2;local n=0
        for id,p in pairs(self.cataloguePending) do
            if p.tries<5 then self:LoadCatalogueItem(id);n=n+1;if n>=30 then break end end
        end
    end
end
function S:BrowserResults(instance,boss,query)
    query=(query or ""):lower()
    local s=self.session;local key=(instance or "").."\031"..(boss or "").."\031"..query..":"..tostring(self.catalogueRevision)..":"..tostring(s and s.id)
    self.browserCache=self.browserCache or {};local cached=self.browserCache[key];if cached then return cached end
    local rows={}
    for _,e in pairs(self.catalogue or {}) do
        local matches=not instance and not boss
        for _,source in ipairs(e.sources) do if (not instance or source.instance==instance) and (not boss or source.boss==boss) then matches=true end end
        if matches and (query=="" or (e.search or e.name:lower()):find(query,1,true) or tostring(e.id)==query) and (not s or not s.selectedInstances or self:ScopeAllows(s,e.id)) then rows[#rows+1]=e end
    end
    table.sort(rows,function(a,b) if a.name==b.name then return a.id<b.id end;return a.name<b.name end)
    -- Bounded cache rather than a growing entry for every historic keystroke.
    self.browserCacheCount=(self.browserCacheCount or 0)+1
    if self.browserCacheCount>30 then self.browserCache={};self.browserCacheCount=1 end
    self.browserCache[key]=rows;return rows
end
local options=S.BrowserOptions
function S:BrowserOptions(instance)
    self.browserOptionCache=self.browserOptionCache or {};local key=(instance or "")..":"..tostring(self.session and self.session.id)
    if not self.browserOptionCache[key] then self.browserOptionCache[key]=options(self,instance) end
    return self.browserOptionCache[key]
end
local show=S.ShowBrowser
function S:ShowBrowser(...)
    local value=show(self,...)
    if self.browser and not self.browser.catalogueSearchHooked then
        self.browser.catalogueSearchHooked=true
        self.browser.search:SetScript("OnTextChanged",function()
            if S.browser.search:GetText()~="" then
                if S.browserMode~="search" then S.browserSearchReturnMode=S.browserMode end;S.browserMode="search";S.browserInstance=nil;S.browserBoss=nil
            elseif S.browserMode=="search" then S.browserMode=S.browserSearchReturnMode or "all" end
            S.browserPage=1;S.searchDue=A.Client:Uptime()+.15
        end)
    end
    return value
end
local render=S.RenderBrowser
function S:RenderBrowser(...)
    render(self,...)
    if self.browser and self.cataloguePending and next(self.cataloguePending) then
        self.browser.status:SetText(self.browser.status:GetText().." | Some item data is pending; it will refresh when loaded.")
    end
end
local frame=CreateFrame("Frame")
for _,event in ipairs({"GET_ITEM_INFO_RECEIVED","ITEM_DATA_LOAD_RESULT"}) do pcall(frame.RegisterEvent,frame,event) end
frame:SetScript("OnEvent",function(_,_,id,success)
    if success~=false and S.setupItemPending and S.setupItemPending[id] then
        S.setupItemPending[id]=nil;S:RenderSessionSetup();S:RenderBrowser();S:RenderAwardQueue();S:RenderLeaderRolls()
    end
    if success~=false and S.cataloguePending and S.cataloguePending[id] then S:LoadCatalogueItem(id);S:RenderBrowser() end
end)
local elapsed=0
frame:SetScript("OnUpdate",function(_,dt)
    elapsed=elapsed+dt;if elapsed<.15 then return end;elapsed=0
    S:CatalogueStep()
    if S.searchDue and A.Client:Uptime()>=S.searchDue then S.searchDue=nil;S:RenderBrowser() end
end)
S.catalogueEvents=frame
