local _,A=...
local function trim(s) return type(s)=="string" and s:match("^%s*(.-)%s*$") or "" end
local function yes(v) return v==true or v==1 end
function A:AutoInviteSettings()
    self:InitStorage()
    local all=NauseRaidToolsDB.autoInviteSettings
    if type(all)~="table" then all={};NauseRaidToolsDB.autoInviteSettings=all end
    local owner=self:Name("player") or self.me or "local"
    local saved=type(all[owner])=="table" and all[owner] or {}
    local keyword=trim(saved.keyword):lower()
    if #keyword<1 or #keyword>32 or keyword:find("[%s|%c]") then keyword="inv" end
    return {enabled=saved.enabled==true,keyword=keyword,guildOnly=saved.guildOnly~=false,convert=saved.convert==true},owner
end
function A:SetAutoInviteSetting(key,value)
    local settings,owner=self:AutoInviteSettings()
    if key=="keyword" then
        value=trim(value):lower()
        if #value<1 or #value>32 or value:find("[%s|%c]") then self:Print("Invite keyword must be one word, from 1 to 32 characters.");return false end
    elseif (key~="enabled" and key~="guildOnly" and key~="convert") or type(value)~="boolean" then return false end
    settings[key]=value;NauseRaidToolsDB.autoInviteSettings[owner]=settings
    self.autoInviteGuildCache=nil
    local state=self.autoInviteState
    if state then state.queue={};state.converting=nil;state.convertBlocked=nil;state.status=nil end
    if settings.enabled and settings.guildOnly then self.Client:Call("GuildRoster") end
    if self.RenderSettings then self:RenderSettings() end
    return true
end
function A:AutoInviteIdentity(name)
    if type(name)~="string" or #name==0 or #name>100 or name:find("[|%c]") then return end
    if self:IsForever() then name=name:gsub("^([^%s%-]+)%s+([^%s%-]+)$","%1-%2") end
    if name:find("%s") then return end
    if not name:find("-",1,true) then
        if self:IsForever() then return end
        local ok,realm=self.Client:Call("GetNormalizedRealmName")
        if not ok or type(realm)~="string" or realm=="" then return end
        name=name.."-"..realm
    end
    return name,name:lower()
end
function A:AutoInviteInGuild(name)
    local _,wanted=self:AutoInviteIdentity(name);if not wanted then return false end
    if type(self.Client:Get("GetNumGuildMembers"))~="function" or type(self.Client:Get("GetGuildRosterInfo"))~="function" then return false end
    local now=self.Client:Uptime();local cached=self.autoInviteGuildCache
    if cached and now<cached.expires then return cached.names[wanted]==true end
    local ok,count=self.Client:Call("GetNumGuildMembers")
    if not ok or type(count)~="number" or count%1~=0 or count<0 or count>1000 then return false end
    local names={}
    for index=1,count do
        local read,member=self.Client:Call("GetGuildRosterInfo",index)
        local _,key=self:AutoInviteIdentity(member)
        if read and key then names[key]=true end
    end
    self.autoInviteGuildCache={names=names,expires=now+1}
    return names[wanted]==true
end
function A:AutoInviteContext()
    local main=self.ui and self.ui.assignments;local personal=self.ui and self.ui.myAssignments
    if self.demo or self.groupTest or (self.assignmentBoard and self.assignmentBoard.test) or (main and main:IsShown() and main.practice) or (personal and personal:IsShown() and personal.practice) then return nil,"Paused during testing." end
    local groupOK=self.Client:Call("IsInGroup");local raidOK=self.Client:Call("IsInRaid")
    if not groupOK or not raidOK then return nil,"Group roster unavailable." end
    local grouped=self.Client:InGroup();local raid=self.Client:InRaid();local count=1
    if grouped then
        local ok,value=self.Client:Call("GetNumGroupMembers")
        if not ok or type(value)~="number" or value%1~=0 or value<1 or value>(raid and 40 or 5) then return nil,"Group roster unavailable." end
        count=value
    end
    local ok,leader=self.Client:Call("UnitIsGroupLeader","player");leader=ok and yes(leader)
    local canInvite=not grouped or leader
    if raid and not canInvite then local available,assistant=self.Client:Call("UnitIsGroupAssistant","player");canInvite=available and yes(assistant) end
    if not canInvite then return nil,"Requires group leader or raid assistant." end
    local members={}
    for i=0,(grouped and (raid and count or count-1) or 0) do
        local unit=i==0 and "player" or ((raid and "raid" or "party")..i)
        local _,key=self:AutoInviteIdentity(self:Name(unit));if key then members[key]=true end
    end
    return {count=count,raid=raid,leader=leader,members=members}
end
function A:AutoInviteState()
    local owner=self:Name("player") or self.me
    if not self.autoInviteState or self.autoInviteState.owner~=owner then
        self.autoInviteState={owner=owner,queue={},pending={},recent={},nextSend=0,nextConvert=0}
    end
    return self.autoInviteState
