local baseline,companion=...
local client=assert(loadfile(companion.."/qa/softres/alpha55_client.lua"))(baseline)
local function patchEnvironment(env)
local create=env.CreateFrame
env.CreateFrame=function(...)
    local f=create(...)
    f.Show=function(self)
        local was=self:IsShown();self._shown=true
        local scripts=rawget(self,"_scripts");if not was and scripts and scripts.OnShow then scripts.OnShow(self) end
    end
    f.Hide=function(self)
        local was=self:IsShown();self._shown=false
        local scripts=rawget(self,"_scripts");if was and scripts and scripts.OnHide then scripts.OnHide(self) end
    end
    f.GetScript=function(self,event) local scripts=rawget(self,"_scripts");return scripts and scripts[event] end
    f.GetVerticalScroll=function(self) return rawget(self,"_offset") or 0 end
    f.SetVerticalScroll=function(self,value) self._offset=value end
    f.GetStringWidth=function(self) return #self:GetText()*6 end
    f.GetFrameLevel=function() return 10 end
    f.GetFrameStrata=function() return "DIALOG" end
    f.countdown=false;f.srWinner=false;f.srTrade=false;f.nrtMoving=false;f.nrtResizing=false;f.nrtCollapsed=false;f.resizeGrip=false
    return f
end
env.UIParent.GetWidth=function() return 1920 end
env.UIParent.GetHeight=function() return 1080 end
env.UIParent.GetEffectiveScale=function() return 1 end
env.GetCursorPosition=function() return 500,500 end
env.IsMouseButtonDown=function() return false end
env.RANDOM_ROLL_RESULT="%s rolls %d (%d-%d)"
env.RandomRoll=function() end
end

return function(name)
 local a,env=client(name);patchEnvironment(env);env._G=env;a.ShowConfirmation=a.RealShowConfirmation
 local s={}
 for line in io.lines(companion.."/NauseRaidTools/NauseRaidTools.toc") do
  if line:match("^SoftRes/.*%.lua$") then assert(loadfile(companion.."/NauseRaidTools/"..line,"t",env))("NauseRaidTools",a) end
 end
 return a,env,a.SoftRes
end
