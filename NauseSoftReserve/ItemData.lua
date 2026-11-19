local _,S=...
local A=S.base

local function cleanName(value)
    if type(value)~="string" then return end
    return value:gsub("|T.-|t",""):gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r",""):gsub("%s+$","")
end

function S:AtlasItemLibrary()
    if self.atlasLibrary then return self.atlasLibrary end
    if not AtlasLoot or not AtlasLoot.ItemDB then return end
    local module="AtlasLootClassic_DungeonsAndRaids"
    local storage=AtlasLoot.ItemDB.Storage
    if not storage or not storage[module] then
        if A.Client:Combat() then return end
        local load=C_AddOns and C_AddOns.LoadAddOn or LoadAddOn
        if type(load)=="function" then pcall(load,module) end
        storage=AtlasLoot.ItemDB.Storage
    end
    local data=storage and storage[module]
    if type(data)~="table" then return end
    local library={sources={},instances={},ids={}}
    local seen={}
    for _,instance in pairs(data) do
        if type(instance)=="table" and type(instance.items)=="table" then
            local name=cleanName(instance.name)
            if name and name~="" then
                local added=false
                for _,boss in ipairs(instance.items) do
                    local bossName=type(boss)=="table" and cleanName(boss.name)
                    if bossName and bossName~="" then
                        for difficulty,rows in pairs(boss) do
                            if type(difficulty)=="number" and type(rows)=="table" then
                                for _,row in ipairs(rows) do
                                    local id=type(row)=="table" and row[2]
                                    if S.Integer(id,1,2147483647) then
                                        local key=name..":"..bossName..":"..id
                                        if not seen[key] then
                                            seen[key]=true;added=true
                                            library.sources[id]=library.sources[id] or {}
                                            table.insert(library.sources[id],{instance=name,boss=bossName})
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
                if added then library.instances[name]=instance end
            end
        end
    end
    for id in pairs(library.sources) do table.insert(library.ids,id) end
    table.sort(library.ids)
    if #library.ids==0 then return end
    function library:GetInstances()
        local rows={}
        for name,instance in pairs(self.instances) do
            rows[#rows+1]={name=name,mapID=instance.mapID or instance.MapID,minLevel=instance.minLevel,maxLevel=instance.maxLevel,
                levelRange=instance.levelRange or instance.LevelRange,isRaid=instance.isRaid,maxNumPlayers=instance.maxNumPlayers}
        end
        table.sort(rows,function(a,b) return a.name<b.name end)
        return rows
    end
    function library:GetSources(id) return self.sources[id] or {} end
    function library:Search() return self.ids end
    function library:GetName(id)
        local ok,name=A.Client:Call("C_Item.GetItemInfo",id)
        return ok and name or nil
    end
    function library:GetInfo(id) return self:GetName(id) end
    function library:GetLink(id)
        local ok,_,link=A.Client:Call("C_Item.GetItemInfo",id)
        return ok and link or nil
    end
    self.atlasLibrary=library
    return library
end

function A:ItemLibrary()
    if LibStub then
        local ok,db=pcall(LibStub,"LibItemDB-1.0",true)
        if ok and db and type(db.IsReady)=="function" then
            local ready,value=pcall(db.IsReady,db)
            if ready and value==true then return db end
        end
    end
    return S:AtlasItemLibrary()
end
