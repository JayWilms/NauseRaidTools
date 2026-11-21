local _,A=...
local unpack=unpack or table.unpack
local function yes(v) return v==true or v==1 end
local mana={DRUID=true,HUNTER=true,MAGE=true,PALADIN=true,PRIEST=true,SHAMAN=true,WARLOCK=true}
function A:BuffReminderSettings()
    self:InitStorage()
    local all=NauseRaidToolsDB.buffReminderSettings
    if type(all)~="table" then all={};NauseRaidToolsDB.buffReminderSettings=all end
    local owner=self:Name("player") or self.me or "local"
    local saved=type(all[owner])=="table" and all[owner] or {}
    return {enabled=saved.enabled~=false,expiring=saved.expiring~=false},owner
end
function A:SetBuffReminderSetting(key,value)
    if (key~="enabled" and key~="expiring") or type(value)~="boolean" then return false end
    local settings,owner=self:BuffReminderSettings();settings[key]=value;NauseRaidToolsDB.buffReminderSettings[owner]=settings
    self.buffReminderDismissed=nil;self:RefreshBuffReminders()
    if self.RenderSettings then self:RenderSettings() end;return true
end
function A:BuffReminderCoverage(target,group)
    if target=="raid" then return true end
    if not group then return nil end
    local first,last=target:match("^(%d)%-(%d)$")
    if first then return group>=tonumber(first) and group<=tonumber(last) end
    return group==tonumber(target)
