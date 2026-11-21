local _,A=...
A.assignmentMarkers={{8,"Skull"},{7,"Cross"},{6,"Square"},{5,"Moon"},{4,"Triangle"},{3,"Diamond"},{2,"Circle"},{1,"Star"}}
local markerNames={};for _,v in ipairs(A.assignmentMarkers) do markerNames[v[1]]=v[2] end
A.assignmentBuffOrder={"intellect","fortitude","mark","kings","might","wisdom"}
A.assignmentBuffDefinitions={}
for _,def in ipairs(A.raidCheckDefinitions) do
    for _,key in ipairs(A.assignmentBuffOrder) do if key==def.key then A.assignmentBuffDefinitions[key]={label=def.label,icon=def.icon,provider=def.provider} end end
end
A.assignmentDebuffOrder={"elements","recklessness","weakness","tongues","faerieFire","exposeArmor"}
A.assignmentDebuffDefinitions={
    elements={label="Curse of the Elements",provider="WARLOCK",icon="Interface/Icons/Spell_Shadow_ChillTouch"},
    recklessness={label="Curse of Recklessness",provider="WARLOCK",icon="Interface/Icons/Spell_Shadow_UnholyStrength"},
    weakness={label="Curse of Weakness",provider="WARLOCK",icon="Interface/Icons/Spell_Shadow_CurseOfMannoroth"},
    tongues={label="Curse of Tongues",provider="WARLOCK",icon="Interface/Icons/Spell_Shadow_CurseOfTounges"},
    faerieFire={label="Faerie Fire",provider="DRUID",icon="Interface/Icons/Spell_Nature_FaerieFire"},
    exposeArmor={label="Expose Armor",provider="ROGUE",icon="Interface/Icons/Ability_Warrior_Riposte"},
}
local function clean(value,max,empty) return type(value)=="string" and #value<=max and (empty or value:find("%S")) and not value:find("[|%c]") end
local function coverage(value) return A:ValidAssignmentCoverage(value) end
A.assignmentCleanupDefinitions={
    dispel={label="Dispel (Magic)",job="Magic dispel",icon="Interface/Icons/Spell_Holy_DispelMagic"},
    decurse={label="Decurse",job="Decurse",icon="Interface/Icons/Spell_Nature_RemoveCurse"},
}
local groupPairs={"1-2","3-4","5-6","7-8"}
-- Class spellbooks checked against Forever client-derived data (see README).
-- Interrupts deliberately use the raid leader's requested rotation list.
A.assignmentClassRules={
    tank={WARRIOR=true,PALADIN=true,DRUID=true},
    healer={PRIEST=true,PALADIN=true,SHAMAN=true,DRUID=true},
    interrupt={ROGUE=true,SHAMAN=true,MAGE=true,WARRIOR=true,WARLOCK=true},
    banish={WARLOCK=true},sheep={MAGE=true},tranq={HUNTER=true},dispel={PRIEST=true,PALADIN=true},decurse={MAGE=true,DRUID=true},
}
local classNames={WARRIOR=true,PALADIN=true,HUNTER=true,ROGUE=true,PRIEST=true,SHAMAN=true,MAGE=true,WARLOCK=true,DRUID=true}
local function knownRole(value) return (value=="TANK" or value=="HEALER" or value=="DAMAGER") and value or nil end
function A:AssignmentMemberInfo(name,practice,scope)
    if practice==nil then practice=self.ui and self.ui.assignments and self.ui.assignments.practice==true end
    if practice and self.assignmentPracticePlayers and self.assignmentPracticePlayers[name] then
        return {class=self.assignmentPracticePlayers[name],role=(self.assignmentPracticeRoles or {})[name]}
    end
    local unit=self.roster and self.roster[name]
    if type(unit)~="string" then unit=name==self.me and "player" or nil end
    if not unit then return {} end
    local ok,_,class=self.Client:Call("UnitClass",unit)
    if not ok or not classNames[class] then class=nil end
    local roleOK,role=self.Client:Call("UnitGroupRolesAssigned",unit);role=roleOK and knownRole(role) or nil
    local index=unit:match("^raid(%d+)$")
    if index and (not role or not class) then
        local roster={self.Client:Call("GetRaidRosterInfo",tonumber(index))}
        if roster[1] then
            if not class and classNames[roster[7]] then class=roster[7] end
            role=role or knownRole(roster[13]) or (roster[11]=="MAINTANK" and "TANK" or nil)
        end
    end
    -- A planned tank must not appear as a healer just because the client reports NONE.
    if not role then
        local board=practice and self.assignmentPracticeBoard or self.assignmentBoard
        if board then
            local f=self.ui and self.ui.assignments
            local context=scope or (f and f.practice==practice and f.viewEncounter) or board.activeEncounter
            local plannedHealer=false
            for _,row in ipairs(self:EffectiveAssignments(context,board)) do
                if row.player==name then
                    if row.kind=="tank" then role="TANK";break end
                    if row.kind=="healer" then plannedHealer=true end
                end
            end
            if not role and plannedHealer then role="HEALER" end
        end
    end
    return {class=class,role=role}
end
function A:AssignmentCellForRole(role)
    local kind=(role=="main" or role=="off") and "tank" or ((role=="tank" or role=="group" or role=="raid") and "healer" or role)
    return {kind=kind}
end
function A:AssignmentPlayerEligible(name,cell,practice)
    if name=="" then return true end
    if not cell then return true end
    local info=self:AssignmentMemberInfo(name,practice,cell.encounter);local allowed=self.assignmentClassRules[cell.kind]
    if cell.kind=="buff" or cell.kind=="debuff" then
        local def=cell.kind=="buff" and self.assignmentBuffDefinitions[cell.buff or ""] or self.assignmentDebuffDefinitions[cell.debuff or ""]
        if not def then return false,"Unknown ability",info end
        allowed={[def.provider]=true}
    end
    if not allowed then return true,nil,info end
    if not info.class then return false,"Class unavailable",info end
    if not allowed[info.class] then return false,"Wrong class",info end
    -- Tank/healer duties use class capability; native role flags do not restrict planned jobs.
    return true,nil,info
end
function A:AssignmentPlayerColor(name,practice)
    if not name or name=="" then return end
    local info=self:AssignmentMemberInfo(name,practice)
    return info.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[info.class]
end
function A:AssignmentPlayerLabel(name,cell,practice)
    local label=self:FullDisplayName(name)
    local info=self:AssignmentMemberInfo(name,practice)
    if cell and cell.kind=="interrupt" and info.class=="WARLOCK" then label=label.." (Felhunter)" end
    return label
end
local function matches(row,kind,marker,seat,ability,slot)
    if row.kind~=kind then return false end
    if kind=="buff" then return row.buff==ability and row.slot==1 end
    if kind=="debuff" then return row.debuff==ability and row.slot==1 end
    if A.assignmentCleanupDefinitions[kind] then return row.marker==0 and row.slot==(slot or 1) and row.job==A.assignmentCleanupDefinitions[kind].job end
    if row.marker~=marker then return false end
    if kind=="healer" then return row.role=="tank" and row.slot==(marker-1)*2+(seat or 1) end
    return true
end
function A:MarkerBoardRow(board,scope,kind,marker,seat,ability,effective,slot)
    for _,row in ipairs(effective or self:EffectiveAssignments(scope,board)) do if matches(row,kind,marker,seat,ability,slot) then return row end end
