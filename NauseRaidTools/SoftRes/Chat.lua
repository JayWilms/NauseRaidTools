local _, namespace = ...
local S = namespace.SoftRes or namespace
local A=S.base
local function cleanChatMarkup(value)
    return value:gsub("|T.-|t",""):gsub("|A.-|a","")
        :gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|cn[%w_]+:",""):gsub("|r","")
end
local function itemName(value)
    if type(value)~="string" then return "" end
    value=cleanChatMarkup(value):match("^%s*(.-)%s*$")
    return (value:match("^%[(.*)%]$") or value):lower()
end
function S:ResolveReservationChatItem(text)
    text=cleanChatMarkup(text)
    local id=tonumber(text:match("^%s*(%d+)%s*$") or text:match("|H[iI][tT][eE][mM]:(%d+)"))
    if id then return id end
    local wanted=itemName(text);local found
    if wanted=="" then return nil,"Choose an item link, item name or item ID." end
    for itemID,entry in pairs(self.catalogue or {}) do
        if itemName(entry.name)==wanted and (not self.ScopeAllows or self:ScopeAllows(self.session,itemID)) then
            if found and found~=itemID then return nil,"More than one item has that name. Whisper its full item link or ID." end
            found=itemID
        end
    end
    if found then return found end
    -- A cached item can still be resolved before the catalogue has finished loading.
    local ok,name,link=A.Client:Call("C_Item.GetItemInfo",text:match("^%s*%[(.*)%]%s*$") or text)
    if ok and itemName(name)==wanted and type(link)=="string" then
        id=tonumber(link:match("|Hitem:(%d+)"));if id then return id end
    end
    return nil,"Item name not found in the loaded loot list. Whisper its full item link or ID, or wait for the list to load."
