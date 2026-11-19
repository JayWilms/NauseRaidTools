local _,S=...
local A=S.base
local render=A.RenderLootTimers

local active=false

-- Reuse the LC renderer against a view; never manufacture council session state.
function S:TimerLootView()
    local entries,awards={},{}
    local byGUID={}
    for _,h in ipairs(self.session.history or {}) do
        if h.status~="cancelled" and h.holder and h.guid then byGUID[h.holder..":"..h.guid]=h end
    end
    for _,entry in ipairs(self.session.lootEntries or {}) do
        local h=self:LootAward(entry)
        if not h then
            local matched=byGUID[entry.holder..":"..entry.guid]
            if matched and matched.item==tonumber(entry.link:match("item:(%d+)")) then h=matched end
        end
        if h then awards[h.id]=true end
        if not h or h.status~="delivered" then
            local view=A.Copy(entry);view.srAward=h and h.id
            entries[#entries+1]=view
        end
    end
    -- Manually entered items also remain visible while awaiting a holder/trade.
    for i,h in ipairs(self.session.history or {}) do
        if h.status=="pending" and not awards[h.id] then
            entries[#entries+1]={id=10000+i,link="|cffa335ee|Hitem:"..h.item.."::::::::|h[Item "..h.item.."]|h|r",holder=h.holder,guid=h.guid,kind="unknown",srAward=h.id}
        end
    end
    table.sort(entries,function(a,b) return a.id<b.id end)
    return entries
end

function S:LayoutSharedTimer()
    local p=A.ui and A.ui.lootTimers;if not p then return end
    for _,row in ipairs(p.rows) do
        if row.srWinner then
            -- Expanded SR rows have two item lines; keep the caption above its status.
            row.caption:ClearAllPoints()
            row.caption:SetPoint("TOPLEFT",p.compact and 34 or 46,p.compact and -7 or (self.session and -5 or -13))
            row.srWinner:ClearAllPoints()
            row.srWinner:SetPoint("TOPLEFT",row.caption,"BOTTOMLEFT",0,-2)
            row.srWinner:SetHeight(14)
            row.srWinner:SetWidth(row.caption:GetWidth())
            row.holderStatus:SetShown(not p.compact and not self.session)
            row.srTrade:ClearAllPoints();row.srTrade:SetPoint("TOPLEFT",row.holder,"BOTTOMLEFT",0,-1)
            row.srTrade:SetWidth(math.min(70,row.holder:GetWidth()))
        end
    end
end
local layout=A.LayoutLootTimer
function A:LayoutLootTimer(...)
    local result=layout(self,...);S:LayoutSharedTimer();return result
end
function A:RenderLootTimers()
    local p=self.ui and self.ui.lootTimers;if not p then return end
    if not S.session then
        if active then
            for _,row in ipairs(p.rows) do if row.srWinner then row.srWinner:Hide();row.srTrade:Hide();row.holderStatus:SetShown(not p.compact) end end
            active=false
            S:LayoutSharedTimer()
        end
        return render(self)
    end
    active=true
    local entries=S:TimerLootView()
    local view=setmetatable({state={id="pug:"..S.session.id,trackedLoot=entries,items={}}},{__index=self})
    render(view)
    local byID={};for _,e in ipairs(entries) do byID[e.id]=e end
    for _,row in ipairs(p.rows) do
        if not row.srWinner then
            row.srWinner=row:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
            row.srWinner:SetJustifyH("LEFT");row.srWinner:SetMaxLines(1);row.srWinner:SetWordWrap(false)
            row.srTrade=S:CreateUIFrame("Button",nil,row,"UIPanelButtonTemplate");row.srTrade:SetSize(65,18)
        end
        local entry=byID[row.tracked];local h=entry and entry.srAward and S:AwardByID(entry.srAward)
        row.srWinner:SetShown(entry~=nil and not p.compact)
        row.srWinner:SetText(self:FitTimerItemName(h and ("Winner: "..self:DisplayName(h.winner)) or "Awaiting award",row.measure,row.caption:GetWidth()))
        row.srTrade:SetShown(h~=nil and not p.compact)
        row.srTrade:SetText(h and h.holder==h.winner and "Held" or (h and self:TradePartner()==h.winner and "Offer" or "Trade"))
        row.srTrade:SetEnabled(h~=nil and h.status=="pending" and h.holder==self.me and h.guid~=nil and h.winner~=self.me)
        local sid,id,revision,guid=S.session.id,h and h.id,h and h.revision,h and h.guid
        row.srTrade:SetScript("OnClick",function()
            local award=S:AwardByID(id)
            if not S.session or S.session.id~=sid or not award or award.revision~=revision or award.guid~=guid then S:Print("Award changed. Review the Timer window again.");return end
            local ok,why=S:TradeAward(award,A:TradePartner()==award.winner);if why then S:Print(why) end
        end)
    end
    S:LayoutSharedTimer()
end
local windows=A.RenderLootWindows
function A:RenderLootWindows(...)
    local result=windows(self,...);if S.session then self:RenderLootTimers() end;return result
end
