local _, namespace = ...
local S = namespace.SoftRes or namespace
local A=S.base
local function label(parent,text,x,y)
    local l=parent:CreateFontString(nil,"OVERLAY","GameFontNormal");l:SetPoint("TOPLEFT",x,y);l:SetText(text);return l
end
local function box(parent,w,h,x,y,multi)
    local e=S:CreateUIFrame("EditBox",nil,parent,"InputBoxTemplate");e:SetSize(w,h);e:SetPoint("TOPLEFT",x,y);e:SetAutoFocus(false)
    e:SetMultiLine(multi or false);e:SetFontObject("ChatFontNormal");e:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
    return e
end
local function button(parent,text,x,y,w,fn)
    local b=S:CreateUIFrame("Button",nil,parent,"UIPanelButtonTemplate");b:SetSize(w or 100,24);b:SetPoint("TOPLEFT",x,y);b:SetText(text)
    b:SetScript("OnClick",function() local ok,why=fn();if why then S:Print(why) end;S:Render() end);return b
end
local function run(cmd) return function() return S:Command(cmd) end end
function S:Show()
    if not self.ui then
        local f=S:CreateUIFrame("Frame","NauseSRExperimentalWindow",UIParent,"BasicFrameTemplateWithInset");self.ui=f
        f:SetSize(760,620);f:SetPoint("CENTER");f:SetMovable(true);f:EnableMouse(true);f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart",f.StartMoving);f:SetScript("OnDragStop",f.StopMovingOrSizing)
        if f.TitleText then f.TitleText:SetText("Nause Raid Tools - SoftRes") end
        if UISpecialFrames then table.insert(UISpecialFrames,"NauseSRExperimentalWindow") end
        f.status=label(f,"",18,-38)
        label(f,"Reserves per player (1–6)",18,-66);f.limit=box(f,40,24,190,-62);f.limit:SetText("1")
        button(f,"New session",245,-62,105,function() return self:Command("new "..f.limit:GetText()) end)
        button(f,"Sync",355,-62,70,run("sync"));button(f,"Lock",430,-62,70,run("lock"));button(f,"Unlock",505,-62,70,run("unlock"))
        label(f,"My reservations: item IDs separated by spaces; repeat an ID to stack",18,-101)
        f.picks=box(f,500,24,22,-121)
        button(f,"Submit picks",540,-121,110,function() local ok,why=self:Command("reserve "..f.picks:GetText());return ok,why or (ok and "Picks submitted.") end)
        label(f,"Softres.it → Gargul export (paste below; leader only)",18,-157)
        local scroll=S:CreateUIFrame("ScrollFrame",nil,f,"UIPanelScrollFrameTemplate");scroll:SetSize(690,65);scroll:SetPoint("TOPLEFT",20,-178)
        f.import=S:CreateUIFrame("EditBox",nil,scroll);f.import:SetSize(680,65);f.import:SetMultiLine(true);f.import:SetFontObject("ChatFontNormal");f.import:SetAutoFocus(false);f.import:SetMaxLetters(65536);scroll:SetScrollChild(f.import)
        f.import:SetScript("OnEscapePressed",function(e) e:ClearFocus() end)
        button(f,"Preview",20,-250,100,function()
            if not self:IsHost() then return false,"Only the hosting raid leader can import." end
            local preview,why=self:Preview(f.import:GetText(),self.session,function(name) return A:Resolve(name) end)
            self.preview=preview;return preview~=nil,why
        end)
        button(f,"Apply preview",125,-250,120,function()
            if not self:IsHost() then return false,"Only the hosting raid leader can import." end
            local ok,why=self:ApplyPreview(self.session,self.preview)
            if ok then self.preview=nil;f.import:SetText("");self:Publish() end;return ok,why
        end)
        button(f,"Clear preview",250,-250,120,function() self.preview=nil;return true end)
        label(f,"Item ID",390,-256);f.item=box(f,110,24,445,-250)
        button(f,"Add item",565,-250,100,function() return self:Command("roll "..f.item:GetText()) end)
        button(f,"Pass",20,-282,70,run("pass"));button(f,"Close rolls",95,-282,95,run("close"));button(f,"Tie reroll",195,-282,90,run("reroll"))
        button(f,"Roll table",290,-282,90,function() self:RenderLeaderRolls(true);return true end);button(f,"Record winner",385,-282,120,run("record"));button(f,"Cancel item",510,-282,100,run("cancel"))
        local out=S:CreateUIFrame("ScrollFrame",nil,f,"UIPanelScrollFrameTemplate");out:SetSize(690,235);out:SetPoint("TOPLEFT",20,-320)
        local child=S:CreateUIFrame("Frame",nil,out);child:SetSize(675,235);out:SetScrollChild(child)
        f.output=label(child,"",0,0);f.output:SetWidth(670);f.output:SetJustifyH("LEFT");f.output:SetJustifyV("TOP");f.outputParent=child
        button(f,"Resume saved",20,-578,120,run("resume"));button(f,"End session",145,-578,110,run("end"))
        label(f,"Experimental roll records only. Deliver loot manually.",280,-584)
    end
    self.ui:Show();self:Render()
