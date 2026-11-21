local _,A=...
local function readable(value) return not (issecretvalue and issecretvalue(value)) end
local function boolean(value)
    if not readable(value) then return end
    if value==true or value==1 then return true end
    if value==false or value==0 then return false end
end
local manaClasses={DRUID=true,HUNTER=true,MAGE=true,PALADIN=true,PRIEST=true,SHAMAN=true,WARLOCK=true}
-- Spell IDs are aura effects, including rank/group variants and Forever copies.
A.raidCheckDefinitions={
    {key="fortitude",showPresent=true,short="Fort",icon="Interface/Icons/Spell_Holy_WordFortitude",label="Power Word: Fortitude",provider="PRIEST",nameIDs={1243,21562},ids={1243,1244,1245,2791,10937,10938,10939,10940,13864,23947,23948,21562,21564,450086}},
    {key="mark",showPresent=true,short="Mark",icon="Interface/Icons/Spell_Nature_Regeneration",label="Mark of the Wild",provider="DRUID",nameIDs={1126,21849},ids={1126,5232,5234,5286,5287,6756,8907,8908,9884,9885,16878,24752,364163,1291335,1310503,21849,21850}},
    {key="intellect",showPresent=true,short="Int",icon="Interface/Icons/Spell_Holy_MagicalSentry",label="Arcane Intellect",provider="MAGE",mana=true,nameIDs={1459,23028},ids={1459,1460,1461,10156,10157,13326,16876,364161,23028}},
    {key="kings",short="Kings",icon="Interface/Icons/Spell_Magic_MageArmor",label="Blessing of Kings",provider="PALADIN",observe=true,requiredByDefault=false,nameIDs={20217,25898},ids={20217,1213408,25898}},
    {key="might",short="Might",icon="Interface/Icons/Spell_Holy_FistOfJustice",label="Blessing of Might",provider="PALADIN",observe=true,requiredByDefault=false,physical=true,nameIDs={19740,25782},ids={19740,19834,19835,19836,19837,19838,25291,25782,25916}},
    {key="wisdom",short="Wisdom",icon="Interface/Icons/Spell_Holy_SealOfWisdom",label="Blessing of Wisdom",provider="PALADIN",observe=true,requiredByDefault=false,mana=true,nameIDs={19742,25894},ids={19742,19850,19852,19853,19854,25290,25894,25918}},
    {key="food",short="Food",icon="Interface/Icons/INV_Misc_Food_15",label="Food",nameIDs={19705},ids={19705,18192,18194,22730,25661,18125,18141}},
    {key="consumable",short="Flask",icon="Interface/Icons/INV_Potion_54",label="Flask / elixir",ids={17626,17627,17628,17629,17538,17539,11474,21920,17537,17535,11348,11334,11405,11390,11371,26276}},
}
function A:RaidCheckSettings()
    self:InitStorage();local saved=type(NauseRaidToolsDB.raidCheckSettings)=="table" and NauseRaidToolsDB.raidCheckSettings or {};local settings={}
    for _,definition in ipairs(self.raidCheckDefinitions) do
        local value=saved[definition.key]
        if type(value)=="boolean" then settings[definition.key]=value else settings[definition.key]=definition.requiredByDefault~=false end
    end
    return settings
end
function A:SetRaidCheckSetting(key,value)
    local settings=self:RaidCheckSettings();if settings[key]==nil or type(value)~="boolean" then return false end
    settings[key]=value;NauseRaidToolsDB.raidCheckSettings=settings
    self:ScanRaidChecks();if self.RenderSettings then self:RenderSettings() end;return true
end
function A:CanControlRaidChecks()
    if not self.Client:InGroup() then return false end
    if self:IsGameLeader() then return true end
    local ok,assistant=self.Client:Call("UnitIsGroupAssistant","player")
    return ok and boolean(assistant)==true
