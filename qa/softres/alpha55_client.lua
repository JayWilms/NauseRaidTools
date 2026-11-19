local root = ... .. "/NauseRaidTools/"
local checked = 0
local function check(condition, message)
    checked = checked + 1
    assert(condition, message)
end
local function client(name)
    local env = setmetatable({}, {__index = _G})
    local fake = {}
    local fakeMeta
    fakeMeta = {__index = function(_, k)
        if not k:match("^[A-Z]") then return nil end
        return function(self, value, second, third, fourth, fifth)
            if k == "GetChildren" or k == "GetRegions" then
                local result={}
                for _,o in ipairs(rawget(self,k=="GetChildren" and "_children" or "_regions") or {}) do
                    if rawget(o,"_parent")==self then result[#result+1]=o end
                end
                return table.unpack(result)
            end
            if k == "GetObjectType" then return rawget(self,"_kind") or "Frame" end
            if k == "GetDrawLayer" then return rawget(self,"_layer") or "ARTWORK" end
            if k == "CreateTexture" or k == "CreateFontString" then
                local o=setmetatable({_parent=self,_kind=k=="CreateTexture" and "Texture" or "FontString",_layer=second},fakeMeta)
                self._regions=rawget(self,"_regions") or {};table.insert(self._regions,o);return o
            end
            if k == "SetBackdrop" then self._backdrop=value;return end
            if k == "GetBackdrop" then return rawget(self,"_backdrop") end
            if k == "SetSize" then self._width,self._height=value,second;return end
            if k == "SetWidth" then self._width=value;return end
            if k == "SetHeight" then self._height=value;return end
            if k == "GetWidth" then return rawget(self,"_width") or 1920 end
            if k == "GetHeight" then return rawget(self,"_height") or 1080 end
            if k == "SetScrollChild" then self._scrollChild=value;return end
            if k == "GetVerticalScrollRange" then
                local child=rawget(self,"_scrollChild")
                return math.max(0,(child and rawget(child,"_height") or 0)-self:GetHeight())
            end
            if k == "GetScale" or k == "GetEffectiveScale" then return rawget(self,"_scale") or 1 end
            if k == "SetScale" then self._scale=value;return end
            if k == "GetLeft" then return 100 end
            if k == "GetTop" then return 900 end
            if k == "SetPoint" then self._point={value,second,third,fourth,fifth};return end
            if k == "GetPoint" then
                local point=rawget(self,"_point") or {"CENTER"}
                if type(point[2])=="number" then return point[1],rawget(self,"_parent"),point[1],point[2],point[3] end
                if #point==1 then return point[1],rawget(self,"_parent"),point[1],0,0 end
                return table.unpack(point,1,5)
            end
            if k == "SetColorTexture" then self._color={value,second,third,fourth};return end
            if k == "HookScript" then
                self._scripts=rawget(self,"_scripts") or {};local before=self._scripts[value]
                self._scripts[value]=function(...) if before then before(...) end;second(...) end;return
            end
            if k == "SetScript" then self._scripts = rawget(self, "_scripts") or {}; self._scripts[value] = second; return end
            if k == "RegisterEvent" then self._events = rawget(self, "_events") or {}; self._events[value] = true; return end
            if k == "GetText" then return rawget(self,"_text") or "" end
            if k == "SetText" then self._text = value; return end
            if k == "Show" then self._shown = true; return end
            if k == "Hide" then self._shown = false; return end
            if k == "SetShown" then self._shown = value; return end
            if k == "IsShown" then return self._shown == true end
            if k == "SetParent" then
                self._parent=value
                if value then
                    local list=(rawget(self,"_kind")=="Texture" or rawget(self,"_kind")=="FontString") and "_regions" or "_children"
                    value[list]=rawget(value,list) or {};table.insert(value[list],self)
                end
                return
            end
            if k == "SetEnabled" then self._enabled = value; return end
            if k == "IsEnabled" then return self._enabled~=false end
            if k == "SetValue" then self._value = value; return end
            if k == "SetMinMaxValues" then self._min, self._max = value, second; return end
            if k == "SetStatusBarColor" then self._color = {value, second, third}; return end
            if k == "GetStringHeight" then return 20 end
            return setmetatable({}, fakeMeta)
        end
    end}
    setmetatable(fake, fakeMeta)
    env.CreateFrame = function(_,name,parent)
        local f=setmetatable({_parent=parent,_kind="Frame"},fakeMeta)
        if parent then parent._children=rawget(parent,"_children") or {};table.insert(parent._children,f) end
        return f
    end
    env.CreateFont = function() return setmetatable({},fakeMeta) end
    env.DEFAULT_CHAT_FRAME = {AddMessage = function() end}
    env.GetServerTime = function() return 1793180000 end
    env.GetTime = function() return 100 end
    env.IsInRaid = function() return true end
    env.InCombatLockdown = function() return false end
    env.C_Timer = {After = function() end}
    env.C_ChatInfo = {RegisterAddonMessagePrefix = function() end, SendAddonMessage = function() end}
    env.StaticPopupDialogs, env.UISpecialFrames, env.SlashCmdList = {}, {}, {}
    env.UIParent = fake
    env.STANDARD_TEXT_FONT = "font"
    env.NauseRaidToolsDB = {history = {}}
    env.date = os.date
    env.StaticPopup_Show = function() return {} end
    local a = {}
    for file in io.lines(root.."NauseRaidTools.toc") do
        if file:match("%.lua$") then assert(loadfile(root..file,"t",env))("NauseRaidTools",a) end
    end
    a.RealShowConfirmation=a.ShowConfirmation
    a.ShowConfirmation=function(self,...) return env.StaticPopup_Show(...) end
    env.StaticPopupDialogs=a.confirmationDialogs
    a:InitStorage()
    a.me, a.leader = name, "Leader-Realm"
    a.roster = {["Leader-Realm"] = true, ["Master-Realm"] = true, ["Council-Realm"] = true, ["Raider-Realm"] = true}
    a.sent = {}
    a.WireSend=a.Send
    a.Send = function(self, packet, target)
        packet.protocol = a.protocol
        self.sent[#self.sent + 1] = {packet = a.Decode(a.Encode(packet)), target = target}
    end
    return a, env
end

return client