end
function A:HandleAutoInviteWhisper(message,sender)
    local settings=self:AutoInviteSettings()
    if not settings.enabled or type(message)~="string" or #message>64 or trim(message):lower()~=settings.keyword then return false end
    local context=self:AutoInviteContext();if not context then return false end
    local name,key=self:AutoInviteIdentity(sender);if not key or context.members[key] then return false end
    if settings.guildOnly and not self:AutoInviteInGuild(name) then return false end
    local state=self:AutoInviteState();local now=self.Client:Uptime()
    if (state.recent[key] or 0)>now or #state.queue>=40 or context.count>=40 then return false end
    if not context.raid and context.count>=5 and not settings.convert then return false end
    state.recent[key]=now+30;state.queue[#state.queue+1]={name=name,key=key,expires=now+60}
    self:PumpAutoInvites();return true
end
function A:PumpAutoInvites()
    local settings=self:AutoInviteSettings();local state=self:AutoInviteState();local now=self.Client:Uptime()
    for key,expires in pairs(state.recent) do if expires<=now then state.recent[key]=nil end end
    if not settings.enabled then state.queue={};state.converting=nil;state.status="Off";return end
    local context,reason=self:AutoInviteContext()
    if not context then state.queue={};state.converting=nil;state.status=reason;return end
    local pending=0
    for key,expires in pairs(state.pending) do
        if expires<=now or context.members[key] then state.pending[key]=nil else pending=pending+1 end
    end
    for i=#state.queue,1,-1 do
        local entry=state.queue[i]
        if entry.expires<=now or context.members[entry.key] or state.pending[entry.key] or (settings.guildOnly and not self:AutoInviteInGuild(entry.name)) then table.remove(state.queue,i) end
    end
    if self.Client:Combat() then state.status="Waiting until combat ends.";return end
    if context.raid then state.converting=nil;state.convertBlocked=nil end
    if not context.raid and context.count>=5 and settings.convert and context.leader then
        if state.converting then
            if now>=state.converting then state.converting=nil;state.convertBlocked=true;self:Print("Auto Invite could not confirm raid conversion. Convert the group manually or toggle auto-convert to retry.") end
        elseif not state.convertBlocked and now>=state.nextConvert then
            state.nextConvert=now+15
            local ok,result=self.Client:Call("ConvertToRaid")
            if ok and result~=false then state.converting=now+8 else state.convertBlocked=true;self:Print("Automatic raid conversion is unavailable. Convert the group manually.") end
        end
        state.status=state.convertBlocked and "Convert to raid manually to continue." or "Waiting for raid conversion."
        return
    end
    if context.count+pending>=(context.raid and 40 or 5) then state.status="Waiting for group space or pending invites.";return end
    if #state.queue==0 then state.status="Listening for the invite keyword.";return end
    if now<state.nextSend then return end
    state.nextSend=now+1
    local entry=table.remove(state.queue,1)
    local ok,result=self.Client:Call("InviteUnit",entry.name)
    if ok and result~=false then state.pending[entry.key]=now+45;state.status="Invite sent; waiting for a response."
    else state.status="Invite could not be sent.";self:Print("Auto Invite could not send an invite. Check your group permissions and try again.") end
end
function A:AutoInviteStatusText()
    local settings=self:AutoInviteSettings()
    if not settings.enabled then return "Off. Enable when you are ready to form a group." end
    return (self.autoInviteState and self.autoInviteState.status or "Listening for the invite keyword.").." Whisper: "..settings.keyword
end
local events=CreateFrame("Frame");A.autoInviteEvents=events
for _,event in ipairs({"ADDON_LOADED","CHAT_MSG_WHISPER","GROUP_ROSTER_UPDATE","PARTY_LEADER_CHANGED","GUILD_ROSTER_UPDATE","PLAYER_REGEN_ENABLED"}) do pcall(events.RegisterEvent,events,event) end
local ready=false;local elapsed=0
events:SetScript("OnEvent",function(_,event,message,sender)
    if event=="ADDON_LOADED" then
        if message~="NauseRaidTools" then return end
        ready=true;local settings=A:AutoInviteSettings();if settings.enabled and settings.guildOnly then A.Client:Call("GuildRoster") end
    elseif ready and event=="CHAT_MSG_WHISPER" then A:HandleAutoInviteWhisper(message,sender)
    elseif ready then
        if event=="GUILD_ROSTER_UPDATE" then A.autoInviteGuildCache=nil end
        A:PumpAutoInvites()
    end
end)
events:SetScript("OnUpdate",function(_,dt)
    if not ready then return end
    elapsed=elapsed+dt;if elapsed<.5 then return end;elapsed=0;A:PumpAutoInvites()
    local u=A.ui
    if u and u.autoInviteStatus and u.settingsHub:IsShown() then u.autoInviteStatus:SetText(A:AutoInviteStatusText()) end
end)
