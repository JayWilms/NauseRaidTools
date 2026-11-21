local _,A=...
local colors={Present={.35,.85,.55},Missing={1,.32,.25},Unknown={.65,.68,.72},["Not required"]={.40,.43,.48}}
local readyTextures={Ready="Interface/RaidFrame/ReadyCheck-Ready",["Not ready"]="Interface/RaidFrame/ReadyCheck-NotReady",["No reply"]="Interface/RaidFrame/ReadyCheck-Waiting",Waiting="Interface/RaidFrame/ReadyCheck-Waiting",["Not checked"]="Interface/RaidFrame/ReadyCheck-Waiting"}
local function set(label,value,state)
    label:SetText(value);local c=colors[state] or colors.Unknown;label:SetTextColor(c[1],c[2],c[3])
end
local function tooltip(frame,title,lines)
    if not GameTooltip then return end
    GameTooltip:SetOwner(frame,"ANCHOR_RIGHT");GameTooltip:SetText(title)
    for _,line in ipairs(lines or {}) do GameTooltip:AddLine(line,.85,.87,.90,true) end
    GameTooltip:Show()
end
local function hideTip() if GameTooltip then GameTooltip:Hide() end end
function A:RaidCheckRemainingText(detail)
    local expires=detail and detail.expires
    if type(expires)~="number" or expires<=0 then return "" end
    local seconds=math.max(0,expires-self.Client:Uptime())
    if seconds<60 then return "<1m" end
    if seconds>=3600 then return math.floor(seconds/3600).."h" end
    return math.floor(seconds/60).."m"
end
local function finite(value) return type(value)=="number" and value==value and math.abs(value)<1000000 end
function A:RaidCheckHeightBounds(frame)
    local _,top=self:WindowTopLeft(frame)
    local maximum=math.max(244,math.min(1100,UIParent:GetHeight()-math.max(0,top)-16))
    return math.min(270,maximum),maximum
end
function A:SetRaidCheckHeight(height)
    local f=self.ui and self.ui.raidChecks;if not f then return false end
    local store=self:WindowLayoutStore()
    if height==nil then store.raidCheckHeight=nil
    elseif finite(height) then
        local minimum,maximum=self:RaidCheckHeightBounds(f)
        store.raidCheckHeight=math.max(minimum,math.min(maximum,height))
    else return false end
    self:RenderRaidChecks();return true
end
function A:InstallRaidCheckResize(f)
    f.nrtRaidCheckVertical=true
    local grip=CreateFrame("Button",nil,f);f.resizeGrip=grip
    grip:SetSize(80,12);grip:SetPoint("BOTTOM",0,2)
    local level=f:GetFrameLevel();if type(level)=="number" then grip:SetFrameLevel(level+20) end
    for index=1,3 do local line=grip:CreateTexture(nil,"ARTWORK");line:SetColorTexture(.55,.57,.61,1);line:SetSize(32-index*6,1);line:SetPoint("TOP",0,-index*3) end
    local resizing
    local function finish()
        if not resizing then return end
        resizing=nil;f.nrtResizing=false;A:ClampWindowPosition(f);A:SaveWindowLayout(f,"NauseRaidToolsRaidChecks")
    end
    grip:SetScript("OnMouseDown",function(_,button)
        if button~="LeftButton" or A:WindowLocked(f) or f.nrtCollapsed==true then return end
        local _,y=GetCursorPosition();if not finite(y) then return end
        local left,top=A:WindowTopLeft(f)
        f:ClearAllPoints();f:SetPoint("TOPLEFT",UIParent,"TOPLEFT",left,-top)
        resizing={y=y,height=f:GetHeight()};f.nrtResizing=true
    end)
    grip:SetScript("OnUpdate",function()
        if not resizing then return end
        if A:WindowLocked(f) or f.nrtCollapsed==true or (IsMouseButtonDown and not IsMouseButtonDown("LeftButton")) then finish();return end
        local _,y=GetCursorPosition();local scale=f:GetEffectiveScale()
        if not finite(y) or not finite(scale) or scale<=0 then return end
        A:SetRaidCheckHeight(resizing.height+(resizing.y-y)/scale)
    end)
    grip:SetScript("OnMouseUp",finish);grip:HookScript("OnHide",finish);f:HookScript("OnHide",finish)
    grip:SetScript("OnEnter",function() tooltip(grip,"Resize height",{"Drag down to show more players. Auto Height restores the compact size."}) end)
    grip:SetScript("OnLeave",hideTip)
