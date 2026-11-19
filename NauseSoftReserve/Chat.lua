local _,S=...
local A=S.base
function S:ProcessReserveChat(text,sender)
    if not self:IsHost() or type(text)~="string" or #text>700 then return end
    sender=A:Resolve(sender)
    if not sender or not A.roster[sender] then return end
    local command,args=text:match("^%s*!(%a+)%s*(.-)%s*$")
    if command then command=command:lower() end
    if command~="reserve" and command~="unreserve" and command~="myreserves" then return end
    self.chatLimits=self.chatLimits or {};local now=A.Client:Uptime()
    if self.chatLimits[sender] and now-self.chatLimits[sender]<2 then return false,"Please wait before another reservation command." end
    self.chatLimits[sender]=now
    local s=self.session;local picks=A.Copy(s.reserves[sender] or {});local ok,why
    if command=="myreserves" then
        local ids={};for _,id in ipairs(picks) do ids[#ids+1]=tostring(id) end
        ok=true;why=#ids>0 and ("Your reserves: "..table.concat(ids,", ")) or "You have no confirmed reserves."
    else
        local itemText,count=args:match("^(.-)%s+[xX](%d+)$");itemText=itemText or args;count=tonumber(count) or 1
        local id=tonumber(itemText:match("^%s*(%d+)%s*$") or itemText:match("|Hitem:(%d+):"))
        if not id or not self.Integer(id,1,2147483647) or not self.Integer(count,1,s.limit) then ok=false;why="Use !reserve ITEM_ID x2, !unreserve ITEM_ID or !myreserves. Full item links also work."
        else
            if command=="reserve" then for _=1,count do picks[#picks+1]=id end
            else
                local removed=0
                for i=#picks,1,-1 do if picks[i]==id and removed<count then table.remove(picks,i);removed=removed+1 end end
                if removed==0 then why="That item is not reserved by you." end
            end
            if not why then
                self.chatSerial=(self.chatSerial or 0)+1
                ok,why=self:Handle(sender,{id=s.id,requestID="chat:"..self.chatSerial,action="reserve",items=picks,
                    reservationEpoch=s.reservationEpoch or 0,original=A.Copy(s.reserves[sender] or {}),reservationVersion=(s.reservationVersions or {})[sender] or 0})
                why=why or (ok and ("Confirmed: "..(#picks>0 and table.concat(picks,", ") or "no reserves").." ("..#picks.."/"..s.limit..")"))
            end
        end
    end
    local response="[Nause SR] "..tostring(why or "Reservation request rejected.")
    if type(SendChatMessage)=="function" then SendChatMessage(response:sub(1,240),"WHISPER",nil,sender) end
    return ok,why
end
local frame=CreateFrame("Frame");S.chatEvents=frame
for _,event in ipairs({"CHAT_MSG_WHISPER","CHAT_MSG_RAID","CHAT_MSG_RAID_LEADER","CHAT_MSG_PARTY","CHAT_MSG_PARTY_LEADER"}) do pcall(frame.RegisterEvent,frame,event) end
frame:SetScript("OnEvent",function(_,_,text,sender) S:ProcessReserveChat(text,sender) end)
