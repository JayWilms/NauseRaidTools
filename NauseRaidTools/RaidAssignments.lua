local _,A=...
-- Versioned separately from loot traffic: older clients must not flatten boss plans.
local KIND="raidAssignments7"
A.assignmentSections={{"tank","Tanks"},{"healer","Healers"},{"interrupt","Interrupts"},{"dispel","Dispels"},{"cooldown","Cooldowns"},{"custom","Custom Jobs"},{"banish","Banishes"},{"sheep","Sheeps"},{"buff","Buffing"},{"tranq","Tranqs"},{"decurse","Decurse"},{"debuff","Debuffs"}}
local roles={main="Main Tank",off="Off-Tank",tank="Tank Healer",group="Group Healer",raid="Raid Healer",interrupt="Interrupt",dispel="Dispel",cooldown="Cooldown",custom="Custom Job",banish="Banish",sheep="Sheep",buff="Buff",tranq="Tranq",decurse="Decurse",debuff="Debuff"}
A.assignmentRoles=roles
local function clean(s,n,empty)
    return type(s)=="string" and #s<=n and (empty or #s>0) and not s:find("[|%c]")
end
local function integer(n,max) return type(n)=="number" and n==n and n%1==0 and n>=1 and n<=max end
local function trim(s) return type(s)=="string" and s:match("^%s*(.-)%s*$") or "" end
local function array(t,max)
    if type(t)~="table" or #t>max then return false end
    for k in pairs(t) do if not integer(k,#t) then return false end end
    return true
end
function A:AssignmentLeader()
    if not self.Client:InGroup() then return self.me end
    if select(2,self.Client:Call("UnitIsGroupLeader","player"))==true then return self.me end
    for name,entry in pairs(self.roster or {}) do
        local unit=type(entry)=="string" and entry or type(entry)=="table" and entry.unit
        if unit and select(2,self.Client:Call("UnitIsGroupLeader",unit))==true then return name end
    end
    -- Roster entries differ across clients; use native units for authority.
    local ok,count=self.Client:Call("GetNumGroupMembers");count=ok and type(count)=="number" and math.min(40,count) or 0
    for i=1,count do
        local unit=(self.Client:InRaid() and "raid" or "party")..i
        if select(2,self.Client:Call("UnitIsGroupLeader",unit))==true then return self:Name(unit) end
    end
end
function A:AssignmentTransportPeer(sender) return not self.demo and sender==self:AssignmentLeader() end
function A:CanEditAssignments(name)
    if self.demo then return false end
    name=name or self.me
    if not self.Client:InGroup() then return name==self.me end
    if name==self:AssignmentLeader() then return true end
    if name==self.me then return select(2,self.Client:Call("UnitIsGroupAssistant","player"))==true end
    local ok,count=self.Client:Call("GetNumGroupMembers");count=ok and type(count)=="number" and math.min(40,count) or 0
    for i=1,count do
        local unit=(self.Client:InRaid() and "raid" or "party")..i
        if self:Name(unit)==name then return select(2,self.Client:Call("UnitIsGroupAssistant",unit))==true end
    end
    return false
end

function A:ValidAssignmentCoverage(value)
    return type(value)=="string" and (value=="raid" or value=="1-2" or value=="3-4" or value=="5-6" or value=="7-8" or value=="1-4" or value=="5-8" or value:match("^[1-8]$")~=nil)
end
function A:AssignmentCoverageLabel(value)
    if value=="raid" then return "Whole Raid" end
    if type(value)=="string" and value:match("^%d%-%d$") then return "Groups "..value:gsub("%-","–") end
    return "Group "..tostring(value)
end
function A:AssignmentCoverageChoices()
    local choices={{"Whole Raid","raid"},{"Groups 1–2","1-2"},{"Groups 3–4","3-4"},{"Groups 5–6","5-6"},{"Groups 7–8","7-8"},{"Groups 1–4","1-4"},{"Groups 5–8","5-8"}}
    for group=1,8 do choices[#choices+1]={"Group "..group,tostring(group)} end;return choices
end
function A:AssignmentSlotKey(row)
    return row.kind..":"..row.role..":"..(row.job or ""):lower()..":"..tostring(row.slot or 1)..":"..tostring(row.marker or 0)..":"..(row.buff or "")
end
function A:NormaliseAssignmentRow(row)
    if type(row)~="table" then return end
    return {id=row.id,kind=row.kind,role=row.role,player=row.player or "",target=row.target or "",note=row.note or "",
        encounter=row.encounter or "raid",slot=row.slot or 1,backup=row.backup or "",job=row.job or "",link=row.link or 0,marker=row.marker or 0,buff=row.buff or "",targetPlayer=row.targetPlayer or "",debuff=row.debuff or ""}
end
function A:ValidAssignmentRow(row)
    if type(row)~="table" then return false end
    local r=self:NormaliseAssignmentRow(row)
    if not clean(r.player,100,true) or not clean(r.backup,100,true) or not clean(r.target,80,true) or not clean(r.note,120,true)
        or not clean(r.job,60,true) or not clean(r.encounter,20) or not integer(r.slot,99)
        or (r.marker~=0 and not integer(r.marker,8)) or not clean(r.buff,30,true) or not clean(r.targetPlayer,100,true) or not clean(r.debuff,30,true)
        or (r.link~=0 and not integer(r.link,1000000)) or (r.backup~="" and r.backup==r.player) then return false end
    if r.targetPlayer~="" and (not r.targetPlayer:find("%S") or (r.kind~="dispel" and r.kind~="decurse") or r.marker~=0 or r.link~=0 or r.slot>4) then return false end
    if r.kind=="debuff" then
        return r.role=="debuff" and self.assignmentDebuffDefinitions and self.assignmentDebuffDefinitions[r.debuff]~=nil
            and r.encounter=="raid" and r.marker==0 and r.slot==1 and r.link==0 and r.buff=="" and r.targetPlayer==""
    end
    if r.debuff~="" then return false end
    if r.kind=="buff" then
        return r.role=="buff" and self.assignmentBuffDefinitions and self.assignmentBuffDefinitions[r.buff]~=nil
            and r.marker==0 and r.link==0 and self:ValidAssignmentCoverage(r.target)
    end
    if r.buff~="" then return false end
    if r.kind=="tranq" then return r.role=="tranq" and r.marker~=0 and r.slot==r.marker and r.link==0 end
    if r.kind=="decurse" or (r.kind=="dispel" and r.job=="Magic dispel" and r.marker==0) then
        return r.role==r.kind and r.marker==0 and r.slot<=4 and r.link==0 and self:ValidAssignmentCoverage(r.target)
    end
    if r.kind=="tank" then return r.role=="main" or r.role=="off" end
    if r.kind=="healer" then
        if r.role~="tank" and r.role~="group" and r.role~="raid" then return false end
        if r.role=="group" then return r.link==0 and r.target:match("^[1-8]$")~=nil end
        return r.role~="tank" or r.link~=0 or clean(r.target,80)
    end
    return (r.kind=="interrupt" or r.kind=="dispel" or r.kind=="cooldown" or r.kind=="custom" or r.kind=="banish" or r.kind=="sheep")
        and r.role==r.kind and (r.kind~="custom" or clean(trim(r.job),60))
end
function A:ValidAssignmentRows(rows)
    if not array(rows,480) then return false end
    local ids={}
    for _,row in ipairs(rows) do
        if not self:ValidAssignmentRow(row) or not integer(row.id,1000000) or ids[row.id] then return false end
        ids[row.id]=true
    end
    return true
end
function A:CleanAssignmentPlan(value)
    if type(value)~="table" then return end
    if value.test~=nil and type(value.test)~="boolean" then return end
    local legacy=value.schema==nil
    if not legacy and value.schema~=2 then return end
    if not self:ValidAssignmentRows(value.rows) then return end
    local plan={schema=2,test=value.test==true,raidName=legacy and "Custom raid" or value.raidName,encounters={},activeEncounter=legacy and "raid" or value.activeEncounter,rows={},nextRow=1,nextEncounter=1}
    if not clean(plan.raidName,60) or not clean(plan.activeEncounter,20) then return end
    local encounters=legacy and {} or value.encounters
    if not array(encounters,24) then return end
    local scopes={raid=true};local names={}
    for _,v in ipairs(encounters) do
        if type(v)~="table" or not clean(v.id,20) or not v.id:match("^e%d+$") or scopes[v.id] or not clean(trim(v.name),60) or names[trim(v.name):lower()] then return end
        scopes[v.id]=true;names[trim(v.name):lower()]=true;plan.encounters[#plan.encounters+1]={id=v.id,name=trim(v.name)}
        local serial=tonumber(v.id:sub(2));if not integer(serial,1000000) then return end
        plan.nextEncounter=math.max(plan.nextEncounter,serial+1)
    end
    if not scopes[plan.activeEncounter] then return end
    local ids,slots={},{}
    for _,row in ipairs(value.rows) do
        local r=self:NormaliseAssignmentRow(row)
        if not scopes[r.encounter] then return end
        local key=r.encounter..":"..self:AssignmentSlotKey(r)
        if legacy then
            while slots[key] and r.slot<99 do r.slot=r.slot+1;key=r.encounter..":"..self:AssignmentSlotKey(r) end
        end
        if slots[key] then return end
        slots[key]=true;ids[r.id]=r;plan.rows[#plan.rows+1]=r;plan.nextRow=math.max(plan.nextRow,r.id+1)
    end
    -- Links name a stable slot. Keep them local to the encounter or its defaults.
    for _,row in ipairs(plan.rows) do
        if row.link~=0 then
            local target=ids[row.link]
            if not target or target.id==row.id or (target.encounter~="raid" and target.encounter~=row.encounter) then return end
            local seen={[row.id]=true};local nextRow=target
            while nextRow do
                if seen[nextRow.id] then return end;seen[nextRow.id]=true
                nextRow=nextRow.link~=0 and ids[nextRow.link] or nil
            end
        end
    end
    -- Bound the visible sheet as well as the whole raid so every job fits the UI.
    for scope in pairs(scopes) do
        local visible={};for _,r in ipairs(plan.rows) do if r.encounter=="raid" then visible[self:AssignmentSlotKey(r)]=true end end
        if scope~="raid" then for _,r in ipairs(plan.rows) do if r.encounter==scope then visible[self:AssignmentSlotKey(r)]=true end end end
        local count=0;for _ in pairs(visible) do count=count+1 end;if count>120 then return end
    end
    if integer(value.nextRow,1000000) then plan.nextRow=math.max(plan.nextRow,value.nextRow) end
    if integer(value.nextEncounter,1000000) then plan.nextEncounter=math.max(plan.nextEncounter,value.nextEncounter) end
    return plan
end
function A:AssignmentPlan(board)
    local b=board or self:AssignmentBoard();if not b then return end
    return {schema=2,test=b.test==true,raidName=b.raidName,encounters=self.Copy(b.encounters),activeEncounter=b.activeEncounter,rows=self.Copy(b.rows),nextRow=b.nextRow,nextEncounter=b.nextEncounter}
end
function A:StoreAssignmentPlan(b)
    if b.test then return end
    local plan=self:AssignmentPlan(b);plan.epoch=b.epoch;NauseRaidToolsDB.raidAssignments=plan
end
function A:NextAssignmentEpoch(previous)
    self:InitStorage()
    local epoch=math.max((tonumber(previous) or 0)+1,(tonumber(NauseRaidToolsDB.assignmentEpoch) or 0)+1,self.Client:ServerTime())
    NauseRaidToolsDB.assignmentEpoch=epoch;return epoch
end
function A:AssignmentBoard()
    if self.demo then return self.assignmentBoard end
    self:InitStorage();local owner=self:AssignmentLeader()
    if self.assignmentOwner~=owner then self.assignmentOwner=owner;self.assignmentBoard=nil;self.assignmentTestRestore=nil end
    if not self.assignmentBoard and owner==self.me then
        local saved=NauseRaidToolsDB.raidAssignments or {rows={}}
        local plan=self:CleanAssignmentPlan(saved) or self:CleanAssignmentPlan({rows={}})
        local epoch=self:NextAssignmentEpoch(saved.epoch)
        plan.test=false
        plan.owner=owner;plan.epoch=epoch;plan.revision=0;self.assignmentBoard=plan;self:StoreAssignmentPlan(plan)
    end
    return self.assignmentBoard
end
function A:SendAssignments(op,data,target)
    if self.demo or not self.Client:InGroup() then return false end
    return self:Send({kind=KIND,op=op,data=data},target,{priority=2,key=op=="state" and ("assignments:"..tostring(target)) or nil})
end
function A:PublishAssignments(target)
    local b=self:AssignmentBoard()
    if b and b.owner==self.me then self:SendAssignments("state",self.Copy(b),target) end
end
function A:RefreshAssignments(force)
    local b=self:AssignmentBoard();local now=self.Client:Uptime()
    if not self.demo and self.Client:InGroup() and (force or (not b and now-(self.assignmentRequestedAt or -100)>5)) then
        self.assignmentRequestedAt=now
        if self.assignmentOwner==self.me then self:PublishAssignments() else self:SendAssignments("sync",{},self.assignmentOwner) end
    end
    if self.RenderAssignments then self:RenderAssignments() end
    return b
end
function A:CommitAssignmentPlan(plan,edit)
    local b=self:AssignmentBoard();local cleanPlan=self:CleanAssignmentPlan(plan)
    if not b or b.owner~=self.me or not self:CanEditAssignments() or not cleanPlan then return false end
    if b.test and not cleanPlan.test then self.assignmentTestRestore=nil end
    for key,value in pairs(cleanPlan) do b[key]=value end
    local before=b.revision;b.revision=before+1;self:StoreAssignmentPlan(b)
    if edit then
        self:SendAssignments("delta",{epoch=b.epoch,baseRevision=before,revision=b.revision,op=edit.op,row=edit.row,id=edit.id})
    else self:PublishAssignments() end
    if self.RenderAssignments then self:RenderAssignments() end;return true
end
-- A pure reducer is shared by the host and receivers; only the host authorises edits.
function A:EditedAssignmentPlan(b,op,row,id)
    local plan=self:AssignmentPlan(b);local index
    for i,v in ipairs(plan.rows) do if v.id==id then index=i end end
    if op=="boardCell" then
        if not self:EditMarkerBoardCell(plan,row) then return false end
    elseif op=="remove" then
        if not index then return false end;table.remove(plan.rows,index)
    elseif op=="add" or op=="update" then
        if not self:ValidAssignmentRow(row) or (op=="update" and not index) then return false end
        local value=self:NormaliseAssignmentRow(row)
        if op=="add" then
            if #plan.rows>=480 or plan.nextRow>1000000 then return false end
            value.id=plan.nextRow;plan.nextRow=plan.nextRow+1;plan.rows[#plan.rows+1]=value
        else value.id=id;plan.rows[index]=value end
    elseif op=="newRaid" then
        if type(row)~="table" or not clean(trim(row.name),60) then return false end
        plan.raidName=trim(row.name);plan.encounters={};plan.rows={};plan.activeEncounter="raid"
    elseif op=="raidName" then
        if type(row)~="table" or not clean(trim(row.name),60) then return false end;plan.raidName=trim(row.name)
    elseif op=="encounterAdd" then
        if type(row)~="table" or not clean(trim(row.name),60) or #plan.encounters>=24 then return false end
        local key="e"..plan.nextEncounter;plan.nextEncounter=plan.nextEncounter+1
        plan.encounters[#plan.encounters+1]={id=key,name=trim(row.name)};plan.activeEncounter=key
    elseif op=="encounterRename" or op=="encounterRemove" then
        local found
        for i,v in ipairs(plan.encounters) do if v.id==id then found=i end end
        if not found then return false end
        if op=="encounterRename" then
            if type(row)~="table" or not clean(trim(row.name),60) then return false end;plan.encounters[found].name=trim(row.name)
        else
            table.remove(plan.encounters,found)
            for i=#plan.rows,1,-1 do if plan.rows[i].encounter==id then table.remove(plan.rows,i) end end
            if plan.activeEncounter==id then plan.activeEncounter="raid" end
        end
    elseif op=="activate" then plan.activeEncounter=id
    elseif op=="copyEncounter" then
        if type(row)~="table" or not clean(trim(row.name),60) or #plan.encounters>=24 then return false end
        local found=id=="raid";for _,v in ipairs(plan.encounters) do if v.id==id then found=true end end
        if not found then return false end
        local key="e"..plan.nextEncounter;plan.nextEncounter=plan.nextEncounter+1
        local copies,map,slotCopies={},{},{}
        for _,v in ipairs(self:EffectiveAssignments(id,b)) do
            if v.kind~="debuff" then
                local c=self.Copy(v);c.id=plan.nextRow;plan.nextRow=plan.nextRow+1;c.encounter=key;map[v.id]=c.id;slotCopies[self:AssignmentSlotKey(v)]=c.id;copies[#copies+1]=c
            end
        end
        for _,v in ipairs(plan.rows) do if v.encounter=="raid" and slotCopies[self:AssignmentSlotKey(v)] then map[v.id]=slotCopies[self:AssignmentSlotKey(v)] end end
        for _,v in ipairs(copies) do if map[v.link] then v.link=map[v.link] end;plan.rows[#plan.rows+1]=v end
        plan.encounters[#plan.encounters+1]={id=key,name=trim(row.name)};plan.activeEncounter=key
    else return false end
    return self:CleanAssignmentPlan(plan)
end
function A:ApplyAssignmentEdit(op,row,id)
    local b=self:AssignmentBoard()
    if not b or b.owner~=self.me or not self:CanEditAssignments() then return false end
    if op=="boardCell" and type(row)=="table" and (row.field==nil or row.field=="player" or row.field=="backup") and row.value~="" then
        if not self:AssignmentPlayerEligible(row.value,row,false) then return false end
    end
    local plan=self:EditedAssignmentPlan(b,op,row,id);if not plan then return false end
    local value
    if op=="boardCell" then value={kind=row.kind,marker=row.marker,seat=row.seat,slot=row.slot,buff=row.buff,debuff=row.debuff,field=row.field,value=row.value,encounter=row.encounter}
    elseif op=="add" or op=="update" then value=self:NormaliseAssignmentRow(row)
    elseif type(row)=="table" then value={name=row.name} end
    return self:CommitAssignmentPlan(plan,{op=op,row=value,id=id})
end
function A:EditAssignment(op,row,id)
    if not self:CanEditAssignments() then return false end
    local b=self:AssignmentBoard();if not b then self:RefreshAssignments(true);return false end
    if b.owner==self.me then return self:ApplyAssignmentEdit(op,row,id) end
    return self:SendAssignments("edit",{epoch=b.epoch,revision=b.revision,op=op,row=row,id=id},b.owner)
end
function A:AssignmentEncounterName(id,b)
    b=b or self:AssignmentBoard();if id=="raid" then return "Raid-Wide Assignments" end
    for _,v in ipairs(b and b.encounters or {}) do if v.id==id then return v.name end end
    return "Unknown encounter"
end
function A:EffectiveAssignments(scope,b)
    b=b or self:AssignmentBoard();if not b then return {} end
    scope=scope or b.activeEncounter;local slots={};local rows={}
    for _,row in ipairs(b.rows) do if row.encounter=="raid" then slots[self:AssignmentSlotKey(row)]=row end end
    if scope~="raid" then for _,row in ipairs(b.rows) do if row.encounter==scope then slots[self:AssignmentSlotKey(row)]=row end end end
    for _,row in pairs(slots) do rows[#rows+1]=row end
    local order={};for i,v in ipairs(self.assignmentSections) do order[v[1]]=i end
    table.sort(rows,function(a,c)
        if order[a.kind]~=order[c.kind] then return order[a.kind]<order[c.kind] end
        local an,cn=a.job~="" and a.job or roles[a.role],c.job~="" and c.job or roles[c.role]
        if an~=cn then return an<cn end
        if a.slot~=c.slot then return a.slot<c.slot end;return a.id<c.id
    end)
    return rows
end
function A:AssignmentTarget(row,scope,b,effective)
    b=b or self:AssignmentBoard()
    if (row.kind=="dispel" or row.kind=="decurse") and row.marker==0 and row.targetPlayer and row.targetPlayer~="" then
        return self:FullDisplayName(row.targetPlayer)
    end
    if row.link and row.link~=0 then
        local linked;for _,v in ipairs(b and b.rows or {}) do if v.id==row.link then linked=v end end
        if not linked then return "Missing linked slot" end
        -- Defaults follow the same job/number when that slot has a boss override.
        if linked.encounter=="raid" then
            for _,v in ipairs(effective or self:EffectiveAssignments(scope,b)) do if self:AssignmentSlotKey(v)==self:AssignmentSlotKey(linked) then linked=v end end
        end
        return (linked.job~="" and linked.job or roles[linked.role]).." #"..linked.slot..": "..(linked.player~="" and self:FullDisplayName(linked.player) or "Unfilled")
    end
    if row.kind=="buff" or ((row.kind=="dispel" or row.kind=="decurse") and row.marker==0 and self:ValidAssignmentCoverage(row.target)) then
        return self:AssignmentCoverageLabel(row.target)
    end
    if row.role=="group" then return "Group "..row.target end
    if row.role=="tank" then return self:FullDisplayName(row.target) end
    return row.target
end
-- Display known built-in labels consistently without rewriting saved job/slot keys.
function A:AssignmentJobLabel(row)
    local labels={["Tank healer"]="Tank Healer",["Main tank"]="Main Tank",["Off-tank"]="Off-Tank",["Group healer"]="Group Healer",["Raid healer"]="Raid Healer",["Magic dispel"]="Magic Dispel"}
    return row.job~="" and (labels[row.job] or row.job) or roles[row.role]
end
function A:AssignmentText(row,scope,b,effective)
    local target=self:AssignmentTarget(row,scope,b,effective)
    return (row.player~="" and self:FullDisplayName(row.player) or "UNFILLED").." - "..self:AssignmentJobLabel(row)..(row.kind~="buff" and row.kind~="debuff" and (" #"..row.slot) or "")
        ..(target~="" and (": "..target) or "")..(row.backup~="" and ("; backup "..self:FullDisplayName(row.backup)) or "")..(row.note~="" and (" ("..row.note..")") or "")
end
local packet=A.Packet
function A:Packet(sender,p,channel)
    if type(p)~="table" or p.kind~=KIND then return packet(self,sender,p,channel) end
    if self.demo or p.protocol~=self.protocol or not self.roster[sender] then return end
    local b=self:AssignmentBoard();local d=p.data
    if p.op=="head" and sender==self.assignmentOwner and type(d)=="table" then
        if not b or b.epoch~=d.epoch or b.revision~=d.revision then self:RefreshAssignments(true) end
    elseif p.op=="notice" and sender==self.assignmentOwner then self:Print("Assignments changed or the edit was invalid. Review the refreshed plan and try again.")
    elseif p.op=="sync" and self.assignmentOwner==self.me then
        self.assignmentSyncAt=self.assignmentSyncAt or {};local now=self.Client:Uptime()
        if now-(self.assignmentSyncAt[sender] or -100)>=3 then self.assignmentSyncAt[sender]=now;self:PublishAssignments(sender) end
    elseif p.op=="delta" and sender==self.assignmentOwner and type(d)=="table" then
        if not b or d.epoch~=b.epoch or type(d.baseRevision)~="number" or d.baseRevision~=b.revision or d.revision~=b.revision+1 then
            if not b or type(d.revision)~="number" or d.revision>b.revision then self:RefreshAssignments(true) end;return
        end
        local plan=self:EditedAssignmentPlan(b,d.op,d.row,d.id)
        if not plan then self:RefreshAssignments(true);return end
        plan.owner=sender;plan.epoch=b.epoch;plan.revision=d.revision;self.assignmentBoard=plan
        self.assignmentSeen=self.assignmentSeen or {};self.assignmentSeen[sender]={epoch=plan.epoch,revision=plan.revision}
        if plan.test and self.AdoptSharedAssignmentTest then self:AdoptSharedAssignmentTest() end
        if self.RenderAssignments then self:RenderAssignments() end
    elseif p.op=="state" and sender==self.assignmentOwner and type(d)=="table" and d.owner==sender and d.schema==2
        and integer(d.epoch,1000000000000) and type(d.revision)=="number" and d.revision>=0 and d.revision<1e9 and d.revision%1==0 then
        local plan=self:CleanAssignmentPlan(d);if not plan then return end
        self.assignmentSeen=self.assignmentSeen or {};local seen=self.assignmentSeen[sender]
        if seen and (d.epoch<seen.epoch or (d.epoch==seen.epoch and d.revision<seen.revision)) then return end
        if b and (d.epoch<b.epoch or (d.epoch==b.epoch and d.revision<b.revision)) then return end
        self.assignmentSeen[sender]={epoch=d.epoch,revision=d.revision};plan.owner=sender;plan.epoch=d.epoch;plan.revision=d.revision
        self.assignmentBoard=plan
        if plan.test and self.AdoptSharedAssignmentTest then self:AdoptSharedAssignmentTest() end
        if self.RenderAssignments then self:RenderAssignments() end
    elseif p.op=="edit" and b and b.owner==self.me and self:CanEditAssignments(sender) and type(d)=="table" then
        if d.epoch~=b.epoch or d.revision~=b.revision or not self:ApplyAssignmentEdit(d.op,d.row,d.id) then
            self:SendAssignments("notice",{},sender);self:PublishAssignments(sender)
        end
    end
end
function A:AnnounceAssignments(scope)
    if (self:AssignmentBoard() or {}).test then return false end
    if self.demo or not self.Client:InGroup() or not self:CanEditAssignments() then return false end
    local b=self:AssignmentBoard();if not b then return false end
    scope=scope or b.activeEncounter
    local channel=self.Client:InRaid() and "RAID" or "PARTY"
    local effective=self:EffectiveAssignments(scope,b)
    for _,row in ipairs(effective) do
        local line="[Nause] "..self:AssignmentEncounterName(scope,b).." | "..self:AssignmentText(row,scope,b,effective)
        while #line>240 do local n=240;while n>0 and line:byte(n+1)>=128 and line:byte(n+1)<192 do n=n-1 end
            self.Client:Call("C_ChatInfo.SendChatMessage",line:sub(1,n),channel);line=line:sub(n+1) end
        self.Client:Call("C_ChatInfo.SendChatMessage",line,channel)
    end
    return true
end
function A:SaveAssignmentProfile(name)
    self:InitStorage();local p=NauseRaidToolsDB.profiles[name or ""];local b=self:AssignmentBoard()
    if not p or not b or b.test or self.demo or self:AssignmentLeader()~=self.me then return false end
    p.raidAssignmentPlan=self:AssignmentPlan(b);p.raidAssignments=nil;self:Print("Saved assignments to profile: "..name);return true
end
function A:LoadAssignmentProfile(name)
    self:InitStorage();local p=NauseRaidToolsDB.profiles[name or ""]
    if self.demo or self:AssignmentLeader()~=self.me or not p then return false end
    local plan=self:CleanAssignmentPlan(p.raidAssignmentPlan or {rows=p.raidAssignments})
    return plan and self:CommitAssignmentPlan(plan) or false
end
function A:SaveAssignmentTemplate(name)
    self:InitStorage();name=trim(name)
    if not clean(name,40) or self.demo or self:AssignmentLeader()~=self.me then return false end
    local b=self:AssignmentBoard();if not b or b.test then return false end
    local templates=NauseRaidToolsDB.assignmentTemplates or {};local count=0;for _ in pairs(templates) do count=count+1 end
    if count>=20 and not templates[name] then return false end
    templates[name]=self:AssignmentPlan(b);NauseRaidToolsDB.assignmentTemplates=templates;self:Print("Saved raid plan: "..name);return true
end
function A:DeleteAssignmentTemplate(name)
    self:InitStorage();if self.demo or self:AssignmentLeader()~=self.me then return false end
    local templates=NauseRaidToolsDB.assignmentTemplates or {};if not templates[name or ""] then return false end
    templates[name]=nil;return true
end
function A:LoadAssignmentTemplate(name)
    self:InitStorage();if self.demo or self:AssignmentLeader()~=self.me then return false end
    local plan=(NauseRaidToolsDB.assignmentTemplates or {})[name or ""]
    return plan and self:CommitAssignmentPlan(plan) or false
end
function A:CreateAssignmentPractice()
    if self.demo or self.Client:InGroup() then return false end
    local b=self:AssignmentBoard();local plan=self:AssignmentPlan(b)
    if #plan.encounters>=24 or #plan.rows>477 then return false end
    local scope="e"..plan.nextEncounter;plan.nextEncounter=plan.nextEncounter+1
    local title="Practice encounter (fictional) "..(#plan.encounters+1)
    plan.encounters[#plan.encounters+1]={id=scope,name=title};plan.activeEncounter=scope
    local tankID=plan.nextRow
    local examples={{kind="tank",role="main",job="Practice tank"},{kind="healer",role="tank",job="Practice healer",link=tankID},{kind="interrupt",role="interrupt",job="Practice interrupt"}}
    for _,v in ipairs(examples) do
        local row=self:NormaliseAssignmentRow(v);row.id=plan.nextRow;plan.nextRow=plan.nextRow+1;row.encounter=scope;row.note="Fictional job for testing; not encounter guidance."
        plan.rows[#plan.rows+1]=row
    end
    return self:CommitAssignmentPlan(plan)
end
local save=A.SaveProfile
function A:SaveProfile(name)
    local b=self:AssignmentBoard();if b and b.test then self:Print("End the assignment test before saving a profile.");return false end
    local result=save(self,name)
    if result then local trimmed=name:match("^%s*(.-)%s*$");self:SaveAssignmentProfile(trimmed) end
    return result
end
local load=A.LoadProfile
function A:LoadProfile(name)
    local result=load(self,name)
    if result~=false then self:LoadAssignmentProfile(name:match("^%s*(.-)%s*$")) end
    return result
end
local events=CreateFrame("Frame");events:RegisterEvent("GROUP_ROSTER_UPDATE");events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent",function() A.assignmentRefreshDue=A.Client:Uptime()+1 end)
local elapsed=0
events:SetScript("OnUpdate",function(_,dt)
    elapsed=elapsed+dt;if elapsed<1 then return end;elapsed=0
    local now=A.Client:Uptime()
    if A.me and not A.demo and A.Client:InGroup() and A:AssignmentLeader()==A.me and now-(A.assignmentHeadAt or -100)>15 then
        A.assignmentHeadAt=now;local b=A:AssignmentBoard();A:SendAssignments("head",{epoch=b.epoch,revision=b.revision})
    end
    if A.assignmentRefreshDue and now>=A.assignmentRefreshDue then A.assignmentRefreshDue=nil;A:RefreshAssignments(true)
    elseif A.ui and A.ui.assignments and A.ui.assignments:IsShown() then A:RefreshAssignments(false) end
end)

A.confirmationDialogs.NAUSERAIDTOOLS_ASSIGNMENT_PLAN={text="%s",button1="Confirm",button2="Cancel",timeout=60,OnAccept=function(dialog)
    local d=dialog.data;local b=A:AssignmentBoard()
    if type(d)~="table" or not b or b.owner~=d.owner or b.epoch~=d.epoch or b.revision~=d.revision or not A:CanEditAssignments() then A:Print("The raid plan changed. Review it before trying again.");return end
    local ok
    if d.op=="encounterRemove" then ok=A:EditAssignment(d.op,nil,d.id)
    elseif d.op=="newRaid" then ok=A:EditAssignment(d.op,{name=d.name})
    elseif d.op=="load" then
        local kind,name=d.id:match("^([^:]+):(.*)$")
        ok=kind=="profile" and A:LoadAssignmentProfile(name) or (kind=="plan" and A:LoadAssignmentTemplate(name))
    elseif d.op=="save" then ok=A:SaveAssignmentTemplate(d.name)
    elseif d.op=="delete" then ok=A:DeleteAssignmentTemplate(d.name) end
    if not ok then A:Print("Could not apply this change. Check the saved plan and your permissions.") end
    if ok and d.saveNewRaid then A:SaveAssignmentTemplate(d.name) end
    if ok and d.openBoard and A.OpenSimpleAssignmentsBoard then A:OpenSimpleAssignmentsBoard(false) end
    local f=A.ui and A.ui.assignmentAdvanced
    if f and ok then
        if d.op=="load" or d.op=="newRaid" or d.op=="encounterRemove" then f.viewEncounter=nil;if f.ClearEditor then f.ClearEditor() end end
        if d.op=="delete" then f.templateSource=nil end;A:RenderAssignments()
    end
end}
function A:ConfirmAssignmentAction(op,name,id)
    local b=self:AssignmentBoard();if not b or not self:CanEditAssignments() then return false end
    local message=op=="encounterRemove" and ("Remove encounter '"..name.."' and all its specific jobs? Raid defaults remain.")
        or op=="newRaid" and ("Start a blank raid plan named '"..name.."'? This replaces the active plan. Save a template first to keep it.")
        or op=="delete" and ("Delete the saved plan '"..name.."'? The active raid plan remains.")
        or op=="save" and ("Overwrite the saved plan '"..name.."' with the current raid and all encounter assignments?")
        or ("Replace the current raid plan with '"..name.."'? This loads its raid defaults, encounters and jobs.")
    local context=self:ShowConfirmation("NAUSERAIDTOOLS_ASSIGNMENT_PLAN",message)
    if not context then return false end
    context.data={op=op,name=name,id=id,owner=b.owner,epoch=b.epoch,revision=b.revision}
    self.ui.confirmation.nrtDialogOwner=(self.ui.assignmentAdvanced and self.ui.assignmentAdvanced:IsShown()) and self.ui.assignmentAdvanced or self.ui.assignments;return true
end
