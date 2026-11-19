local _,S=...
local A=S.base
local function clock()
    if not A.Client:ClockReady() then return end
    local t=A.Client:ServerTime()
    if type(t)=="number" and t==t and t>=0 and t<math.huge then return t end
end
local new=S.New
function S:New(owner,id,limit)
    local s,why=new(self,owner,id,limit)
    if s then local duration=self:DB().rollDuration;s.rollDuration=self.Integer(duration,0,600) and duration or 30 end
    return s,why
end
function S:SetRollDuration(duration)
    if not self:IsHost() then return false,"Only the hosting leader can set the roll timer." end
    if self.session.round then return false,"The current item's timer cannot be changed. Finish or cancel it first." end
    if not self.Integer(duration,0,600) then return false,"Use 1–600 seconds, or 0 for manual closing." end
    self.session.rollDuration=duration;self:DB().rollDuration=duration;self.session.revision=self.session.revision+1;self:Publish();return true
end
local function duration(s) return s.rollDuration==nil and 30 or s.rollDuration end
function S:StampDeadline(session,now)
    local r=session.round;local seconds=duration(session)
    r.startedAt=now;r.duration=seconds;r.deadline=seconds>0 and r.startedAt+seconds or nil;r.closeReason=nil;r.closedAt=nil
end
local start=S.StartRound
function S:StartRound(session,...)
    local seconds=duration(session)
    if not self.Integer(seconds,0,600) then return false,"Invalid roll timer configuration." end
    local now=clock();if not now then return false,"Server clock unavailable; a new roll cannot start." end
    local ok,why=start(self,session,...);if ok then self:StampDeadline(session,now) end;return ok,why
end
local reroll=S.Reroll
function S:Reroll(session)
    local now=clock();if not now then return false,"Server clock unavailable; a tie-break cannot start." end
    local ok,why=reroll(self,session);if ok then self:StampDeadline(session,now) end;return ok,why
end
local close=S.CloseRound
function S:CloseRound(session,roster)
    local r=session.round
    local ok,why=close(self,session,roster)
    if ok then r.closedAt=clock();r.closeReason=r.closeReason or "manual" end
    return ok,why
