local _, namespace = ...
local S = namespace.SoftRes or namespace
local alphabet="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local values={};for i=1,#alphabet do values[alphabet:sub(i,i)]=i-1 end
function S:Base64(text)
    text=text:gsub("%s","")
    assert(#text>0 and #text<=65536 and #text%4==0,"Invalid export size or padding.")
    assert(not text:find("[^A-Za-z0-9+/=]"),"Invalid export characters.")
    local out={}
    for i=1,#text,4 do
        local a,b,c,d=text:sub(i,i),text:sub(i+1,i+1),text:sub(i+2,i+2),text:sub(i+3,i+3)
        assert(values[a] and values[b],"Invalid base64.")
        assert((c~="=" or d=="=") and ((c~="=" and d~="=") or i==#text-3),"Invalid padding.")
        local n=values[a]*262144+values[b]*4096+(values[c] or 0)*64+(values[d] or 0)
        out[#out+1]=string.char(math.floor(n/65536)%256)
        if c~="=" then out[#out+1]=string.char(math.floor(n/256)%256) end
        if d~="=" then out[#out+1]=string.char(n%256) end
    end
    return table.concat(out)
end
function S:DecodeExport(text)
    assert(type(text)=="string" and #text<=65536,"Paste a complete Gargul export (maximum 64 KiB).")
    local bytes=self:Base64(text)
    local json,left=self.Deflate:DecompressZlib(bytes)
    assert(type(json)=="string" and #json<=262144 and (not left or left==0),"Invalid or oversized compressed export.")
    local depth,quoted,escaped=0,false,false
    for i=1,#json do
        local c=json:sub(i,i)
        if quoted then
            if escaped then escaped=false elseif c=="\\" then escaped=true elseif c=='"' then quoted=false end
        elseif c=='"' then quoted=true
        elseif c=="{" or c=="[" then depth=depth+1;assert(depth<=16,"Export nesting too deep.")
        elseif c=="}" or c=="]" then depth=depth-1 end
    end
    return self.JSON.decode(json)
end
function S:Preview(text, session, resolve)
    local ok,data=pcall(self.DecodeExport,self,text)
    if not ok then return nil,"Cannot decode Softres export. Copy the complete Gargul export from Softres.it." end
    if type(data)~="table" or type(data.metadata)~="table" or not data.metadata.id or type(data.softreserves)~="table" then return nil,"Export is missing Softres metadata or reservations." end
    local preview={rows={},issues={},revision=session.revision,id=session.id,source=tostring(data.metadata.id):sub(1,100)}
    local function issue(s) preview.issues[#preview.issues+1]=s end
    if data.metadata.hidden==true or data.metadata.hidden==1 then issue("Hidden reservations are not supported in this experiment.") end
    if data.hardreserves and (type(data.hardreserves)~="table" or next(data.hardreserves)) then issue("Hard reserves are not supported yet; import blocked to preserve raid rules.") end
    if data.bonusrolls and (type(data.bonusrolls)~="table" or next(data.bonusrolls)) then issue("Bonus rolls are not supported yet; import blocked.") end
    local n=0;local seen={}
    for _,entry in pairs(data.softreserves) do
        n=n+1;if n>40 then issue("More than 40 player rows.");break end
        if type(entry)~="table" or type(entry.name)~="string" or #entry.name>100 or type(entry.items)~="table" then
            issue("Invalid player row.")
        else
            local player=resolve(entry.name)
            local ids={};local valid=true
            for _,item in pairs(entry.items) do
                if type(item)~="table" or not self.Integer(tonumber(item.id),1,2147483647) then valid=false;break end
                ids[#ids+1]=tonumber(item.id)
            end
            if not player then issue("Unknown or ambiguous raid player: "..entry.name)
            elseif seen[player] then issue("Duplicate player row: "..entry.name)
            elseif not valid or #ids>session.limit then issue("Invalid item IDs or too many reserves: "..entry.name)
            elseif tonumber(entry.plusOnes or 0)~=0 then issue("MS +1 values are not supported: "..entry.name)
            else
                seen[player]=true
                preview.rows[#preview.rows+1]={player=player,items=ids,replaces=session.reserves[player]~=nil}
            end
        end
    end
    table.sort(preview.rows,function(a,b) return a.player<b.player end)
    return preview
end
function S:ApplyPreview(session, preview)
    if session.locked then return false,"Reservations are locked." end
    if not preview or preview.id~=session.id or preview.revision~=session.revision then return false,"Reservations changed; preview the import again." end
    if #preview.issues>0 then return false,"Resolve all import issues first." end
    -- All validation precedes mutation. Imported players replace their previous picks;
    -- players absent from the import retain their in-game reservations.
    for _,row in ipairs(preview.rows) do
        local items,why=self:Items(row.items,session.limit);if not items then return false,why end
    end
    local names={};for name in pairs(session.reserves) do names[name]=true end
    for _,row in ipairs(preview.rows) do names[row.player]=true end
    local n=0;for _ in pairs(names) do n=n+1 end
    if n>40 then return false,"Combined reservation list exceeds 40 players." end
    for _,row in ipairs(preview.rows) do session.reserves[row.player]=self:Items(row.items,session.limit);session.sources[row.player]="softres:"..preview.source end
    session.revision=session.revision+1
    return true
end
