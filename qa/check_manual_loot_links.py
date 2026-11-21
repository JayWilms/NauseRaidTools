from pathlib import Path
from lupa.lua51 import LuaRuntime

root=Path(__file__).resolve().parent.parent
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute("""
A={confirmationDialogs={}}; SlashCmdList={}
local focused,shown,enabled,master,shift=true,true,true,true,true
local input={value=''}
function input:IsEnabled() return enabled end
function input:HasFocus() return focused end
function input:GetText() return self.value end
function input:SetText(value) self.value=value end
function input:SetCursorPosition(value) self.cursor=value end
A.ui={itemInput=input,itemTools={IsShown=function() return shown end}}
A.state={id='raid'}
function A:IsMaster() return master end
function A:CaptureHistoryLink() return false end
function A:ReadManualBagItem(bag,slot)
    if bag==0 and (slot==1 or slot==2) then
        return {link='|cffffffff|Hitem:123:0|h[Sample]|h|r',guid='Item-copy'..slot}
    end
end
function configure(f,s,e,m) focused,shown,enabled,master=f,s,e,m end
function IsModifiedClick(kind) return shift and kind=='CHATLINK' end
function setShift(value) shift=value end
function hooksecurefunc(target,key,callback)
    if type(target)=='string' then target,key,callback=_G,target,key end
    local original=target[key]
    target[key]=function(...)
        local result=original(...)
        callback(...)
        return result
    end
end
ChatFrameUtil={InsertLink=function() return false end}
local link='|cffffffff|Hitem:123:0|h[Sample]|h|r'
function HandleModifiedItemClick(item,location)
    -- Simulate native focus loss before the addon post-hook sees the link.
    focused=false
    ChatFrameUtil.InsertLink(item)
    return false
end
ContainerFrameItemButtonMixin={}
function ContainerFrameItemButtonMixin:OnModifiedClick()
    local location={GetBagAndSlot=function() return self:GetBagID(),self:GetID() end}
    return HandleModifiedItemClick(link,location)
end
function clickSlot(slot)
    local control={GetBagID=function() return 0 end,GetID=function() return slot end}
    return ContainerFrameItemButtonMixin.OnModifiedClick(control,'LeftButton')
end
""")
for name in ('Equipment','UI'):
    lua.execute((root/'NauseRaidTools'/f'{name}.lua').read_text(encoding='utf-8'),
                'NauseRaidTools',lua.globals().A)
lua.execute("""
A:InstallManualLootLinkHooks()
A:InstallManualLootLinkHooks()
configure(true,true,true,true)
assert(clickSlot(1)==false,'native handler return changed')
assert(A.ui.itemInput:GetText()=='|cffffffff|Hitem:123:0|h[Sample]|h|r')
assert(A.manualBagSelection.guid=='Item-copy1')
assert(not A.ui.itemInput:HasFocus())
-- Identical item links still select the second physical copy.
assert(clickSlot(2)==false)
assert(A.manualBagSelection.guid=='Item-copy2')
-- An unreadable clicked slot must never select another matching copy.
clickSlot(3)
assert(A.manualBagSelection.unavailable and not A.manualBagSelection.guid)
clickSlot(1)
local original=A.manualBagSelection
configure(false,false,true,true);clickSlot(2)
assert(A.manualBagSelection==original)
configure(false,true,false,true);clickSlot(2)
assert(A.manualBagSelection==original)
configure(false,true,true,false);clickSlot(2)
assert(A.manualBagSelection==original)
configure(false,true,true,true)
local before=A.manualBagSelection
assert(not A:CaptureManualLootLink('not an item link'))
assert(A.manualBagSelection==before)
""")
print('Add Loot hooks passed focus loss, duplicate copies, unreadable slots, hidden/disabled dialog and role checks.')
