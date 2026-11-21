from pathlib import Path
from lupa.lua51 import LuaRuntime
root=Path(__file__).resolve().parent.parent
lua=LuaRuntime(unpack_returned_tuples=True)
source=(root/'NauseRaidTools/VersionCheck.lua').read_text(encoding='utf-8')
lua.execute(r"""
local source=...
local count=0
local function check(ok,why) count=count+1;assert(ok,why) end
local function client(name,mode)
    local e=setmetatable({now=100,mode=mode,units={player=name},guild={},sent={},frames={}},{__index=_G})
    e._G=e
    e.CreateFrame=function()
        local f={RegisterEvent=function() end,SetScript=function(self,k,fn) self[k]=fn end};e.frames[#e.frames+1]=f;return f
    end
    local a={version='0.12.0-alpha.78',protocol=19,Client={},me=name,state={id='protected-session'},rev=7}
    e.NauseSoftReserve={version='0.1.0-experimental.16'}
    function a:Name(unit) return e.units[unit] end
    function a:IsForever() return true end
    function a:Print(t) e.message=t end
    function a:BuildUI() error('unexpected UI build') end
    function a.Client:Invoke(fn,...)
        if type(fn)~='function' then return false end
        return pcall(fn,...)
    end
    function a.Client:InRaid() return e.mode=='RAID' end
    function a.Client:InGroup() return e.mode=='RAID' or e.mode=='PARTY' end
    function a.Client:Uptime() return e.now end
    function a.Client:Call(api,...)
        if api=='UnitIsConnected' then return true,e.offline~=(...) end
        if api=='C_ChatInfo.SendAddonMessage' then
            local prefix,message,channel,target=...
            e.sent[#e.sent+1]={prefix,message,channel,target};return true
        end
        return true
    end
    e.IsInGuild=function() return e.inGuild==true end
    e.GetNumGuildMembers=function() return #e.guild end
    e.GetGuildRosterInfo=function(i) local g=e.guild[i];return g and g.name,nil,nil,nil,nil,nil,nil,nil,g and g.online end
    e.GuildRoster=function() e.guildRequested=true end
    local fn=assert(loadstring(source));setfenv(fn,e);fn('NauseRaidTools',a)
    return a,e
end
local a,e=client('Raider-Realm','SOLO')
check(a:StartVersionCheck(false),'solo version check blocked')
check(a.versionCheck.scope=='SOLO' and a.versionCheck.members[a.me].sr=='0.1.0-experimental.16','own versions not detected')
check(#e.sent==0 and a.state.id=='protected-session' and a.rev==7,'solo check changed session or sent network data')
e.mode='PARTY';e.units.party1='Other-Realm';e.now=106
assert(a:StartVersionCheck(false))
check(a.versionCheck.scope=='PARTY' and e.sent[1][3]=='PARTY','ordinary party member could not query')
local b,be=client('Other-Realm','PARTY');be.units.party1='Raider-Realm'
b:VersionCheckMessage('NauseRTVersion',e.sent[1][2],'PARTY','Raider-Realm')
check(#be.sent==1 and be.sent[1][3]=='WHISPER' and be.sent[1][4]=='Raider-Realm','peer reply was not private')
a:VersionCheckMessage('NauseRTVersion',be.sent[1][2],'WHISPER','Other-Realm')
check(a:VersionMemberStatus('Other-Realm')=='Matched','peer versions failed to match')
be.NauseSoftReserve=nil;be.now=106
b:VersionCheckMessage('NauseRTVersion',e.sent[1][2],'PARTY','Raider-Realm')
a:VersionCheckMessage('NauseRTVersion',be.sent[2][2],'WHISPER','Other-Realm')
check(a:VersionMemberStatus('Other-Realm')=='SoftRes not enabled','missing companion was not distinguished')
be.now=112;be.NauseSoftReserve={version='0.1.0-experimental.15'}
b:VersionCheckMessage('NauseRTVersion',e.sent[1][2],'PARTY','Raider-Realm')
a:VersionCheckMessage('NauseRTVersion',be.sent[3][2],'WHISPER','Other-Realm')
check(a:VersionMemberStatus('Other-Realm')=='SoftRes mismatch','companion mismatch missed')
local id=a.versionCheck.id
local before=#be.sent
b:VersionCheckMessage('NauseRTVersion','Q|1-2-3','PARTY','Outsider-Realm')
check(#be.sent==before,'outsider got a version reply')
a:VersionCheckMessage('NauseRTVersion','R|'..id..'|0.12.0-alpha.78|19|0.1.0-experimental.16','WHISPER','Outsider-Realm')
check(not a.versionCheck.members['Outsider-Realm'],'outsider injected results')
a:VersionCheckMessage('NauseRTVersion','R|wrong|0.12.0-alpha.78|19|0.1.0-experimental.16','WHISPER','Other-Realm')
check(a:VersionMemberStatus('Other-Realm')=='SoftRes mismatch','stale result overwrote current check')
a:VersionCheckMessage('NauseRTVersion','R|'..id..'|0.12.0-alpha.78|18|0.1.0-experimental.16','WHISPER','Other-Realm')
check(a:VersionMemberStatus('Other-Realm')=='Incompatible','protocol mismatch missed')
assert(a:StartVersionCheck(false));check(a.versionCheck.id==id,'request cooldown failed')
e.now=112;e.offline='party1';assert(a:StartVersionCheck(false))
check(a:VersionMemberStatus('Other-Realm')=='Offline','offline peer shown as missing')
e.now=173;check(a:VersionMemberStatus(a.me)=='Refresh needed','old result presented as current')
e.mode='SOLO';e.inGuild=true;e.guild={{name='Other Realm',online=true}};e.now=180
local sentBefore=#e.sent
assert(a:StartVersionCheck(false))
check(a.versionCheck.scope=='SOLO' and a.versionCheck.peers['Other-Realm']==nil,'ungrouped check included guild members')
check(#e.sent==sentBefore and not e.guildRequested,'ungrouped check contacted the guild')
a:VersionCheckMessage('NauseRTVersion','Q|9-9-9','GUILD','Other-Realm')
check(#e.sent==sentBefore,'guild query received a reply')
check(not a:StartVersionCheck(false,'GUILD'),'guild scope remained available')
e.now=250;check(a:VersionMemberStatus(a.me)=='Installed','local installed version incorrectly expired')
e.mode='RAID';e.units.raid1='Other-Realm';e.now=260;assert(a:StartVersionCheck(false))
check(a.versionCheck.scope=='RAID','ordinary raid member could not query')
check(a.state.id=='protected-session' and a.rev==7,'version check changed raid authority or state')
print('PASS: '..count..' version checks; solo, all-role party/raid, no guild traffic, both addons, rate limits, stale/outsider rejection and session isolation')
""",source)
