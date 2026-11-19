local _,A=...
local PREFIX="NauseRTVersion"
local function version(value) return type(value)=="string" and #value<=40 and value:match("^[%w%.%-]+$")~=nil end
local function normalize(name)
    if type(name)~="string" or #name>120 or name:find("[|%c]") then return end
    if A:IsForever() then name=name:gsub("^([^%s%-]+)%s+([^%s%-]+)$","%1-%2") end
    return name
end
function A:InstalledSoftResVersion()
    local sr=NauseSoftReserve
    return type(sr)=="table" and version(sr.version) and sr.version or "-"
end
function A:VersionScope()
    if self.Client:InRaid() then return "RAID" end
    if self.Client:InGroup() then return "PARTY" end
    return "SOLO"
end
function A:VersionPeers(scope)
    local peers={};local me=self:Name("player") or self.me
    if me then peers[me]={online=true} end
    if scope=="RAID" or scope=="PARTY" then
        local count=scope=="RAID" and 40 or 4
        for i=1,count do
            local unit=(scope=="RAID" and "raid" or "party")..i
            local name=self:Name(unit)
            if name then
                local ok,connected=self.Client:Call("UnitIsConnected",unit)
                peers[name]={online=not (ok and (connected==false or connected==0))}
            end
        end
    end
    return peers
end
function A:SendVersionMessage(message,channel,target)
    if #message>255 then return false end
    local ok,sent=self.Client:Call("C_ChatInfo.SendAddonMessage",PREFIX,message,channel,target)
    return ok and sent~=false
end
function A:StartVersionCheck(show,requestedScope)
    local now=self.Client:Uptime()
    local scope=requestedScope or self:VersionScope()
    if scope~="SOLO" and scope~=self:VersionScope() then return false end
    if not self.versionCheck or self.versionCheck.scope~=scope or now-(self.lastVersionProbe or -10)>=5 then
        self.versionCheckSerial=(self.versionCheckSerial or 0)+1
        local id=tostring(self.versionCheckSerial).."-"..tostring(math.floor(now*1000)).."-"..tostring(math.random(100000,999999))
        local me=self:Name("player") or self.me
        if not me then self:Print("Your character name is not available yet.");return false end
        local peers=self:VersionPeers(scope)
        local r={id=id,scope=scope,started=now,members={},peers=peers,me=me}
        r.members[me]={nrt=self.version,wire=self.protocol,sr=self:InstalledSoftResVersion()}
        self.versionCheck=r;self.lastVersionProbe=now
        if scope~="SOLO" then r.sent=self:SendVersionMessage("Q|"..id,scope) end
    end
    if show then
        self:BuildUI();self.ui.versionWindow:Show();self:FocusWindow(self.ui.versionWindow)
    end
    self:RenderVersionCheck();return true
end
function A:VersionCheckMessage(prefix,message,channel,rawSender)
    if prefix~=PREFIX or type(message)~="string" or #message>255 then return end
    if channel~="RAID" and channel~="PARTY" and channel~="WHISPER" then return end
    local sender=normalize(rawSender);local me=self:Name("player") or self.me
    if not sender or sender==me then return end
    local now=self.Client:Uptime()
    local query=message:match("^Q|([%d%-]+)$")
    if query then
        if #query>60 or channel=="WHISPER" or channel~=self:VersionScope() then return end
        local peers=self:VersionPeers(channel)
        if not peers[sender] or not peers[sender].online then return end
        self.versionReplyLimits=self.versionReplyLimits or {}
        if now-(self.versionReplyLimits[sender] or -10)<5 then return end
        local bucket=self.versionReplyBucket
        if not bucket or now-bucket.at>=5 then bucket={at=now,count=0};self.versionReplyBucket=bucket end
        if bucket.count>=10 then return end
        bucket.count=bucket.count+1;self.versionReplyLimits[sender]=now
        self:SendVersionMessage("R|"..query.."|"..self.version.."|"..self.protocol.."|"..self:InstalledSoftResVersion(),"WHISPER",sender)
        return
    end
    local id,nrt,wire,sr=message:match("^R|([%d%-]+)|([^|]+)|(%d+)|([^|]+)$")
    local r=self.versionCheck
    if channel~="WHISPER" or not r or id~=r.id or now-r.started<0 or now-r.started>60
        or not version(nrt) or not version(sr) then return end
    wire=tonumber(wire);if not wire or wire<1 or wire>10000 then return end
    local peers=self:VersionPeers(r.scope)
    if not peers[sender] or not peers[sender].online then return end
    r.peers=peers;r.members[sender]={nrt=nrt,wire=wire,sr=sr};self:RenderVersionCheck()
