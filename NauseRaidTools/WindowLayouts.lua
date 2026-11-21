local _, A = ...
local anchors={TOPLEFT=true,TOP=true,TOPRIGHT=true,LEFT=true,CENTER=true,RIGHT=true,BOTTOMLEFT=true,BOTTOM=true,BOTTOMRIGHT=true}
local function finite(n) return type(n)=="number" and n==n and math.abs(n)<100000 end

function A:WindowModalOwner(frame)
    local u=self.ui
    if not u then return nil,false end
    local parent
    local modal=frame==u.correction or frame==u.lootReason or frame==u.personalColor or frame==u.itemTools
        or frame==u.reroll or frame==u.endSession or frame==u.confirmation
    if frame==u.correction then parent=u.main
    elseif frame==u.lootReason or frame==u.personalColor or frame==u.endSession then parent=u.settingsHub
    elseif frame==u.itemTools then parent=u.lootPanels and u.lootPanels.timer.window
    elseif frame==u.confirmation then parent=frame.nrtDialogOwner
    elseif frame==u.reroll then
        parent=u.main and u.main:IsShown() and u.main or u.lootPanels and u.lootPanels.timer.window
    end
    while parent and parent~=UIParent and not parent.nrtManagedWindow do parent=parent:GetParent() end
    return parent~=UIParent and parent or nil,modal
end

