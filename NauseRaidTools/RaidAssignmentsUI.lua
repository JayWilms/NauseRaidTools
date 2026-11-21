local _,A=...
local function feedback(ok,message) if not ok then A:Print(message or "Could not save. Check the fields, slot number, links and duplicate jobs, then refresh if the plan changed.") end;return ok end
local function rowSignature(row)
    if not row then return "" end
    local values={};for _,key in ipairs({"id","kind","role","player","target","note","encounter","slot","backup","job","link","marker","buff","targetPlayer","debuff"}) do values[#values+1]=A.Encode(row[key]) end
    return table.concat(values)
end
local function editorClear(f)
    f.editBasis=nil;f.stale=false;f.selected=nil;f.playerName="";f.backupName="";f.link=0;f.slot:SetText("1");f.target:SetText("");f.job:SetText("");f.note:SetText("")
end
function A:AdvancedAssignmentViewScope()
    local f=self.ui and self.ui.assignmentAdvanced;local b=self:AssignmentBoard()
    if not b then return "raid" end
    local scope=f and f.viewEncounter or b.activeEncounter
    if scope=="raid" then return scope end
    for _,v in ipairs(b.encounters) do if v.id==scope then return scope end end
    if f then f.viewEncounter=nil end;return b.activeEncounter
end
function A:AssignmentPlayerChoices(emptyLabel)
    local f=self.ui and self.ui.assignmentAdvanced
    local cell=f and self:AssignmentCellForRole(f.role) or nil
    return self:SimpleAssignmentPlayerChoices(emptyLabel,cell,false)
end
function A:BuildAdvancedAssignmentsUI(u,window,text,button,edit)
    local f=window("NauseRaidToolsAssignments","Nause Raid Tools | Other Assignment Jobs",1000,740)
    u.assignmentAdvanced=f;f.ClearEditor=function() editorClear(f) end;f.filter="all";f.section="all";f.role="main";f.link=0;f.playerName="";f.backupName=""
    f.summary=text(f,"",12,20,-48,960);f.summary:SetHeight(34)
    local function dropdown(label,x,y,width,choices,action)
        local control=button(f,label,x,y,width,function() end);A:BindSettingsDropdown(control,choices,action,button);return control
    end
    f.raidName=edit(f,20,-103,350,"Custom raid name");f.raidName:SetMaxLetters(60)
    f.renameRaid=button(f,"Set Name",380,-103,100,function() feedback(A:EditAssignment("raidName",{name=f.raidName:GetText()})) end)
    f.encounter=dropdown("Follow current encounter",500,-103,310,function()
        local b=A:AssignmentBoard();local c={{"Follow current: "..A:AssignmentEncounterName(b and b.activeEncounter or "raid"),"follow"},{"Raid-Wide Assignments","raid"}}
        for _,v in ipairs(b and b.encounters or {}) do c[#c+1]={v.name,v.id} end;return c
    end,function(id) f.viewEncounter=id~="follow" and id or nil;editorClear(f);f.scroll:SetVerticalScroll(0);A:RenderAdvancedAssignments() end)
    f.activate=button(f,"Set Current Encounter",820,-103,160,function() feedback(A:EditAssignment("activate",nil,A:AdvancedAssignmentViewScope())) end)
    f.encounterName=edit(f,20,-157,350,"Encounter name (add, rename or copy)");f.encounterName:SetMaxLetters(60)
    local function encounterAction(op)
        if feedback(A:EditAssignment(op,{name=f.encounterName:GetText()},A:AdvancedAssignmentViewScope())) then
            f.viewEncounter=nil;editorClear(f);f.encounterName:SetText("");A:RenderAdvancedAssignments()
        end
    end
    f.addEncounter=button(f,"Add",380,-157,100,function() encounterAction("encounterAdd") end)
    f.renameEncounter=button(f,"Rename",500,-157,110,function() encounterAction("encounterRename") end)
    f.copyEncounter=button(f,"Copy Plan",620,-157,110,function() encounterAction("copyEncounter") end)
    f.removeEncounter=button(f,"Remove",740,-157,110,function()
        A:ConfirmAssignmentAction("encounterRemove",A:AssignmentEncounterName(A:AdvancedAssignmentViewScope()),A:AdvancedAssignmentViewScope())
    end)
    f.practice=button(f,"Practice Plan",860,-157,120,function()
        if feedback(A:CreateAssignmentPractice(),"Practice plans can be created outside a group, after ending loot tests.") then f.viewEncounter=nil;editorClear(f);A:RenderAdvancedAssignments() end
    end)
    f.template=dropdown("Choose Saved Plan",20,-211,280,function()
        local choices={};local names={};for name in pairs(NauseRaidToolsDB.assignmentTemplates or {}) do names[#names+1]=name end;table.sort(names)
        for _,name in ipairs(names) do choices[#choices+1]={"Plan: "..name,"plan:"..name} end
        names={};for name,p in pairs(NauseRaidToolsDB.profiles or {}) do if p.raidAssignmentPlan or p.raidAssignments then names[#names+1]=name end end;table.sort(names)
        for _,name in ipairs(names) do choices[#choices+1]={"Raid profile: "..name,"profile:"..name} end;return choices
    end,function(value) f.templateSource=value;f.templateName:SetText(value:match("^[^:]+:(.*)$") or "");A:RenderAdvancedAssignments() end)
    f.templateName=edit(f,310,-211,280,"Save plan as (1–40 characters)");f.templateName:SetMaxLetters(40)
    f.save=button(f,"Save Plan",600,-211,120,function()
        local name=(f.templateName:GetText() or ""):match("^%s*(.-)%s*$")
        if (NauseRaidToolsDB.assignmentTemplates or {})[name] then A:ConfirmAssignmentAction("save",name)
        elseif feedback(A:SaveAssignmentTemplate(name),"Enter a plan name. Only the leader can save plans; up to 20 are supported.") then f.templateSource="plan:"..name;A:RenderAdvancedAssignments() end
    end)
    f.load=button(f,"Load Plan",730,-211,120,function()
        if f.templateSource then A:ConfirmAssignmentAction("load",f.templateSource:match("^[^:]+:(.*)$"),f.templateSource) end
    end)
    f.announce=button(f,"Announce",860,-211,120,function() A:AnnounceAssignments(A:AdvancedAssignmentViewScope()) end)
    button(f,"All Jobs",20,-253,100,function() f.filter="all";f.scroll:SetVerticalScroll(0);A:RenderAdvancedAssignments() end)
    button(f,"My Jobs / Backup",130,-253,160,function() f.filter="mine";f.scroll:SetVerticalScroll(0);A:RenderAdvancedAssignments() end)
    f.sectionButton=dropdown("All Sections",300,-253,180,function()
        local c={{"All Sections","all"}};for _,v in ipairs(A.assignmentSections) do c[#c+1]={v[2],v[1]} end;return c
    end,function(kind) f.section=kind;f.scroll:SetVerticalScroll(0);A:RenderAdvancedAssignments() end)
    button(f,"Refresh",490,-253,100,function() A:RefreshAssignments(true) end)
    f.newRaid=button(f,"New Raid",600,-253,110,function() A:ConfirmAssignmentAction("newRaid",f.raidName:GetText()) end)
    f.context=text(f,"",11,730,-260,250);f.context:SetMaxLines(1)
    f.scroll=self:CreateScrollFrame(f);f.scroll:SetPoint("TOPLEFT",20,-292);f.scroll:SetSize(945,204)
    f.child=CreateFrame("Frame",nil,f.scroll);f.child:SetSize(940,204);f.scroll:SetScrollChild(f.child);f.rows={};f.sectionHeaders={}
    for i,v in ipairs(self.assignmentSections) do
        local header=text(f.child,v[2],12,8,0,920);header:SetTextColor(1,.78,.28);f.sectionHeaders[i]=header
    end
    for i=1,120 do
        local row=button(f.child,"",0,0,940,function()
            local item=f.rows[i].value;if not item then return end
            local b=A:AssignmentBoard();f.editBasis={owner=b.owner,epoch=b.epoch,scope=A:AdvancedAssignmentViewScope(),row=rowSignature(item)}
            f.selected=item.id;f.playerName=item.player;f.backupName=item.backup;f.role=item.role;f.link=item.link
            f.slot:SetText(tostring(item.slot));f.job:SetText(item.job);f.target:SetText(item.target);f.note:SetText(item.note);A:RenderAdvancedAssignments()
        end)
        row:SetHeight(46);row.labels={};self:StyleDataRow(row,i)
        for j,col in ipairs({{8,-7,190},{205,-7,235},{450,-7,315},{8,-27,900},{775,-7,155}}) do
            row.labels[j]=text(row,"",11,col[1],col[2],col[3]);row.labels[j]:SetMaxLines(1)
        end
        f.rows[i]=row
    end
    f.empty=text(f.child,"No jobs in this view. Add jobs below, or create a fictional Practice plan while solo.",12,8,-12,915)
    f.formLabels={}
    f.player=dropdown("Unfilled",20,-538,210,function() return A:AssignmentPlayerChoices("Unfilled Slot") end,function(name) f.playerName=name;A:RenderAdvancedAssignments() end)
    f.roleButton=dropdown("Main Tank",240,-538,200,{{"Main Tank","main"},{"Off-Tank","off"},{"Tank Healer","tank"},{"Group Healer","group"},{"Raid Healer","raid"},{"Interrupt","interrupt"},{"Dispel","dispel"},{"Cooldown","cooldown"},{"Custom Job","custom"}},function(role)
        f.role=role;if role=="group" then f.link=0 end
        local cell=A:AssignmentCellForRole(role)
        if not A:AssignmentPlayerEligible(f.playerName,cell,false) then f.playerName="" end
        if not A:AssignmentPlayerEligible(f.backupName,cell,false) then f.backupName="" end
        A:RenderAdvancedAssignments()
    end)
    f.slot=edit(f,450,-538,60,"Slot #");f.slot:SetMaxLetters(2);f.slot:SetText("1")
    f.backup=dropdown("No Backup",520,-538,220,function() return A:AssignmentPlayerChoices("No Backup") end,function(name) f.backupName=name;A:RenderAdvancedAssignments() end)
    f.linkButton=dropdown("Free Target",750,-538,230,function()
        local c={{"Free target (no link)",0}};local b=A:AssignmentBoard();local scope=A:AdvancedAssignmentViewScope()
        for _,v in ipairs(A:EffectiveAssignments(scope,b)) do
            if v.id~=f.selected then c[#c+1]={(v.job~="" and v.job or A.assignmentRoles[v.role]).." #"..v.slot.." - "..(v.player~="" and A:FullDisplayName(v.player) or "Unfilled"),v.id} end
        end
        return c
    end,function(id) f.link=id;A:RenderAdvancedAssignments() end)
    f.target=edit(f,20,-594,240,"Free target / group 1–8");f.target:SetMaxLetters(80)
    f.job=edit(f,270,-594,250,"Job label (required for Custom)");f.job:SetMaxLetters(60)
    f.note=edit(f,530,-594,450,"Optional note");f.note:SetMaxLetters(120)
    f.apply=button(f,"Add Job",20,-638,200,function()
        local b=A:AssignmentBoard();if not b then return end
        if f.stale then A:Print("This job changed. Select it again before editing.");return end
        local scope=A:AdvancedAssignmentViewScope();local selected
        for _,v in ipairs(b.rows) do if v.id==f.selected then selected=v end end
        local target=f.target:GetText() or ""
        if f.role=="tank" and f.link==0 then target=A:Resolve(target) or target:gsub("^([^ ]+) (.+)$","%1-%2") end
        local kind=(f.role=="main" or f.role=="off") and "tank" or ((f.role=="tank" or f.role=="group" or f.role=="raid") and "healer" or f.role)
        local value={kind=kind,role=f.role,player=f.playerName,backup=f.backupName,slot=tonumber(f.slot:GetText()) or 0,job=f.job:GetText(),note=f.note:GetText(),target=target,link=f.link,encounter=scope}
        -- An inherited default is copied into this encounter, never edited globally by accident.
        local updating=selected and selected.encounter==scope
        if feedback(A:EditAssignment(updating and "update" or "add",value,updating and selected.id or nil)) then editorClear(f);A:RenderAdvancedAssignments() end
    end)
    f.remove=button(f,"Remove Selected Job",230,-638,210,function()
        if feedback(A:EditAssignment("remove",nil,f.selected),"Cannot remove this job while another job links to it. Unlink those jobs first, or edit Raid defaults for inherited jobs.") then editorClear(f);A:RenderAdvancedAssignments() end
    end)
    f.clear=button(f,"New / clear selection",450,-638,220,function() editorClear(f);A:RenderAdvancedAssignments() end)
    f.deleteTemplate=button(f,"Delete Saved Plan",680,-638,150,function()
        if f.templateSource and f.templateSource:sub(1,5)=="plan:" then A:ConfirmAssignmentAction("delete",f.templateSource:sub(6)) end
    end)
    f.close=button(f,"Close",840,-638,140,function() f:Hide() end)
    f.footer=text(f,"",11,20,-686,960);f.footer:SetHeight(36)
    f:SetScript("OnShow",function() A:RenderAdvancedAssignments() end)
end
function A:RenderAdvancedAssignments()
    local f=self.ui and self.ui.assignmentAdvanced;if not f then return end
    local height=math.max(600,math.min(740,UIParent:GetHeight()-24));f:SetHeight(height);f.scroll:SetHeight(height-536)
    local offset=740-height
    for _,position in ipairs({{f.player,20,-538},{f.roleButton,240,-538},{f.slot,450,-538},{f.backup,520,-538},{f.linkButton,750,-538},
        {f.target,20,-594},{f.job,270,-594},{f.note,530,-594},{f.apply,20,-638},{f.remove,230,-638},{f.clear,450,-638},{f.deleteTemplate,680,-638},{f.close,840,-638}}) do
        local control,x,y=position[1],position[2],position[3]+offset;control:ClearAllPoints();control:SetPoint("TOPLEFT",x,y)
        if control.hint then control.hint:ClearAllPoints();control.hint:SetPoint("TOPLEFT",x,y+18) end
    end
    f.footer:ClearAllPoints();f.footer:SetPoint("TOPLEFT",20,-height+54)
    local b=self:AssignmentBoard();local editable=self:CanEditAssignments();local owner=self.assignmentOwner;local scope=self:AdvancedAssignmentViewScope()
    f.summary:SetText(self.demo and "End loot testing to edit or share raid plans." or (not self.Client:InGroup() and "Personal preparation - create your own raids, encounters and jobs. No mechanics are assumed." or
        ("Leader: "..self:FullDisplayName(owner or "Unknown").." - "..(b and ("Revision "..b.revision.." - "..(editable and "Leader and assistants can edit." or "View only.")) or "Waiting for the leader's plan..."))))
    local combatOK,combat=self.Client:Call("InCombatLockdown")
    if combatOK and combat and not self.demo and self.Client:InGroup() then f.summary:SetText(f.summary:GetText().." Updates wait until combat ends.") end
    if b and f.lastRaidName~=b.raidName then f.lastRaidName=b.raidName;f.raidName:SetText(b.raidName) end
    f.encounter:SetText((f.viewEncounter and "Viewing: " or "Current: ")..self:AssignmentEncounterName(scope,b))
    f.context:SetText(b and ("Raid current: "..self:AssignmentEncounterName(b.activeEncounter,b)) or "Waiting for plan")
    f.template:SetText(f.templateSource and f.templateSource:gsub("^plan:","Plan: "):gsub("^profile:","Profile: ") or "Choose Saved Plan")
    local sectionLabel="All Sections";for _,v in ipairs(self.assignmentSections) do if f.section==v[1] then sectionLabel=v[2] end end;f.sectionButton:SetText(sectionLabel)
    f.player:SetText(f.playerName~="" and self:FullDisplayName(f.playerName) or "Unfilled Slot")
    f.backup:SetText(f.backupName~="" and ("Backup: "..self:FullDisplayName(f.backupName)) or "No Backup")
    f.roleButton:SetText(self.assignmentRoles[f.role]);local linkedLabel="Free Target"
    if f.link~=0 then
        linkedLabel="Missing linked slot"
        for _,row in ipairs(b and b.rows or {}) do if row.id==f.link then linkedLabel="Linked: "..self:AssignmentJobLabel(row).." #"..row.slot end end
    end
    f.linkButton:SetText(linkedLabel)
    local selected;for _,v in ipairs(b and b.rows or {}) do if v.id==f.selected then selected=v end end
    if f.selected and not selected then editorClear(f) end
    local basis=f.editBasis
    f.stale=basis and (not b or basis.owner~=b.owner or basis.epoch~=b.epoch or basis.scope~=scope or basis.row~=rowSignature(selected)) or false
    local inherited=selected and selected.encounter~=scope
    f.apply:SetText(f.stale and "Job changed - reselect" or (inherited and "Override for encounter" or (selected and "Update job" or "Add Job")))
    f.announce:SetEnabled(editable and self.Client:InGroup() and b~=nil)
    local leader=editable and owner==self.me
    f.save:SetEnabled(leader);f.load:SetEnabled(leader and f.templateSource~=nil)
    for _,control in ipairs({f.player,f.roleButton,f.backup,f.linkButton,f.renameRaid,f.addEncounter,f.copyEncounter,f.activate,f.newRaid}) do control:SetEnabled(editable and b~=nil) end
    f.renameEncounter:SetEnabled(editable and scope~="raid");f.removeEncounter:SetEnabled(editable and scope~="raid")
    f.practice:SetEnabled(editable and not self.Client:InGroup())
    f.apply:SetEnabled(editable and b~=nil and not f.stale);f.remove:SetEnabled(editable and selected~=nil and not inherited and not f.stale)
    f.deleteTemplate:SetEnabled(leader and f.templateSource~=nil and f.templateSource:sub(1,5)=="plan:")
    for _,field in ipairs({f.target,f.note,f.job,f.slot,f.raidName,f.encounterName,f.templateName}) do field:EnableMouse(editable);field:EnableKeyboard(editable) end
    local effective=self:EffectiveAssignments(scope,b)
    local visible={};for _,row in ipairs(effective) do
        if (f.filter=="all" or row.player==self.me or row.backup==self.me) and (f.section=="all" or f.section==row.kind) then visible[#visible+1]=row end
    end
    f.empty:SetShown(#visible==0);for _,h in ipairs(f.sectionHeaders) do h:Hide() end
    local y=0;local section
    for i,control in ipairs(f.rows) do
        local row=visible[i];control.value=row;control:SetShown(row~=nil)
        if row then
            if row.kind~=section then
                section=row.kind
                for j,v in ipairs(self.assignmentSections) do if v[1]==section then local h=f.sectionHeaders[j];h:ClearAllPoints();h:SetPoint("TOPLEFT",8,-y-3);h:Show() end end
                y=y+26
            end
            control:ClearAllPoints();control:SetPoint("TOPLEFT",0,-y);y=y+50
            local unit=self.roster[row.player];local ok,connected=self.Client:Call("UnitIsConnected",unit)
            local status=row.player=="" and "Unfilled" or (not unit and "Absent" or (not ok and "Unknown" or (connected and "In group" or "Offline")))
            if not self.Client:InGroup() and row.player==self.me then status="Local" end
            local secondary={}
            if row.encounter=="raid" and scope~="raid" then secondary[#secondary+1]="Raid default (click to override)" end
            if row.backup~="" then secondary[#secondary+1]="Backup: "..self:FullDisplayName(row.backup) end
            if row.note~="" then secondary[#secondary+1]=row.note end
            local values={row.player~="" and self:FullDisplayName(row.player) or "Unfilled Slot",self:AssignmentJobLabel(row).." #"..row.slot,self:AssignmentTarget(row,scope,b,effective),table.concat(secondary," | "),status}
            for j,label in ipairs(control.labels) do label:SetText(values[j]);label:SetTextColor(.88,.89,.91) end
            control.labels[1]:SetTextColor(row.id==f.selected and 1 or .88,row.id==f.selected and .78 or .89,row.id==f.selected and .25 or .91)
            if status=="Absent" or status=="Offline" or status=="Unfilled" then control.labels[5]:SetTextColor(1,.65,.2) end
        end
    end
    f.child:SetHeight(math.max(204,y))
    f.footer:SetText("Raid defaults carry into encounters. Matching job labels and slot numbers override a default. Linked targets follow the assigned player.\n"..(self.demo and "Loot tests cannot edit plans." or "Practice jobs are fictional. Announce is manual. Shared plans require members to use the same NRT version."))
end
function A:ShowAdvancedAssignments()
    self:BuildUI();self:RefreshAssignments(true);self.ui.assignmentAdvanced:Show();self:FocusWindow(self.ui.assignmentAdvanced)
end