end
function A:VersionMemberStatus(name)
    local r=self.versionCheck;local peer=r and r.peers[name];local row=r and r.members[name]
    if r and r.scope=="SOLO" and name==r.me then return "Installed",true end
    if r and self.Client:Uptime()-r.started>60 then return "Refresh needed",false end
    if peer and not peer.online then return "Offline",false end
    if not row then return self.Client:Uptime()-r.started<3 and "Waiting" or "No reply",false end
    if row.wire~=self.protocol then return "Incompatible",false end
    if row.nrt~=self.version then return "Version mismatch",false end
    local sr=self:InstalledSoftResVersion()
    if sr~="-" and row.sr=="-" then return "SoftRes not enabled",false end
    if sr~="-" and row.sr~=sr then return "SoftRes mismatch",false end
    return "Matched",true
end
function A:BuildVersionCheckUI(u,window,text,button)
    local f=window("NauseRaidToolsVersions","Nause Raid Tools - Version Check",780,530);u.versionWindow=f
    u.versionScope=text(f,"",12,20,-50,740)
    u.versionNote=text(f,"Anyone can check. No reply does not prove the addon is missing.",11,20,-79,740)
    button(f,"Refresh",640,-108,120,function() A:StartVersionCheck(false) end)
    for i,row in ipairs({{"PLAYER",20,230},{"NRT",260,145},{"SOFTRES",415,145},{"STATUS",570,190}}) do text(f,row[1],11,row[2],-151,row[3]) end
    local scroll=self:CreateScrollFrame(f);scroll:SetPoint("TOPLEFT",20,-178);scroll:SetSize(720,285);u.versionScroll=scroll
    local child=CreateFrame("Frame",nil,scroll);child:SetSize(720,1);scroll:SetScrollChild(child);u.versionChild=child;u.versionRows={}
    u.versionSummary=text(f,"",11,20,-485,740)
    f:SetScript("OnUpdate",function(_,dt)
        f.versionElapsed=(f.versionElapsed or 0)+dt
        if f.versionElapsed>=1 then f.versionElapsed=0;A:RenderVersionCheck() end
    end)
end
function A:RenderVersionCheck()
    local u=self.ui;local r=self.versionCheck
    if not u or not u.versionWindow or not u.versionWindow:IsShown() or not r then return end
    local peers=self:VersionPeers(r.scope)
    r.peers=peers
    r.members[r.me]={nrt=self.version,wire=self.protocol,sr=self:InstalledSoftResVersion()}
    local names={};for name in pairs(peers) do names[#names+1]=name end;table.sort(names)
    local detected,matched=0,0
    for i=1,math.max(#names,#u.versionRows) do
        local row=u.versionRows[i]
        if not row then
            row=CreateFrame("Frame",nil,u.versionChild);row:SetPoint("TOPLEFT",0,-(i-1)*26);row:SetSize(720,26);self:StyleDataRow(row,i)
            row.cells={}
            for n,cell in ipairs({{0,230},{240,145},{395,145},{550,170}}) do
                local label=row:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");label:SetPoint("TOPLEFT",cell[1],-5);label:SetSize(cell[2],18);label:SetMaxLines(1);label:SetWordWrap(false);label:SetJustifyH("LEFT");row.cells[n]=label
            end
            u.versionRows[i]=row
        end
        local name=names[i];row:SetShown(name~=nil)
        if name then
            local entry=r.members[name];local status,correct=self:VersionMemberStatus(name)
            if entry then detected=detected+1 end;if correct then matched=matched+1 end
            local values={name..(name==r.me and " (you)" or ""),entry and entry.nrt or "—",entry and (entry.sr=="-" and "Not enabled" or entry.sr) or "—",status}
            for n,cell in ipairs(row.cells) do cell:SetText(values[n]) end
            row.cells[4]:SetTextColor(correct and .35 or 1,correct and .85 or .70,correct and .50 or .35)
        end
    end
    u.versionChild:SetHeight(math.max(1,#names*26))
    u.versionScope:SetText("Checking: "..(r.scope=="SOLO" and "Your installed addons" or r.scope).." · Your NRT: "..self.version.." · SoftRes: "..(self:InstalledSoftResVersion()=="-" and "Not enabled" or self:InstalledSoftResVersion()))
    local stale=r.scope~="SOLO" and self.Client:Uptime()-r.started>60
    u.versionSummary:SetText((r.scope=="SOLO" and "Installed versions on this character" or (detected.."/"..#names.." replied · "..matched.." matched"))..(stale and " · Refresh needed" or "")..(r.sent==false and " · Request could not be sent" or ""))
    self:RefreshScrollChrome(u.versionScroll)
end
local events=CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED");events:RegisterEvent("CHAT_MSG_ADDON")
events:SetScript("OnEvent",function(_,event,...)
    if event=="ADDON_LOADED" and (...)=="NauseRaidTools" then A.Client:Call("C_ChatInfo.RegisterAddonMessagePrefix",PREFIX)
    elseif event=="CHAT_MSG_ADDON" then A:VersionCheckMessage(...) end
end)
