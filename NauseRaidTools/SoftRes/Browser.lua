local _, namespace = ...
local S = namespace.SoftRes or namespace
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
function S:BrowserSourceText(entry)
    local names,seen={},{}
    for _,source in ipairs(entry.sources or {}) do
        if (not self.browserInstance or source.instance==self.browserInstance)
            and (not self.browserBoss or source.boss==self.browserBoss) then
            local name=self.browserInstance and source.boss or (source.instance.." · "..source.boss)
            if not seen[name] then seen[name]=true;names[#names+1]=name end
        end
    end
    return #names>0 and table.concat(names,", ") or "Source unavailable"
end
function S:BrowserReserveCounts()
    local counts={}
    local function add(name,picks)
        for _,id in ipairs(picks or {}) do
            local row=counts[id] or {total=0,players={}};counts[id]=row
            row.total=row.total+1;row.players[name]=(row.players[name] or 0)+1
        end
    end
    for name,picks in pairs(self.session and self.session.reserves or {}) do if name~=A.me then add(name,picks) end end
    add(A.me,self.browserDraft or (self.session and self.session.reserves[A.me]) or {})
    return counts
end
function S:SelectBrowserView(mode,instance,boss)
    local f=self.browser
    if mode~="search" then f.search:SetText("");self.searchDue=nil end
    self.browserMode=mode;self.browserInstance=instance;self.browserBoss=boss;self.browserSidebarDefaulted=true
    self.browserItemOffset=0;self.browserPage=1;self:RenderBrowser();return true
end
function S:BrowserViewRows(counts)
    local mode=self.browserMode or "all";local f=self.browser;local rows,seen={},{}
    for _,entry in ipairs(self:BrowserResults(self.browserInstance,self.browserBoss,f.search:GetText())) do
        local count=counts[entry.id];local mine=count and count.players[A.me] or 0
        if mode~="mine" and mode~="reserved" or (mode=="mine" and mine>0) or (mode=="reserved" and count and count.total>0) then rows[#rows+1]=entry;seen[entry.id]=true end
    end
    if mode=="mine" or mode=="reserved" then
        for id,count in pairs(counts) do
            if not seen[id] and (mode=="reserved" or (count.players[A.me] or 0)>0) then
                rows[#rows+1]={id=id,name="Item "..id,link=self:ReservationItemText(id),sources=call(A:ItemLibrary(),"GetSources",id) or {}}
            end
        end
    end
    table.sort(rows,function(x,y) if x.name==y.name then return x.id<y.id end;return x.name<y.name end)
    return rows
end
function S:BrowserItemDetails(entry)
    local ok,name,link,quality,level,required,kind,subtype=A.Client:Call("C_Item.GetItemInfo",entry.id)
    local description=ok and type(kind)=="string" and kind or nil
    if description and type(subtype)=="string" and subtype~="" and subtype~=kind then description=description..", "..subtype end
    return (description and (description.." · ") or "")..self:BrowserSourceText(entry)
end
function S:RenderBrowserNavigation(counts)
    local f=self.browser;local mine=#(self.browserDraft or {});local total=0
    for _,row in pairs(counts) do total=total+row.total end
    local entries={{kind="view",mode="mine",text="My reserves ("..mine..")"},{kind="view",mode="reserved",text="All reserves ("..total..")"},
        {kind="view",mode="search",text="Search results"},{kind="view",mode="all",text="All loot"}}
    for _,instance in ipairs(self:BrowserOptions()) do
        entries[#entries+1]={kind="instance",mode="all",instance=instance,text=instance}
        if self.browserInstance==instance then
            for _,boss in ipairs(self:BrowserOptions(instance)) do entries[#entries+1]={kind="boss",mode="all",instance=instance,boss=boss,text=boss} end
        end
    end
    for i=1,math.max(#entries,#f.navigationRows) do
        local b=f.navigationRows[i]
        if not b then
            b=self:UIButton(f.navigationContent,"",0,-(i-1)*27,168,function()
                local entry=f.navigationRows[i].entry
                if not entry then return false end
                return S:SelectBrowserView(entry.mode,entry.instance,entry.boss)
            end)
            b:EnableMouseWheel(true);b:SetScript("OnMouseWheel",function(_,delta) local fn=f.navigationScroll:GetScript("OnMouseWheel");if fn then fn(f.navigationScroll,delta) end end)
            f.navigationRows[i]=b
        end
        local entry=entries[i];b.entry=entry;b:SetShown(entry~=nil)
        if entry then
            b:SetText(entry.text);b:SetPoint("TOPLEFT",entry.kind=="boss" and 10 or 0,-(i-1)*27);b:SetWidth(entry.kind=="boss" and 158 or 168)
            local selected=(self.browserMode or "all")==entry.mode and self.browserInstance==entry.instance and self.browserBoss==entry.boss
            b:SetBackdropColor(selected and .19 or .08,selected and .16 or .09,selected and .09 or .11,1)
            b:SetBackdropBorderColor(selected and .75 or .20,selected and .57 or .22,selected and .18 or .26,1)
            b:SetEnabled(entry.mode~="search" or f.search:GetText()~="")
        end
    end
    f.navigationContent:SetHeight(math.max(1,#entries*27))
    local maximum=math.max(0,f.navigationContent:GetHeight()-f.navigationScroll:GetHeight())
    f.navigationScroll:SetVerticalScroll(math.min(f.navigationScroll:GetVerticalScroll(),maximum))
    if A.RefreshScrollChrome then A:RefreshScrollChrome(f.navigationScroll) end
end
function S:ShowBrowser()
    if not self.browser then
        local f=S:CreateUIFrame("Frame","NauseReservationBrowser",UIParent,"BasicFrameTemplateWithInset");self.browser=f
        f:SetSize(850,650);f:SetPoint("CENTER");f:SetMovable(true);f:EnableMouse(true);f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart",f.StartMoving);f:SetScript("OnDragStop",f.StopMovingOrSizing)
        table.insert(UISpecialFrames,"NauseReservationBrowser")
        local function label(x,y,w) return S:UILabel(f,"",x,y,w) end
        local function button(text,x,y,w,fn)
            local b=S:UIButton(f,text,x,y,w,function() local ok,why=fn();S:RenderBrowser();return ok,why end);return b
        end
        self:InstallManagerNavigation(f,"Reservations")
        f.scope=label(20,-92,810);f.scope:SetHeight(18);f.scope:SetMaxLines(1);f.scope:SetWordWrap(false);self:SetTextRole(f.scope,"heading")
        f.remaining=label(20,-116,810);f.remaining:SetFontObject("GameFontNormalLarge");f.remaining:SetHeight(24)
        f.status=label(20,-146,810);f.status:SetHeight(22);f.status:SetMaxLines(1)
        f.search=S:CreateUIFrame("EditBox",nil,f,"InputBoxTemplate");f.search:SetSize(190,26);f.search:SetPoint("TOPLEFT",20,-179);f.search:SetAutoFocus(false)
        f.search:SetScript("OnEscapePressed",function(e) e:ClearFocus() end)
        f.search:SetScript("OnTextChanged",function() S.browserPage=1;S:RenderBrowser() end)
        self:UIPlaceholder(f.search,"Search items or ID")
        f.navigationScroll=self:CreateUIFrame("ScrollFrame",nil,f,"UIPanelScrollFrameTemplate");f.navigationScroll:SetPoint("TOPLEFT",20,-216);f.navigationScroll:SetSize(168,257)
        f.navigationContent=self:CreateUIFrame("Frame",nil,f.navigationScroll);f.navigationContent:SetSize(168,1);f.navigationScroll:SetScrollChild(f.navigationContent);f.navigationRows={}
        f.listTitle=label(230,-178,330);self:SetTextRole(f.listTitle,"heading")
        button("Refresh items",676,-174,130,function() return S:StartCatalogue() end)
        local countHeader=label(569,-178,58);countHeader:SetText("Reserves");self:SetTextRole(countHeader,"muted")
        f.itemsScroll=self:CreateUIFrame("ScrollFrame",nil,f,"UIPanelScrollFrameTemplate");f.itemsScroll:SetPoint("TOPLEFT",230,-202);f.itemsScroll:SetSize(578,272)
        f.itemsContent=self:CreateUIFrame("Frame",nil,f.itemsScroll);f.itemsContent:SetSize(578,1);f.itemsScroll:SetScrollChild(f.itemsContent)
        f.itemsScroll:HookScript("OnVerticalScroll",function(_,offset)
            if not S.browserRendering then S.browserItemOffset=offset;S:RenderBrowser() end
        end)
        f.rows={}
        for i=1,9 do
            local row=S:CreateUIFrame("Frame",nil,f.itemsContent);f.rows[i]=row;row:SetSize(578,40);row:EnableMouse(true)
            row.shade=row:CreateTexture(nil,"BACKGROUND");row.shade:SetAllPoints()
            row.icon=row:CreateTexture(nil,"ARTWORK");row.icon:SetPoint("TOPLEFT",0,-3);row.icon:SetSize(34,34)
            row.name=S:UILabel(row,"",42,-3,294);row.name:SetFontObject("GameFontHighlight");row.name:SetHeight(17);row.name:SetWordWrap(false);row.name:SetMaxLines(1)
            row.source=S:UILabel(row,"",42,-23,294);self:SetTextRole(row.source,"muted");row.source:SetHeight(14);row.source:SetWordWrap(false);row.source:SetMaxLines(1)
            row.count=S:UILabel(row,"",343,-12,38);row.count:SetJustifyH("CENTER")
            row.add=S:UIButton(row,"Reserve",386,-7,100,function() if row.entry then local ok,why=S:EditBrowserPick(row.entry.id);S:RenderBrowser();return ok,why end end)
            row.remove=S:UIButton(row,"Remove",494,-7,82,function()
                if row.entry then for n=#(S.browserDraft or {}),1,-1 do if S.browserDraft[n]==row.entry.id then local ok,why=S:EditBrowserPick(nil,n);S:RenderBrowser();return ok,why end end end
                return false,"This item is not in your selections."
            end)
            for _,surface in ipairs({row,row.add,row.remove}) do
                surface:EnableMouseWheel(true);surface:SetScript("OnMouseWheel",function(_,delta) local fn=f.itemsScroll:GetScript("OnMouseWheel");if fn then fn(f.itemsScroll,delta) end end)
            end
        end
        f.empty=label(250,-290,550);f.empty:SetHeight(75);f.empty:SetJustifyH("CENTER");self:SetTextRole(f.empty,"muted")
        f.page=label(230,-477,590);f.page:SetHeight(12);self:SetTextRole(f.page,"muted")
        self:UISection(f,-493)
        f.picks=label(20,-501,810);self:SetTextRole(f.picks,"heading");f.slots={}
        for i=1,6 do f.slots[i]=button("",20+((i-1)%3)*270,-526-math.floor((i-1)/3)*30,260,function() return S:EditBrowserPick(nil,i) end) end
        f.submit=button("Submit reservations",20,-600,220,function() return S:SubmitBrowserDraft() end);f.submit:SetBackdropBorderColor(.75,.57,.18,1)
        button("Reset draft",250,-600,160,function() S:ResetBrowserDraft();return true end)
        f.help=label(430,-600,400);f.help:SetHeight(36);self:SetTextRole(f.help,"muted")
        f:SetScript("OnUpdate",function(_,dt)
            S:CatalogueStep();S.browserTick=(S.browserTick or 0)+dt
            if S.browserTick>=1 then S.browserTick=0;local rev=S.session and S.session.revision or -1;if S.browserRevision~=rev then S.browserRevision=rev;S:RenderBrowser() end end
        end)
    end
    local viewSession=self.session and self.session.id or false
    if self.browserViewSession~=viewSession then
        self.browserViewSession=viewSession;self.browserMode="all";self.browserSidebarDefaulted=nil
        self.browserInstance=self.session and self.session.raidName or nil;self.browserBoss=nil;self.browserPage=1;self.browserItemOffset=0;self.browser.search:SetText("")
    end
    if not self.browserDraft or self.browserSession~=(self.session and self.session.id) then self:ResetBrowserDraft() end
    if not self.catalogue then self:StartCatalogue() end
    self.browser:Show();self:RenderBrowser()
end
function S:RenderBrowser()
    local f=self.browser;if not f then return end
    self.browserRendering=true
    local session=self.session
    local instances={};for name in pairs(session and session.selectedInstances or {}) do instances[#instances+1]=name end;table.sort(instances)
    f.scope:SetText(session and ("Content: "..(#instances>0 and table.concat(instances,", ") or session.raidName or "All loot")) or "Content: waiting for host")
    if session and self.browserSession~=session.id then self:ResetBrowserDraft() end
    if session and self.browserOriginal and equal(self.browserDraft or {},self.browserOriginal) and not equal(self.browserOriginal,session.reserves[A.me] or {}) then self:ResetBrowserDraft() end
    if not self.browserSidebarDefaulted and not self.catalogueJobs and self.catalogue then
        local options=self:BrowserOptions();if #options==1 then self.browserInstance=options[1] end;self.browserSidebarDefaulted=true
    end
    local editable=session~=nil and not session.locked
    local used,limit=#(self.browserDraft or {}),session and session.limit or 0
    local remaining=math.max(0,limit-used)
    f.remaining:SetText(not session and "No active SoftRes session" or (session.locked and "Reservations are locked" or (used>limit and ("Remove "..(used-limit).." selections to fit this session") or (remaining>0 and ("You can reserve "..remaining.." more item"..(remaining==1 and "" or "s")) or "All reservation slots used"))))
    self:SetTextRole(f.remaining,session and session.locked and "attention" or "heading")
    local changed=not equal(self.browserDraft or {},session and session.reserves[A.me] or {})
    local submission=changed and "Unsaved selections" or (session and session.reserves[A.me] and "Selections saved" or "Not submitted")
    f.status:SetText(self.sessionDiscoveryStatus or self.catalogueError or self.hostCatalogueWaiting or (self.catalogueJobs and "Loading items…" or (not session and "Choose a session to submit reserves." or (self:ColoredText(session.locked and "Locked" or "Open",session.locked and "attention" or "ready").." · "..self:ColoredText(submission,changed and "attention" or (session.reserves[A.me] and "ready" or "muted")).." · Counts include your current selections"))))
    self:SetTextRole(f.status,self.catalogueError and "attention" or "body")
    if session and equal(self.browserDraft or {},session.reserves[A.me] or {}) then self.browserOriginal=A.Copy(self.browserDraft or {}) end
    local counts=self:BrowserReserveCounts();self:RenderBrowserNavigation(counts)
    local rows=self:BrowserViewRows(counts)
    local mode=self.browserMode or "all"
    f.listTitle:SetText(mode=="mine" and "My reserves" or mode=="reserved" and "All reserves" or mode=="search" and "Search results" or self.browserBoss or self.browserInstance or "All loot")
    local key=tostring(session and session.id)..":"..mode..":"..tostring(self.browserInstance)..":"..tostring(self.browserBoss)..":"..f.search:GetText()
    if self.browserListKey~=key then self.browserListKey=key;self.browserItemOffset=0 end
    local height=math.max(1,#rows*42);f.itemsContent:SetHeight(height)
    local maximum=math.max(0,height-f.itemsScroll:GetHeight());local offset=math.max(0,math.min(self.browserItemOffset or 0,maximum));self.browserItemOffset=offset
    f.itemsScroll:SetVerticalScroll(offset);if A.RefreshScrollChrome then A:RefreshScrollChrome(f.itemsScroll) end
    local first=math.floor(offset/42)+1
    for i,b in ipairs(f.rows) do
        local row=rows[first+i-1]
        b.entry=row;b:SetShown(row~=nil);b:ClearAllPoints();b:SetPoint("TOPLEFT",0,-(first+i-2)*42)
        if row then
            local count=counts[row.id];local mine=count and count.players[A.me] or 0
            b.name:SetText(self:ReservationItemText(row.id,row.link or row.name));b.source:SetText(self:BrowserItemDetails(row))
            b.count:SetText(count and tostring(count.total) or "-");self:SetTextRole(b.count,mine>0 and "heading" or "body")
            if mine>0 then b.shade:SetColorTexture(.32,.26,.10,.45) else b.shade:SetColorTexture(1,1,1,(first+i)%2==0 and .045 or .015) end
            local ok,icon=A.Client:Call("C_Item.GetItemIconByID",row.id);b.icon:SetTexture(ok and icon or "Interface/Icons/INV_Misc_QuestionMark")
            b.add:SetText(mine>0 and "Reserve +1" or "Reserve");b.add:SetEnabled(editable and used<limit);b.remove:SetEnabled(editable and mine>0)
        end
    end
    f.empty:SetShown(#rows==0)
    f.empty:SetText(self.sessionDiscoveryStatus or self.hostCatalogueWaiting or (self.catalogueJobs and "Loading the item catalogue…" or (self.catalogueError and "The item catalogue is unavailable. Check the message above." or mode=="mine" and "No items selected yet. Choose a dungeon or boss to browse its loot." or mode=="reserved" and "No reservations yet. Submitted picks and your current selections appear here." or "No items match this view. Choose another boss or change your search.")))
    f.page:SetText(#rows.." items · Scroll to browse · Reserve adds to your selections")
    f.help:SetText(not session and "Join a SoftRes session to submit reservations." or (session.locked and "Selections cannot be changed while locked." or "Reserve adds one. Remove takes one away. Submit saves changes."))
    f.picks:SetText("Your selections: "..used.."/"..limit..(changed and " · Not yet submitted" or ""))
    f.submit:SetText(self.pendingRequest and "Submitting…" or "Submit reservations");f.submit:SetEnabled(editable and used<=limit and not self.pendingRequest)
    for i,b in ipairs(f.slots) do
        local id=(self.browserDraft or {})[i]
        b:SetText(id and ("- "..self:ReservationItemText(id)) or self:ColoredText("Slot "..i.." · Empty","muted"));b:SetShown(session~=nil and i<=limit);b:SetEnabled(id~=nil and editable)
    end
    self.browserRendering=nil
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
    if ok and mode=="SoftRes Run" then self:ShowBrowser() end
    return ok,why
end
