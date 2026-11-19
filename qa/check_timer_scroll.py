from pathlib import Path
import ast
from lupa.lua51 import LuaRuntime

root=Path(__file__).resolve().parent.parent
tree=ast.parse((root/'qa/check_reason_dropdown.py').read_text(encoding='utf-8'))
frames=next(ast.literal_eval(n.value) for n in tree.body if isinstance(n,ast.Assign)
            and any(isinstance(t,ast.Name) and t.id=='FRAMES' for t in n.targets))
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute(frames)
lua.execute('''
SlashCmdList={}
local create=CreateFrame
function CreateFrame(kind,name,parent,...)
    local f=create(kind,name,parent,...)
    function f:SetWidth(w) self.width=w end
    function f:SetHeight(h) self.height=h end
    function f:CreateTexture() return CreateFrame('Texture',nil,self) end
    function f:SetScrollChild(child) self.child=child end
    function f:GetVerticalScrollRange() return math.max(0,(self.child and self.child.height or 0)-self.height) end
    function f:GetVerticalScroll() return self.offset or 0 end
    function f:SetVerticalScroll(value) self.offset=value end
    return f
end
''')
for name in ['UI','LootUI']:
    lua.execute((root/'NauseRaidTools'/f'{name}.lua').read_text(encoding='utf-8'),
                'NauseRaidTools',lua.globals().A)
