local root=...
local make=assert(loadfile(root.."/qa/softres/improvements_client.lua"))(root,root)
local a,e,s=make("Leader-Realm");local confirm=assert(loadfile(root.."/qa/softres/test_catalogue.lua"))(a,e)
local count=0;local function check(value,message) count=count+1;assert(value,message) end
e.IsInRaid=function() return false end;e.IsInGroup=function() return false end
function a:Name(unit) if unit=="player" then return "Leader-Realm" end end
e.NauseSoftReserveDB={schema=1,history={{untouched=true}},session={id="saved-session"}}
local saved=a.Encode(e.NauseSoftReserveDB)
a:BuildUI();assert(s:StartTest());assert(confirm(s));s:ShowBrowser()
local id=s.browserDraft[1];local initial=s:BrowserReserveCounts()[id].total;local revision=s.session.revision
assert(s:SelectBrowserView("mine"))
check(s.browser.rows[1].entry.id==id and not s.browser.rows[2]:IsShown(),"My reserves did not combine stacked picks into one item row")
s.browser.rows[1].remove:GetScript("OnClick")()
check(#s.browserDraft==1 and #s.session.reserves[a.me]==2 and s.session.revision==revision,"removing a pick changed confirmed reservations before submission")
check(s:BrowserReserveCounts()[id].total==initial-1,"raid total double-counted confirmed picks and the local draft")
assert(s:SubmitBrowserDraft());check(#s.session.reserves[a.me]==1,"Submit did not save the edited picks")
assert(s:SelectBrowserView("reserved"))
for _,row in ipairs(s.browser.rows) do if row.entry then check(s:BrowserReserveCounts()[row.entry.id].total>0,"All reserves included an unreserved item") end end
local old=s.catalogue[id];s.catalogue[id]=nil;s:InvalidateCatalogue();assert(s:SelectBrowserView("mine"))
check(s.browser.rows[1].entry.id==id,"uncached selected item disappeared from My reserves")
s.catalogue[id]=old;s:InvalidateCatalogue();assert(s:SelectBrowserView("all","Fixture Dungeon"))
local bossButton
for _,b in ipairs(s.browser.navigationRows) do if b.entry and b.entry.kind=="boss" then bossButton=b;break end end
check(bossButton~=nil,"selected instance did not expose its bosses")
bossButton:GetScript("OnClick")();check(s.browserBoss=="Fixture Boss" and #s:BrowserViewRows(s:BrowserReserveCounts())==4,"boss navigation did not filter loot")

-- More items than visible rows exercise real scroll offsets, not page controls.
s.session.selectedInstances=nil;s.catalogue={}
for i=1,20 do s.catalogue[90000+i]={id=90000+i,name=string.format("List Item %02d",i),sources={{instance="Fixture Dungeon",boss="Fixture Boss"}}} end
e.C_Item={GetItemInfo=function(value) return string.format("List Item %02d",value-90000),nil,4,40,30,"Armor","Mail" end}
s:InvalidateCatalogue();assert(s:SelectBrowserView("all"))
check(s.browser.rows[1].entry.id==90001,"all-loot view did not start with its first item")
s.browser.itemsScroll:SetVerticalScroll(420);s.browser.itemsScroll:GetScript("OnVerticalScroll")(s.browser.itemsScroll,420)
check(s.browser.rows[1].entry.id==90011,"scrolling did not reveal later items")
check(s.browser.rows[1].source:GetText():find("Armor, Mail",1,true),"item row omitted cached item-type details")
s.browser.search:SetText("List Item 20");s.browser.search:GetScript("OnTextChanged")();s:RenderBrowser()
check(s.browserMode=="search" and s.browser.rows[1].entry.id==90020 and not s.browser.rows[2]:IsShown(),"search did not switch to filtered results")
s:ShowPugSetup();s:ShowBrowser()
check(s.browserMode=="search" and s.browser.search:GetText()=="List Item 20","switching manager tabs lost the search view")
s.session.locked=true;s:RenderBrowser()
check(not s.browser.rows[1].add:IsEnabled() and not s.browser.submit:IsEnabled(),"locked reservations left reserve/submit actions enabled")
check(not s:EditBrowserPick(90020),"locked editing bypassed validation")
assert(s:StopTest());check(a.Encode(e.NauseSoftReserveDB)==saved,"browser practice altered saved session data")
print("RESERVATION BROWSER PASS: "..count.." checks; sidebar views, stacked counts, drafts, boss navigation, virtual scrolling, search, locks and saved-data isolation")
