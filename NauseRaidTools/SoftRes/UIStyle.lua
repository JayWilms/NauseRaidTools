local _, namespace = ...
local S = namespace.SoftRes or namespace
local A=S.base
-- Shared NRT surfaces, typography, scrollbars and window chrome.
local function button(parent)
    local b=CreateFrame("Button",nil,parent,"BackdropTemplate")
    A:StylePanel(b);b:SetBackdropColor(.12,.13,.15,1)
    local t=b:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    t:SetPoint("LEFT",5,0);t:SetPoint("RIGHT",-5,0);t:SetJustifyH("CENTER");t:SetMaxLines(1)
    b:SetFontString(t);b:SetNormalFontObject("GameFontHighlightSmall");b:SetHighlightFontObject("GameFontHighlightSmall");b:SetDisabledFontObject("GameFontDisableSmall")
    b:SetHighlightTexture("Interface/Buttons/WHITE8X8","ADD");b:GetHighlightTexture():SetVertexColor(.35,.39,.45,.18)
    b:SetPushedTexture("Interface/Buttons/WHITE8X8");b:GetPushedTexture():SetVertexColor(.02,.025,.03,.6)
    return b
end
function S:CreateUIFrame(kind,name,parent,template)
    if kind=="ScrollFrame" and template=="UIPanelScrollFrameTemplate" then return A:CreateScrollFrame(parent) end
    if kind=="Button" and template=="UIPanelButtonTemplate" then return button(parent) end
    if kind=="EditBox" and template=="InputBoxTemplate" then
        local e=CreateFrame(kind,name,parent,"BackdropTemplate");A:StylePanel(e);e:SetBackdropColor(.025,.028,.035,1)
        e:SetFontObject("ChatFontNormal");e:SetTextColor(.90,.91,.93);e:SetTextInsets(8,8,0,0);return e
    end
    if template~="BasicFrameTemplateWithInset" then return CreateFrame(kind,name,parent,template) end
    local f=CreateFrame(kind,name,parent,"BackdropTemplate");A:StylePanel(f,34)
    f.title=f:CreateFontString(nil,"OVERLAY","GameFontNormal");f.title:SetTextColor(1,.82,0);f.TitleText=f.title
    f.closeButton=button(f);f.closeButton:SetSize(22,22);f.closeButton:SetPoint("TOPRIGHT",-6,-6)
    f.closeButton:SetScript("OnClick",function() f:Hide() end);A:StyleCrossButton(f.closeButton)
    local identity=name or ("NauseSRTransient"..tostring(f))
    A.allWindowFrames=A.allWindowFrames or {};table.insert(A.allWindowFrames,f)
    if name then
        A.windowFrames=A.windowFrames or {};table.insert(A.windowFrames,{frame=f,name=identity})
    end
    A:InstallWindowChrome(f,identity,function(p,text,x,y,w,fn)
        local b=button(p);b:SetSize(w,22);b:SetPoint("TOPLEFT",x,y);b:SetText(text);b:SetScript("OnClick",fn);return b
    end)
    A:RegisterWindowLayers(f)
    local styledSetScript=f.SetScript
    function f:SetScript(event,fn)
        if event=="OnDragStart" then fn=function(frame) A:BeginWindowMove(frame) end
        elseif event=="OnDragStop" then fn=function(frame) A:FinishWindowMove(frame,identity) end end
        return styledSetScript(self,event,fn)
    end
    f:HookScript("OnShow",function()
        if not f.srLayoutRestored then
            f.srLayoutRestored=true
            local saved=A:WindowLayoutStore()[identity]
            if type(saved)=="table" and type(saved.point)=="string" and type(saved.relativePoint)=="string" and type(saved.x)=="number" and type(saved.y)=="number" and saved.x==saved.x and saved.y==saved.y then
                f:ClearAllPoints();f:SetPoint(saved.point,UIParent,saved.relativePoint,saved.x,saved.y)
            end
            A:ClampWindowPosition(f)
        end
        A:LayoutTitleText(f.title,18,f:GetWidth()-104,34)
        f.nrtHeader:SetWidth(f:GetWidth());A:RefreshWindowChrome(f)
    end)
    f:HookScript("OnHide",function() A:FinishWindowMove(f,identity);A:SaveWindowLayout(f,identity) end)
    -- Native frames start shown. Hide until the caller has set final geometry,
    -- so its first explicit Show runs title/layout restoration at the right size.
    local fontString=f.CreateFontString
    function f:CreateFontString(...)
        local text=fontString(self,...);text:SetTextColor(.90,.91,.93);return text
    end
    f:Hide()
    return f
end
function S:ShowConfirmation(kind,...)
    local definition=StaticPopupDialogs[kind] or A.confirmationDialogs[kind]
    if not definition then return end
    A.confirmationDialogs[kind]=definition
    local dialog=A:ShowConfirmation(kind,...)
    if dialog and kind=="NAUSE_SR_END_RUN" then dialog.data={sid=self.session and self.session.id} end
    if dialog and A.ui and A.ui.confirmation then
        local owner=self.leaderRollUI and self.leaderRollUI:IsShown() and self.leaderRollUI
            or self.sessionSetup and self.sessionSetup:IsShown() and self.sessionSetup
        if owner then
            A.ui.confirmation.nrtDialogOwner=owner;A.ui.confirmation:ClearAllPoints();A.ui.confirmation:SetPoint("CENTER",owner,"CENTER",0,0);A:FocusWindow(A.ui.confirmation)
        end
    end
    return dialog
end