end
function A:ReadRaidCheckAuras(unit)
    if type(unit)~="string" then return {},{},false end
    if unit~="player" then
        local ok,visible=self.Client:Call("UnitIsVisible",unit)
        if not ok or boolean(visible)~=true then return {},{},false end
        local checked,inRange,hasRange=self.Client:Call("UnitInRange",unit)
        if checked and readable(hasRange) and hasRange and boolean(inRange)~=true then return {},{},false end
    end
    local modern=type(self.Client:Get("C_UnitAuras.GetAuraDataByIndex"))=="function"
    if not modern and type(self.Client:Get("UnitBuff"))~="function" then return {},{},false end
    local ids,names={},{};local timing={ids={},names={}};local complete=false
    for index=1,128 do
        local ok,aura,name,id,expires,duration
        if modern then
            ok,aura=self.Client:Call("C_UnitAuras.GetAuraDataByIndex",unit,index,"HELPFUL")
            if not ok or not readable(aura) then break end
            if aura==nil then complete=true;break end
            if type(aura)~="table" then break end
            local fields,spellID,auraName=pcall(function() return aura.spellId or aura.spellID,aura.name end)
            if not fields or not readable(spellID) or not readable(auraName) then break end
            id,name=spellID,auraName
            local timeOK,endTime,length=pcall(function() return aura.expirationTime,aura.duration end)
            if timeOK and readable(endTime) and readable(length) then expires,duration=endTime,length end
        else
            local result={self.Client:Call("UnitBuff",unit,index)};ok=result[1];name=result[2];id=result[11]
            if not ok or not readable(name) or not readable(id) then break end
            if name==nil then complete=true;break end
            if readable(result[7]) and readable(result[8]) then duration,expires=result[7],result[8] end
        end
        local detail
        if type(expires)=="number" and expires==expires and expires>=0 and expires<100000000000 then
            detail={expires=expires,duration=type(duration)=="number" and duration==duration and duration>=0 and duration or nil}
        end
        if type(id)=="number" then ids[id]=true;if detail then timing.ids[id]=detail end end
        if type(name)=="string" then names[name]=true;if detail then timing.names[name]=detail end end
    end
    return ids,names,complete,timing
end
function A:RaidCheckEffect(definition,ids,names,complete,timing)
    local secretAPI=type(self.Client:Get("C_Secrets.ShouldSpellAuraBeSecret"))=="function"
    if self.Client:Combat() and not secretAPI then complete=false end
    for _,id in ipairs(definition.ids) do
        if secretAPI then
            local ok,secret=self.Client:Call("C_Secrets.ShouldSpellAuraBeSecret",id)
            if not ok or not readable(secret) or secret then return "Unknown" end
        end
    end
    for _,id in ipairs(definition.ids) do if ids[id] then return "Present",timing and timing.ids[id] end end
    self.raidCheckSpellNames=self.raidCheckSpellNames or {}
    for _,id in ipairs(definition.nameIDs or definition.ids) do
        local name=self.raidCheckSpellNames[id]
        if not name then
            local ok,value=self.Client:Call("C_Spell.GetSpellName",id)
            if not ok then ok,value=self.Client:Call("GetSpellInfo",id) end
            if ok and readable(value) and type(value)=="string" then name=value;self.raidCheckSpellNames[id]=name end
        end
        if name and names[name] then return "Present",timing and timing.names[name] end
    end
    return complete and "Missing" or "Unknown"
end
function A:RaidCheckReadyStatus(name,unit)
    local check=self.raidReadyCheck
    if not check or self.Client:Uptime()>check.expires+90 or not check.members[name] then return "Not checked" end
    local status=check.members[name]
    if not check.finished and self.Client:Uptime()<check.expires then
        local ok,value=self.Client:Call("GetReadyCheckStatus",unit)
        if ok and readable(value) then
            if value=="ready" then status="Ready" elseif value=="notready" then status="Not ready" end
        end
    end
    check.members[name]=status
    if status=="Waiting" and (check.finished or self.Client:Uptime()>=check.expires) then return "No reply" end
    return status
