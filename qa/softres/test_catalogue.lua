local a,e=...
local items=a:TestItems();local byID={};local ids={}
for i=1,8 do local row=items[i];byID[row.id]=row;ids[#ids+1]=row.id end
local lib={}
function lib:IsReady() return true end
function lib:GetInstances() return {{name="Fixture Dungeon"},{name="Fixture Raid"}} end
function lib:Search() return ids end
function lib:GetSources(id)
    for i,value in ipairs(ids) do if value==id then return {{instance=i<=4 and "Fixture Dungeon" or "Fixture Raid",boss="Fixture Boss"}} end end
    return {}
end
function lib:GetName(id) return byID[id] and (byID[id].link:match("|h%[(.-)%]|h") or ("Item "..id)) end
function lib:GetInfo(id) return self:GetName(id) end
function lib:GetLink(id) return byID[id] and byID[id].link end
local previous=e.LibStub
e.LibStub=function(name,...) if name=="LibItemDB-1.0" then return lib end;if previous then return previous(name,...) end end
return function(s,selection,limit)
    assert(s.test and s.testSetup and not s.session,"test did not wait for content selection")
    s.setupSelection=selection or {["Fixture Dungeon"]=true,["Fixture Raid"]=true};s.setup.limit:SetText(tostring(limit or 2))
    assert(s:ConfirmPugSetup());return true
end