lua.execute('''
local timerMode="Full"
function A:LootWindowLayout() return timerMode end
function A:StyleRailArrow() end
function A:StyleDataRow() end
function A:WarningSettings() return {early=600,urgent=120} end
function A:ItemIcon(entry) return entry.id end
function A:FitTimerItemName(link) return link end
function A:TradeRemaining(entry) return entry.remaining or 1000,'~0:16:40' end
function A:LootHolderInfo(name) return name end
local function window(name,title,w,h)
    local f=CreateFrame('Frame',name,UIParent);f:SetSize(w,h);return f
end
local function text(parent,value)
    local f=CreateFrame('FontString',nil,parent);f:SetText(value);return f
end
A.ui={}
A:BuildLootTimerUI(A.ui,window,text,function(parent,label) return text(parent,label) end)
local p=A.ui.lootTimers
assert(p.itemHeader.parent==p.window and p.rows[80].parent==p.child)
assert(not p.previous and not p.next)
A.state={id='raid',trackedLoot={}}
for i=80,1,-1 do A.state.trackedLoot[#A.state.trackedLoot+1]={id=i,link='item:'..i,holder='Holder'} end
A:RenderLootTimers()
assert(p.rows[1].tracked==1 and p.rows[80].tracked==80 and p.rows[80]:IsShown())
A.state.trackedLoot[1].remaining=60
A:RenderLootTimers()
assert(p.rows[1].tracked==80 and p.rows[2].tracked==1)
A.state.trackedLoot[1].remaining=nil
A:RenderLootTimers()
assert(p.scroll:GetVerticalScroll()==0 and p.scroll.nrtScrollChrome.rail:IsShown())
p.scroll.scripts.OnMouseWheel(p.scroll,-1)
assert(p.scroll:GetVerticalScroll()==36)
p.scroll.nrtScrollChrome.down:Click();assert(p.scroll:GetVerticalScroll()==72)
local maximum=p.scroll:GetVerticalScrollRange()
p.scroll.nrtScrollChrome.slider:SetValue(maximum)
assert(p.scroll:GetVerticalScroll()==maximum)
A:RenderLootTimers();assert(p.scroll:GetVerticalScroll()==maximum,'countdown refresh reset scroll')
p.window:SetSize(760,460);A:LayoutLootTimer()
assert(p.scroll:GetVerticalScroll()==p.scroll:GetVerticalScrollRange())
-- Removal of delivered items clamps the bottom position and hides old rows.
for i=1,78 do A.state.trackedLoot[i].delivery='delivered' end
A:RenderLootTimers()
assert(p.count==2 and p.rows[1].tracked==1 and p.rows[2].tracked==2)
assert(not p.rows[3]:IsShown() and p.scroll:GetVerticalScroll()==0)
assert(not p.scroll.nrtScrollChrome.rail:IsShown())
A.state.trackedLoot={};A:RenderLootTimers()
assert(p.empty:IsShown() and not p.rows[1]:IsShown())
A.state={id='next',trackedLoot={}}
for i=1,20 do A.state.trackedLoot[i]={id=i,link='item:'..i,holder='Holder'} end
p.scroll:SetVerticalScroll(100)
A:RenderLootTimers();assert(p.scroll:GetVerticalScroll()==0)
p.window:SetSize(440,220);A:LayoutLootTimer()
assert(p.rows[1].holder:GetWidth()>=40 and p.rows[1].caption:GetWidth()>=90)

p.scroll:SetVerticalScroll(88)
timerMode='Compact';p.window:SetSize(380,250);A:LayoutLootTimer()
assert(not p.holderHeader:IsShown() and not p.rows[1].holder:IsShown() and not p.rows[1].holderStatus:IsShown())
assert(p.rowStride==32 and p.rows[1]:GetHeight()==30 and p.scroll:GetVerticalScroll()==64)
A:RenderLootTimers()
assert(p.rows[1].caption:GetText()=='item:1' and p.rows[1].countdown:GetText()=='~0:16:40')
assert(p.scroll:GetVerticalScroll()==64 and not p.rows[1].holder:IsShown())
timerMode='Full';p.window:SetSize(600,320);A:LayoutLootTimer();A:RenderLootTimers()
assert(p.holderHeader:IsShown() and p.rows[1].holder:IsShown() and p.rows[1].holder:GetText()=='Holder')
assert(p.rowStride==44 and p.scroll:GetVerticalScroll()==88)
''')
print('Timer scroll: 80 items, wheel/arrows/slider, refresh preservation, resize, delivery removal, empty and session reset passed.')
lua.execute("""
local function window(name,title,w,h)
    local frame=CreateFrame('Frame',name,UIParent)
    frame:SetSize(w,h)
    function frame:CreateTexture() return CreateFrame('Texture',nil,self) end
    return frame
end
local function text(parent,label)
    local frame=CreateFrame('FontString',nil,parent)
    frame:SetText(label)
    return frame
end
local function button(parent,label,x,y,w,action)
    local frame=window(nil,nil,w,30)
    frame:SetText(label);frame:SetScript('OnClick',action)
    return frame
end
A:BuildLootUI(A.ui,window,text,button,function() return window(nil,nil,200,30) end)
local loot=A.ui.lootPanels.deliveries
function A:CanViewLoot() return true end
function A:IsMaster() return true end
function A:IsLeader() return true end
function A:DisplayName(name) return name end
function A:TradeWarningLevel() end
function A:EntryInTrade() return false end
function A:WinnerInTradeRange() return true end
function A:LootWindowAutoOpen() return false end
function A:SetSettingsToggle() end
function A:RefreshRailArrow() end
function A:CanQueueTrackedLoot(entry) return not entry.item and entry.delivery~='delivered' end
function A:LootSuggestion(entry) return entry.councilSuggestion end
function A:ItemByID(id) return self.state.items[id] end
function A:TrackedByID(id)
    for _,entry in ipairs(self.state.trackedLoot) do
        if entry.id==id then return entry end
    end
end
function A:StartTrade(id) self.tradeClicked=id end
function A:QueueTrackedLoot(id) self.queued=id end
A.me='Holder'
A.state={id='loot-queue',items={
    {status='awarded',winner='Winner'},
    {status='awarded',winner='Bank',automaticAssignment=true,awardReason='Guild Bank'},
    {status='open'},
    {status='awarded',winner='Previous'},
},trackedLoot={
    {id=1,guid='copy-one',link='item:123',holder='Holder'},
    {id=2,guid='copy-two',link='item:123',holder='Holder',item=1,remaining=480},
    {id=3,guid='bank',link='item:3',holder='Bank',item=2,delivery='delivered',deliveredTo='Bank'},
    {id=4,guid='suggestion',link='item:4',holder='Holder',councilSuggestion={first='Council'}},
    {id=5,guid='responses',link='item:5',holder='Holder',item=3},
    {id=6,guid='complete',link='item:6',holder='Holder',item=4,delivery='delivered'},
}}
A:RenderLootWindows()
assert(loot.summary:GetText():find('Needs attention: 3'))
assert(loot.count==5)
assert(loot.rows[1].tracked==2 and loot.rows[1].action:GetText()=='Trade to Winner')
assert(loot.rows[1].deadline:GetText()=='Trade due in 8m' and not loot.rows[1].bar)
assert(loot.rows[2].tracked==4 and loot.rows[2].action:GetText()=='Council suggestion')
assert(loot.rows[3].tracked==1 and loot.rows[3].action:GetText()=='Queue for council')
assert(loot.rows[3].deadline:GetText()=='')
assert(loot.rows[4].tracked==5 and loot.rows[4].action:GetText()=='Responses open')
assert(loot.rows[5].tracked==6 and loot.rows[5].action:GetText()=='Delivered')
loot.rows[1].trade:Click()
loot.rows[3].trade:Click()
assert(A.tradeClicked==2 and A.queued==1)
local timer=A.ui.lootTimers
assert(timer.rows[1].tracked==2 and timer.rows[1].trade:IsShown())
assert(timer.rows[1].holderStatus:GetText()=='To: Winner')
A.me='Observer'
function A:IsLeader() return false end
function A:IsMaster() return false end
A:RenderLootTimers()
assert(not timer.rows[1].trade:IsShown() and timer.rows[1].holderStatus:GetText()=='')
""")
print('Loot queue: duplicate identities, urgent badge, suggestions, pending responses, delivered records and trade permissions passed.')