function A:FocusWindow(frame)
    if not frame or not frame.nrtManagedWindow or self.nrtLayering then return end
    for _=1,#(self.windowStack or {}) do
        local nextDialog
        for _,candidate in ipairs(self.windowStack or {}) do
            local parent=self:WindowModalOwner(candidate)
            if candidate:IsShown() and parent==frame then nextDialog=candidate end
        end
        if not nextDialog then break end
        frame=nextDialog
    end
    local stack=self.windowStack or {}
    for i=#stack,1,-1 do if stack[i]==frame then table.remove(stack,i) end end
    stack[#stack+1]=frame;self.windowStack=stack
    self:RefreshWindowLayers()
end

function A:RefreshWindowLayers()
    if self.nrtLayering then return end
    self.nrtLayering=true
    local stack=self.windowStack or {}
    local present={}
    for _,frame in ipairs(stack) do present[frame]=true end
    for _,frame in ipairs(self.allWindowFrames or {}) do
        if not present[frame] then stack[#stack+1]=frame;present[frame]=true end
    end
    self.windowStack=stack
    -- Capture offsets before changing any level: native setters may also move
    -- descendants. Keep each complete window within its own 256-level band.
    local function capture(node,root)
        if node~=root and node.nrtManagedWindow then return end
        node.nrtFocusRoot=root
        if not node.nrtFocusHooked and not node.nrtModalBlocker then
            node:HookScript("OnMouseDown",function(f) A:FocusWindow(f.nrtFocusRoot) end)
            node.nrtFocusHooked=true
        end
        for _,child in ipairs({node:GetChildren()}) do
            if child.nrtLayerParent~=node then
                child.nrtLayerOffset=math.max(0,math.min(40,child:GetFrameLevel()-node:GetFrameLevel()))
                child.nrtLayerParent=node
            end
            capture(child,root)
        end
    end
    local function paint(node,root,base,relative,strata)
        if node~=root and node.nrtManagedWindow then return end
        if node.nrtModalBlocker then relative=240 end
        node:SetFrameStrata(strata);node:SetFrameLevel(base+relative)
        for _,child in ipairs({node:GetChildren()}) do
            paint(child,root,base,math.min(200,relative+(child.nrtLayerOffset or 1)),strata)
        end
    end
    local blocked={}
    for _,frame in ipairs(stack) do
        if frame:IsShown() then
            local parent=self:WindowModalOwner(frame)
            if parent and parent:IsShown() then blocked[parent]=frame end
        end
    end
    for _,parent in ipairs(stack) do
        local dialog=blocked[parent]
        local blocker=parent.nrtDialogBlocker
        if dialog and not blocker then
            blocker=CreateFrame("Frame",nil,parent)
            parent.nrtDialogBlocker=blocker;blocker.nrtModalBlocker=true
            blocker:SetAllPoints(parent);blocker:EnableMouse(true);blocker:EnableMouseWheel(true)
            blocker:SetScript("OnMouseDown",function(f) A:FocusWindow(f.nrtBlockedBy) end)
            local shade=blocker:CreateTexture(nil,"BACKGROUND");shade:SetAllPoints();shade:SetColorTexture(0,0,0,.25)
        end
        if blocker then blocker.nrtBlockedBy=dialog;blocker:SetShown(dialog~=nil) end
    end
    for _,frame in ipairs(stack) do if frame:IsShown() then capture(frame,frame) end end
    local index=0
    for _,frame in ipairs(stack) do
        if frame:IsShown() then
            index=index+1
            local _,modal=self:WindowModalOwner(frame)
            paint(frame,frame,10+index*256,0,modal and "FULLSCREEN_DIALOG" or "DIALOG")
        end
    end
    self.nrtLayering=false
    if self.PositionBuffReminderClicks then self:PositionBuffReminderClicks() end
end

function A:RegisterWindowLayers(frame)
    frame.nrtManagedWindow=true
    frame:HookScript("OnShow",function(f) A:FocusWindow(f) end)
    frame:HookScript("OnHide",function() A:RefreshWindowLayers() end)
end

-- Personal layout is deliberately separate from shared raid profiles/state.
function A:WindowLayoutStore()
    self:InitStorage()
    local db=NauseRaidToolsDB
    if type(db.windowLayouts)~="table" then db.windowLayouts={} end
    local character=self.me or "local"
    if type(db.windowLayouts[character])~="table" then db.windowLayouts[character]={} end
    return db.windowLayouts[character]
end

function A:FitVotingDialog(dialog)
    local owner=self.ui and self.ui.votingSurface
    if not owner then return end
    local scale=math.min(1,owner:GetWidth()*0.82/dialog:GetWidth(),owner:GetHeight()*0.8/dialog:GetHeight())
    dialog:SetScale(scale*owner:GetEffectiveScale()/UIParent:GetEffectiveScale())
    dialog:ClearAllPoints();dialog:SetPoint("CENTER",owner,"CENTER",0,0)
end

-- Title controls are personal UI state; never part of raid communication.
function A:LayoutTitleText(title,left,width,barHeight)
    title:ClearAllPoints();title:SetPoint("TOPLEFT",left,-4)
    title:SetSize(math.max(1,width),barHeight-8)
    title:SetJustifyH("LEFT");title:SetJustifyV("MIDDLE")
    title:SetMaxLines(1);title:SetWordWrap(false)
end
function A:WindowLocked(frame)
    local locks=self:WindowLayoutStore().windowLocks
    local name=frame.nrtWindowName
    if type(locks)=="table" and type(locks[name])=="boolean" then return locks[name] end
    return self:WindowPositionsLocked()
end
function A:ToggleWindowLock(frame)
    local store=self:WindowLayoutStore()
    if type(store.windowLocks)~="table" then store.windowLocks={} end
    store.windowLocks[frame.nrtWindowName]=not self:WindowLocked(frame)
    self:FinishWindowMove(frame)
    self:RefreshWindowChrome(frame)
end
function A:RefreshWindowChrome(frame)
    if frame.nrtChrome~=true then return end
    local locked=self:WindowLocked(frame)
    frame.lockButton.locked=locked
    if type(frame.resizeGrip)=="table" or type(frame.resizeGrip)=="userdata" then
        frame.resizeGrip:SetShown(self:CanResizeWindow(frame) and not locked and frame.nrtCollapsed~=true)
    end
    frame.lockButton.shackle:ClearAllPoints()
    frame.lockButton.shackle:SetPoint("TOPLEFT",locked and 7 or 10,-4)
    frame.lockButton.leftStem:SetShown(locked)
    frame.collapseButton:SetText(frame.nrtCollapsed==true and "+" or "−")
    local width=(self.ui and frame==self.ui.main) and self.ui.votingSurface:GetWidth() or frame:GetWidth()
    frame.nrtHeader:SetWidth(width)
    self:LayoutTitleText(frame.title,18,width-110,34)
    if self.ui and frame==self.ui.checkWindow then
        self:LayoutTitleText(frame.title,18,width-260,34)
        self:LayoutTitleText(self.ui.checkExpected,width-250,145,34)
    end
    if frame.nrtCollapsed==true then
        self:CaptureWindowBody(frame)
        frame.nrtBody:Hide();frame:SetBackdrop(nil);frame:EnableMouse(false);frame:EnableMouseWheel(false)
    end
end
function A:CaptureWindowBody(frame)
    if type(frame.nrtBody)~="table" and type(frame.nrtBody)~="userdata" then
        frame.nrtBody=CreateFrame("Frame",nil,frame)
        frame.nrtBody:SetAllPoints(frame)
    end
    local body=frame.nrtBody
    -- Reparent content without hiding the window or changing any child's own
    -- visibility. Network/render refreshes can continue safely while collapsed.
    for _,child in ipairs({frame:GetChildren()}) do
        if child~=body and child~=frame.nrtHeader then child:SetParent(body) end
    end
    for _,region in ipairs({frame:GetRegions()}) do
        local kind=region:GetObjectType()
        if region~=frame.headerBand and (kind=="FontString" or kind=="Texture") then
            region:SetParent(body)
        end
    end
end
function A:ToggleWindowCollapse(frame)
    if self.ui and frame==self.ui.settingsHub then self:CloseSettingsDropdown() end
    if frame.nrtCollapsed==true then
        frame.nrtCollapsed=false
        if frame.nrtBackdrop then self:StylePanel(frame) end
        frame:EnableMouse(true)
        if frame==self.ui.popup or frame.nrtWheelEnabled==true then frame:EnableMouseWheel(true) end
        frame.nrtBody:Show()
    else
        frame.nrtBackdrop=frame:GetBackdrop()
        frame.nrtCollapsed=true
        self:FinishWindowMove(frame)
    end
    self:RefreshWindowChrome(frame)
end
function A:InstallWindowChrome(frame,name,button)
    frame.nrtWindowName=name
    if name=="NauseRaidToolsLauncher" then return end
    frame.nrtChrome=true;frame.nrtCollapsed=false;frame.nrtBody=nil
    local header=CreateFrame("Frame",nil,frame,"BackdropTemplate")
    frame.nrtHeader=header
    header:SetPoint("TOPLEFT",0,0);header:SetSize(frame:GetWidth(),34)
    self:StylePanel(header,34)
    frame.headerBand:Hide()
    frame.title:SetParent(header);frame.closeButton:SetParent(header)
    local level=frame:GetFrameLevel();if type(level)=="number" then header:SetFrameLevel(level+30) end
    header:EnableMouse(true);header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart",function() A:BeginWindowMove(frame) end)
    header:SetScript("OnDragStop",function() A:FinishWindowMove(frame,name) end)
    frame.collapseButton=button(header,"−",0,0,22,function() A:ToggleWindowCollapse(frame) end)
    frame.collapseButton:SetSize(22,22);frame.collapseButton:ClearAllPoints();frame.collapseButton:SetPoint("TOPRIGHT",-32,-6)
    local lock=button(header,"",0,0,22,function() A:ToggleWindowLock(frame) end)
    frame.lockButton=lock
    lock:SetSize(22,22);lock:ClearAllPoints();lock:SetPoint("TOPRIGHT",-58,-6)
    local function stroke(parent,x,y,w,h,r,g,b)
        local t=parent:CreateTexture(nil,"ARTWORK");t:SetColorTexture(r,g,b,1)
        t:SetPoint("TOPLEFT",x,y);t:SetSize(w,h);return t
    end
    lock.iconParts={stroke(lock,6,-10,10,8,.84,.86,.89)}
    stroke(lock,10,-12,2,3,.1,.11,.13)
    local shackle=CreateFrame("Frame",nil,lock);shackle:SetSize(8,8);lock.shackle=shackle
    lock.iconParts[#lock.iconParts+1]=stroke(shackle,0,0,8,2,.84,.86,.89)
    lock.iconParts[#lock.iconParts+1]=stroke(shackle,6,-1,2,7,.84,.86,.89)
    lock.leftStem=stroke(shackle,0,-1,2,7,.84,.86,.89)
    lock.iconParts[#lock.iconParts+1]=lock.leftStem
    lock:SetScript("OnEnter",function() for _,part in ipairs(lock.iconParts) do part:SetColorTexture(1,1,1,1) end end)
    lock:SetScript("OnLeave",function() for _,part in ipairs(lock.iconParts) do part:SetColorTexture(.84,.86,.89,1) end end)
    frame:HookScript("OnShow",function() A:RefreshWindowChrome(frame) end)
    self:RefreshWindowChrome(frame)
end

-- Dimensions are UI units; resizing never changes text or icon scale.
local policies={
    NauseRaidToolsMyAssignments={400,280,340,200,600,600,"middle",true},
    NauseRaidToolsResponses={760,380,680,380,900,475,"responses"},
    NauseRaidToolsMain={1100,640,1000,560,1300,800,"voting"},
    NauseRaidToolsTrade={820,440,680,300,960,620,"loot",true},
    NauseRaidToolsTimer={600,320,440,220,760,460,"timer",true},
    NauseRaidToolsSettings={1000,720,900,600,1200,820,"middle"},
    NauseRaidToolsHistory={980,560,840,440,1200,720,"middle"},
    NauseRaidToolsReadiness={640,500,560,360,760,650,"middle"},
}
local compactPolicies={
    NauseRaidToolsResponses={620,315,560,315,620,395,"responses"},
    NauseRaidToolsMain={740,530,620,460,740,530,"voting"},
    NauseRaidToolsTimer={380,250,320,180,480,380,"timer",true},
}
function A:WindowPolicy(frame)
    for _,entry in ipairs(self.windowFrames or {}) do
        if entry.frame==frame then
            local kind=entry.name=="NauseRaidToolsResponses" and "response"
                or entry.name=="NauseRaidToolsMain" and "voting"
                or entry.name=="NauseRaidToolsTimer" and "timer"
            if kind and self.LootWindowLayout and self:LootWindowLayout(kind)=="Compact" then return compactPolicies[entry.name] end
            return policies[entry.name]
        end
    end
end
function A:CanResizeWindow(frame)
    if frame.nrtRaidCheckVertical==true then return true end
    local p=self:WindowPolicy(frame)
    return p and p[8]==true or false
end
function A:IsReadableWindow(frame) return self:WindowPolicy(frame)~=nil end
function A:WindowPositionsLocked()
    return self:WindowLayoutStore().positionsLocked==true
end
function A:SetWindowPositionsLocked(locked)
    local store=self:WindowLayoutStore()
    store.positionsLocked=locked==true
    store.windowLocks={}
    for _,frame in ipairs(self.allWindowFrames or {}) do self:RefreshWindowChrome(frame) end
    self:RenderSettings()
end
function A:ReadableWindowBounds(frame)
    local p=self:WindowPolicy(frame)
    if not p then return frame:GetWidth(),frame:GetHeight(),frame:GetWidth(),frame:GetHeight() end
    return p[3],p[4],p[5],p[6]
end
function A:ResponseWindowHeight()
    local count=0
    local item=self.state and self:ItemByID(self.popupItem or 0)
    for _,v in ipairs(self:ResponseOptions(item)) do if v.enabled then count=count+1 end end
    local rows=math.ceil(count/3)
    if self:LootWindowLayout("response")=="Compact" then
        return 315+math.max(0,rows-2)*30+(self.responseNoteExpanded and 44 or 0)
    end
    return math.max(380,math.min(475,312+rows*34+math.max(0,rows-2)*8))
end
function A:ResizeReadableWindow(frame,width,height)
    local minW,minH,maxW,maxH=self:ReadableWindowBounds(frame)
    local policy=self:WindowPolicy(frame)
    if policy and not self:CanResizeWindow(frame) then width,height=policy[1],policy[2] end
    local sw,sh=UIParent:GetWidth(),UIParent:GetHeight()
    -- On a smaller desktop fit the available canvas without shrinking fonts.
    local availableW,availableH=math.max(1,sw-32),math.max(1,sh-32)
    if sw<minW+32 then availableW=sw end
    if sh<minH+32 then availableH=sh end
    maxW,maxH=math.min(maxW,availableW),math.min(maxH,availableH)
    minW,minH=math.min(minW,maxW),math.min(minH,maxH)
    if self.ui and frame==self.ui.popup then height=self:ResponseWindowHeight() end
    frame:SetScale(1)
    frame:SetSize(math.max(minW,math.min(maxW,width)),math.max(minH,math.min(maxH,height)))
    self:LayoutReadableWindow(frame)
end
local fractions={TOPLEFT={0,1},TOP={.5,1},TOPRIGHT={1,1},LEFT={0,.5},CENTER={.5,.5},RIGHT={1,.5},BOTTOMLEFT={0,0},BOTTOM={.5,0},BOTTOMRIGHT={1,0}}
function A:WindowTopLeft(frame)
    local point,_,relativePoint,x,y=frame:GetPoint(1)
    local a,b=fractions[point],fractions[relativePoint]
    if not a or not b or not finite(x) or not finite(y) then return 16,60 end
    return b[1]*UIParent:GetWidth()+x-a[1]*frame:GetWidth(),(1-b[2])*UIParent:GetHeight()-y-(1-a[2])*frame:GetHeight()
end
-- Keep one UIParent-relative anchor throughout a drag. Native StartMoving can
-- switch to screen-relative anchors, whose offsets differ at non-default scales.
function A:BeginWindowMove(frame)
    self:FocusWindow(frame)
    if self:WindowLocked(frame) or frame.nrtResizing==true then return false end
    if frame.nrtMoving then return false end
    local x,y=GetCursorPosition()
    local scale=UIParent:GetEffectiveScale()
    if not finite(x) or not finite(y) or not finite(scale) or scale<=0 then return false end
    local left,top=self:WindowTopLeft(frame)
    frame.nrtDrag={x=x,y=y,left=left,top=top,scale=scale}
    frame.nrtMoving=true
    if not frame.nrtDragHooked then
        frame.nrtDragHooked=true
        frame:HookScript("OnUpdate",function(f)
            if not f.nrtMoving then return end
            if A:WindowLocked(f) or not IsMouseButtonDown("LeftButton")
                or UIParent:GetEffectiveScale()~=f.nrtDrag.scale then
                A:FinishWindowMove(f)
            else A:UpdateWindowMove(f) end
        end)
        frame:HookScript("OnHide",function(f) A:FinishWindowMove(f) end)
    end
    return true
end
function A:UpdateWindowMove(frame)
    local drag=frame.nrtDrag
    if not frame.nrtMoving or not drag then return end
    local x,y=GetCursorPosition()
    local scale=UIParent:GetEffectiveScale()
    -- A display/scale change invalidates the old mouse coordinate space.
    if scale~=drag.scale or not finite(x) or not finite(y) then return end
    local sw,sh,w,h=UIParent:GetWidth(),UIParent:GetHeight(),frame:GetWidth(),frame:GetHeight()
    local left=math.max(0,math.min(sw-w,drag.left+(x-drag.x)/scale))
    local top=math.max(0,math.min(sh-h,drag.top+(drag.y-y)/scale))
    frame:ClearAllPoints();frame:SetPoint("TOPLEFT",UIParent,"TOPLEFT",left,-top)
end
function A:FinishWindowMove(frame,name)
    if not frame.nrtMoving then return end
    self:UpdateWindowMove(frame)
    frame.nrtMoving=false;frame.nrtDrag=nil
    self:ClampWindowPosition(frame)
    self:SaveWindowLayout(frame,name or frame.nrtWindowName)
end
function A:ClampWindowPosition(frame)
    if frame.nrtMoving then return end
    local x,y=self:WindowTopLeft(frame)
    local sw,sh,w,h=UIParent:GetWidth(),UIParent:GetHeight(),frame:GetWidth(),frame:GetHeight()
    x=math.max(0,math.min(sw-w,x));y=math.max(0,math.min(sh-h,y))
    frame:ClearAllPoints();frame:SetPoint("TOPLEFT",UIParent,"TOPLEFT",x,-y)
end
function A:DefaultWindowPosition(frame)
    local p=self:WindowPolicy(frame)
    local sw,sh=UIParent:GetWidth(),UIParent:GetHeight()
    local w,h=frame:GetWidth(),frame:GetHeight()
    local kind=p and p[7] or "middle"
    local x,y=(sw-w)/2,math.max(32,(sh-h)*.28)
    if kind=="loot" then
        x,y=(sw-w)/2,(sh-h)/2
    elseif kind=="responses" then
        local responseW=policies.NauseRaidToolsResponses[1]
        local lootW=policies.NauseRaidToolsTrade[1]
        if sw>=responseW+lootW+64 then
            x=(sw-responseW-lootW-24)/2
            if kind=="loot" then x=x+responseW+24 end
        elseif kind=="responses" then x=math.max(16,(sw-w)/2-80)
        else x=math.min(sw-w-16,(sw-w)/2+80) end
        y=math.max(60,sh*.18)
    elseif kind=="timer" then x=sw-w-24;y=math.max(180,sh*.2)
    elseif kind=="voting" then y=math.max(32,sh*.1) end
    frame:ClearAllPoints();frame:SetPoint("TOPLEFT",UIParent,"TOPLEFT",x,-y)
    self:ClampWindowPosition(frame)
end
local resetWindowLabels={
    NauseRaidToolsBuffReminders="Assigned Buff Reminders",
    NauseRaidToolsResponses="Response Window",NauseRaidToolsMain="Voting Window",
    NauseRaidToolsTrade="Loot Window",NauseRaidToolsTimer="Timer Window",
    NauseRaidToolsSettings="Settings Window",NauseRaidToolsHistory="History Window",
    NauseRaidToolsReadiness="Pre-Raid Loot Check",NauseRaidToolsRaidChecks="Raid Check",NauseRaidToolsAssignments="Other Assignment Jobs",NauseRaidToolsAssignmentBoard="Assignments",NauseRaidToolsMyAssignments="My Assignments",
}
function A:WindowResetChoices()
    local choices={}
    for _,entry in ipairs(self.windowFrames or {}) do
        local label=resetWindowLabels[entry.name]
        if label then choices[#choices+1]={label,entry.name} end
    end
    table.sort(choices,function(a,b) return a[1]<b[1] end)
    return choices
end
function A:ResetOneWindowLayout(name)
    if not resetWindowLabels[name] then return false end
    for _,entry in ipairs(self.windowFrames or {}) do
        if entry.name==name then
            local frame=entry.frame
            self:FinishWindowMove(frame,name)
            self:WindowLayoutStore()[name]=nil
            if name=="NauseRaidToolsRaidChecks" then self:WindowLayoutStore().raidCheckHeight=nil end
            local policy=self:WindowPolicy(frame)
            if policy then self:ResizeReadableWindow(frame,policy[1],policy[2]) end
            self:DefaultWindowPosition(frame)
            self:SaveWindowLayout(frame,name)
            self:RefreshWindowChrome(frame)
            self:Render()
            if name=="NauseRaidToolsRaidChecks" and self.RenderRaidChecks then self:RenderRaidChecks() end
            return true
        end
    end
    return false
end

function A:ResetWindowLayout()
    local store=self:WindowLayoutStore()
    store.raidCheckHeight=nil
    for _,entry in ipairs(self.windowFrames or {}) do store[entry.name]=nil end
    self:RestoreWindowLayouts()
    self:Render()
    if self.RenderRaidChecks then self:RenderRaidChecks() end
end

function A:LayoutReadableWindow(frame)
    local u=self.ui
    if not u then return end
    self:RefreshWindowChrome(frame)
    local w,h=frame:GetWidth(),frame:GetHeight()
    local function place(object,x,y,width,height)
        object:ClearAllPoints();object:SetPoint("TOPLEFT",x,-y)
        if width then object:SetWidth(width) end
        if height then object:SetHeight(height) end
    end
    if frame==u.myAssignments then self:RenderMyAssignments();return end
    if frame==u.settingsHub then self:LayoutSettings();return end
    if frame==u.lootTimers.window then self:LayoutLootTimer();return end
    if frame==u.lootPanels.deliveries.window then
        local p=u.lootPanels.deliveries
        local old=p.visibleRows or 6
        p.visibleRows=math.max(1,math.min(12,math.floor((h-165)/44)))
        if old~=p.visibleRows then p.page=math.floor((p.page or 0)*old/p.visibleRows) end
        frame.title:SetWidth(w-60)
        local holderX=w-440
        local actionX=w-302
        local itemWidth=holderX-56
        place(p.itemHeader,24,70,itemWidth+30)
        place(p.holderHeader,18+holderX,70,126)
        place(p.actionHeader,18+actionX,70,142)
        for _,header in ipairs({p.itemHeader,p.holderHeader,p.actionHeader}) do header:SetTextColor(.80,.74,.57) end
        for i,row in ipairs(p.rows) do
            place(row,0,(i-1)*44,w-58,42)
            row.caption:SetWidth(itemWidth)
            row.detail:SetWidth(itemWidth)
            place(row.holder,holderX,8,126)
            place(row.holderStatus,holderX,26,126)
            place(row.action,actionX,7,146)
            place(row.deadline,actionX,25,146)
            place(row.trade,w-150,8,88)
        end
        p.scroll:SetSize(w-58,p.visibleRows*44);p.child:SetWidth(w-58)
        place(p.empty,24,math.min(150,h*.4),w-48)
        place(p.previous,20,h-75);place(p.next,60,h-75)
        place(p.pageLabel,110,h-67,math.min(95,math.max(55,w-625)))
        p.summary:SetWidth(w-40)
        place(u.itemToolsButton,w-505,h-75,145)
        place(p.queueAll,w-350,h-75,105);place(u.manageLoot,w-235,h-75,100)
        place(p.close,w-125,h-75,100);place(p.footer,20,h-33,w-40)
        return
    elseif frame==u.history then
        local cols=u.historyColumns
        local itemWidth=w-570
        cols[4][3]=itemWidth;cols[5][2]=340+itemWidth
        cols[5][3]=w-65-cols[5][2]
        frame.title:SetWidth(w-60);u.historyScope:SetWidth(w-60)
        place(u.historySearch,20,98,math.min(560,w-60),26)
        place(u.historyMine,20,132,165,26)
        place(u.historyGuildBank,195,132,165,26)
        place(u.historySync,w-170,h-50,130,28)
        place(u.historyExport,w-300,h-50,120,28)
        place(u.historyDelete,20,h-50,170,28)
        place(u.historySelectAll,200,h-50,145,28)
        place(u.historyDeleteCancel,355,h-50,85,28)
        place(u.historySyncStatus,610,136,w-650,32)
        if u.archiveCompleted then place(u.archiveCompleted,370,132,220,28) end
        if u.archiveHelp then place(u.archiveHelp,20,h-78,w-40,18);u.archiveHelp:SetMaxLines(1) end
        u.historyScroll:ClearAllPoints();u.historyScroll:SetPoint("TOPLEFT",20,-194);u.historyScroll:SetPoint("BOTTOMRIGHT",-35,95)
        for _,col in ipairs(cols) do place(col.heading,20+col[2],171,col[3]) end
        u.historyChild:SetWidth(w-55)
        for _,row in ipairs(u.historyRows) do
            row:SetWidth(w-65)
            for i,col in ipairs(cols) do place(row.cells[i],col[2],7,col[3]) end
        end
        if type(u.historyEmpty)=="table" then u.historyEmpty:SetWidth(w-65) end
        return
    elseif frame==u.checkWindow then
        frame.title:SetWidth(w-200)
        place(u.checkExpected,w-250,22,145)
        for _,line in ipairs(u.checkRoles) do line:SetWidth(w-50) end
        local playerWidth=w-350
        place(u.checkplayerHeader,20,139,playerWidth)
        place(u.checkaddonHeader,30+playerWidth,139,130)
        place(u.checkversionHeader,170+playerWidth,139,140)
        u.checkChild:SetWidth(w-55)
        for _,row in ipairs(u.checkRows) do
            row:SetWidth(w-55);row.player:SetWidth(playerWidth)
            place(row.addon,playerWidth+10,5,130);place(row.version,playerWidth+150,5,140)
        end
        place(u.checkSummary,20,h-38,w-175);place(u.recheck,w-140,h-48,115)
        return
    end

    if frame==u.popup then
        local body=w-125
        frame.title:SetWidth(w-60)
        u.responseProgress:SetWidth(body)
        u.popupItem:SetWidth(w-152)
        u.popupStatus:SetWidth(body);u.popupFacts:SetWidth(body);u.popupEligibility:SetWidth(body)
        u.responseBar:SetWidth(body)
        u.note:SetWidth(body-10);u.note.hint:SetWidth(body-100)
        local compact=self:LootWindowLayout("response")=="Compact"
        local noteOpen=not compact or self.responseNoteExpanded==true
        u.responseNoteToggle:SetShown(compact and self.noteDraftKey~=nil)
        u.responseNoteToggle:SetText(noteOpen and "Hide Note" or (u.note:GetText()~="" and "Edit Note" or "Add Note"))
        u.note:SetShown(noteOpen);u.noteBytes:SetShown(noteOpen);u.note.hint:SetShown(not compact)
        place(u.popupStatus,92,compact and 92 or 108)
        place(u.popupFacts,92,compact and 109 or 125)
        place(u.responseBar,92,compact and 122 or 140)
        place(u.popupEligibility,92,compact and 145 or 165)
        place(u.note,97,compact and 195 or 200)
        local step=(body+10)/3
        local buttonTop=compact and (197+(noteOpen and 44 or 0)) or math.min(245,h-145)
        for i,b in ipairs(u.responseButtons) do
            place(b,92+(i-1)%3*step,buttonTop+math.floor((i-1)/3)*(compact and 30 or 34),step-10)
        end
        local pitch=compact and 33 or 43
        u.responseRailPitch=pitch
        u.responseRail:SetHeight(6*pitch)
        for i,b in ipairs(u.responseItemButtons) do place(b,5,(i-1)*pitch,compact and 33 or 40,compact and 32 or 38);b.icon:SetSize(compact and 24 or 30,compact and 24 or 30) end
        place(u.responseRailPage,0,6*pitch)
        place(u.responseRailPrevious,0,6*pitch+20)
        place(u.responseRailNext,28,6*pitch+20)
        local scale=u.responseVoting:GetEffectiveScale()
        if not finite(scale) or scale<=0 then scale=1 end
        local votingX=math.floor((92+(body-200)/2)*scale+.5)/scale
        place(u.responseVoting,votingX,h-45)
        self:StyleButtonOutline(u.responseVoting)
        place(u.responseRoleHint,92,h-37,body)
    elseif frame==u.main then
        -- All panels fit within the actual window; never crop a larger canvas.
        local compact=self:LootWindowLayout("voting")=="Compact"
        local sidebar=math.min(304,math.max(264,math.floor(w*304/1100+0.5)))
        local surface=compact and w or w-sidebar-16
        u.selectedLootPane:SetShown(not compact)
        u.votingHistory.frame:SetShown(not compact)
        u.compareGear:SetShown(compact)
        u.votingSurface:SetSize(surface,h)
        frame.title:SetParent(frame.nrtHeader or u.votingSurface)
        place(frame.title,80,12,surface-130)
        frame.closeButton:SetParent(frame.nrtHeader or u.votingSurface)
        frame.closeButton:ClearAllPoints();frame.closeButton:SetPoint("TOPRIGHT",-6,-6)
        u.status:SetWidth(surface-100);u.status:SetMaxLines(1)
        u.itemTitle:SetWidth(surface-145);u.itemTitle:SetMaxLines(1)
        u.itemDetails:SetWidth(surface-145)
        local barWidth=math.min(210,math.floor((surface-140)*0.42))
        u.councilResponseBar:SetWidth(barWidth)
        place(u.itemStatus,127+barWidth+12,112,surface-149-barWidth,16)
        place(u.councilEmpty,90,190,surface-110,100)
        self:LayoutVotingColumns(surface,compact)
        local oldItems,oldCandidates=self.votingItemRows,self.votingCandidateRows
        self.votingItemRows=math.min(9,math.max(3,math.floor((h-251)/43)))
        self.votingCandidateRows=math.min(14,math.max(3,math.floor((h-332)/22)))
        if oldItems and oldItems~=self.votingItemRows then
            for i,item in ipairs(self.state and self.state.items or {}) do if item.id==self.selectedItem then self.itemPage=math.floor((i-1)/self.votingItemRows);break end end
        end
        if oldCandidates and oldCandidates~=self.votingCandidateRows then self.candidateRowsChanged=true end
        u.votingItemRail:SetHeight((self.votingItemRows or 9)*43)
        place(u.itemPages,15,h-182,50,14)
        place(u.itemPrev,16,h-162,22,22);place(u.itemNext,42,h-162,22,22)
        place(u.playerPagePrevious,surface-210,h-137,95);place(u.playerPageNext,surface-110,h-137,95)
        if compact then
            place(u.playerHistory,surface-125,h-177,110)
            place(u.compareGear,surface-245,h-177,110)
            place(u.selection,80,h-171,math.max(80,surface-340))
        else
            place(u.selection,80,h-171,math.max(100,surface-220))
            place(u.playerHistory,surface-125,h-177,110)
        end
        place(u.votingProgress,80,h-137,surface-310)
        place(u.votingOwn,80,h-105,surface-90,42)
        place(u.open,80,h-60)
        place(u.correctAward,250,h-60,140)
        place(u.votingResponses,surface-(self:IsMaster() and 225 or 145),h-60)
        place(u.votingLoot,surface-90,h-60)
        if compact then return end
        local topHeight=math.floor(h/2)
        place(u.selectedLootPane,surface+16,0,sidebar,topHeight)
        local scrollWidth=sidebar-38
        u.selectedLootScroll:SetWidth(scrollWidth);u.selectedLootChild:SetWidth(scrollWidth)
        u.selectedLootPlaceholder:SetWidth(scrollWidth-16)
        u.selectedLootScroll:SetHeight(topHeight-41)
        local p=u.votingHistory
        local historyHeight=h-topHeight-12
        place(p.frame,surface+16,topHeight+12,sidebar,historyHeight)
        p.title:SetWidth(sidebar-24);p.title:SetMaxLines(1)
        p.summary:SetWidth(sidebar-24)
        p.scroll:SetWidth(scrollWidth);p.child:SetWidth(scrollWidth);p.empty:SetWidth(scrollWidth-16)
        for _,row in ipairs(p.rows) do row:SetWidth(scrollWidth-4);row.item:SetWidth(scrollWidth-44);row.detail:SetWidth(scrollWidth-44) end
        p.scroll:SetHeight(historyHeight-80)
        place(p.footer,10,historyHeight-18,sidebar-20)
        self:SizeSelectedLootTooltip()
    end
end

function A:SaveWindowLayout(frame,name)
    if frame.nrtMoving then return end
    local point,_,relativePoint,x,y=frame:GetPoint(1)
    local scale=frame:GetScale()
    if not anchors[point] or not anchors[relativePoint] or not finite(x) or not finite(y) or not finite(scale) then return end
    local saved={point=point,relativePoint=relativePoint,x=x,y=y,scale=scale}
    local store=self:WindowLayoutStore()
    if self:IsReadableWindow(frame) then
        local width,height=frame:GetWidth(),frame:GetHeight()
        local prior=store[name]
        saved.width,saved.height,saved.geometryVersion=width,height,3
        if name=="NauseRaidToolsTimer" then
            if self:LootWindowLayout("timer")=="Compact" then
                saved.compactWidth,saved.compactHeight=width,height
                saved.width,saved.height=prior and prior.width,prior and prior.height
            elseif prior then saved.compactWidth,saved.compactHeight=prior.compactWidth,prior.compactHeight end
        end
    end
    if name=="NauseRaidToolsTrade" then saved.centeredLoot=true end
    store[name]=saved
end

function A:WindowScale(frame,scale)
    local parentScale=UIParent:GetEffectiveScale()
    local width,height=UIParent:GetWidth(),UIParent:GetHeight()
    local fw,fh=frame:GetWidth(),frame:GetHeight()
    local maximum=2
    if finite(width) and finite(height) and finite(fw) and finite(fh) and finite(parentScale) and fw>0 and fh>0 then
        maximum=math.min(maximum,width/fw,height/fh)
    end
    return math.max(math.min(0.5,maximum),math.min(maximum,scale))
end

function A:InstallWindowResizeGrip(frame,name)
    if type(frame.resizeGrip)=="table" or type(frame.resizeGrip)=="userdata" then return end
    local grip=CreateFrame("Button",nil,frame)
    local inset=name=="NauseRaidToolsMyAssignments" and 6 or 3
    frame.resizeGrip=grip;grip:SetSize(18,18);grip:SetPoint("BOTTOMRIGHT",-inset,inset)
    local level=frame:GetFrameLevel();if type(level)=="number" then grip:SetFrameLevel(level+20) end
    for i=1,3 do
        local line=grip:CreateTexture(nil,"ARTWORK");line:SetSize(i*4,1.5)
        line:SetRotation(math.pi/4);line:SetPoint("CENTER",5-i*2,-5+i*2)
        line:SetColorTexture(.52,.54,.59,1)
    end
    local resizing
    local function finish()
        if not resizing then return end
        resizing=nil;frame.nrtResizing=false
        A:ClampWindowPosition(frame);A:SaveWindowLayout(frame,name)
    end
    grip:SetScript("OnMouseDown",function(_,mouse)
        if mouse~="LeftButton" or A:WindowLocked(frame) or frame.nrtCollapsed==true then return end
        local x,y=GetCursorPosition();if not finite(x) or not finite(y) then return end
        local left,top=A:WindowTopLeft(frame)
        resizing={x=x,y=y,left=left,top=top,width=frame:GetWidth(),height=frame:GetHeight()}
        frame.nrtResizing=true
    end)
    grip:SetScript("OnUpdate",function()
        if not resizing then return end
        if A:WindowLocked(frame) or frame.nrtCollapsed==true then finish();return end
        local x,y=GetCursorPosition();if not finite(x) or not finite(y) then return end
        if resizing.lastX==x and resizing.lastY==y then return end
        resizing.lastX,resizing.lastY=x,y
        local scale=UIParent:GetEffectiveScale();if not finite(scale) or scale<=0 then scale=1 end
        local width=math.min(resizing.width+(x-resizing.x)/scale,UIParent:GetWidth()-resizing.left-16)
        local height=math.min(resizing.height+(resizing.y-y)/scale,UIParent:GetHeight()-resizing.top-16)
        A:ResizeReadableWindow(frame,width,height)
        frame:ClearAllPoints();frame:SetPoint("TOPLEFT",UIParent,"TOPLEFT",resizing.left,-resizing.top)
        A:ClampWindowPosition(frame);A:RenderLootWindows()
    end)
    grip:SetScript("OnMouseUp",finish);grip:HookScript("OnHide",finish);frame:HookScript("OnHide",finish)
end

function A:PreferredWindowSize(frame,saved)
    local policy=self:WindowPolicy(frame)
    if self:CanResizeWindow(frame) and type(saved)=="table" and saved.geometryVersion==3 then
        local width,height=saved.width,saved.height
        if policy==compactPolicies.NauseRaidToolsTimer then width,height=saved.compactWidth,saved.compactHeight end
        if finite(width) and finite(height) and width>0 and height>0 then return width,height end
    end
    return policy[1],policy[2]
end

function A:RestoreWindowLayouts()
    local store=self:WindowLayoutStore()
    for _,entry in ipairs(self.windowFrames or {}) do
        local f,name=entry.frame,entry.name
        self:FinishWindowMove(f,name)
        local saved,p=store[name],self:WindowPolicy(f)
        f:SetScale(1)
        if p then self:ResizeReadableWindow(f,self:PreferredWindowSize(f,saved)) end
        if p and p[7]=="loot" and (type(saved)~="table" or saved.centeredLoot~=true) then
            self:DefaultWindowPosition(f)
        elseif type(saved)=="table" and anchors[saved.point] and anchors[saved.relativePoint] and finite(saved.x) and finite(saved.y) then
            f:ClearAllPoints();f:SetPoint(saved.point,UIParent,saved.relativePoint,saved.x,saved.y)
            self:ClampWindowPosition(f)
        else self:DefaultWindowPosition(f) end
        self:SaveWindowLayout(f,name)
        f:SetScript("OnDragStart",function(frame) A:BeginWindowMove(frame) end)
        f:SetScript("OnDragStop",function(frame)
            A:FinishWindowMove(frame,name)
        end)
        if self:CanResizeWindow(f) then
            self:InstallWindowResizeGrip(f,name)
        else f.resizeGrip=false end
        self:RefreshWindowChrome(f)

    end
    if not self.windowDisplayEvents then
        local events=CreateFrame("Frame");self.windowDisplayEvents=events
        events:RegisterEvent("DISPLAY_SIZE_CHANGED");events:RegisterEvent("UI_SCALE_CHANGED")
        events:SetScript("OnEvent",function()
            for _,entry in ipairs(A.windowFrames or {}) do
                local f=entry.frame
                A:FinishWindowMove(f,entry.name)
                if A:IsReadableWindow(f) then A:ResizeReadableWindow(f,f:GetWidth(),f:GetHeight()) end
                A:ClampWindowPosition(f);A:SaveWindowLayout(f,entry.name)
            end
            A:Render()
        end)
    end
end