end
function A:BuildRaidChecksUI(u,window,text,button)
    local f=window("NauseRaidToolsRaidChecks","Nause Raid Tools | Raid Check",790,348);u.raidChecks=f
    f.summary=text(f,"",12,14,-47,744);f.summary:SetHeight(24)
    f.scan=button(f,"Refresh",14,-78,90,function() A:ScanRaidChecks() end)
    f.ready=button(f,"Ready Check",112,-78,108,function() A:StartRaidReadyCheck() end)
    f.announce=button(f,"Announce Issues",228,-78,124,function() A:AnnounceRaidCheckIssues() end)
    f.players=button(f,"Players",360,-78,84,function() A.raidCheckView="players";f.scroll:SetVerticalScroll(0);A:RenderRaidChecks() end)
    f.issues=button(f,"By Issue",452,-78,84,function() A.raidCheckView="issues";f.scroll:SetVerticalScroll(0);A:RenderRaidChecks() end)
    f.settings=button(f,"Settings",544,-78,76,function()
        f:Hide();A:ShowSettings();A:SelectSettingsPage("Raid Tools");A:FocusWindow(A.ui.settingsHub)
    end)
    f.filter=button(f,"Show: All",624,-78,136,function() A.raidCheckIssuesOnly=not A.raidCheckIssuesOnly;f.scroll:SetVerticalScroll(0);A:RenderRaidChecks() end)
    f.nameHeader=text(f,"Ready / Player",11,14,-142,250)
    f.issueHeader=text(f,"Players",11,244,-142,500);f.issueHeader:Hide()
    f.headers={}
    for index,definition in ipairs(self.raidCheckDefinitions) do
        local header=CreateFrame("Frame",nil,f);f.headers[index]=header;header:SetSize(76,48);header:SetPoint("TOPLEFT",14+290+(index-1)*84,-115);header:EnableMouse(true)
        header.icon=header:CreateTexture(nil,"ARTWORK");header.icon:SetSize(23,23);header.icon:SetPoint("TOPLEFT",2,0);header.icon:SetTexture(definition.icon)
        header.count=text(header,"",11,28,-4,46)
        header.label=text(header,definition.short,10,0,-27,76);header.label:SetMaxLines(1)
        header:SetScript("OnEnter",function() tooltip(header,definition.label,{header.explanation or ""}) end)
        header:SetScript("OnLeave",hideTip);header:SetScript("OnHide",hideTip)
    end
    f.scroll=self:CreateScrollFrame(f);f.scroll:SetPoint("TOPLEFT",14,-170);f.scroll:SetSize(748,130)
    f.content=CreateFrame("Frame",nil,f.scroll);f.content:SetSize(748,1);f.scroll:SetScrollChild(f.content);f.rows={}
    local function wheel(_,delta)
        local handler=f.scroll:GetScript("OnMouseWheel");if handler then handler(f.scroll,delta) end
    end
    for index=1,42 do
        local row=CreateFrame("Frame",nil,f.content);row:SetSize(748,26);f.rows[index]=row
        row:EnableMouseWheel(true);row:SetScript("OnMouseWheel",wheel)
        row.shade=row:CreateTexture(nil,"BACKGROUND");row.shade:SetAllPoints()
        row.classBar=row:CreateTexture(nil,"ARTWORK");row.classBar:SetSize(2,22);row.classBar:SetPoint("LEFT",24,0)
        row.ready=CreateFrame("Frame",nil,row);row.ready:SetSize(22,24);row.ready:SetPoint("TOPLEFT",0,-1);row.ready:EnableMouse(true)
        row.ready.icon=row.ready:CreateTexture(nil,"ARTWORK");row.ready.icon:SetAllPoints()
        row.ready:EnableMouseWheel(true);row.ready:SetScript("OnMouseWheel",wheel)
        row.ready:SetScript("OnEnter",function() tooltip(row.ready,row.playerName or "Ready status",{row.readyStatus or "Not checked"}) end)
        row.ready:SetScript("OnLeave",hideTip)
        row.ready:SetScript("OnHide",function() if GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(row.ready) then hideTip() end end)
        row.name=text(row,"",11,30,-6,205);row.name:SetHeight(18);row.name:SetMaxLines(1);row.name:SetWordWrap(false)
        row.status=text(row,"",10,238,-6,50);row.status:SetHeight(18)
        row.issue=text(row,"",11,230,-5,505);row.issue:SetHeight(38);row.issue:SetJustifyV("TOP")
        row.cells={}
        for column,definition in ipairs(self.raidCheckDefinitions) do
            local cell=CreateFrame("Frame",nil,row);row.cells[column]=cell;cell:SetSize(76,24);cell:SetPoint("TOPLEFT",290+(column-1)*84,-1);cell:EnableMouse(true)
            cell:EnableMouseWheel(true);cell:SetScript("OnMouseWheel",wheel)
            cell.icon=cell:CreateTexture(nil,"ARTWORK");cell.icon:SetSize(22,22);cell.icon:SetPoint("TOPLEFT",2,-1);cell.icon:SetTexture(definition.icon)
            cell.badge=cell:CreateTexture(nil,"OVERLAY");cell.badge:SetSize(12,12);cell.badge:SetPoint("BOTTOMRIGHT",cell.icon,"BOTTOMRIGHT",2,-1)
            cell.time=text(cell,"",10,29,-5,45);cell.time:SetHeight(17);cell.time:SetWordWrap(false);cell.time:SetMaxLines(1)
            cell:SetScript("OnEnter",function()
                local lines={cell.state or "Unknown"}
                if cell.remaining and cell.remaining~="" then lines[#lines+1]=cell.remaining.." remaining" end
                if cell.state=="Unknown" then lines[#lines+1]="Aura data unavailable; this is not reported as missing."
                elseif cell.state=="Not required" then lines[#lines+1]="Check disabled, provider absent, or not required for this class." end
                tooltip(cell,definition.label.." - "..(row.playerName or ""),lines)
            end)
            cell:SetScript("OnLeave",hideTip);cell:SetScript("OnHide",function() if GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(cell) then hideTip() end end)
        end
    end
    f.scroll:HookScript("OnVerticalScroll",function() if not A.renderingRaidChecks then A:RenderRaidChecks() end end)
    f.empty=text(f,"",12,24,-190,720)
    f.legend=text(f,"",10,14,-318,620);f.legend:SetHeight(18)
    f.autoHeight=button(f,"Auto Height",546,-310,104,function() A:SetRaidCheckHeight(nil) end)
    f.close=button(f,"Close",660,-310,100,function() f:Hide() end)
    f:SetScript("OnShow",function() A:ScanRaidChecks() end)
    f:SetScript("OnHide",hideTip)
    self:InstallRaidCheckResize(f)
end
function A:RenderRaidChecks()
    local f=self.ui and self.ui.raidChecks;local report=self.raidCheckReport
    if not f or not report or self.renderingRaidChecks or f.nrtCollapsed==true then return end
    self.renderingRaidChecks=true
    local grouped=self.raidCheckView=="issues";local entries={}
    if grouped then
        local groups={};for key,group in pairs(report.groups) do groups[#groups+1]={key=key,group=group} end
        table.sort(groups,function(a,b) return a.group.label<b.group.label end)
        for _,entry in ipairs(groups) do
            for first=1,#entry.group.names,4 do
                local names={};for i=first,math.min(first+3,#entry.group.names) do names[#names+1]=self:FullDisplayName(entry.group.names[i]) end
                entries[#entries+1]={label=entry.group.label,names=table.concat(names,", "),state="Missing"}
            end
        end
        local unknown={};for _,row in ipairs(report.rows) do if row.unknown and row.online~=false and row.dead~=true then unknown[#unknown+1]=row.name end end
        for first=1,#unknown,4 do
            local names={};for i=first,math.min(first+3,#unknown) do names[#names+1]=self:FullDisplayName(unknown[i]) end
            entries[#entries+1]={label="Buff data unavailable",names=table.concat(names,", "),state="Unknown"}
        end
    else for _,row in ipairs(report.rows) do if not self.raidCheckIssuesOnly or row.hasIssue then entries[#entries+1]=row end end end
    -- Stable columns keep each effect in the same place as players join,
    -- leave or lose a buff. Non-required effects already render dimmed.
    local columns={};for index in ipairs(self.raidCheckDefinitions) do columns[#columns+1]=index end
    local pitch=#columns>5 and 76 or 84;local cellWidth=pitch-8
    local width=grouped and 790 or math.max(790,290+#columns*pitch+44)
    if f:GetWidth()~=width then f:SetWidth(width) end
    f.summary:SetWidth(width-28);f.scroll:SetWidth(width-42);f.content:SetWidth(width-42)
    f.filter:ClearAllPoints();f.filter:SetPoint("TOPLEFT",width-166,-78)
    f.legend:SetWidth(width-290)
    local positions={};for column,index in ipairs(columns) do positions[index]=290+(column-1)*pitch end
    local chrome=218
    f.scroll:ClearAllPoints();f.scroll:SetPoint("TOPLEFT",14,-170)
    local stride=grouped and 44 or 26
    local visible=math.max(5,math.min(grouped and 10 or 16,#entries))
    local preferred=self:WindowLayoutStore().raidCheckHeight
    local minimum,maximum=self:RaidCheckHeightBounds(f)
    local height=math.max(minimum,math.min(maximum,finite(preferred) and preferred or chrome+visible*stride))
    if f:GetHeight()~=height then
        local left,top=self:WindowTopLeft(f);f:ClearAllPoints();f:SetPoint("TOPLEFT",UIParent,"TOPLEFT",left,-top);f:SetHeight(height)
    end
    f.scroll:SetHeight(math.max(26,height-chrome));f.legend:ClearAllPoints();f.legend:SetPoint("TOPLEFT",14,-height+29)
    f.autoHeight:ClearAllPoints();f.autoHeight:SetPoint("TOPLEFT",width-244,-height+35);f.autoHeight:SetEnabled(finite(preferred))
    f.close:ClearAllPoints();f.close:SetPoint("TOPLEFT",width-130,-height+35)
    f.content:SetHeight(math.max(1,#entries*stride))
    local offset=math.max(0,math.min(f.scroll:GetVerticalScroll(),math.max(0,f.content:GetHeight()-f.scroll:GetHeight())))
    if offset~=f.scroll:GetVerticalScroll() then f.scroll:SetVerticalScroll(offset) end
    local first=math.floor(offset/stride)+1
    for index,row in ipairs(f.rows) do
        local entry=entries[first+index-1];row:SetShown(entry~=nil)
        if entry then
            row:ClearAllPoints();row:SetPoint("TOPLEFT",0,-(first+index-2)*stride);row:SetHeight(stride);row:SetWidth(width-42)
            row.ready:SetShown(not grouped);row.status:SetShown(not grouped);row.classBar:SetShown(not grouped);row.issue:SetShown(grouped)
            for column,cell in ipairs(row.cells) do
                cell:SetShown(not grouped and positions[column]~=nil)
                if positions[column] then
                    cell:ClearAllPoints();cell:SetPoint("TOPLEFT",positions[column],-1);cell:SetWidth(cellWidth);cell.time:SetWidth(cellWidth-29)
                end
            end
            if grouped then
                row.shade:SetColorTexture(.075,.065,.08,1);set(row.name,entry.label,entry.state);row.issue:SetText(entry.names)
            else
                row.playerName=self:DisplayName(entry.name);row.readyStatus=entry.ready
                local c=RAID_CLASS_COLORS and RAID_CLASS_COLORS[entry.class] or {r=.85,g=.86,b=.89}
                row.shade:SetColorTexture(c.r*.13+(index%2)*.02,c.g*.13+(index%2)*.02,c.b*.13+(index%2)*.02,1)
                row.classBar:SetColorTexture(c.r,c.g,c.b,.9);row.name:SetText(row.playerName);row.name:SetTextColor(c.r,c.g,c.b)
                local status=entry.online==false and "Offline" or entry.dead==true and "Dead" or entry.online~=true and "Unknown" or ""
                set(row.status,status,status=="Unknown" and "Unknown" or "Missing")
                row.ready.icon:SetTexture(readyTextures[entry.ready] or readyTextures["Not checked"])
                row.ready.icon:SetAlpha(entry.ready=="Not checked" and .35 or 1)
                for column,definition in ipairs(self.raidCheckDefinitions) do
                    local cell=row.cells[column];local state=entry.effects[definition.key];cell.state=state
                    cell.remaining=state=="Present" and self:RaidCheckRemainingText(entry.effectTiming and entry.effectTiming[definition.key]) or ""
                    cell.icon:SetDesaturated(state~="Present");cell.icon:SetAlpha(state=="Present" and 1 or state=="Not required" and .16 or .42)
                    cell.badge:SetShown(state=="Missing" or state=="Unknown")
                    cell.badge:SetTexture(state=="Missing" and readyTextures["Not ready"] or readyTextures.Waiting)
                    cell.time:SetText(cell.remaining);cell.time:SetTextColor(.84,.86,.89)
                end
            end
        end
    end
    for index,header in ipairs(f.headers) do
        header:SetShown(not grouped and positions[index]~=nil)
        if positions[index] then header:ClearAllPoints();header:SetPoint("TOPLEFT",14+positions[index],-115);header:SetWidth(cellWidth);header.label:SetWidth(cellWidth);header.count:SetWidth(cellWidth-28) end
        local key=self.raidCheckDefinitions[index].key;local missing,unknown,required=0,0,0
        for _,row in ipairs(report.rows) do local state=row.effects[key];if state=="Missing" then missing=missing+1 elseif state=="Unknown" then unknown=unknown+1 end;if state~="Not required" then required=required+1 end end
        header.count:SetText(missing>0 and tostring(missing) or unknown>0 and "?" or required>0 and "OK" or "-")
        local color=missing>0 and colors.Missing or unknown>0 and colors.Unknown or required>0 and colors.Present or colors["Not required"]
        header.count:SetTextColor(color[1],color[2],color[3]);header.icon:SetAlpha(required>0 and 1 or .2)
        header.explanation=missing.." missing | "..unknown.." unknown. Hover a player's icon for details."
        if self.raidCheckDefinitions[index].observe then header.explanation=header.explanation.." Requirements: Settings > Raid Tools." end
    end
    f.nameHeader:SetText(grouped and "Issue" or "Ready / Player");f.issueHeader:SetShown(grouped)
    f.empty:SetShown(#entries==0);f.empty:SetText("No issues in the current view.")
    local ready=0;for _,row in ipairs(report.rows) do if row.ready=="Ready" then ready=ready+1 end end
    local check=self.raidReadyCheck;local pending=check and not check.finished and self.Client:Uptime()<check.expires
    f.summary:SetText(ready.."/"..#report.rows.." ready"..(pending and (" | "..math.ceil(check.expires-self.Client:Uptime()).."s") or "").." | "..report.offline.." offline | "..report.dead.." dead | "..report.missing.." missing | "..report.unknown.." unknown")
    f.legend:SetText("Buffs - Colour: present   Red X: missing   ?: unknown   Dim: not required")
    f.players:SetEnabled(grouped);f.issues:SetEnabled(not grouped)
    f.filter:SetText(self.raidCheckIssuesOnly and "Show: Issues" or "Show: All");f.filter:SetEnabled(not grouped)
    f.ready:SetEnabled(self:CanControlRaidChecks() and not self.demo and not self.Client:Combat() and not pending and type(self.Client:Get("DoReadyCheck"))=="function")
    f.announce:SetEnabled(self:CanControlRaidChecks());self:RefreshScrollChrome(f.scroll,math.max(0,f.content:GetHeight()-f.scroll:GetHeight()),offset)
    self.renderingRaidChecks=nil
end
function A:ShowRaidChecks()
    self:BuildUI()
    local layouts=self:WindowLayoutStore()
    if layouts.raidCheckCompactHeadings~=1 then layouts.raidCheckHeight=nil;layouts.raidCheckCompactHeadings=1 end
    self.ui.raidChecks:Show();self:ScanRaidChecks();self:FocusWindow(self.ui.raidChecks);return true
end