end
function A:ScanRaidChecks()
    if self.scanningRaidChecks then return self.raidCheckReport end
    self.scanningRaidChecks=true
    self:RefreshRoster()
    if self.raidReadyCheck and self.raidReadyCheck.roster~=self:RosterKey() then self.raidReadyCheck=nil end
    local roster=self.Copy(self.roster or {})
    if not next(roster) and self.me then roster[self.me]="player" end
    local report={at=self.Client:Uptime(),rows={},groups={},unknown=0,missing=0,offline=0,dead=0}
    local providers={}
    for _,unit in pairs(roster) do if type(unit)=="string" then
        local ok,connected=self.Client:Call("UnitIsConnected",unit)
        local classOK,_,class=self.Client:Call("UnitClass",unit)
        if ok and boolean(connected)==true and classOK and readable(class) and type(class)=="string" then providers[class]=true end
    end end
    local settings=self:RaidCheckSettings()
    local function issue(key,label,name)
        local group=report.groups[key];if not group then group={label=label,names={}};report.groups[key]=group end
        group.names[#group.names+1]=name
    end
    for name,unit in pairs(roster) do
        local row={name=name,unit=unit,effects={},effectTiming={},missing={},unknown=false,ready=self:RaidCheckReadyStatus(name,unit)}
        local ok,connected=self.Client:Call("UnitIsConnected",unit)
        row.online=ok and boolean(connected) or nil
        if ok and boolean(connected)==false then row.online=false end
        local deadOK,dead=self.Client:Call("UnitIsDeadOrGhost",unit);row.dead=deadOK and boolean(dead) or nil
        local classOK,_,class=self.Client:Call("UnitClass",unit);row.class=classOK and readable(class) and class or nil
        if row.online==false then report.offline=report.offline+1;issue("offline","Offline",name)
        elseif row.dead==true then report.dead=report.dead+1;issue("dead","Dead",name) end
        if row.ready=="Not ready" or row.ready=="No reply" then issue(row.ready,row.ready,name) end
        local ids,names,complete,timing={},{},false,nil
        if row.online==true and row.dead~=true then ids,names,complete,timing=self:ReadRaidCheckAuras(unit) end
        for _,definition in ipairs(self.raidCheckDefinitions) do
            local enabled=settings[definition.key] and (not definition.provider or providers[definition.provider])
            if enabled and definition.mana and row.class and not manaClasses[row.class] then enabled=false end
            if enabled and definition.physical and row.class and row.class~="WARRIOR" and row.class~="ROGUE" and row.class~="HUNTER" then enabled=false end
            local state="Not required"
            if enabled or definition.observe or (definition.showPresent and settings[definition.key]) then
                if row.online~=true or row.dead==true then state="Unknown"
                else
                    state,row.effectTiming[definition.key]=self:RaidCheckEffect(definition,ids,names,complete,timing)
                    if state=="Missing" and enabled and (definition.mana or definition.physical) and not row.class then state="Unknown" end
                end
                if not enabled and state~="Present" then state="Not required" end
                if state=="Missing" then row.missing[#row.missing+1]=definition.label;report.missing=report.missing+1;issue(definition.key,"Missing "..definition.label,name)
                elseif state=="Unknown" then row.unknown=true end
            end
            row.effects[definition.key]=state
        end
        if row.unknown and row.online~=false and row.dead~=true then report.unknown=report.unknown+1 end
        row.hasIssue=row.online==false or row.dead==true or #row.missing>0 or row.ready=="Not ready" or row.ready=="No reply" or row.unknown
        report.rows[#report.rows+1]=row
    end
    table.sort(report.rows,function(a,b) if a.hasIssue~=b.hasIssue then return a.hasIssue end;return a.name<b.name end)
    for _,group in pairs(report.groups) do table.sort(group.names) end
    self.raidCheckReport=report;self.scanningRaidChecks=nil
    if self.RenderRaidChecks then self:RenderRaidChecks() end
    return report
end
function A:BeginRaidReadyRecord(timeout)
    timeout=type(timeout)=="number" and readable(timeout) and math.max(1,math.min(120,timeout)) or 30
    local check={expires=self.Client:Uptime()+timeout,members={},roster=self:RosterKey()}
    for name in pairs(self.roster or {}) do check.members[name]="Waiting" end
    self.raidReadyCheck=check
end
function A:StartRaidReadyCheck()
    if not self:CanControlRaidChecks() or self.demo then self:Print("Only a live group leader or raid assistant can start a Ready Check.");return false end
    if self.Client:Combat() then self:Print("Start the Ready Check after combat.");return false end
    if self.raidReadyCheck and not self.raidReadyCheck.finished and self.Client:Uptime()<self.raidReadyCheck.expires then
        self:Print("A Ready Check is already in progress.");return false
    end
    local previous=self.raidReadyCheck;self:RefreshRoster();self:BeginRaidReadyRecord(30)
    local ok,result=self.Client:Call("DoReadyCheck")
    if not ok or result==false then self.raidReadyCheck=previous;self:Print("The client could not start a Ready Check.");return false end
    self:ScanRaidChecks();return true
end
function A:RaidCheckAnnouncementLines(report)
    local keys={};for key in pairs(report.groups) do keys[#keys+1]=key end;table.sort(keys)
    local lines={}
    for _,key in ipairs(keys) do
        local group=report.groups[key];local prefix="[Nause] "..group.label..": ";local message=prefix
        for _,name in ipairs(group.names) do
            name=self:FullDisplayName(name)
            local separator=message==prefix and "" or ", "
            if #message+#separator+#name>240 then lines[#lines+1]=message;message=prefix;separator="" end
            message=message..separator..name
        end
        if message~=prefix then lines[#lines+1]=message end
    end
    if #lines==0 then lines[1]="[Nause] No detected raid readiness issues." end
    if report.unknown>0 then lines[#lines+1]="[Nause] Buff data unavailable for "..report.unknown.." player(s). Unknown checks are not announced as missing." end
    return lines
end
function A:AnnounceRaidCheckIssues()
    if not self:CanControlRaidChecks() then self:Print("Only the group leader or raid assistants can announce raid issues.");return false end
    local lines=self:RaidCheckAnnouncementLines(self:ScanRaidChecks())
    for _,line in ipairs(lines) do
        if self.demo then self:Print("TEST: "..line)
        else self.Client:Call("C_ChatInfo.SendChatMessage",line,self.Client:InRaid() and "RAID" or "PARTY") end
    end
    return true
end
local events=CreateFrame("Frame")
for _,event in ipairs({"READY_CHECK","READY_CHECK_CONFIRM","READY_CHECK_FINISHED","GROUP_ROSTER_UPDATE","UNIT_AURA","UNIT_CONNECTION","UNIT_HEALTH","PLAYER_ENTERING_WORLD"}) do pcall(events.RegisterEvent,events,event) end
local dirty=true
local function shown() return A.ui and A.ui.raidChecks and A.ui.raidChecks:IsShown() end
events:SetScript("OnEvent",function(_,event,unit,value)
    if event=="READY_CHECK" then A:RefreshRoster();A:BeginRaidReadyRecord(value)
    elseif event=="READY_CHECK_CONFIRM" then
        local name=A:Name(unit) or A:Resolve(unit);local check=A.raidReadyCheck
        local ready=boolean(value)
        if check and name and check.members[name] and ready~=nil then check.members[name]=ready and "Ready" or "Not ready" end
    elseif event=="READY_CHECK_FINISHED" and A.raidReadyCheck then
        for name,token in pairs(A.roster or {}) do A:RaidCheckReadyStatus(name,token) end
        A.raidReadyCheck.finished=true
    end
    dirty=true
end)
local elapsed=0
events:SetScript("OnUpdate",function(_,dt)
    elapsed=elapsed+dt
    if shown() and elapsed>=1 and (dirty or elapsed>=5 or (A.raidReadyCheck and not A.raidReadyCheck.finished)) then elapsed=0;dirty=false;A:ScanRaidChecks() end
end)
A.raidCheckEvents=events
