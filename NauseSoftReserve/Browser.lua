local _,S=...
local A=S.base
local function call(db,key,...)
    if not db or type(db[key])~="function" then return end
    local ok,v=pcall(db[key],db,...);if ok then return v end
end
function S:StartCatalogue()
    self.atlasLibrary=nil
    local db=A:ItemLibrary()
    if not db then self.catalogueError="Loot catalogue unavailable. Enable AtlasLoot Forever with Dungeons and Raids, or ItemDB, then Refresh.";return false end
    local rows=call(db,"Search",{max=1000000})
    if type(rows)~="table" then self.catalogueError="The loot catalogue does not expose searchable items.";return false end
    self.catalogue={};self.catalogueJobs=rows;self.cataloguePosition=1;self.catalogueDB=db;self.catalogueError=nil
    return true
end
function S:CatalogueStep()
    if not self.catalogueJobs then return end
    local db=self.catalogueDB
    for i=1,100 do
        local row=self.catalogueJobs[self.cataloguePosition]
        if not row then self.catalogueJobs=nil;self:RenderBrowser();return end
        self.cataloguePosition=self.cataloguePosition+1
        local id=type(row)=="table" and (tonumber(row.id) or (type(row.link)=="string" and tonumber(row.link:match("item:(%d+)")))) or tonumber(row)
        if self.Integer(id,1,2147483647) and not self.catalogue[id] then
            local name=call(db,"GetName",id) or call(db,"GetInfo",id)
            if type(name)=="string" then
                local entry={id=id,name=name,link=call(db,"GetLink",id),sources={}}
                for _,source in ipairs(call(db,"GetSources",id) or {}) do
                    if type(source)=="table" and type(source.instance)=="string" and type(source.boss)=="string" then
                        entry.sources[#entry.sources+1]={instance=source.instance,boss=source.boss}
                    end
                end
                self.catalogue[id]=entry
            end
        end
    end
end
function S:BrowserResults(instance,boss,query)
    local rows={};query=(query or ""):lower()
    for _,entry in pairs(self.catalogue or {}) do
        local match=not instance and not boss
        for _,source in ipairs(entry.sources) do
            if (not instance or source.instance==instance) and (not boss or boss==source.boss) then match=true end
        end
        if match and (query=="" or entry.name:lower():find(query,1,true) or tostring(entry.id)==query) then rows[#rows+1]=entry end
    end
    table.sort(rows,function(a,b) if a.name==b.name then return a.id<b.id end;return a.name<b.name end)
    return rows
end
function S:BrowserOptions(instance)
    local names={}
    for _,entry in pairs(self.catalogue or {}) do for _,source in ipairs(entry.sources) do
        if not instance or instance==source.instance then names[instance and source.boss or source.instance]=true end
    end end
    local out={};for name in pairs(names) do out[#out+1]=name end;table.sort(out);return out
end
local function equal(a,b) if #a~=#b then return false end;for i,v in ipairs(a) do if v~=b[i] then return false end end;return true end
function S:ResetBrowserDraft()
    self.browserDraft=A.Copy(self.session and self.session.reserves[A.me] or {})
    self.browserOriginal=A.Copy(self.browserDraft);self.browserSession=self.session and self.session.id
end
function S:EditBrowserPick(id,index)
    local session=self.session
    if not session or session.locked then return false,"Reservations are locked or no run is active." end
    if self.browserSession~=session.id then self:ResetBrowserDraft() end
    if index then table.remove(self.browserDraft,index)
    elseif #self.browserDraft>=session.limit then return false,"All reservation slots are filled. Remove a pick first."
    else self.browserDraft[#self.browserDraft+1]=id end
    return true
end
function S:SubmitBrowserDraft()
    local session=self.session
    if not session or session.id~=self.browserSession then return false,"Run changed. Reset your picks." end
    if not equal(self.browserOriginal,session.reserves[A.me] or {}) then return false,"Your confirmed picks changed. Reset the draft before submitting." end
    return self:Request("reserve",self.browserDraft)
end
function S:UseBrowserInstance()
    if not self:IsHost() or self.session.locked then return false,"Only the host can choose an instance before locking." end
    self.session.raidName=self.browserInstance;self.session.revision=self.session.revision+1;self:Publish();return true
end
function S:ShowBrowser()
    if not self.browser then
        local f=S:CreateUIFrame("Frame","NauseReservationBrowser",UIParent,"BasicFrameTemplateWithInset");self.browser=f
        f:SetSize(850,650);f:SetPoint("CENTER");f:SetMovable(true);f:EnableMouse(true);f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart",f.StartMoving);f:SetScript("OnDragStop",f.StopMovingOrSizing)
        if f.TitleText then f.TitleText:SetText("Nause Raid Tools - My Reservations") end
        table.insert(UISpecialFrames,"NauseReservationBrowser")
        local function label(x,y,w) local l=f:CreateFontString(nil,"OVERLAY","GameFontNormal");l:SetPoint("TOPLEFT",x,y);l:SetWidth(w);l:SetJustifyH("LEFT");return l end
        local function button(text,x,y,w,fn)
            local b=S:CreateUIFrame("Button",nil,f,"UIPanelButtonTemplate");b:SetPoint("TOPLEFT",x,y);b:SetSize(w,25);b:SetText(text)
            b:SetScript("OnClick",function() local ok,why=fn();if why then S:Print(why) end;S:RenderBrowser() end);return b
        end
        self:InstallManagerNavigation(f,"Reservations")
        f.status=label(20,-91,810);f.status:SetHeight(24)
        f.instance=button("All instances",20,-120,350,function()
            local choices={{"All selected instances",false}}
            for _,name in ipairs(S:BrowserOptions()) do choices[#choices+1]={name,name} end
            S:SelectMenu(f.instance,choices,function(value) S.browserInstance=value or nil;S.browserBoss=nil;S.browserPage=1;S:RenderBrowser() end);return true
        end)
        f.boss=button("All bosses",380,-120,270,function()
            if not S.browserInstance then return false,"Select an instance before choosing a boss." end
            local choices={{"All bosses",false}}
            for _,name in ipairs(S:BrowserOptions(S.browserInstance)) do choices[#choices+1]={name,name} end
            S:SelectMenu(f.boss,choices,function(value) S.browserBoss=value or nil;S.browserPage=1;S:RenderBrowser() end);return true
        end)
        f.useForRun=button("Use for run",660,-120,165,function() return S:UseBrowserInstance() end)
        f.search=S:CreateUIFrame("EditBox",nil,f,"InputBoxTemplate");f.search:SetSize(610,24);f.search:SetPoint("TOPLEFT",20,-158);f.search:SetAutoFocus(false)
        f.search:SetScript("OnEscapePressed",function(e) e:ClearFocus() end)
        f.search:SetScript("OnTextChanged",function() S.browserPage=1;S:RenderBrowser() end)
        self:UIPlaceholder(f.search,"Search items by name or ID")
        button("Refresh items",660,-158,165,function() return S:StartCatalogue() end)
        f.rows={}
        for i=1,8 do
            local row=S:CreateUIFrame("Frame",nil,f);f.rows[i]=row;row:SetPoint("TOPLEFT",20,-198-(i-1)*30);row:SetSize(805,28);row:EnableMouse(true)
            row.icon=row:CreateTexture(nil,"ARTWORK");row.icon:SetPoint("LEFT");row.icon:SetSize(26,26)
            row.name=S:UILabel(row,"",34,0,510);row.name:SetHeight(15);row.name:SetWordWrap(false);row.name:SetMaxLines(1)
            row.source=S:UILabel(row,"",34,-15,510);row.source:SetTextColor(.60,.63,.68);row.source:SetHeight(13);row.source:SetWordWrap(false)
            row.count=S:UILabel(row,"",550,-6,60)
            row.add=S:UIButton(row,"+ Reserve",620,0,105,function() if row.entry then local ok,why=S:EditBrowserPick(row.entry.id);S:RenderBrowser();return ok,why end end)
            row.remove=S:UIButton(row,"−",735,0,65,function()
                if row.entry then for n=#(S.browserDraft or {}),1,-1 do if S.browserDraft[n]==row.entry.id then local ok,why=S:EditBrowserPick(nil,n);S:RenderBrowser();return ok,why end end end
                return false,"This item is not in your selections."
            end)
            local function hover() if row.entry and GameTooltip then GameTooltip:SetOwner(row,"ANCHOR_RIGHT");GameTooltip:SetHyperlink(row.entry.link or ("item:"..row.entry.id));GameTooltip:Show() end end
            row:SetScript("OnEnter",hover);row:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
            for _,b in ipairs({row.add,row.remove}) do b:SetScript("OnEnter",hover);b:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end) end
        end
        f.previous=button("Previous",20,-444,100,function() S.browserPage=math.max(1,(S.browserPage or 1)-1);return true end)
        f.next=button("Next",130,-444,100,function() S.browserPage=(S.browserPage or 1)+1;return true end)
        f.page=label(250,-450,570)
        f.picks=label(20,-480,810);f.picks:SetTextColor(1,.82,.25);f.slots={}
        for i=1,6 do f.slots[i]=button("",20+((i-1)%3)*270,-504-math.floor((i-1)/3)*30,260,function() return S:EditBrowserPick(nil,i) end) end
        f.submit=button("Submit reservations",20,-575,220,function() return S:SubmitBrowserDraft() end)
        f.submit:SetBackdropBorderColor(.75,.57,.18,1)
        button("Reset draft",250,-575,160,function() S:ResetBrowserDraft();return true end)
        f.help=label(20,-613,810);f.help:SetHeight(28);f.help:SetTextColor(.60,.63,.68)
        f.help:SetText("Use + / − to choose items. Stacked reserves spend one slot each. Submit saves your choices.")
        f:SetScript("OnUpdate",function(_,dt)
            S:CatalogueStep();S.browserTick=(S.browserTick or 0)+dt
            if S.browserTick>=1 then S.browserTick=0;local rev=S.session and S.session.revision or -1;if S.browserRevision~=rev then S.browserRevision=rev;S:RenderBrowser() end end
        end)
    end
    self.browserInstance=self.session and self.session.raidName or self.browserInstance
    self.browserBoss=nil;self.browserPage=1
    if not self.browserDraft or self.browserSession~=(self.session and self.session.id) then self:ResetBrowserDraft() end
    if not self.catalogue then self:StartCatalogue() end
    self.browser:Show();self:RenderBrowser()
end
function S:RenderBrowser()
    local f=self.browser;if not f then return end
    local session=self.session
    if session and self.browserSession~=session.id then self:ResetBrowserDraft() end
    if session and self.browserOriginal and equal(self.browserDraft or {},self.browserOriginal)
        and not equal(self.browserOriginal,session.reserves[A.me] or {}) then self:ResetBrowserDraft() end
    local editable=session~=nil and not session.locked
    local changed=not equal(self.browserDraft or {},session and session.reserves[A.me] or {})
    f.status:SetText(self.catalogueError or (self.catalogueJobs and "Loading items…" or (not session and "No active SoftRes session" or ((session.locked and "|cffffcf70Reservations locked|r" or "|cff6fe39cReservations open|r")..(changed and "  ·  Unsaved selections" or "  ·  Selections saved")))))
    f.instance:SetText(self.browserInstance or "All selected instances ▾")
    f.boss:SetText(self.browserBoss or "All bosses ▾");f.boss:SetEnabled(self.browserInstance~=nil)
    if session and equal(self.browserDraft or {},session.reserves[A.me] or {}) then self.browserOriginal=A.Copy(self.browserDraft or {}) end
    local rows=self:BrowserResults(self.browserInstance,self.browserBoss,f.search:GetText())
    local pages=math.max(1,math.ceil(#rows/8));self.browserPage=math.min(self.browserPage or 1,pages)
    for i,b in ipairs(f.rows) do
        local row=rows[(self.browserPage-1)*8+i];b.entry=row;b:SetShown(row~=nil)
        if row then
            local n=0;for _,id in ipairs(self.browserDraft or {}) do if id==row.id then n=n+1 end end
            b.name:SetText(row.link or row.name)
            local sources={};for _,source in ipairs(row.sources or {}) do sources[#sources+1]=source.boss end
            b.source:SetText(table.concat(sources,", "));b.count:SetText(n>0 and ("×"..n) or "")
            local ok,icon=A.Client:Call("C_Item.GetItemIconByID",row.id);b.icon:SetTexture(ok and icon or "Interface/Icons/INV_Misc_QuestionMark")
            b.add:SetEnabled(editable and #(self.browserDraft or {})<session.limit);b.remove:SetEnabled(editable and n>0)
        end
    end
    f.previous:SetEnabled(self.browserPage>1);f.next:SetEnabled(self.browserPage<pages)
    f.page:SetText("Page "..self.browserPage.." / "..pages.." · "..#rows.." items")
    f.picks:SetText("Your reserves: "..#(self.browserDraft or {}).."/"..(session and session.limit or 0)..(changed and " · Not yet submitted" or ""))
    f.submit:SetEnabled(editable)
    for i,b in ipairs(f.slots) do
        local id=(self.browserDraft or {})[i]
        b:SetText(id and S:ReservationItemText(id) or ("Slot "..i.." · Empty"));b:SetShown(session~=nil and i<=session.limit);b:SetEnabled(id~=nil and editable)
        b:SetScript("OnEnter",function() if id and GameTooltip then GameTooltip:SetOwner(b,"ANCHOR_RIGHT");GameTooltip:SetHyperlink("item:"..id);GameTooltip:Show() end end)
        b:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
    end
end
local show=S.Show
function S:Show(...)
    show(self,...)
    if not self.ui.browse then
        local b=S:CreateUIFrame("Button",nil,self.ui,"UIPanelButtonTemplate");self.ui.browse=b;b:SetSize(85,24);b:SetPoint("TOPLEFT",655,-121);b:SetText("Browse loot");b:SetScript("OnClick",function() S:ShowBrowser() end)
    end
end

local choose=S.ChooseRun
function S:ChooseRun(mode,limit)
    local ok,why=choose(self,mode,limit)
    if ok and mode=="PuG Run" then self:ShowBrowser() end
    return ok,why
end
