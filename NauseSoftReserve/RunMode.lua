local _, S = ...
local A=S.base
local originalAct,originalReduce,originalResume=A.Act,A.Reduce,A.ResumeSession

function S:CanChooseRun()
    if not A:IsLeader() or not A.Client:InRaid() then return false,"Only the current raid leader can start a run." end
    if A.demo then return false,"Leave solo test mode before starting a live run." end
    if A.state or self.session then return false,"End the current run before choosing another run type." end
    if not A.Client:ClockReady() then return false,"Client clocks unavailable. Use /nrt diagnostics." end
    return true
end
function S:ChooseRun(mode,limit)
    local ok,why=self:CanChooseRun()
    if not ok then self:Print(why);return false,why end
    if mode=="Guild Run" then
        -- Use the original council start, including its authority and native role checks.
        originalAct(A,"start")
        if not A.state then return false,"The Guild Run could not start; check the addon messages." end
        if self.runChooser then self.runChooser:Hide() end
        self:RefreshModeControls()
        if A.ui and A.ui.settingsHub then A.ui.settingsHub:Hide() end
        if A.ui and A.ui.main then A.ui.main:Show() end
        return true
    elseif mode=="PuG Run" then
        ok,why=self:Begin(limit)
        if not ok then self:Print(why);return false,why end
        if self.runChooser then self.runChooser:Hide() end
        if A.ui then
            for _,key in ipairs({"main","voting","settingsHub"}) do if A.ui[key] then A.ui[key]:Hide() end end
        end
        self:Show();return true
    end
    return false,"Choose Guild Run or PuG Run."
end
function S:ShowRunChooser()
    local ok,why=self:CanChooseRun()
    if not ok then self:Print(why);return false,why end
    if not self.runChooser then
        local f=S:CreateUIFrame("Frame","NauseRunTypeChooser",UIParent,"BasicFrameTemplateWithInset")
        self.runChooser=f;f:SetSize(470,255);f:SetPoint("CENTER");f:SetFrameStrata("DIALOG")
        f:SetClampedToScreen(true);f:EnableMouse(true)
        if f.TitleText then f.TitleText:SetText("Nause Raid Tools - Run Type") end
        if UISpecialFrames then table.insert(UISpecialFrames,"NauseRunTypeChooser") end
        local function label(text,x,y,width)
            local l=f:CreateFontString(nil,"OVERLAY","GameFontNormal");l:SetPoint("TOPLEFT",x,y);l:SetWidth(width);l:SetJustifyH("LEFT");l:SetText(text);return l
        end
        label("How will loot be distributed for this run?",22,-42,425)
        label("Guild Run\nLoot Council voting and awards.",22,-77,205)
        label("PuG Run\nSoft Reserve > Main Spec > Off Spec.",245,-77,205)
        label("PuG reserves per player (1–6):",22,-136,305)
        f.limit=S:CreateUIFrame("EditBox",nil,f,"InputBoxTemplate");f.limit:SetSize(45,24);f.limit:SetPoint("TOPLEFT",355,-131)
        f.limit:SetAutoFocus(false);f.limit:SetNumeric(true);f.limit:SetMaxLetters(1);f.limit:SetText("1")
        f.limit:SetScript("OnEscapePressed",function(e) e:ClearFocus() end)
        local function button(text,x,callback)
            local b=S:CreateUIFrame("Button",nil,f,"UIPanelButtonTemplate");b:SetSize(205,30);b:SetPoint("TOPLEFT",x,-174);b:SetText(text)
            b:SetScript("OnClick",callback);return b
        end
        f.guild=button("Guild Run",22,function() S:ChooseRun("Guild Run") end)
        f.pug=button("PuG Run",245,function() S:ChooseRun("PuG Run",tonumber(f.limit:GetText())) end)
        label("Close or press Escape to cancel without starting a session.",22,-220,425)
    end
    self.runChooser:Show();return true
end

-- The settings Start session button calls Act. Keep demo starts on their existing path.
function A:Act(op,data)
    if op=="start" and not self.demo and not self.guidedGuildStart then return S:ShowRunChooser() end
    return originalAct(self,op,data)
