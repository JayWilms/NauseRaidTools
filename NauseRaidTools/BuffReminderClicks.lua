local _,A=...
local function number(v) return type(v)=="number" and v==v and math.abs(v)<1000000 end
function A:BuffReminderClickBinding(target,key)
    local unit=target.unit
    if type(unit)~="string" or not (unit=="player" or unit:match("^party[1-4]$") or unit:match("^raid%d+$")) or self:Name(unit)~=target.name then return end
    local definition;for _,def in ipairs(self.raidCheckDefinitions) do if def.key==key then definition=def;break end end
    if not definition or not definition.provider then return end
    local id=(definition.nameIDs or definition.ids)[1]
    local ok,spell=self.Client:Call("C_Spell.GetSpellName",id)
    if not ok then ok,spell=self.Client:Call("GetSpellInfo",id) end
    if not ok or type(spell)~="string" or spell=="" or spell:find("[|%c]") then return end
    -- A secure macro supplies the combat guard independently of addon event timing.
    return {unit=unit,name=target.name,spell=spell,macro="/cast [nocombat,@"..unit..",help,nodead] "..spell}
end
function A:HideBuffReminderClicks()
    if self.Client:Combat() then return end
    local host=self.buffReminderClickHost;if not host then return end
    self.Client:Call("UnregisterStateDriver",host,"visibility")
    for _,button in ipairs(host.buttons) do button:SetAttribute("type1",nil);button:SetAttribute("macrotext1",nil);button:Hide() end
    host:Hide();self.buffReminderClickGeometry=nil
end
function A:PositionBuffReminderClicks()
    if self.Client:Combat() or self.buffReminderPositioning then return end
    local f=self.ui and self.ui.buffReminders
    if not f or not f:IsShown() or f.nrtCollapsed==true or not self:BuffRemindersAllowed() then self:HideBuffReminderClicks();return end
    if type(self.Client:Get("RegisterStateDriver"))~="function" or type(self.Client:Get("UnregisterStateDriver"))~="function" or type(self.Client:Get("C_Macro.RunMacroText"))~="function" then self:HideBuffReminderClicks();return end
    local left,top=f.scroll:GetLeft(),f.scroll:GetTop();local scale=f:GetEffectiveScale()/UIParent:GetEffectiveScale()
    if not number(left) or not number(top) or not number(scale) or scale<=0 then return end
    local board=self:AssignmentBoard();if not board or board.epoch~=f.reportEpoch or board.revision~=f.reportRevision then self:HideBuffReminderClicks();return end
    local geometry=table.concat({left,top,f:GetWidth(),f:GetHeight(),f.scroll:GetWidth(),f.scroll:GetHeight(),f.scroll:GetVerticalScroll(),f:GetFrameLevel(),scale,board.epoch,board.revision},":")
    if geometry==self.buffReminderClickGeometry then return end
    self.buffReminderPositioning=true
    local host=self.buffReminderClickHost
    if not host then
        -- Independent secure root: never parent or anchor protected actions to an NRT window.
        -- Absolute positions are updated only out of combat, so normal window chrome stays unprotected.
        local ok,frame=pcall(CreateFrame,"Frame","NauseRaidToolsBuffClickHost",UIParent,"SecureHandlerStateTemplate")
        if not ok then self.buffReminderPositioning=nil;return end
        host=frame;host.buttons={};host:EnableMouse(false);self.buffReminderClickHost=host
    end
    local ok,result=self.Client:Call("RegisterStateDriver",host,"visibility","[combat] hide; show")
    if not ok or result==false then self.buffReminderPositioning=nil;return end
    host:SetFrameStrata(f:GetFrameStrata());host:SetFrameLevel(f:GetFrameLevel()+80)
    local viewportBottom=top-f.scroll:GetHeight();local count=0
    for _,visual in ipairs(f.rows) do
        local binding=visual.binding
        if visual:IsShown() and binding then
            local rowTop=visual:GetTop();local height=visual:GetHeight()
            if number(rowTop) and rowTop<=top+.1 and rowTop-height>=viewportBottom-.1 then
                count=count+1;local button=host.buttons[count]
                if not button then
                    local created;created,button=pcall(CreateFrame,"Button",nil,host,"SecureActionButtonTemplate")
                    if not created then break end
                    host.buttons[count]=button;button:RegisterForClicks("LeftButtonUp");button:SetAttribute("useOnKeyDown",false)
                    button:EnableMouseWheel(true);button:SetScript("OnMouseWheel",function(_,delta)
                        if not A.Client:Combat() then f.scroll:GetScript("OnMouseWheel")(f.scroll,delta);A.buffReminderClickGeometry=nil;A:PositionBuffReminderClicks() end
                    end)
                    button:SetHighlightTexture("Interface/Buttons/WHITE8X8");button:GetHighlightTexture():SetVertexColor(.25,.28,.32,.3)
                    button:SetScript("PreClick",function(b)
                        if A.Client:Combat() then return end
                        local current=A:AssignmentBoard()
                        if not A:BuffRemindersAllowed() or not current or current.epoch~=b.boardEpoch or current.revision~=b.boardRevision or A:Name(b.nativeUnit)~=b.targetName then
                            b:SetAttribute("type1",nil);b:SetAttribute("macrotext1",nil)
                        end
                    end)
                end
                button.nativeUnit=binding.unit;button.targetName=binding.name;button.boardEpoch=board.epoch;button.boardRevision=board.revision
                button:SetAttribute("unit",binding.unit);button:SetAttribute("type1","macro");button:SetAttribute("macrotext1",binding.macro)
                button:SetFrameStrata(f:GetFrameStrata());button:SetFrameLevel(f:GetFrameLevel()+81)
                button:ClearAllPoints();button:SetPoint("TOPLEFT",UIParent,"TOPLEFT",left*scale,-UIParent:GetHeight()+rowTop*scale)
                button:SetSize(f.scroll:GetWidth()*scale,height*scale);button:Show()
            end
        end
    end
    for index=count+1,#host.buttons do local b=host.buttons[index];b:SetAttribute("type1",nil);b:SetAttribute("macrotext1",nil);b:Hide() end
    host:Show();self.buffReminderClickGeometry=geometry;self.buffReminderPositioning=nil
end
