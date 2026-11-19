local _,S=...
local A=S.base
local countdown=S.RenderCountdown
function S:RenderCountdown()
    local r=self.session and self.session.round
    local key=self:CountdownText()..":"..tostring(self:RollKey())..":"..tostring(self.session and self.session.revision)
        ..":"..tostring(self.localRollKey)..":"..tostring(self.localRollCount)..":"..tostring(self.localRollChoice)
        ..":"..tostring(self.rollUI)..":"..tostring(self.leaderRollUI)
    if key==self.countdownPaint then return end
    self.countdownPaint=key;return countdown(self)
end
local lootRender=A.RenderLootWindows
function A:RenderLootWindows(...)
    if not S.session or not self.ui or not self.ui.lootPanels then return lootRender(self,...) end
    local p=self.ui.lootPanels.timer;local timer=self.ui.lootTimers;local partner=self:TradePartner()
    local key=tostring(S.paintSignatures and S.paintSignatures.loot)..":"..tostring(S.session.id)..":"..tostring(self.me)
        ..":"..tostring(S.selectedPugLoot)..":"..tostring(p.page)..":"..p.window:GetWidth()..":"..p.window:GetHeight()
        ..":"..timer.window:GetWidth()..":"..timer.window:GetHeight()..":"..math.floor(self.Client:ServerTime())
        ..":"..tostring(partner)
    if S.lootPaint==key then return end
    S.lootPaint=key;return lootRender(self,...)
end
local ranked=S.RankedRolls
function S:RankedRolls(s,roster)
    local r=s and s.round;if not r then return {} end
    local key=tostring(r.epoch)..":"..#r.attempts..":"..A.Encode(r.passed)..":"..A.Encode(roster)
    if self.rankedRound~=r or self.rankedKey~=key then self.rankedRound=r;self.rankedKey=key;self.rankedCache=ranked(self,s,roster) end
    return self.rankedCache
end
local function awardSignature(s)
    local rows={};for i,h in ipairs(s and s.history or {}) do rows[i]={h.id,h.revision,h.status,h.holder,h.guid,h.winner} end
    return A.Encode(rows)
end
-- Render scopes are evaluated independently. A native roll never rebuilds the
-- reservation catalogue, import preview, award list or trade queue.
local function signature(s,keys)
    local v={};for _,key in ipairs(keys) do v[key]=s and s[key] end;return A.Encode(v)
end
function S:Render()
    local s=self.session;local previous=self.paintSignatures or {};self.paintSignatures=previous
    local identity=s and s.id or "none"
    local function paint(key,value,fn)
        if previous[key]~=value then previous[key]=value;fn() end
    end
    local roster=A.Encode(A.roster or {})
    paint("browser",identity..signature(s,{"locked","limit","reserves","selectedInstances"})..tostring(self.catalogueRevision),function() if self.browser then self:RenderBrowser() end end)
    paint("setup",identity..tostring(self.rosterFilter)..":"..tostring(self.catalogueRevision)..signature(s,{"locked","limit","reserves","selectedInstances"})..roster..tostring(self:IsHost())..tostring(s and s.round~=nil),function() self:RenderSessionSetup() end)
    paint("import",identity..tostring(s and s.revision)..tostring(self:IsHost()),function() if self.importUI and self.importUI:IsShown() then self:RenderImport() end end)
    local r=s and s.round
    local round=identity..tostring(r and r.epoch)..":"..tostring(r and #r.attempts)..":"..tostring(r and r.closed)..":"..tostring(r and r.best)
        ..":"..A.Encode(r and r.passed or {})..":"..roster..":"..tostring(self:IsHost())
    paint("round",round,function() self:RenderRollWindow();self:RenderLeaderRolls() end)
    local awards=awardSignature(s)
    paint("awards",identity..awards..tostring(self:IsHost()),function() if self.awardUI then self:RenderAwardQueue() end end)
    local loot=identity..signature(s,{"lootEntries","pugQueue","autoCollectLoot"})..awards..tostring(self:IsHost())..roster
    paint("loot",loot,function() A:RenderLootWindows() end)
    self:RefreshModeControls();self:RenderCountdown()
end
-- Countdown's own 0.1s ticker remains authoritative for expiry, but redraws
-- occur only when the displayed second or relevant eligibility state changes.