end
function S:ParseReservationChatItems(args,limit)
    -- Convert complete links to atomic IDs before handling plain/bracketed names.
    -- Other addons may add icons, named colours or different display labels.
    -- Read a complete hyperlink's item ID independently of its visible name.
    local text=cleanChatMarkup(args):gsub("|H[iI][tT][eE][mM]:(%d+)[^|]*|h.-|h",function(id) return "["..id.."]" end)
    local items={}
    local function add(id,count)
        if not self.Integer(id,1,2147483647) or not self.Integer(count,1,limit) or #items+count>limit then
            return false,"Too many picks. This run allows "..limit.." reserves per player."
        end
        for _=1,count do items[#items+1]=id end
        return true
    end
    while true do
        text=text:match("^%s*(.-)%s*$")
        if text=="" then break end
        if text:sub(1,1)=="[" then
            local close=text:find("]",2,true)
            if not close then return nil,"Close the item name's bracket, or send a full item link." end
            local id,why=self:ResolveReservationChatItem(text:sub(2,close-1))
            if not id then return nil,why end
            text=text:sub(close+1)
            local _,finish,n=text:find("^%s*[xX](%d+)")
            local ok,errorText=add(id,tonumber(n) or 1);if not ok then return nil,errorText end
            if finish then text=text:sub(finish+1) end
        else
            local nextBracket=text:find("[",1,true)
            local chunk=nextBracket and text:sub(1,nextBracket-1) or text
            text=nextBracket and text:sub(nextBracket) or ""
            chunk=chunk:match("^%s*(.-)%s*$")
            local name,n=chunk:match("^(.-)%s+[xX](%d+)$");name=name or chunk
            local multiplier=tonumber(n) or 1
            local id,why=self:ResolveReservationChatItem(name)
            local repeats=1
            if not id then
                -- Unbracketed names can contain spaces. Only split a repeated
                -- complete name, rather than guessing individual words.
                local normalized=name:gsub("%s+"," ")
                for count=2,limit do
                    local length=(#normalized-(count-1))/count
                    if length>0 and length%1==0 then
                        local candidate=normalized:sub(1,length)
                        if (candidate..string.rep(" "..candidate,count-1)):lower()==normalized:lower() then
                            id=self:ResolveReservationChatItem(candidate)
                            if id then repeats=count;break end
                        end
                    end
                end
            end
            if not id then return nil,why end
            local ok,errorText=add(id,repeats*multiplier);if not ok then return nil,errorText end
        end
    end
    if #items==0 then return nil,"Use !sr Item Name, !removesr Item Name or !mysr. Repeat an item or add x2 for two." end
    return items
end
function S:ReservationChatName(id)
    local entry=self.catalogue and self.catalogue[id]
    local name=entry and entry.name
    if not name then local ok,value=A.Client:Call("C_Item.GetItemInfo",id);if ok then name=value end end
    if not name then
        for _,loot in ipairs(self.session and self.session.lootEntries or {}) do
            if type(loot.link)=="string" and tonumber(loot.link:match("item:(%d+)"))==id then name=loot.link:match("|h%[(.-)%]|h");break end
        end
    end
    if type(name)~="string" or name=="" then
        if C_Item and type(C_Item.RequestLoadItemDataByID)=="function" then pcall(C_Item.RequestLoadItemDataByID,id) end
        name="Item name loading"
    end
    name=name:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r",""):gsub("[%c|]","")
    return "["..name.."]"
end
function S:ReservationChatReplies(picks,heading,limit)
    local counts,order={},{}
    for _,id in ipairs(picks) do if not counts[id] then order[#order+1]=id;counts[id]=0 end;counts[id]=counts[id]+1 end
    local suffix=" ("..#picks.."/"..limit..")"
    local replies={};local message=heading
    for _,id in ipairs(order) do
        local label=self:ReservationChatName(id)..(counts[id]>1 and (" x"..counts[id]) or "")
        local separator=message==heading and "" or ", "
        -- Split at item boundaries, leaving space for the chat/test prefix.
        if message~=heading and #message+#separator+#label+#suffix>220 then replies[#replies+1]=message..suffix;message=heading;separator="" end
        message=message..separator..label
    end
    replies[#replies+1]=message..(#picks==0 and "no reserves" or "")..suffix
    return replies
end
function S:ProcessReserveChat(text,sender)
    if not self:IsHost() or type(text)~="string" or #text>700 then return end
    sender=A:Resolve(sender)
    if not sender or not A.roster[sender] then return end
    local command,args=text:match("^%s*!(%a+)%s*(.-)%s*$")
    if command then command=command:lower() end
    if command~="sr" and command~="mysr" and command~="removesr" then return end
    self.chatLimits=self.chatLimits or {};local now=A.Client:Uptime()
    if self.chatLimits[sender] and now-self.chatLimits[sender]<2 then return false,"Please wait before another reservation command." end
    self.chatLimits[sender]=now
    local s=self.session;local picks=A.Copy(s.reserves[sender] or {});local ok,why,replies
    if command=="mysr" then
        ok=true
        if #picks>0 then replies=self:ReservationChatReplies(picks,"Your reserves: ",s.limit);why=table.concat(replies,"\n")
        else why="You have no confirmed reserves." end
    else
        local requested,itemError=self:ParseReservationChatItems(args,s.limit)
        if not requested then ok=false;why=itemError
        else
            if command=="removesr" then
                local counts={};for _,id in ipairs(requested) do counts[id]=(counts[id] or 0)+1 end
                for id,count in pairs(counts) do
                    local removed=0
                    for i=#picks,1,-1 do if picks[i]==id and removed<count then table.remove(picks,i);removed=removed+1 end end
                    if removed==0 then ok=false;why="That item is not reserved by you.";break end
                end
            else for _,id in ipairs(requested) do picks[#picks+1]=id end end
            if not why then
                self.chatSerial=(self.chatSerial or 0)+1
                ok,why=self:Handle(sender,{id=s.id,requestID="chat:"..self.chatSerial,action="reserve",items=picks,
                    reservationEpoch=s.reservationEpoch or 0,original=A.Copy(s.reserves[sender] or {}),reservationVersion=(s.reservationVersions or {})[sender] or 0})
                if ok and not why then replies=self:ReservationChatReplies(picks,"Confirmed: ",s.limit);why=table.concat(replies,"\n") end
            end
        end
    end
    for _,reply in ipairs(replies or {tostring(why or "Reservation request rejected.")}) do
        local response="[Nause SR] "..(self.test and "TEST: " or "")..reply
        if self.test and not self.testGroup then self:Print(response)
        elseif type(SendChatMessage)=="function" then SendChatMessage(response:sub(1,240),"WHISPER",nil,sender) end
    end
    return ok,why
end
local frame=CreateFrame("Frame");S.chatEvents=frame
for _,event in ipairs({"CHAT_MSG_WHISPER","CHAT_MSG_RAID","CHAT_MSG_RAID_LEADER","CHAT_MSG_PARTY","CHAT_MSG_PARTY_LEADER"}) do pcall(frame.RegisterEvent,frame,event) end
frame:SetScript("OnEvent",function(_,_,text,sender) S:ProcessReserveChat(text,sender) end)