end
function A:BuildBuffReminderReport(board,settings)
    local report={groups={},unknown=0,count=0};if not board or self.Client:Combat() or self.buffReminderInCombat then return report end
    settings=settings or self:BuffReminderSettings()
    local definitions={};for _,def in ipairs(self.raidCheckDefinitions) do definitions[def.key]=def end
    local me=self.me;local jobs={};local roster=self.roster or {}
    for _,row in ipairs(board.rows) do
        if row.encounter=="raid" and row.kind=="buff" and definitions[row.buff] then
            local primary=row.player==me;local backup=false
            if not primary and row.backup==me then
                local unit=roster[row.player]
                if row.player=="" or not unit then backup=true
                else
                    local ok,online=self.Client:Call("UnitIsConnected",unit)
                    local deadOK,dead=self.Client:Call("UnitIsDeadOrGhost",unit)
                    backup=(ok and (online==false or online==0)) or (deadOK and yes(dead))
                end
            end
            if (primary or backup) and self:AssignmentPlayerEligible(me,{kind="buff",buff=row.buff},false) then jobs[row.buff]={row=row,backup=backup} end
        end
    end
    if not next(jobs) then return report end
    local units={}
    for name,unit in pairs(roster) do if type(unit)=="string" then
        local ok,online=self.Client:Call("UnitIsConnected",unit);local deadOK,dead=self.Client:Call("UnitIsDeadOrGhost",unit)
        if ok and yes(online) and deadOK and not yes(dead) then
            local classOK,_,class=self.Client:Call("UnitClass",unit)
            local subgroup=1
            if self.Client:InRaid() then
                local index=tonumber(unit:match("^raid(%d+)$"));subgroup=nil
                if index then
                    local read,_,_,value=self.Client:Call("GetRaidRosterInfo",index)
                    if read and type(value)=="number" and value%1==0 and value>=1 and value<=8 then subgroup=value end
                end
            end
            units[#units+1]={name=name,unit=unit,class=classOK and class or nil,subgroup=subgroup}
        end
    end end
    table.sort(units,function(a,b) return a.name<b.name end)
    for _,key in ipairs(self.assignmentBuffOrder) do
        local job=jobs[key]
        if job then
            local definition=definitions[key];local group={key=key,label=definition.label,icon=definition.icon,backup=job.backup,targets={}}
            for _,member in ipairs(units) do
                local covered=self:BuffReminderCoverage(job.row.target,member.subgroup)
                local applies=not definition.mana and not definition.physical or member.class~=nil
                if definition.mana then applies=member.class and mana[member.class] end
                if definition.physical then applies=member.class=="WARRIOR" or member.class=="ROGUE" or member.class=="HUNTER" end
                if covered==nil or (covered and not member.class and (definition.mana or definition.physical)) then report.unknown=report.unknown+1
                elseif covered and applies then
                    if not member.auras then member.auras={self:ReadRaidCheckAuras(member.unit)} end
                    local state,timing=self:RaidCheckEffect(definition,unpack(member.auras))
                    local remaining=timing and timing.expires and timing.expires>0 and timing.expires-self.Client:Uptime() or nil
                    if state=="Missing" or (state=="Present" and settings.expiring and remaining and remaining<=60) then
                        group.targets[#group.targets+1]={name=member.name,unit=member.unit,class=member.class,state=state=="Missing" and "Missing" or "Expiring"};report.count=report.count+1
                    elseif state=="Unknown" then report.unknown=report.unknown+1 end
                end
            end
            if #group.targets>0 then report.groups[#report.groups+1]=group end
        end
    end
    return report
end
function A:BuffRemindersAllowed()
    if not self:BuffReminderSettings().enabled or self.Client:Combat() or self.buffReminderInCombat or not self.Client:InGroup() or self.demo or self.groupTest then return false end
    local u=self.ui
    if u and ((u.assignments:IsShown() and u.assignments.practice) or (u.myAssignments:IsShown() and u.myAssignments.practice)) then return false end
    return true
end
function A:RefreshBuffReminders()
    local f=self.ui and self.ui.buffReminders
    if not self:BuffRemindersAllowed() then if f then f:Hide() end;self:HideBuffReminderClicks();return end
    local board=self:AssignmentBoard();local report=self:BuildBuffReminderReport(board);self.buffReminderReport=report
    local parts={};for _,group in ipairs(report.groups) do
        parts[#parts+1]=group.key..(group.backup and ":backup" or ":primary")
        for _,target in ipairs(group.targets) do parts[#parts+1]=target.name..":"..target.state end
    end
    report.key=table.concat(parts,"|")
    if report.count==0 then self.buffReminderDismissed=nil;if f then f:Hide() end;return end
    if self.buffReminderDismissed==report.key then return end
    self:BuildUI();f=self.ui.buffReminders
    f.reportEpoch=board.epoch;f.reportRevision=board.revision
    local contentWidth=f:GetWidth()-42;local y=0;local index=0
    local function line(label,icon,heading,target,key)
        index=index+1;local row=f.rows[index] or f.createRow(index)
        row:Show();row:ClearAllPoints();row:SetPoint("TOPLEFT",0,-y);row:SetWidth(contentWidth);row:SetHeight(24)
        row.binding=target and self:BuffReminderClickBinding(target,key) or nil
        row.icon:SetShown(heading);if icon then row.icon:SetTexture(icon) end
        row.label:ClearAllPoints();row.label:SetPoint("TOPLEFT",heading and 28 or 8,-4);row.label:SetWidth(contentWidth-(heading and 34 or 16));row.label:SetText(label)
        local color=target and target.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[target.class]
        row.label:SetTextColor(color and color.r or (heading and .94 or .88),color and color.g or (heading and .78 or .9),color and color.b or (heading and .34 or .92))
        y=y+26
    end
    for _,group in ipairs(report.groups) do
        line(group.label..(group.backup and " (backup)" or ""),group.icon,true)
        for _,target in ipairs(group.targets) do line(self:FullDisplayName(target.name)..(target.state=="Expiring" and " (<1m)" or ""),nil,false,target,group.key) end
    end
    for i=index+1,#f.rows do f.rows[i].binding=nil;f.rows[i]:Hide() end
    f.title:SetWidth(f:GetWidth()-100)
    f.content:SetSize(contentWidth,math.max(1,y));f:SetHeight(math.max(92,math.min(320,y+58,UIParent:GetHeight()-40)))
    f.scroll:SetSize(contentWidth,math.max(24,f:GetHeight()-58))
    f:Show();self:RefreshScrollChrome(f.scroll)
    self.buffReminderClickGeometry=nil;self:PositionBuffReminderClicks()
end
function A:BuildBuffRemindersUI(u,window,text)
    local f=window("NauseRaidToolsBuffReminders","Assigned Buffs",300,120,false,false);u.buffReminders=f
    f.scroll=self:CreateScrollFrame(f);f.scroll:SetPoint("TOPLEFT",14,-44);f.scroll:SetSize(258,62)
    f.content=CreateFrame("Frame",nil,f.scroll);f.content:SetSize(258,1);f.scroll:SetScrollChild(f.content)
    f.rows={};f.createRow=function(index)
        local row=CreateFrame("Frame",nil,f.content)
        row.icon=row:CreateTexture(nil,"ARTWORK");row.icon:SetSize(20,20);row.icon:SetPoint("TOPLEFT",2,-2)
        row.label=text(row,"",12,28,-4,224);row.label:SetHeight(20);row.label:SetMaxLines(1)
        row:EnableMouseWheel(true);row:SetScript("OnMouseWheel",function(_,delta) f.scroll:GetScript("OnMouseWheel")(f.scroll,delta) end)
        f.rows[index]=row;return row
    end
    f.closeButton:SetScript("OnClick",function() A.buffReminderDismissed=A.buffReminderReport and A.buffReminderReport.key;f:Hide() end)
    f.scroll:HookScript("OnVerticalScroll",function() A.buffReminderClickGeometry=nil;A:PositionBuffReminderClicks() end)
    f:HookScript("OnHide",function() A:HideBuffReminderClicks() end)
    f:HookScript("OnUpdate",function() if f:IsShown() then A:PositionBuffReminderClicks() end end)
end
local events=CreateFrame("Frame");A.buffReminderEvents=events
for _,event in ipairs({"ADDON_LOADED","PLAYER_REGEN_DISABLED","PLAYER_REGEN_ENABLED","UNIT_AURA","UNIT_FLAGS","UNIT_CONNECTION","GROUP_ROSTER_UPDATE","PLAYER_ENTERING_WORLD"}) do pcall(events.RegisterEvent,events,event) end
local ready=false;local elapsed=0
events:SetScript("OnEvent",function(_,event,name)
    if event=="ADDON_LOADED" then if name=="NauseRaidTools" then ready=true end;return end
    if not ready then return end
    if event=="PLAYER_REGEN_DISABLED" then A.buffReminderInCombat=true;if A.ui and A.ui.buffReminders then A.ui.buffReminders:Hide() end;return end
    if event=="PLAYER_REGEN_ENABLED" then A.buffReminderInCombat=false;A.buffReminderDismissed=nil;A:RefreshBuffReminders() end
    elapsed=1
end)
events:SetScript("OnUpdate",function(_,dt)
    if not ready then return end
    elapsed=elapsed+dt;if elapsed<1 then return end;elapsed=0;A:RefreshBuffReminders()
end)