end
function A:EditMarkerBoardCell(plan,cell)
    if type(cell)~="table" then return false end
    local kind=cell.kind;local field=cell.field or "player";local scope=cell.encounter or "raid"
    local groupJob=self.assignmentCleanupDefinitions[kind]
    if kind~="tank" and kind~="healer" and kind~="interrupt" and kind~="banish" and kind~="sheep" and kind~="buff" and kind~="debuff" and kind~="tranq" and not groupJob then return false end
    if groupJob and (type(cell.slot)~="number" or cell.slot%1~=0 or cell.slot<1 or cell.slot>4) then return false end
    local exists=scope=="raid";for _,enc in ipairs(plan.encounters) do if enc.id==scope then exists=true end end
    if not exists then return false end
    if kind=="debuff" and scope~="raid" then return false end
    if field~="player" and field~="backup" and field~="coverage" and field~="target" then return false end
    if field=="target" then
        if not groupJob or not clean(cell.value,100,true) or (cell.value~="" and not cell.value:find("%S")) then return false end
    elseif field=="coverage" then if (kind~="buff" and not groupJob) or not coverage(cell.value) then return false end
    elseif not clean(cell.value,100,true) then return false end
    if field~="player" and kind~="buff" and kind~="debuff" and not groupJob then return false end
    if kind=="buff" then
        if not self.assignmentBuffDefinitions[cell.buff] then return false end
    elseif kind=="debuff" then
        if not self.assignmentDebuffDefinitions[cell.debuff] then return false end
    elseif not groupJob and not markerNames[cell.marker] then return false end
    local seat=cell.seat or 1;if kind=="healer" and seat~=1 and seat~=2 then return false end
    local function getRow(wanted,wantedSeat,write)
        local inherited=self:MarkerBoardRow(plan,scope,wanted,cell.marker,wantedSeat,cell.buff or cell.debuff,nil,cell.slot)
        if inherited and (inherited.encounter==scope or not write) then return inherited end
        if not write then return end
        if plan.nextRow>1000000 then return end
        local row
        if inherited then row=self.Copy(inherited)
        else
            local isBuff=wanted=="buff";local isDebuff=wanted=="debuff";local cleanup=self.assignmentCleanupDefinitions[wanted]
            row=self:NormaliseAssignmentRow({kind=wanted,role=wanted=="tank" and "main" or (wanted=="healer" and "tank" or wanted),
                marker=(isBuff or isDebuff or cleanup) and 0 or cell.marker,buff=isBuff and cell.buff or "",debuff=isDebuff and cell.debuff or "",slot=cleanup and cell.slot or (wanted=="healer" and ((cell.marker-1)*2+(wantedSeat or 1)) or ((isBuff or isDebuff) and 1 or cell.marker)),
                job=isDebuff and self.assignmentDebuffDefinitions[cell.debuff].label or (cleanup and cleanup.job or (isBuff and self.assignmentBuffDefinitions[cell.buff].label or (wanted=="healer" and "Tank healer" or markerNames[cell.marker]))),
                target=isDebuff and "Raid targets" or (cleanup and groupPairs[cell.slot] or (isBuff and "raid" or markerNames[cell.marker]))})
        end
        row.id=plan.nextRow;plan.nextRow=plan.nextRow+1;row.encounter=scope;plan.rows[#plan.rows+1]=row;return row
    end
    local row=getRow(kind,seat,true);if not row then return false end
    if kind=="healer" then
        local tank=getRow("tank",1,false) or getRow("tank",1,true);if not tank then return false end
        row.link=tank.id
    end
    if field=="coverage" then row.target=cell.value;row.targetPlayer=""
    elseif field=="target" then row.targetPlayer=cell.value
    else row[field]=cell.value end
    return true
end
function A:SimpleAssignmentBoard()
    local f=self.ui and self.ui.assignments
    if f and f.practice then return self.assignmentPracticeBoard end
    return self:AssignmentBoard()
end
function A:SimpleAssignmentScope()
    local b=self:SimpleAssignmentBoard();local f=self.ui and self.ui.assignments
    if not b then return "raid" end
    local scope=f and f.viewEncounter or b.activeEncounter
    if scope=="raid" then return scope end
    for _,v in ipairs(b.encounters) do if v.id==scope then return scope end end
    if f then f.viewEncounter=nil end;return b.activeEncounter
end
function A:CanEditSimpleAssignments()
    local f=self.ui and self.ui.assignments
    return f and f.practice==true or self:CanEditAssignments()
end
function A:CreateSimpleAssignmentTest()
    if self.assignmentPracticeBoard then return self.assignmentPracticeBoard end
    local plan=self:CleanAssignmentPlan({rows={}});plan.raidName="Test Raid";plan.owner=self.me;plan.epoch=1;plan.revision=0
    self.assignmentPracticePlayers={};self.assignmentPracticeRoles={}
    local groups={{"Tank",3,"WARRIOR"},{"Healer",6,"PRIEST"},{"Rogue",2,"ROGUE"},{"Mage",2,"MAGE"},{"Hunter",2,"HUNTER"},{"Warlock",2,"WARLOCK"},{"Druid",2,"DRUID"},{"Paladin",1,"PALADIN"}}
    for _,group in ipairs(groups) do for i=1,group[2] do
        local name=string.format("Test%s%02d-Practice",group[1],i)
        local class=group[3];local role="DAMAGER"
        if group[1]=="Tank" then class=({"WARRIOR","PALADIN","DRUID"})[i];role="TANK"
        elseif group[1]=="Healer" then class=({"PRIEST","PALADIN","SHAMAN","DRUID","PRIEST","PALADIN"})[i];role="HEALER"
        elseif group[1]=="Druid" and i==1 then role="HEALER" end
        self.assignmentPracticePlayers[name]=class;self.assignmentPracticeRoles[name]=role
    end end
    local function pick(kind,marker,seat,player,buff)
        assert(self:EditMarkerBoardCell(plan,{kind=kind,marker=marker,seat=seat,value=player,buff=buff,encounter="raid"}))
    end
    for i=1,3 do local marker=A.assignmentMarkers[i][1]
        pick("tank",marker,1,string.format("TestTank%02d-Practice",i))
        pick("healer",marker,1,string.format("TestHealer%02d-Practice",i*2-1))
        pick("healer",marker,2,string.format("TestHealer%02d-Practice",i*2))
    end
    pick("interrupt",8,1,"TestRogue01-Practice");pick("banish",7,1,"TestWarlock01-Practice");pick("sheep",5,1,"TestMage01-Practice")
    pick("buff",nil,1,"TestMage01-Practice","intellect");pick("buff",nil,1,"TestHealer01-Practice","fortitude");pick("buff",nil,1,"TestDruid01-Practice","mark")
    -- Classic Molten Core names provide a full practice route; sample jobs are not encounter strategy.
    local bosses={"Lucifron","Magmadar","Gehennas","Garr","Baron Geddon","Shazzrah","Sulfuron Harbinger","Golemagg the Incinerator","Majordomo Executus","Ragnaros"}
    plan.encounters={};for i,name in ipairs(bosses) do plan.encounters[i]={id="e"..i,name=name} end;plan.nextEncounter=11
    local function assign(kind,slot,player,scope)
        assert(self:EditMarkerBoardCell(plan,{kind=kind,slot=slot,value=player,encounter=scope or "raid"}))
    end
    local dispellers={"TestHealer01-Practice","TestHealer02-Practice","TestHealer05-Practice","TestHealer06-Practice"}
    local decursers={"TestMage01-Practice","TestMage02-Practice","TestDruid01-Practice","TestHealer04-Practice"}
    for slot=1,4 do assign("dispel",slot,dispellers[slot]);assign("decurse",slot,decursers[slot]) end
    pick("tranq",8,1,"TestHunter01-Practice");pick("tranq",7,1,"TestHunter02-Practice")
    for _,assignment in ipairs({{"elements","TestWarlock01-Practice"},{"recklessness","TestWarlock02-Practice"},{"faerieFire","TestDruid01-Practice"},{"exposeArmor","TestRogue01-Practice"}}) do
        assert(self:EditMarkerBoardCell(plan,{kind="debuff",debuff=assignment[1],value=assignment[2],encounter="raid"}))
    end
    -- Every boss inherits raid-wide jobs until the user explicitly makes an override.
    assert(self:EditMarkerBoardCell(plan,{kind="dispel",slot=1,field="backup",value="TestHealer02-Practice",encounter="raid"}))
    assert(self:EditMarkerBoardCell(plan,{kind="decurse",slot=1,field="backup",value="TestDruid02-Practice",encounter="raid"}))
    self.assignmentPracticeBoard=plan;return plan
end
function A:SimpleAssignmentPlayerChoices(emptyLabel,cell,practice)
    local choices={{emptyLabel or "Unassigned",""}};local names,seen={},{}
    local function add(name) if name and name~="" and not seen[name] then seen[name]=true;names[#names+1]=name end end
    for name in pairs(self.roster or {}) do add(name) end;add(self.me)
    if practice==nil then practice=self.ui and self.ui.assignments and self.ui.assignments.practice==true end
    local b=practice and self.assignmentPracticeBoard or self:AssignmentBoard();for _,row in ipairs(b and b.rows or {}) do add(row.player);add(row.backup);add(row.targetPlayer) end
    if practice then for name in pairs(self.assignmentPracticePlayers or {}) do add(name) end end
    table.sort(names);for _,name in ipairs(names) do
        if self:AssignmentPlayerEligible(name,cell,practice) then choices[#choices+1]={self:AssignmentPlayerLabel(name,cell,practice),name,self:AssignmentPlayerColor(name,practice)} end
    end
    return choices
end
function A:AssignmentCleanupTargetChoices()
    local choices=self:AssignmentCoverageChoices()
    for _,choice in ipairs(self:SimpleAssignmentPlayerChoices("",nil)) do
        if choice[2]~="" then choices[#choices+1]={choice[1],"player:"..choice[2],choice[3]} end
    end
    return choices
end
function A:SetSimpleAssignmentCell(cell,field,value,stamp)
    local b=self:SimpleAssignmentBoard();local f=self.ui and self.ui.assignments
    if not b or not self:CanEditSimpleAssignments() then return false end
    local scope=self:SimpleAssignmentScope()
    if stamp and (stamp.board~=b or stamp.epoch~=b.epoch or stamp.revision~=b.revision or stamp.scope~=scope or stamp.practice~=f.practice) then
        self:Print("The assignments changed while the list was open. Open the dropdown again.");return false
    end
    if field~="coverage" and field~="target" and value~="" then
        local eligible,reason=self:AssignmentPlayerEligible(value,cell,f.practice)
        if not eligible then self:Print("That player cannot fill this assignment: "..(reason or "not eligible")..".");return false end
    end
    local request={kind=cell.kind,marker=cell.marker,seat=cell.seat,slot=cell.slot,buff=cell.buff,debuff=cell.debuff,field=field,value=value,encounter=scope}
    local ok
    if f.practice then
        local plan=self:EditedAssignmentPlan(b,"boardCell",request)
        if plan then plan.owner=b.owner;plan.epoch=b.epoch;plan.revision=b.revision+1;self.assignmentPracticeBoard=plan;ok=true end
    else ok=self:EditAssignment("boardCell",request) end
    if not ok then self:Print("Could not assign that player. The assigned player and backup must be different; refresh if the raid changed.") end
    self:RenderAssignments();return ok==true
end
function A:SimpleRaidChoices()
    self:InitStorage();local choices={};local b=self:AssignmentBoard()
    if b and (#b.rows>0 or #b.encounters>0 or b.raidName~="Custom raid") then choices[#choices+1]={"Current Raid: "..b.raidName,"current"} end
    local names={};for name in pairs(NauseRaidToolsDB.assignmentTemplates or {}) do names[#names+1]=name end;table.sort(names)
    for _,name in ipairs(names) do choices[#choices+1]={name,"plan:"..name} end
    names={};for name,p in pairs(NauseRaidToolsDB.profiles or {}) do if p.raidAssignmentPlan or p.raidAssignments then names[#names+1]=name end end;table.sort(names)
    for _,name in ipairs(names) do choices[#choices+1]={name.." (raid profile)","profile:"..name} end
    choices[#choices+1]={"Test Raid","test"};return choices
end
function A:AdoptSharedAssignmentTest()
    local u=self.ui;if not u then return end
    if u.assignments.practice then u.assignments.practice=false;u.assignments.viewEncounter=nil end
    if u.myAssignments.practice then u.myAssignments.practice=false;u.myAssignments.section="raid" end
end
function A:OpenAssignmentTest()
    if not self.Client:InGroup() then return self:OpenSimpleAssignmentsBoard(true) end
    if self.demo then self:Print("End loot testing before starting an assignment test.");return false end
    self:RefreshRoster();local b=self:AssignmentBoard()
    if self:AssignmentLeader()~=self.me then
        self:RefreshAssignments(true)
        if b and b.test then return self:OpenSimpleAssignmentsBoard(false) end
        self:Print("The group leader must start Test Raid. Their test assignments will then appear in My Assignments.");return false
    end
    if b and b.test then self:PublishAssignments();return self:OpenSimpleAssignmentsBoard(false) end
    if self.Client:Combat() then self:Print("Start the assignment test after combat.");return false end
    if not b then return false end
    self.assignmentTestRestore=self:AssignmentPlan(b)
    local plan=self:AssignmentPlan(self:CreateSimpleAssignmentTest())
    plan.test=true
    -- Shared testing uses actual group members, never fictional practice recipients.
    for _,row in ipairs(plan.rows) do
        for _,field in ipairs({"player","backup"}) do
            local name=row[field]
            local cell={kind=row.kind,buff=row.buff,debuff=row.debuff,encounter=row.encounter}
            if name~="" and (not self.roster[name] or not self:AssignmentPlayerEligible(name,cell,false)) then row[field]="" end
        end
        if row.targetPlayer~="" and not self.roster[row.targetPlayer] then row.targetPlayer="" end
    end
    plan=self:CleanAssignmentPlan(plan)
    if not plan then self.assignmentTestRestore=nil;return false end
    plan.owner=self.me;plan.epoch=self:NextAssignmentEpoch(b.epoch);plan.revision=0
    self.assignmentBoard=plan;self.assignmentOwner=self.me;self.assignmentSyncAt={}
    self:PublishAssignments();return self:OpenSimpleAssignmentsBoard(false)
end
function A:EndAssignmentTest()
    local b=self:AssignmentBoard()
    if not b or not b.test or b.owner~=self.me or self:AssignmentLeader()~=self.me or self.Client:Combat() then return false end
    local plan=self:CleanAssignmentPlan(self.assignmentTestRestore or NauseRaidToolsDB.raidAssignments or {rows={}})
    if not plan then return false end
    plan.test=false;plan.owner=self.me;plan.epoch=self:NextAssignmentEpoch(b.epoch);plan.revision=0
    self.assignmentBoard=plan;self.assignmentTestRestore=nil;self:StoreAssignmentPlan(plan);self:PublishAssignments();self:RenderAssignments();return true
end
function A:OpenSimpleAssignmentsBoard(practice)
    local u=self.ui;local f=u.assignments;f.practice=practice==true;f.viewEncounter=nil
    if f.practice then self:CreateSimpleAssignmentTest() end
    u.assignmentChooser:Hide();u.assignmentNameDialog:Hide();u.assignmentAdvanced:Hide();self:CloseSettingsDropdown()
    f:Show();self:RenderAssignments();self:FocusWindow(f);return true
end
function A:OpenChosenAssignmentRaid()
    local choice=self.ui.assignmentChooser.choice
    if choice=="test" then return self:OpenAssignmentTest() end
    if choice=="current" then return self:OpenSimpleAssignmentsBoard(false) end
    if not choice or not self:CanEditAssignments() or self:AssignmentLeader()~=self.me then return false end
    if not self:ConfirmAssignmentAction("load",choice:match("^[^:]+:(.*)$"),choice) then return false end
    self.confirmationContext.data.openBoard=true;self.ui.confirmation.nrtDialogOwner=self.ui.assignmentChooser;return true
end
function A:SaveSimpleAssignmentRaid(name)
    local f=self.ui and self.ui.assignments;if not f or f.practice then return false end
    local b=self:AssignmentBoard();if b and b.test then return false end;name=name or (b and b.raidName)
    if not clean(name,40,false) or name:lower()=="test raid" then return false end
    local templates=NauseRaidToolsDB.assignmentTemplates or {};local count=0;for _ in pairs(templates) do count=count+1 end
    if count>=20 and not templates[name] then self:Print("Twenty raids are already saved. Delete an old saved raid from Edit Raid first.");return false end
    if name~=b.raidName and not self:EditAssignment("raidName",{name=name}) then return false end
    return self:SaveAssignmentTemplate(name)
end
function A:AnnounceSimpleAssignments()
    local f=self.ui.assignments;local b=self:SimpleAssignmentBoard();local scope=self:SimpleAssignmentScope()
    if f.practice or (b and b.test) then
        self:Print("Test Raid - local announcement preview:")
        for _,row in ipairs(self:EffectiveAssignments(scope,b)) do self:Print(self:AssignmentText(row,scope,b)) end
        return true
    end
    return self:AnnounceAssignments(scope)
end

-- Resolve healer links against the effective boss plan, never the stale default.
function A:PersonalAssignmentTank(row,scope,board,effective)
    if row.kind~="healer" or row.role~="tank" then return end
    effective=effective or self:EffectiveAssignments(scope,board)
    local linked
    for _,candidate in ipairs(board.rows) do if candidate.id==row.link then linked=candidate;break end end
    if linked then
        for _,candidate in ipairs(effective) do
            if self:AssignmentSlotKey(candidate)==self:AssignmentSlotKey(linked) then return candidate.player end
        end
        return ""
    end
    if row.marker~=0 then
        for _,candidate in ipairs(effective) do if candidate.kind=="tank" and candidate.marker==row.marker then return candidate.player end end
        return ""
    end
    return row.target~="" and row.target or ""
end
function A:PersonalAssignmentName(name,practice)
    local label=self:FullDisplayName(name)
    local color=self:AssignmentPlayerColor(name,practice)
    if color then return string.format("|cff%02x%02x%02x%s|r",math.floor(color.r*255+.5),math.floor(color.g*255+.5),math.floor(color.b*255+.5),label) end
    return label
end
function A:PersonalAssignmentLabel(entry,board,practice)
    local row=entry.row
    local target=self:AssignmentTarget(row,entry.scope,board)
    local label=row.marker~=0 and self.assignmentRoles[row.role] or self:AssignmentJobLabel(row)
    if row.kind=="healer" and row.role=="tank" then
        local tank=self:PersonalAssignmentTank(row,entry.scope,board)
        label="Heal "..(tank and tank~="" and self:PersonalAssignmentName(tank,practice) or "Unassigned Tank")
    elseif row.kind=="buff" or ((row.kind=="dispel" or row.kind=="decurse") and row.marker==0) then
        label=row.targetPlayer and row.targetPlayer~="" and self:PersonalAssignmentName(row.targetPlayer,practice) or target
    elseif row.marker==0 and target~="" and row.kind~="debuff" then label=label.." - "..target end
    return (entry.backup and "Backup: " or "")..label
end

-- Each boss shows effective duties: raid defaults plus its own overrides.
function A:PersonalAssignmentEntries(board,player,section)
    if not board then return {} end
    player=player or self.me;local entries={};local scopes={{id="raid",name="Raid-Wide Assignments"}}
    for _,enc in ipairs(board.encounters) do scopes[#scopes+1]=enc end
    for _,scope in ipairs(scopes) do
        local jobs={}
        local effective=self:EffectiveAssignments(scope.id,board)
        local selected=not section or section=="all" or section==scope.id
        for _,row in ipairs(effective) do
            if selected and (scope.id=="raid" or row.kind~="buff") and (row.player==player or row.backup==player) then jobs[#jobs+1]=row end
        end
        if #jobs>0 then
            entries[#entries+1]={heading=scope.name,scope=scope.id}
            local healGroups={}
            for _,row in ipairs(jobs) do
                local tank=self:PersonalAssignmentTank(row,scope.id,board,effective)
                local key=tank and tank~="" and row.marker~=0 and table.concat({tank,tostring(row.backup==player),row.player,row.backup,row.note,tostring(row.encounter~="raid")},"|")
                local entry=key and healGroups[key]
                if not entry then
                    entry={row=row,scope=scope.id,backup=row.backup==player,markers={}}
                    entries[#entries+1]=entry
                    if key then healGroups[key]=entry end
                end
                if row.marker~=0 then
                    local seen=false;for _,marker in ipairs(entry.markers) do if marker==row.marker then seen=true end end
                    if not seen then entry.markers[#entry.markers+1]=row.marker end
                end
            end
        end
    end
    return entries
end
function A:ShowMyAssignments(practice)
    self:BuildUI()
    local main=self.ui.assignments;local f=self.ui.myAssignments
    if practice==nil then practice=main:IsShown() and main.practice==true end
    f.practice=practice==true
    if not f.practice then self:RefreshAssignments(true) end
    self.ui.assignmentChooser:Hide()
    f.section="raid";self:CloseSettingsDropdown();f.scroll:SetVerticalScroll(0)
    local layouts=self:WindowLayoutStore()
    if layouts.myAssignmentsCompactVersion~=1 then
        self:ResizeReadableWindow(f,400,280);layouts.myAssignmentsCompactVersion=1
    end
    main:Hide();f:Show();self:RenderMyAssignments();self:FitMyAssignments()
    self:SaveWindowLayout(f,"NauseRaidToolsMyAssignments");self:FocusWindow(f)
end
function A:PersonalAssignmentChoices(board)
    local choices={{"All Assignments","all"},{"Raid-Wide Assignments","raid"}}
    for _,enc in ipairs(board and board.encounters or {}) do choices[#choices+1]={enc.name,enc.id} end
    return choices
end
function A:FitMyAssignments()
    local f=self.ui.myAssignments
    self:ResizeReadableWindow(f,f:GetWidth(),math.max(200,math.min(340,f.content:GetHeight()+120)))
end
function A:RenderMyAssignments()
    local f=self.ui and self.ui.myAssignments;if not f or not f:IsShown() then return end
    local b=f.practice and self.assignmentPracticeBoard or self:AssignmentBoard()
    local selected
    for _,choice in ipairs(self:PersonalAssignmentChoices(b)) do if choice[2]==f.section then selected=choice[1] end end
    if not selected then f.section="all";selected="All Assignments" end
    f.sectionMenu:SetText(selected)
    local entries=self:PersonalAssignmentEntries(b,nil,f.section);f.entries=entries
    local width=f:GetWidth();local contentWidth=width-48
    f.title:SetWidth(width-100)
    f.settings:ClearAllPoints();f.settings:SetPoint("TOPLEFT",width-96,-38)
    f.summary:SetWidth(width-126);f.summary:SetText((f.practice and "LOCAL TEST | " or (b and b.test and "GROUP TEST | " or ""))..(b and b.raidName or "Waiting for raid assignments"))
    f.scroll:SetSize(contentWidth,math.max(40,f:GetHeight()-120));f.content:SetWidth(contentWidth)
    f.sectionMenu:SetWidth(width-28)
    local y=0
    for index,entry in ipairs(entries) do
        local visual=f.rows[index] or f.createRow(index);local row=entry.row
        if not row and y>0 then y=y+6 end
        visual.shade:SetShown(row~=nil)
        visual.label:SetFont(STANDARD_TEXT_FONT,row and 11 or 14,row and "" or "OUTLINE")
        visual:Show();visual:ClearAllPoints();visual:SetPoint("TOPLEFT",0,-y);visual:SetWidth(contentWidth)
        visual.icon:SetShown(row~=nil)
        visual.label:ClearAllPoints();visual.label:SetPoint("TOPLEFT",row and 36 or 8,-5);visual.label:SetWidth(row and contentWidth-42 or contentWidth-16)
        visual.detail:SetWidth(contentWidth-44);visual.detail:Hide()
        visual.override:SetShown(row~=nil and row.encounter~="raid")
        visual.override:ClearAllPoints();visual.override:SetPoint("TOPLEFT",36,-31)
        local rowHeight=row and 36 or 28
        if row then
            local def=self.assignmentBuffDefinitions[row.buff] or self.assignmentDebuffDefinitions[row.debuff] or self.assignmentCleanupDefinitions[row.kind]
            visual.icon:SetTexture(row.marker~=0 and ("Interface/TargetingFrame/UI-RaidTargetingIcon_"..row.marker) or (def and def.icon or "Interface/Icons/INV_Misc_Note_01"))
            local markers=entry.markers or {};local extra=math.max(0,#markers-1)
            visual.markerIcons=visual.markerIcons or {}
            for i=1,extra do
                local icon=visual.markerIcons[i]
                if not icon then icon=visual:CreateTexture(nil,"ARTWORK");visual.markerIcons[i]=icon;icon:SetSize(20,20) end
                icon:ClearAllPoints();icon:SetPoint("TOPLEFT",8+i*24,-5)
                icon:SetTexture("Interface/TargetingFrame/UI-RaidTargetingIcon_"..markers[i+1]);icon:Show()
            end
            for i=extra+1,#visual.markerIcons do visual.markerIcons[i]:Hide() end
            visual.label:SetPoint("TOPLEFT",36+extra*24,-5);visual.label:SetWidth(contentWidth-42-extra*24)
            visual.label:SetText(self:PersonalAssignmentLabel(entry,b,f.practice));visual.label:SetTextColor(.94,.94,.94)
            visual.tooltip=self:AssignmentJobLabel(row)
            if def then visual.tooltip=def.label end
            local detail=""
            local other=entry.backup and row.player or row.backup
            if other~="" then detail=detail..(detail~="" and " | " or "")..(entry.backup and "Primary: " or "Backup: ")..self:FullDisplayName(other) end
            if row.note~="" then detail=detail..(detail~="" and " | " or "")..row.note end
            visual.detail:SetText(detail);visual.detail:SetShown(detail~="")
            if row.encounter~="raid" then
                visual.override:SetText("Override");visual.detail:ClearAllPoints();visual.detail:SetPoint("TOPLEFT",36,-46)
                rowHeight=detail~="" and 76 or 48
            else
                visual.detail:ClearAllPoints();visual.detail:SetPoint("TOPLEFT",36,-31)
                if detail~="" then rowHeight=62 end
            end
        else
            visual.tooltip=nil
            for _,icon in ipairs(visual.markerIcons or {}) do icon:Hide() end
            visual.label:SetText(entry.heading);visual.label:SetTextColor(.94,.78,.34)
        end
        visual:SetHeight(rowHeight);y=y+rowHeight+2
    end
    for index=#entries+1,#f.rows do f.rows[index]:Hide() end
    f.content:SetHeight(math.max(1,y));f.empty:SetShown(#entries==0)
    f.empty:SetWidth(contentWidth-16)
    f.empty:SetText(b and "You have no assignments in this section." or "Waiting for the group leader's raid plan...")
    self:RefreshScrollChrome(f.scroll)
end

function A:BuildAssignmentsUI(u,window,text,button,edit)
    -- Keep older, non-marker jobs accessible without making them the opening screen.
    self:BuildAdvancedAssignmentsUI(u,window,text,button,edit)
    local f=window("NauseRaidToolsAssignmentBoard","Nause Raid Tools | Assignments",900,600)
    u.assignments=f;f.panel="tanks";f.practice=false;f.memberControls={}
    local function dropdown(parent,label,x,y,width,choices,action,menuWidth)
        local control=button(parent,label,x,y,width,function() end)
        A:BindSettingsDropdown(control,choices,action,button,menuWidth);return control
    end
    local personal=window("NauseRaidToolsMyAssignments","My Assignments",400,280,false,false);u.myAssignments=personal
    personal.summary=text(personal,"",11,14,-43,274);personal.summary:SetHeight(16);personal.summary:SetMaxLines(1)
    personal.settings=button(personal,"Assignments",304,-38,82,function()
        A:CloseSettingsDropdown();A:OpenSimpleAssignmentsBoard(personal.practice)
        local board=A:SimpleAssignmentBoard();local scope=personal.section
        local valid=scope=="raid"
        for _,enc in ipairs(board and board.encounters or {}) do if enc.id==scope then valid=true end end
        if valid then A.ui.assignments.viewEncounter=scope;A:RenderAssignments() end
    end)
    personal.settings:SetHeight(22)
    personal.sectionMenu=dropdown(personal,"Raid-Wide Assignments",14,-65,372,function()
        local b=personal.practice and A.assignmentPracticeBoard or A:AssignmentBoard()
        return A:PersonalAssignmentChoices(b)
    end,function(section)
        personal.section=section;personal.scroll:SetVerticalScroll(0);A:RenderMyAssignments();A:FitMyAssignments()
    end,372)
    personal.scroll=self:CreateScrollFrame(personal);personal.scroll:SetPoint("TOPLEFT",14,-94);personal.scroll:SetSize(352,138)
    personal.content=CreateFrame("Frame",nil,personal.scroll);personal.content:SetSize(432,1);personal.scroll:SetScrollChild(personal.content)
    personal.rows={};personal.createRow=function(index)
        local row=CreateFrame("Frame",nil,personal.content);row:SetSize(432,74);A:StyleDataRow(row,index)
        row.icon=row:CreateTexture(nil,"ARTWORK");row.icon:SetSize(20,20);row.icon:SetPoint("TOPLEFT",8,-5)
        row.label=text(row,"",11,36,-5,308);row.label:SetHeight(24);row.label:SetMaxLines(2);row.label:SetWordWrap(true)
        row.override=text(row,"Override",10,36,-31,90);row.override:SetHeight(14);row.override:SetTextColor(.67,.7,.75)
        row.detail=text(row,"",11,36,-31,308);row.detail:SetHeight(28);row.detail:SetMaxLines(2);row.detail:SetWordWrap(true);row.detail:SetTextColor(.75,.77,.8)
        row:EnableMouse(true)
        row:SetScript("OnEnter",function()
            if not row.tooltip then return end
            GameTooltip:SetOwner(row,"ANCHOR_RIGHT");GameTooltip:AddLine(row.tooltip,1,.82,.3,true);GameTooltip:Show()
        end)
        row:SetScript("OnLeave",function() GameTooltip:Hide() end)
        row:EnableMouseWheel(true);row:SetScript("OnMouseWheel",function(_,delta) personal.scroll:GetScript("OnMouseWheel")(personal.scroll,delta) end)
        personal.rows[index]=row;return row
    end
    personal.empty=text(personal.content,"",12,8,-10,416);personal.empty:SetHeight(52)
    local chooser=window("NauseRaidToolsAssignmentChooser","Assignments | Choose a Raid",620,260,true)
    u.assignmentChooser=chooser
    text(chooser,"Which raid are you assigning?",13,20,-53,580)
    chooser.raid=dropdown(chooser,"Choose a Raid",20,-87,580,function() return A:SimpleRaidChoices() end,function(choice)
        chooser.choice=choice;A:RenderAssignments()
    end)
    chooser.new=button(chooser,"New Raid",20,-137,180,function() A:ShowAssignmentNameDialog("new") end)
    chooser.open=button(chooser,"Open Raid",220,-137,180,function() A:OpenChosenAssignmentRaid() end)
    button(chooser,"Cancel",420,-137,180,function() chooser:Hide() end)
    chooser.help=text(chooser,"",12,20,-190,580);chooser.help:SetHeight(48)
    local nameDialog=window("NauseRaidToolsAssignmentName","New Raid",520,220,true)
    u.assignmentNameDialog=nameDialog
    nameDialog.name=edit(nameDialog,20,-86,480,"Raid name");nameDialog.name:SetMaxLetters(40)
    nameDialog.help=text(nameDialog,"",11,20,-121,480);nameDialog.help:SetHeight(36)
    nameDialog.confirm=button(nameDialog,"Create Raid",20,-173,230,function() A:AcceptAssignmentName() end)
    button(nameDialog,"Cancel",270,-173,230,function() nameDialog:Hide() end)
    local management=window("NauseRaidToolsAssignmentEditRaid","Edit Raid",520,290,true);u.assignmentEditRaid=management
    management.name=edit(management,20,-82,480,"Encounter name")
    management.help=text(management,"Add your own encounter names. No boss mechanics are assumed.",11,20,-116,480);management.help:SetHeight(32)
    management.add=button(management,"Add Encounter",20,-163,150,function() A:SimpleEncounterAction("encounterAdd",management.name:GetText()) end)
    management.rename=button(management,"Rename Current",185,-163,150,function() A:SimpleEncounterAction("encounterRename",management.name:GetText()) end)
    management.remove=button(management,"Remove Current",350,-163,150,function() A:SimpleEncounterAction("encounterRemove") end)
    management.saveAs=button(management,"Save Raid As...",20,-225,150,function() A:ShowAssignmentNameDialog("save") end)
    management.deleteSaved=button(management,"Delete Saved Raid",185,-225,150,function()
        local b=A:SimpleAssignmentBoard()
        if not f.practice and b and A:ConfirmAssignmentAction("delete",b.raidName) then u.confirmation.nrtDialogOwner=management end
    end)
    button(management,"Done",350,-225,150,function() management:Hide() end)
    f.encounter=dropdown(f,"Raid-Wide Assignments",20,-53,300,function()
        local b=A:SimpleAssignmentBoard();local c={{"Raid-Wide Assignments","raid"}}
        for _,v in ipairs(b and b.encounters or {}) do c[#c+1]={v.name,v.id} end;return c
    end,function(scope)
        local b=A:SimpleAssignmentBoard();if not b then return end
        if A:CanEditSimpleAssignments() then
            if f.practice then b.activeEncounter=scope;b.revision=b.revision+1 else A:EditAssignment("activate",nil,scope) end
            f.viewEncounter=nil
        else f.viewEncounter=scope end
        f.scroll:SetVerticalScroll(0);A:RenderAssignments()
    end)
    f.editRaid=button(f,"Edit Raid",330,-53,130,function()
        management.name:SetText("");management.rename:SetEnabled(A:SimpleAssignmentScope()~="raid");management.remove:SetEnabled(A:SimpleAssignmentScope()~="raid")
        management.saveAs:SetEnabled(not f.practice and not (A:SimpleAssignmentBoard() or {}).test and A:AssignmentLeader()==A.me)
        local b=A:SimpleAssignmentBoard();management.deleteSaved:SetEnabled(not f.practice and A:AssignmentLeader()==A.me and b~=nil and (NauseRaidToolsDB.assignmentTemplates or {})[b.raidName]~=nil)
        management:Show();A:FocusWindow(management)
    end)
    button(f,"Change Raid",470,-53,130,function() A:ShowAssignments() end)
    f.mineButton=button(f,"My Assignments",610,-53,130,function() A:ShowMyAssignments() end)
    button(f,"Refresh",750,-53,130,function() if not f.practice then A:RefreshAssignments(true) else A:RenderAssignments() end end)
    f.summary=text(f,"",11,20,-92,860);f.summary:SetHeight(20)
    f.tabs={}
    for i,tab in ipairs({{"Buffs","buffs"},{"Debuffs","debuffs"},{"Tanks & Healers","tanks"},{"Kicks, CC & Tranqs","cc"},{"Dispels & Decurse","cleanup"}}) do
        local key=tab[2];f.tabs[key]=button(f,tab[1],20+(i-1)*215,-120,205,function() f.panel=key;f.scroll:SetVerticalScroll(0);A:RenderAssignments() end)
    end
    f.headings={};for i=1,5 do f.headings[i]=text(f,"",11,20,-161,240);f.headings[i]:SetTextColor(.86,.75,.48) end
    f.scroll=self:CreateScrollFrame(f);f.scroll:SetPoint("TOPLEFT",20,-184);f.scroll:SetSize(842,330)
    f.content=CreateFrame("Frame",nil,f.scroll);f.content:SetSize(838,320);f.scroll:SetScrollChild(f.content)
    f.tables={tanks={},cc={},cleanup={},buffs={},debuffs={}}
    local function member(parent,cell,field,x,width)
        local control
        control=dropdown(parent,"Unassigned",x,-7,width,function()
            local b=A:SimpleAssignmentBoard()
            control.stamp=b and {board=b,epoch=b.epoch,revision=b.revision,scope=A:SimpleAssignmentScope(),practice=f.practice}
            return A:SimpleAssignmentPlayerChoices(field=="backup" and "No Backup" or "Unassigned",cell)
        end,function(name) A:SetSimpleAssignmentCell(cell,field,name,control.stamp) end,310)
        control.cell=cell;control.field=field;f.memberControls[#f.memberControls+1]=control;return control
    end
    local function rowBase(index)
        local row=CreateFrame("Frame",nil,f.content);row:SetSize(838,39);A:StyleDataRow(row,index)
        row.icon=row:CreateTexture(nil,"ARTWORK");row.icon:SetSize(26,26);row.icon:SetPoint("TOPLEFT",6,-6)
        row.label=text(row,"",11,40,-12,58);row.controls={};return row
    end
    for _,key in ipairs({"tanks","cc"}) do
        for i,marker in ipairs(self.assignmentMarkers) do
            local row=rowBase(i);row.marker=marker[1];row.label:SetText(marker[2]);row.icon:SetTexture("Interface/TargetingFrame/UI-RaidTargetingIcon_"..marker[1])
            if key=="tanks" then
                row.controls[1]=member(row,{kind="tank",marker=marker[1]},"player",100,238)
                row.controls[2]=member(row,{kind="healer",marker=marker[1],seat=1},"player",347,238)
                row.controls[3]=member(row,{kind="healer",marker=marker[1],seat=2},"player",594,238)
            else
                for column,kind in ipairs({"interrupt","banish","sheep","tranq"}) do row.controls[column]=member(row,{kind=kind,marker=marker[1]},"player",100+(column-1)*184,176) end
            end
            f.tables[key][i]=row
        end
    end
    for i,key in ipairs(self.assignmentBuffOrder) do
        local def=self.assignmentBuffDefinitions[key];local row=rowBase(i);row.buff=key
        row.icon:SetTexture(def.icon);row.label:SetWidth(152);row.label:SetText(def.label)
        row.controls[1]=member(row,{kind="buff",buff=key},"player",200,220)
        row.controls[2]=member(row,{kind="buff",buff=key},"backup",586,246)
        row.coverage=dropdown(row,"Whole Raid",428,-7,150,function()
            local b=A:SimpleAssignmentBoard();row.coverage.stamp=b and {board=b,epoch=b.epoch,revision=b.revision,scope=A:SimpleAssignmentScope(),practice=f.practice}
            return A:AssignmentCoverageChoices()
        end,function(value) A:SetSimpleAssignmentCell({kind="buff",buff=key},"coverage",value,row.coverage.stamp) end)
        row.coverageCell={kind="buff",buff=key};row.defaultCoverage="raid";f.tables.buffs[i]=row
    end
    for i,key in ipairs(self.assignmentDebuffOrder) do
        local def=self.assignmentDebuffDefinitions[key];local row=rowBase(i);row.debuff=key
        row.icon:SetTexture(def.icon);row.label:SetWidth(270);row.label:SetText(def.label)
        row.controls[1]=member(row,{kind="debuff",debuff=key},"player",320,245)
        row.controls[2]=member(row,{kind="debuff",debuff=key},"backup",578,254)
        f.tables.debuffs[i]=row
    end
    for _,kind in ipairs({"dispel","decurse"}) do
        local def=self.assignmentCleanupDefinitions[kind]
        for slot=1,4 do
            local index=#f.tables.cleanup+1;local row=rowBase(index);row.kind=kind;row.slot=slot
            row.icon:SetTexture(def.icon);row.label:SetWidth(152);row.label:SetText(def.label.." "..slot)
            local cell={kind=kind,slot=slot};row.coverageCell=cell;row.defaultCoverage=groupPairs[slot]
            row.controls[1]=member(row,cell,"player",200,220);row.controls[2]=member(row,cell,"backup",646,186)
            row.coverage=dropdown(row,A:AssignmentCoverageLabel(groupPairs[slot]),428,-7,210,function()
                local b=A:SimpleAssignmentBoard();row.coverage.stamp=b and {board=b,epoch=b.epoch,revision=b.revision,scope=A:SimpleAssignmentScope(),practice=f.practice}
                return A:AssignmentCleanupTargetChoices()
            end,function(value)
                if value:sub(1,7)=="player:" then A:SetSimpleAssignmentCell(cell,"target",value:sub(8),row.coverage.stamp)
                else A:SetSimpleAssignmentCell(cell,"coverage",value,row.coverage.stamp) end
            end,340)
            row.target=row.coverage
            f.tables.cleanup[index]=row
        end
    end
    f.empty=text(f.content,"No assignments for you in this section.",12,20,-20,790)
    f.hint=text(f,"",11,20,-531,860);f.hint:SetHeight(18)
    f.save=button(f,"Save Raid",20,-558,205,function()
        if (A:SimpleAssignmentBoard() or {}).test then
            if not A:EndAssignmentTest() then A:Print("Only the group leader can end the assignment test, outside combat.") end
            return
        end
        if not A:SaveSimpleAssignmentRaid() then A:ShowAssignmentNameDialog("save") end
    end)
    f.announce=button(f,"Announce",235,-558,205,function() A:AnnounceSimpleAssignments() end)
    f.other=button(f,"Other Saved Jobs",450,-558,205,function()
        if not f.practice then f:Hide();A:ShowAdvancedAssignments() end
    end)
    f.close=button(f,"Close",665,-558,205,function() f:Hide() end)
    f:SetScript("OnHide",function() A:CloseSettingsDropdown() end)
end
function A:ShowAssignmentNameDialog(mode)
    local u=self.ui;local d=u.assignmentNameDialog;local b=self:SimpleAssignmentBoard()
    d.mode=mode;d.title:SetText(mode=="new" and "New Raid" or "Save Raid As")
    d.name:SetText(mode=="save" and b and b.raidName~="Test Raid" and b.raidName or "")
    d.help:SetText(mode=="new" and "Choose a name for your raid. Save changes to the current raid first if you want to keep them." or "Save this raid and its encounters for next time.")
    d.confirm:SetText(mode=="new" and "Create Raid" or "Save Raid");d:Show();self:FocusWindow(d)
end
function A:AcceptAssignmentName()
    local d=self.ui.assignmentNameDialog;local name=(d.name:GetText() or ""):match("^%s*(.-)%s*$")
    if not clean(name,40,false) or name:lower()=="test raid" then self:Print("Use a raid name of 1–40 characters. Test Raid is reserved for practice.");return false end
    if not self:CanEditAssignments() or self:AssignmentLeader()~=self.me then self:Print("Only the group leader can create or save raids.");return false end
    local b=self:AssignmentBoard()
    if b and b.test then self:Print("End the assignment test before creating or saving a raid.");return false end
    if d.mode=="new" then
        local templates=NauseRaidToolsDB.assignmentTemplates or {}
        if templates[name] then self:Print("That raid is already saved. Choose it from the raid menu.");return false end
        local count=0;for _ in pairs(templates) do count=count+1 end
        if count>=20 then self:Print("Twenty raids are already saved. Delete an old saved raid from Edit Raid first.");return false end
        if #b.rows>0 or #b.encounters>0 then
            if self:ConfirmAssignmentAction("newRaid",name) then
                self.confirmationContext.data.openBoard=true;self.confirmationContext.data.saveNewRaid=true;self.ui.confirmation.nrtDialogOwner=d;return true
            end
            return false
        end
        if not self:EditAssignment("newRaid",{name=name}) or not self:SaveAssignmentTemplate(name) then return false end
        self:OpenSimpleAssignmentsBoard(false);return true
    end
    if name~=b.raidName and (NauseRaidToolsDB.assignmentTemplates or {})[name] then self:Print("That raid already exists. Use a new name or open the saved raid first.");return false end
    if self:SaveSimpleAssignmentRaid(name) then d:Hide();self.ui.assignmentEditRaid:Hide();self:RenderAssignments();return true end
    return false
end
function A:SimpleEncounterAction(op,name)
    local f=self.ui.assignments;local b=self:SimpleAssignmentBoard();local scope=self:SimpleAssignmentScope()
    if not b or not self:CanEditSimpleAssignments() then return false end
    local request={name=name};local ok
    if f.practice then
        local plan=self:EditedAssignmentPlan(b,op,request,scope)
        if plan then plan.owner=b.owner;plan.epoch=b.epoch;plan.revision=b.revision+1;self.assignmentPracticeBoard=plan;ok=true end
    elseif op=="encounterRemove" then
        if self:ConfirmAssignmentAction(op,self:AssignmentEncounterName(scope,b),scope) then self.ui.confirmation.nrtDialogOwner=self.ui.assignmentEditRaid;return true end
    else ok=self:EditAssignment(op,request,scope) end
    if not ok then self:Print("Choose a unique encounter name, or select an encounter to rename or remove.") end
    f.viewEncounter=nil;self:RenderAssignments();return ok==true
end
local function samePlan(a,b)
    if type(a)~=type(b) then return false end
    if type(a)~="table" then return a==b end
    for k,v in pairs(a) do if not samePlan(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end;return true
end
function A:RenderAssignments()
    local u=self.ui;if not u or not u.assignments then return end
    local f=u.assignments;local b=self:SimpleAssignmentBoard();local scope=self:SimpleAssignmentScope();local editable=self:CanEditSimpleAssignments()
    if scope~="raid" and (f.panel=="buffs" or f.panel=="debuffs") then f.panel="tanks";f.scroll:SetVerticalScroll(0) end
    if u.assignmentAdvanced:IsShown() then self:RenderAdvancedAssignments() end
    local leader=self:CanEditAssignments() and self:AssignmentLeader()==self.me
    local chooser=u.assignmentChooser;local choices=self:SimpleRaidChoices();local label;local saved=0
    for _,choice in ipairs(choices) do if choice[2]==chooser.choice then label=choice[1] end;if choice[2]:match("^plan:") or choice[2]:match("^profile:") then saved=saved+1 end end
    if not label then chooser.choice=nil end
    chooser.raid:SetText(label or "Choose a Raid");chooser.new:SetEnabled(leader and not (b and b.test))
    chooser.open:SetEnabled(chooser.choice~=nil and (chooser.choice=="test" or chooser.choice=="current" or leader))
    chooser.help:SetText(saved==0 and "No saved raids yet. Create a New Raid, or choose Test Raid to try the assignment tables." or "Choose a saved raid, your current raid, or Test Raid. Tests share with your group; solo tests stay local.")
    if not leader and not f.practice then chooser.help:SetText("Open the current shared raid or Test Raid. Only the group leader can create or load saved raids.") end
    local height=math.max(480,math.min(600,UIParent:GetHeight()-24));f:SetHeight(height);f.scroll:SetHeight(height-270)
    for _,control in ipairs({f.save,f.announce,f.other,f.close}) do
        local x=control==f.save and 20 or (control==f.announce and 235 or (control==f.other and 450 or 665))
        control:ClearAllPoints();control:SetPoint("TOPLEFT",x,-height+42)
    end
    f.hint:ClearAllPoints();f.hint:SetPoint("TOPLEFT",20,-height+69)
    f.title:SetText("Nause Raid Tools | Assignments - "..(b and b.raidName or "Waiting for raid"))
    f.encounter:SetText(scope=="raid" and "Raid-Wide Assignments" or self:AssignmentEncounterName(scope,b))
    self:RenderMyAssignments()
    f.editRaid:SetEnabled(editable and b~=nil)
    f.save:SetText(b and b.test and "End Test" or "Save Raid")
    f.save:SetEnabled(leader and not f.practice);f.announce:SetEnabled(f.practice or (editable and self.Client:InGroup() and b~=nil))
    f.announce:SetText((f.practice or (b and b.test)) and "Preview Announcement" or "Announce")
    local status=f.practice and "Test Raid - fictional players and local practice. Test assignments stay on your client." or
        (b and b.test and "GROUP TEST - shared with your party/raid. Assign real members; saved raid setup is preserved. End Test restores it.") or
        (not b and "Waiting for the group leader's raid plan..." or (editable and "Choose players from the dropdowns. Save Raid keeps the setup for next time." or "Shared raid assignments - view only."))
    local combatOK,combat=self.Client:Call("InCombatLockdown");if combatOK and combat and not f.practice then status=status.." Updates wait until combat ends." end
    f.summary:SetText(status)
    local effective=self:EffectiveAssignments(scope,b);local mapped={}
    for panel,rows in pairs(f.tables) do
        local y=0
        for _,row in ipairs(rows) do
            for _,control in ipairs(row.controls) do
                local cell=control.cell;local value=self:MarkerBoardRow(b,scope,cell.kind,cell.marker,cell.seat,cell.buff or cell.debuff,effective,cell.slot)
                local player=value and value[control.field] or ""
                if value then mapped[value.id]=true end
                local eligible,reason,info=self:AssignmentPlayerEligible(player,cell,f.practice)
                local label=player~="" and self:AssignmentPlayerLabel(player,cell,f.practice) or (control.field=="backup" and "No Backup" or "Unassigned")
                if player~="" and not eligible and reason~="Class unavailable" then label=label.." (not eligible)" end
                control:SetText(label)
                control:SetEnabled(editable and b~=nil)
                local color=self:AssignmentPlayerColor(player,f.practice)
                control:GetFontString():SetTextColor(color and color.r or .9,color and color.g or .91,color and color.b or .93)
            end
            if row.coverage then
                local cell=row.coverageCell
                local value=self:MarkerBoardRow(b,scope,cell.kind,cell.marker,cell.seat,cell.buff or cell.debuff,effective,cell.slot);local target=value and value.target or row.defaultCoverage
                row.coverage:SetText(value and value.targetPlayer and value.targetPlayer~="" and self:FullDisplayName(value.targetPlayer) or self:AssignmentCoverageLabel(target))
                row.coverage:SetEnabled(editable and b~=nil)
                local color=value and value.targetPlayer~="" and self:AssignmentPlayerColor(value.targetPlayer,f.practice)
                row.coverage:GetFontString():SetTextColor(color and color.r or .9,color and color.g or .91,color and color.b or .93)
            end
            local show=panel==f.panel;row:SetShown(show)
            if show then row:ClearAllPoints();row:SetPoint("TOPLEFT",0,-y);y=y+40 end
        end
        if panel==f.panel then f.content:SetHeight(math.max(1,y));f.empty:SetShown(y==0) end
    end
    local titles
    if f.panel=="debuffs" then titles={{"Debuff",20,300},{"Player",340,245},{"Backup",598,254}}
    elseif f.panel=="buffs" or f.panel=="cleanup" then
        titles={{f.panel=="buffs" and "Buff" or "Job",20,170},{"Player",220,210},{f.panel=="buffs" and "Groups" or "Target",448,f.panel=="buffs" and 140 or 200},{"Backup",f.panel=="buffs" and 606 or 666,f.panel=="buffs" and 240 or 180}}
    elseif f.panel=="cc" then titles={{"Target",20,90},{"Kicks",120,176},{"Banishes",304,176},{"Sheeps",488,176},{"Tranqs",672,176}}
    else titles={{"Target",20,90},{"Tank",120,238},{"Healer 1",367,238},{"Healer 2",614,238}} end
    for i,labelControl in ipairs(f.headings) do local title=titles[i];labelControl:SetShown(title~=nil);if title then labelControl:SetText(title[1]);labelControl:ClearAllPoints();labelControl:SetPoint("TOPLEFT",title[2],-161);labelControl:SetWidth(title[3]) end end
    local tabCount=scope=="raid" and 5 or 3;local tabWidth=(860-(tabCount-1)*10)/tabCount;local position=0
    for _,key in ipairs({"buffs","debuffs","tanks","cc","cleanup"}) do
        local tab=f.tabs[key];local shown=(key~="buffs" and key~="debuffs") or scope=="raid";tab:SetShown(shown)
        if shown then tab:ClearAllPoints();tab:SetPoint("TOPLEFT",20+position*(tabWidth+10),-120);tab:SetWidth(tabWidth);position=position+1 end
        tab:SetBackdropBorderColor(key==f.panel and .8 or .26,key==f.panel and .64 or .28,key==f.panel and .25 or .31,1)
    end
    local other=0;for _,row in ipairs(effective) do if not mapped[row.id] then other=other+1 end end
    f.other:SetShown(other>0 and not f.practice);f.other:SetText("Other Saved Jobs ("..other..")")
    local template=b and (NauseRaidToolsDB.assignmentTemplates or {})[b.raidName]
    local savedState=template and samePlan(self:AssignmentPlan(b),self:CleanAssignmentPlan(template))
    local hint=f.practice and "Practice only. " or (b and b.test and "Shared test. End Test restores your raid setup. ") or (savedState and "Saved raid setup. " or "Save Raid keeps this setup. ")
    hint=hint..(f.panel=="debuffs" and "Class-filtered assignments. A Warlock can maintain one curse per target."
        or f.panel=="cc" and "Tranqs: Hunters. Warlock kicks require a Felhunter with Spell Lock."
        or (f.panel=="buffs" and "Players and backups are filtered to each buff's provider class."
        or (f.panel=="cleanup" and "Target can be a group or one player. Dispellers and backups remain class-filtered." or "Player lists use class eligibility, regardless of spec or group role.")))
    f.hint:SetText(hint)
    self:RefreshSettingsDropdowns()
end
function A:ShowAssignments()
    self:BuildUI();self:RefreshAssignments(true);self:CloseSettingsDropdown()
    local chooser=self.ui.assignmentChooser;chooser:Show();self:RenderAssignments();self:FocusWindow(chooser)
end