end
function S:ExpireRound()
    if not self:IsHost() then return false end
    local r=self.session.round
    if not r or r.closed or not r.deadline then return false end
    local now=clock();if not now or now<r.deadline then return false end
    r.closeReason="deadline"
    local ok=self:CloseRound(self.session,A.roster)
    if ok then
        self.session.revision=self.session.revision+1;self:Publish()
        self:Announce("Rolling closed for item "..r.item..". "..(#r.winners==0 and "No eligible rolls." or (#r.winners>1 and "Tie: leader can start a tied-player reroll." or ("Top eligible player: "..r.winners[1].." ("..r.tier.." "..r.best.."). Leader must confirm the award."))))
    end
    return ok
end
local accept=S.AcceptRoll
function S:AcceptRoll(session,...)
    local r=session.round
    if r and r.deadline and not r.closed then
        local now=clock()
        if not now then return false,"Server clock unavailable; timed rolls cannot be accepted." end
        if now>=r.deadline then self:ExpireRound();return false,"The roll deadline has passed." end
    end
    return accept(self,session,...)
end
local handle=S.Handle
function S:Handle(sender,p)
    if type(p)=="table" and p.action=="pass" then
        local r=self.session and self.session.round
        if r and r.deadline then
            local now=clock()
            if not now then return false,"Server clock unavailable." end
            if not r.closed and now>=r.deadline then self:ExpireRound();return false,"The roll deadline has passed." end
        end
    end
    return handle(self,sender,p)
end
local allowance=S.RollAllowance
function S:RollAllowance(choice)
    local r=self.session and self.session.round
    if r and r.deadline then local now=clock();if not now or now>=r.deadline then return 0 end end
    return allowance(self,choice)
end
local valid=S.ValidSnapshot
function S:ValidSnapshot(s)
    if not valid(self,s) then return false end
    if s.rollDuration~=nil and not self.Integer(s.rollDuration,0,600) then return false end
    local r=s.round
    if r then
        if not self.Integer(r.duration,0,600) or type(r.startedAt)~="number" or r.startedAt~=r.startedAt or r.startedAt<0 or r.startedAt>100000000000 then return false end
        if r.duration==0 then if r.deadline~=nil then return false end
        elseif r.deadline~=r.startedAt+r.duration then return false end
    end
    return true
end
function S:CountdownText()
    local r=self.session and self.session.round
    if not r then return "Next item: "..tostring(self.session and duration(self.session) or 30).." seconds (0 = manual)" end
    if r.closed then return r.closeReason=="deadline" and "TIME UP — rolling closed" or "Rolling stopped by leader" end
    if not r.deadline then return "Manual closing — leader uses Stop rolls" end
    local now=clock();if not now then return "Clock unavailable — timer state unconfirmed" end
    local left=math.max(0,math.ceil(r.deadline-now))
    return left==0 and "TIME UP — waiting for leader's closed result" or ("Roll now: "..left.." seconds remaining")
end
function S:RenderCountdown()
    local text=self:CountdownText()
    local round=self.session and self.session.round;local now=clock()
    local role=not round and "muted" or (round.closed and "muted" or (round.deadline and now and round.deadline-now<=10 and "attention" or "body"))
    if self.rollUI then
        if not self.rollUI.countdown then
            local l=self.rollUI:CreateFontString(nil,"OVERLAY","GameFontNormal");l:SetPoint("TOPLEFT",20,-185);l:SetWidth(460);l:SetJustifyH("LEFT");self.rollUI.countdown=l
        end
        self.rollUI.countdown:SetText(text);self:SetTextRole(self.rollUI.countdown,role)
        local r=self.session and self.session.round;local now=clock()
        self.rollUI.ms:SetEnabled(self:RollAllowance("MS")>0 and type(RandomRoll)=="function")
        self.rollUI.os:SetEnabled(self:RollAllowance("OS")>0 and type(RandomRoll)=="function")
        self.rollUI.pass:SetEnabled(r~=nil and not r.closed and not r.passed[A.me] and A.roster[A.me]~=nil and (not r.deadline or (now~=nil and now<r.deadline)))
    end
    local f=self.leaderRollUI
    if f then
        if not f.countdown then
            f:SetHeight(650)
            f.countdown=f:CreateFontString(nil,"OVERLAY","GameFontNormal");f.countdown:SetPoint("TOPLEFT",20,-148);f.countdown:SetWidth(795);f.countdown:SetJustifyH("LEFT")
            local label=f:CreateFontString(nil,"OVERLAY","GameFontNormal");label:SetPoint("TOPLEFT",20,-619);label:SetText("Roll seconds (0 = manual):")
            f.seconds=S:CreateUIFrame("EditBox",nil,f,"InputBoxTemplate");f.seconds:SetPoint("TOPLEFT",245,-612);f.seconds:SetSize(65,24);f.seconds:SetAutoFocus(false);f.seconds:SetNumeric(true);f.seconds:SetMaxLetters(3)
            f.seconds:SetScript("OnEscapePressed",function(e) e:ClearFocus() end)
            f.applyTimer=S:CreateUIFrame("Button",nil,f,"UIPanelButtonTemplate");f.applyTimer:SetPoint("TOPLEFT",330,-612);f.applyTimer:SetSize(180,25);f.applyTimer:SetText("Set for next item")
            f.applyTimer:SetScript("OnClick",function() local ok,why=S:SetRollDuration(tonumber(f.seconds:GetText()));if why then S:Print(why) end end)
            local note=f:CreateFontString(nil,"OVERLAY","GameFontNormalSmall");note:SetPoint("TOPLEFT",530,-620);note:SetText("Active deadlines cannot be extended.");S:SetTextRole(note,"muted")
        end
        f.countdown:SetText(text);self:SetTextRole(f.countdown,role)
        local r=self.session and self.session.round;local now=clock()
        f.ms:SetEnabled(self:RollAllowance("MS")>0 and type(RandomRoll)=="function")
        f.os:SetEnabled(self:RollAllowance("OS")>0 and type(RandomRoll)=="function")
        f.pass:SetEnabled(r~=nil and not r.closed and not r.passed[A.me] and A.roster[A.me]~=nil and (not r.deadline or (now~=nil and now<r.deadline)))
        f.stop:SetEnabled(self:IsHost() and r~=nil and not r.closed)
        local active=self.session and self.session.round~=nil
        f.seconds:SetEnabled(self:IsHost() and not active);f.applyTimer:SetEnabled(self:IsHost() and not active)
        if f.seconds:HasFocus()~=true then f.seconds:SetText(tostring(self.session and duration(self.session) or 30)) end
    end
end
local render=S.Render
function S:Render(...) render(self,...);self:RenderCountdown() end
local tableRender=S.RenderLeaderRolls
function S:RenderLeaderRolls(...) tableRender(self,...);self:RenderCountdown() end
local promptRender=S.RenderRollWindow
function S:RenderRollWindow(...) promptRender(self,...);self:RenderCountdown() end
local ticker=S:CreateUIFrame("Frame");S.countdownTicker=ticker
local elapsed=0
ticker:SetScript("OnUpdate",function(_,dt)
    elapsed=elapsed+dt;if elapsed<0.1 then return end;elapsed=0
    S:ExpireRound();S:RenderCountdown()
end)