end
-- Also enforce mutual exclusion at the authoritative reducer and both recovery paths.
function A:Reduce(sender,p)
    if type(p)=="table" and p.op=="start" and S.session then return false,"End the PuG Run before starting a Guild Run." end
    return originalReduce(self,sender,p)
end
function A:ResumeSession(...)
    if S.session then self:Print("End the PuG Run before resuming a Guild Run.");return false end
    return originalResume(self,...)
end

StaticPopupDialogs.NAUSE_SR_END_RUN={
    text="End this PuG Soft Reserve run? Reservations and recorded winners will be archived. Item delivery remains manual.",
    button1="End PuG Run",button2="Cancel",timeout=0,whileDead=true,hideOnEscape=true,
    OnAccept=function(dialog)
        if not dialog or not dialog.data or not S:IsHost() or dialog.data.sid~=S.session.id then S:Print("Session changed. Review the active run before ending it.");return end
        local ok,why=S:Command("end");if why then S:Print(why) end
    end,
}
function S:InstallModeControls()
    local u=A.ui
    if not u or self.modeControls==u then return end
    self.modeControls=u
    u.start:SetScript("OnClick",function()
        if S.session then S:Show() else A:Act("start") end
    end)
    u.finish:SetScript("OnClick",function()
        if S:IsHost() then S:ShowConfirmation("NAUSE_SR_END_RUN")
        elseif A.state then A:ReviewEndSession() end
    end)
    if u.settingsPages and u.settingsPages.Tools then
        local status=u.settingsPages.Tools:CreateFontString(nil,"OVERLAY","GameFontNormal")
        status:SetPoint("TOPLEFT",0,-530);status:SetWidth(675);status:SetJustifyH("LEFT");u.runTypeStatus=status
    end
end
function S:RefreshModeControls()
    local u=A.ui;if not u then return end
    local pug=self.session~=nil
    u.start:SetText(pug and "Open PuG session" or "Start session")
    u.start:SetEnabled(A:IsLeader() and not A.state)
    u.finish:SetEnabled(A:IsLeader() and (A.state~=nil or self:IsHost()==true))
    if pug then u.resume:SetEnabled(false) end
    if u.runTypeStatus then u.runTypeStatus:SetText("Run type: "..(pug and "PuG Run — Soft Reserve > MS > OS" or (A.state and "Guild Run — Loot Council" or "choose when starting a session"))) end
end
local originalBuild,originalRender,originalSettings=A.BuildUI,A.Render,A.RenderSettings
function A:BuildUI(...)
    local result=originalBuild(self,...);S:InstallModeControls();S:RefreshModeControls();return result
end
function A:Render(...)
    local result=originalRender(self,...);S:RefreshModeControls();return result
end
function A:RenderSettings(...)
    local result=originalSettings(self,...);S:RefreshModeControls();return result
end
local originalSRRender=S.Render
function S:Render(...)
    originalSRRender(self,...);self:RefreshModeControls()
end
if A.ui then S:InstallModeControls();S:RefreshModeControls() end

-- Guided setup has already selected the guild workflow.
local applySetup=A.ApplyRaidSetupDraft
function A:ApplyRaidSetupDraft(...)
    if S.session then self:Print("End the SoftRes run before applying guild setup.");return false end
    self.guidedGuildStart=true
    local ok,result=pcall(applySetup,self,...)
    self.guidedGuildStart=nil
    if not ok then error(result) end
    return result
end
local showSetup=A.ShowRaidSetup
function A:ShowRaidSetup(...)
    if S.session then self:Print("End the SoftRes run before configuring a guild session.");return false end
    return showSetup(self,...)
end
local restore=A.RestoreSession
function A:RestoreSession(...)
    if S.session then self:Print("End the SoftRes run before restoring a guild session.");return false end
    return restore(self,...)
end
local recover=A.BeginRecovery
function A:BeginRecovery(...)
    if S.session then return false end
    return recover(self,...)
end