end
function S:Render()
    local f=self.ui;if not f then return end
    local s=self.session
    f.status:SetText(s and ("Host: "..self:DisplayPlayerName(s.owner).." | "..(s.locked and "LOCKED" or "OPEN").." | "..s.limit.." SR/player | revision "..s.revision) or "No SR session. Leader: New session. Raiders: Sync.")
    local lines={}
    if self.preview then
        lines[#lines+1]="IMPORT PREVIEW — Apply replaces picks for listed players only:"
        for _,row in ipairs(self.preview.rows) do
            local ids={};for _,id in ipairs(row.items) do ids[#ids+1]=tostring(id) end
            lines[#lines+1]=row.player..": "..table.concat(ids,", ")..(row.replaces and " [REPLACES EXISTING PICKS]" or " [new]")
        end
        for _,issue in ipairs(self.preview.issues) do lines[#lines+1]="BLOCKED: "..issue end
        lines[#lines+1]=""
    end
    if s then
        local r=s.round
        if r then
            lines[#lines+1]="ITEM "..r.item.." | "..r.tier..(r.tiebreak and " tie-break" or "").." | "..(r.closed and "CLOSED" or ("ROLL NOW: /roll "..(r.tier=="OS" and 99 or 100)))
            local names={};for name in pairs(r.eligible) do names[#names+1]=name end;table.sort(names)
            for _,name in ipairs(names) do lines[#lines+1]="Eligible: "..name.." ("..r.eligible[name].." roll(s))" end
            names={};for name in pairs(r.rolls) do names[#names+1]=name end;table.sort(names)
            for _,name in ipairs(names) do local rolls={};for _,v in ipairs(r.rolls[name]) do rolls[#rolls+1]=tostring(v) end;lines[#lines+1]=self:DisplayPlayerName(name)..": "..table.concat(rolls,", ") end
            if r.closed then lines[#lines+1]=#r.winners==0 and "No eligible winner." or ((#r.winners>1 and "TIE: " or "WINNER: ")..table.concat(A.DisplayNames and A:DisplayNames(r.winners) or r.winners,", ").." — "..r.best) end
            lines[#lines+1]=""
        end
        lines[#lines+1]="RAID RESERVATIONS (item IDs; x copies grant x SR rolls):"
        local names={};for name in pairs(s.reserves) do names[#names+1]=name end;table.sort(names)
        for _,name in ipairs(names) do
            local ids={};for _,id in ipairs(s.reserves[name]) do ids[#ids+1]=tostring(id) end
            lines[#lines+1]=self:DisplayPlayerName(name)..": "..(#ids>0 and table.concat(ids,", ") or "none")..(A.roster[name] and "" or " [not in raid]")
        end
        for name in pairs(A.roster) do if not s.reserves[name] then lines[#lines+1]="Missing picks: "..self:DisplayPlayerName(name) end end
        lines[#lines+1]="";lines[#lines+1]="RECENT WINNERS (recorded results; delivery not verified):"
        for i=#s.history,math.max(1,#s.history-9),-1 do local h=s.history[i];lines[#lines+1]=self:DisplayPlayerName(h.winner).." — item "..h.item.." — "..h.tier.." — "..h.roll end
    end
    f.output:SetText(table.concat(lines,"\n"));f.outputParent:SetHeight(math.max(235,f.output:GetStringHeight()+10))
end
if GameTooltip and GameTooltip.HookScript then
    pcall(GameTooltip.HookScript,GameTooltip,"OnTooltipSetItem",function(tip)
        if not S.session then return end
        local _,link=tip:GetItem();local id=link and tonumber(link:match("item:(%d+)"))
        if id then local names=S:Reservers(id);if #names>0 then tip:AddLine("Nause SR: "..table.concat(A.DisplayNames and A:DisplayNames(names) or names,", "),1,0.8,0.3,true);tip:Show() end end
    end)
end
