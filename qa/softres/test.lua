local folder=assert(debug.getinfo(1,"S").source:sub(2):match("^(.*)/qa/softres/test.lua$"))
local root=folder.."/NauseSoftReserve/"
local S={};local count=0
local function check(ok,why) count=count+1;assert(ok,why) end
local function load(name) return assert(loadfile(root..name))("NauseSoftReserve",S) end
load("vendor/LibDeflate.lua");load("vendor/json.lua");load("Model.lua");load("Import.lua")
local roster={["Leader-Realm"]=true,["Raider-Realm"]=true,["Nyra-Realm"]=true,["Other-Realm"]=true}
local s=S:New("Leader-Realm","test",3)
check(not S:New("Leader-Realm","bad",7),"limit cap")
check(not S:Items({[2]=123},3),"sparse picks accepted")
check(not S:Items({0},3),"zero ID accepted")
local f=assert(io.open(folder.."/qa/softres/export.txt"));local text=f:read("*a");f:close()
local function resolve(name) if roster[name.."-Realm"] then return name.."-Realm" end end
local preview=assert(S:Preview(text,s,resolve));check(#preview.rows==2 and #preview.issues==0,"Gargul export not parsed")
check(S:ApplyPreview(s,preview),"valid import rejected")
check(#s.reserves["Raider-Realm"]==2,"stacked reserves lost")
check(not S:ApplyPreview(s,preview),"stale preview accepted")
check(not S:Preview("https://softres.it/raid/test",s,resolve),"URL treated as export")
check(not S:Preview("!!!!",s,resolve),"malformed export accepted")
local function export(data) local b=S.Deflate:CompressZlib(S.JSON.encode(data));return b end
-- DecodeExport is independently exercised above. Here inject decoded structures to test validation.
local originalDecode=S.DecodeExport
S.DecodeExport=function() return {metadata={id="x"},softreserves={{name="Unknown",items={{id=1}}}}} end
local bad=assert(S:Preview("ignored",s,resolve));check(#bad.issues==1 and not S:ApplyPreview(s,bad),"unknown player imported")
S.DecodeExport=function() return {metadata={id="x"},softreserves={},hardreserves={{id=1}}} end
bad=assert(S:Preview("ignored",s,resolve));check(#bad.issues==1,"hard reserves silently ignored")
S.DecodeExport=function() return {metadata={id="x",hidden=true},softreserves={},bonusrolls={1}} end
bad=assert(S:Preview("ignored",s,resolve));check(#bad.issues==2,"hidden/bonus rules ignored")
S.DecodeExport=originalDecode
check(S:Reserve(s,"Other-Realm",{42},"in-game"),"in-game pick failed")
preview=assert(S:Preview(text,s,resolve));check(preview.rows[1].replaces or preview.rows[2].replaces,"replacement missing preview flag")
check(S:ApplyPreview(s,preview) and s.reserves["Other-Realm"][1]==42,"merge removed absent player")
check(not S:StartRound(s,279259,roster),"unlocked roll accepted")
s.locked=true
check(S:StartRound(s,279259,roster),"single pool start failed")
check(S:AcceptRoll(s,"Other-Realm",99,1,99,roster),"OS not collected alongside SR")
check(S:AcceptRoll(s,"Leader-Realm",100,1,100,roster),"MS not collected alongside SR")
check(S:AcceptRoll(s,"Raider-Realm",2,1,100,roster),"SR roll rejected")
check(S:AcceptRoll(s,"Raider-Realm",3,1,100,roster),"stacked SR roll rejected")
check(not S:AcceptRoll(s,"Raider-Realm",100,1,100,roster),"extra SR counted")
check(S:AcceptRoll(s,"Nyra-Realm",1,1,100,roster),"other SR rejected")
local ranked=S:RankedRolls(s,roster)
check(ranked[1].tier=="SR" and ranked[1].value==3 and ranked[1].additional==1,"SR did not outrank MS100/OS99")
check(ranked[#ranked].valid==false and ranked[#ranked].value==100,"extra roll outranked valid roll")
check(S:CloseRound(s,roster) and s.round.winners[1]=="Raider-Realm" and s.round.tier=="SR","top sorted row not winner")
check(S:RecordWinner(s,roster,1) and #s.reserves["Raider-Realm"]==1,"SR award consumption failed")
check(S:StartRound(s,999,roster),"unreserved round failed")
check(S:AcceptRoll(s,"Leader-Realm",1,1,100,roster) and S:AcceptRoll(s,"Other-Realm",99,1,99,roster),"mixed pool failed")
check(S:CloseRound(s,roster) and s.round.winners[1]=="Leader-Realm","OS99 beat MS1")
s.round=nil
S:StartRound(s,999,roster);S:AcceptRoll(s,"Leader-Realm",90,1,99,roster);S:AcceptRoll(s,"Other-Realm",90,1,99,roster)
check(S:CloseRound(s,roster) and #s.round.winners==2 and S:Reroll(s),"OS tie failed")
check(not S:AcceptRoll(s,"Nyra-Realm",99,1,99,roster),"untied player joined tie")
check(not S:AcceptRoll(s,"Leader-Realm",100,1,100,roster),"tie switched range")
check(S:AcceptRoll(s,"Leader-Realm",42,1,99,roster),"tie correct range failed")
check(S:AcceptRoll(s,"Other-Realm",41,1,99,roster),"second tie roll failed")
check(S:CloseRound(s,roster) and s.round.winners[1]=="Leader-Realm","tie winner wrong")
check(not S:NextTier(s),"sequential tiers still enabled")
s.round=nil;S:StartRound(s,999,roster)
check(not S:AcceptRoll(s,"Leader-Realm",100,100,100,roster),"fake 100-100 accepted")
check(S:AcceptRoll(s,"Leader-Realm",98,1,99,roster),"OS rejected")
check(not S:AcceptRoll(s,"Leader-Realm",99,1,100,roster),"duplicate switched to MS")
s.round.passed["Leader-Realm"]=true
check(S:CloseRound(s,roster) and #s.round.winners==0,"Pass remained eligible")
-- Runtime and UI smoke test with representative WoW frame and host transport mocks.
local function copy(t) if type(t)~="table" then return t end;local o={};for k,v in pairs(t) do o[k]=copy(v) end;return o end
local sent={};local base={roster=roster,me="Leader-Realm",leader="Leader-Realm",protocol=11,Copy=copy,Client={}}
function base:IsLeader() return self.me==self.leader end
function base:Resolve(name) if roster[name] then return name end;return resolve(name) end
function base:Send(packet,target) packet.protocol=self.protocol;sent[#sent+1]={packet=copy(packet),target=target};return true end
function base:Packet() self.originalCalled=true end
function base:Print(text) self.lastPrint=text end
function base.Client:ServerTime() return 100 end
function base.Client:Uptime() return 100 end
function base.Client:InRaid() return true end
function base.Client:ClockReady() return true end
function base.Client:Combat() return false end
function base.Client:Call() return false end
NauseRaidTools=base
local meta;meta={__index=function(t,k) return function(self,...)
    if k=="CreateFontString" or k=="CreateTexture" then return setmetatable({},meta) end
    if k=="GetText" then return rawget(self,"text") or "" end
    if k=="SetText" then self.text=(...) end
    if k=="SetEnabled" then self.enabled=(...) end
    if k=="Show" then self.shown=true end
    if k=="Hide" then self.shown=false end
    if k=="GetStringHeight" then return 500 end
    if k=="GetWidth" then return 600 end
    if k=="SetScript" then local key,fn=...;self.scripts=rawget(self,"scripts") or {};self.scripts[key]=fn end
end end}
CreateFrame=function() return setmetatable({countdown=false,TitleText=setmetatable({},meta)},meta) end
S.CreateUIFrame=function(_,...) return CreateFrame(...) end
S.ShowConfirmation=function(_,...) return StaticPopup_Show(...) end
SlashCmdList={};UISpecialFrames={};UIParent={};RANDOM_ROLL_RESULT="%s rolls %d (%d-%d)"
load("Runtime.lua");load("UIComponents.lua");load("UI.lua")
check(S:Command("new 3"),"host start failed")
check(S:Command("reserve 279259 279259"),"host reservation failed")
local session=S.session
check(not S:Handle("Nobody-Realm",{id=session.id,revision=session.revision,action="reserve",items={1}}),"spoofed sender accepted")
check(not S:Handle("Raider-Realm",{id="old",revision=session.revision,action="reserve",items={1}}),"stale session request accepted")
check(S:Handle("Raider-Realm",{id=session.id,revision=session.revision,action="reserve",items={279259}}),"authenticated request rejected")
check(S:Command("lock") and S:Command("roll 279259"),"host roll commands failed")
S.events.scripts.OnEvent(nil,"CHAT_MSG_SYSTEM","Other rolls 100 (1-100)")
check(session.round.rolls["Other-Realm"][1]==100,"non-reserver MS roll not accepted")
S.events.scripts.OnEvent(nil,"CHAT_MSG_SYSTEM","Raider rolls 85 (1-100)")
check(session.round.rolls["Raider-Realm"][1]==85,"localized system roll parse failed")
check(S:Command("close") and S:Command("record"),"runtime record failed")
S:Show();check(type(S.ui.output.text)=="string" and S.ui.output.text:find("RECENT WINNERS",1,true),"management UI failed")
check(S:ValidSnapshot(S.session),"valid snapshot rejected")
base:Packet("Raider-Realm",{kind="nrt-sr-experiment-6",protocol=11,action="snapshot",data={}})
check(S.session==session,"nonleader replaced session")
base:Packet("Raider-Realm",{kind="other"});check(base.originalCalled,"base packets intercepted")
check(S:Command("end") and not S.session,"end failed")
check(NauseRaidToolsDB==nil,"experiment touched baseline storage")
-- Separate Lua globals model an independently installed raider client.
local peerBase=copy(base);peerBase.me="Raider-Realm";peerBase.originalCalled=nil
local outbound={}
function peerBase:Send(packet,target) packet.protocol=self.protocol;outbound[#outbound+1]=copy(packet);return true end
local env=setmetatable({NauseRaidTools=peerBase,NauseSoftReserveDB={schema=1,history={}},SlashCmdList={},UISpecialFrames={}}, {__index=_G})
local peer={CreateUIFrame=function(_,...) return env.CreateFrame(...) end,ShowConfirmation=function(_,...) return StaticPopup_Show(...) end}
for _,file in ipairs({"vendor/LibDeflate.lua","vendor/json.lua","Model.lua","Import.lua","Runtime.lua","UI.lua"}) do assert(loadfile(root..file,"t",env))("NauseSoftReserve",peer) end
check(S:Command("new 2"),"second host session failed")
local snapshot=copy(sent[#sent].packet)
peerBase:Packet("Leader-Realm",snapshot)
check(peer.session and peer.session.id==S.session.id,"peer did not receive host snapshot")
check(peer:Command("reserve 279259"),"peer request not queued")
base:Packet("Raider-Realm",outbound[#outbound])
check(S.session.reserves["Raider-Realm"][1]==279259,"remote own-character reservation failed")
local update
for _,message in ipairs(sent) do if message.packet.action=="snapshot" then update=copy(message.packet) end end
peerBase:Packet("Leader-Realm",update)
check(peer.session.reserves["Raider-Realm"][1]==279259,"reservation acknowledgement not synchronized")
peerBase:Packet("Leader-Realm",snapshot)
check(peer.session.revision==S.session.revision,"older snapshot overwrote current picks")
check(S:Command("end"),"host end failed")
peerBase:Packet("Leader-Realm",copy(sent[#sent].packet))
check(not peer.session,"peer retained ended session")
peerBase:Packet("Leader-Realm",update)
check(not peer.session,"delayed snapshot resurrected ended session")
-- Run-type choice, settings routing and conflicting-mode guards.
function base.Client:ClockReady() return true end
function base:Act(op) if op=="start" then self.state={id="guild"};return true elseif op=="end" then self.state=nil;return true end end
function base:Reduce() self.reduceCalled=true;return true end
function base:ResumeSession() self.state={id="recovered"};return true end
function base:BuildUI() end
function base:Render() end
function base:RenderSettings() end
StaticPopupDialogs={};local popup
StaticPopup_Show=function(name) popup=name end
load("RunMode.lua")
local function frame() return CreateFrame() end
base.ui={start=frame(),finish=frame(),resume=frame(),main=frame(),voting=frame(),settingsHub=frame(),settingsPages={Tools=frame()}}
base:BuildUI()
base.ui.start.scripts.OnClick()
check(S.runChooser.shown and not base.state and not S.session,"settings Start created a session before choosing")
S.runChooser:Hide()
check(not base.state and not S.session,"cancelling chooser started a run")
base.me="Raider-Realm"
check(not S:ShowRunChooser(),"nonleader opened chooser")
base.me="Leader-Realm"
check(S:ShowRunChooser(),"leader could not open chooser")
base.me="Raider-Realm"
check(not S:ChooseRun("Guild Run"),"leader-loss race started guild run")
base.me="Leader-Realm"
check(S:ChooseRun("Guild Run") and base.state and not S.session,"Guild Run routed to wrong workflow")
check(not S:Begin(2),"PuG started during Guild Run")
check(not S:Command("resume"),"PuG recovery started during Guild Run")
check(not S:ShowRunChooser(),"mode switch allowed during Guild Run")
base:Act("end")
check(not S:ChooseRun("PuG Run",7) and not S.session,"invalid SR limit started session")
check(S:ChooseRun("PuG Run",2) and S.session.limit==2 and not base.state,"PuG Run routed to wrong workflow")
check(base.ui.start.text=="Open PuG session" and base.ui.finish.enabled,"settings did not reflect PuG session")
check(not base:Reduce("Leader-Realm",{op="start"}),"direct Guild reducer bypassed mode guard")
check(not base:ResumeSession(),"Guild recovery overlapped PuG session")
base.ui.finish.scripts.OnClick()
check(popup=="NAUSE_SR_END_RUN","settings End used Guild confirmation for PuG")
StaticPopupDialogs.NAUSE_SR_END_RUN.OnAccept({data={sid=S.session.id}})
check(not S.session and base.ui.start.text=="Start session","PuG End failed to restore idle settings")
base.demo=true;base:Act("start")
check(base.state and not S.session,"solo demo no longer uses existing start path")
base.demo=nil;base.state=nil
load("Browser.lua")
local db={}
function db:Search() return {{id=279259},{id=279265},{id=284716}} end
function db:GetName(id) return ({[279259]="Ironwood Blade",[279265]="Azerothium Legplates",[284716]="Band of the Better Half"})[id] end
function db:GetLink(id) return "item:"..id end
function db:GetSources(id) if id==284716 then return {} end;return {{instance="Fixture Raid",boss=id==279259 and "Boss A" or "Boss B"}} end
function base:ItemLibrary() return db end
check(S:StartCatalogue(),"catalogue did not start")
S:CatalogueStep()
check(#S:BrowserResults()==3,"missing source item disappeared")
check(#S:BrowserResults("Fixture Raid")==2,"instance filter failed")
check(#S:BrowserResults("Fixture Raid","Boss A")==1,"boss filter failed")
check(#S:BrowserResults(nil,nil,"IRONWOOD")==1,"case insensitive name search failed")
check(#S:BrowserResults(nil,nil,"284716")==1,"ID search failed")
check(#S:BrowserOptions()==1 and #S:BrowserOptions("Fixture Raid")==2,"source menus incorrect")
check(S:Begin(2),"browser session failed")
S:ResetBrowserDraft()
check(S:EditBrowserPick(279259) and S:EditBrowserPick(279259),"click/stack failed")
check(not S:EditBrowserPick(279265),"draft exceeded cap")
check(S:SubmitBrowserDraft() and #S.session.reserves[base.me]==2,"browser submission failed")
S:ResetBrowserDraft();check(S:EditBrowserPick(nil,1) and #S.browserDraft==1,"remove slot failed")
S.session.reserves[base.me]={279265}
check(not S:SubmitBrowserDraft(),"stale own picks overwritten")
S:ResetBrowserDraft();S.session.locked=true
check(not S:EditBrowserPick(279259),"locked browser edited")
S.session.locked=false;S.browserInstance="Fixture Raid"
check(S:UseBrowserInstance() and S.session.raidName=="Fixture Raid","leader raid selection failed")
S:ShowBrowser();check(S.browser and S.browser.rows[1].entry,"browser window smoke failed")
check(S:Command("end"),"browser session end failed")

function db:GetInstances() return {{name="Fixture Raid"},{name="Second Raid"}} end
local previousSources=db.GetSources
function db:GetSources(id) if id==12345 then return {} end;if id==284716 then return {{instance="Second Raid",boss="Boss C"}} end;return previousSources(self,id) end
load("PugSetup.lua")
check(S:ChooseRun("PuG Run",2) and not S.session,"PuG selection started before scope confirmation")
check(not S:ConfirmPugSetup(),"empty scope started run")
S.setupSelection={["Fixture Raid"]=true,["Second Raid"]=true}
check(S:ConfirmPugSetup() and S.session.selectedInstances["Second Raid"],"multi-instance confirmation failed")
check(S:Reserve(S.session,base.me,{279259,284716},"in-game"),"shared picks across instances failed")
check(not S:Reserve(S.session,base.me,{279259,284716,279265},"in-game"),"shared cap applied per instance")
check(not S:Reserve(S.session,base.me,{12345},"in-game"),"out of scope item accepted")
check(not S:ApplyPreview(S.session,{rows={{player=base.me,items={12345}}}}),"import bypassed scope")
S:StartCatalogue();S:CatalogueStep()
check(#S:BrowserResults()==3 and #S:BrowserOptions()==2,"multi-instance browsing failed")
S.session.selectedInstances={["Fixture Raid"]=true}
check(#S:BrowserResults()==2 and #S:BrowserOptions()==1,"scope filter leaked other instance")
check(not S:UseBrowserInstance(),"browser mutated confirmed scope")
local countPopup=0;local previousShow=S.ShowBrowser
S.ShowBrowser=function() countPopup=countPopup+1 end
S.popupSessions={};base:Packet("Leader-Realm",{kind="irrelevant"});base:Packet("Leader-Realm",{kind="irrelevant"})
check(countPopup==1,"reservation popup repeated for same session")
S.ShowBrowser=previousShow
check(S:Command("end"),"scoped run end failed")

load("RollUI.lua")
local nativeCalls={};RandomRoll=function(low,high) nativeCalls[#nativeCalls+1]={low,high} end
check(S:Begin(2),"roll UI session failed")
S.session.locked=true;check(S:Command("roll 271215"),"mixed window failed")
check(S.rollUI.ms.enabled and S.rollUI.os.enabled,"both choices not enabled together")
local key=S:RollKey()
check(S:ClickNativeRoll("OS",key) and nativeCalls[1][2]==99,"OS native call wrong")
check(not S.session.round.rolls[base.me],"button fabricated native result")
check(not S:ClickNativeRoll("MS",key),"button changed choice for second chance")
S.events.scripts.OnEvent(nil,"CHAT_MSG_SYSTEM","Leader rolls 98 (1-99)")
check(S.session.round.playerTiers[base.me]=="OS","system OS type missing")
check(S:AcceptRoll(S.session,"Raider-Realm",1,1,100,base.roster),"parallel MS roll failed")
check(S:Command("close") and S.session.round.winners[1]=="Raider-Realm","MS priority failed")
S:Command("cancel");S.session.locked=false;S:Reserve(S.session,base.me,{271215,271215},"in-game");S.session.locked=true
S:Command("roll 271215")
check(S:ClickNativeRoll("MS",S:RollKey()) and S:ClickNativeRoll("MS",S:RollKey()),"stacked SR native calls failed")
check(not S:ClickNativeRoll("MS",S:RollKey()),"extra SR native click allowed")
check(not S:ClickNativeRoll("OS",key),"old context reused")
S:Command("cancel");S:Command("end")
load("AwardFlow.lua");load("AwardUI.lua")
local lastDialog
StaticPopup_Show=function(name) lastDialog={name=name};return lastDialog end
function base.Client:Combat() return false end
function base.Client:Call() return false end
function base.Client:Invoke(fn,...) if type(fn)~="function" then return false end;return pcall(fn,...) end
check(S:Begin(2),"award session failed")
S:Reserve(S.session,base.me,{271215},"in-game");S:Reserve(S.session,"Raider-Realm",{271215},"in-game")
S.session.locked=true
S:StartRound(S.session,271215,base.roster)
S:AcceptRoll(S.session,base.me,85,1,100,base.roster);S:AcceptRoll(S.session,"Raider-Realm",72,1,100,base.roster);S:CloseRound(S.session,base.roster)
check(S:Command("record") and #S.session.history==0 and #S.session.reserves[base.me]==1,"review consumed SR before confirmation")
local oldDialog=lastDialog
StaticPopupDialogs.NAUSE_SR_CONFIRM_AWARD.OnAccept(oldDialog)
local h=S.session.history[1]
check(h and h.id and h.status=="pending" and h.consumed and #S.session.reserves[base.me]==0,"confirmed award did not consume exactly one SR")
StaticPopupDialogs.NAUSE_SR_CONFIRM_AWARD.OnAccept(oldDialog)
check(#S.session.history==1,"duplicate confirmation created award")
check(not S:Command("end"),"run ended with pending delivery")
check(not S:AmendAward(h.id,99,"Raider-Realm","test"),"stale correction accepted")
check(not S:AmendAward(h.id,h.revision,"Council-Realm","test"),"nonroller corrected winner")
check(S:AmendAward(h.id,h.revision,"Raider-Realm","Correct winner"),"pending correction failed")
check(#S.session.reserves[base.me]==1 and #S.session.reserves["Raider-Realm"]==0 and h.roll==72,"correction reservation rollback wrong")
check(S:BindAward(base.me,h.id,h.revision,"copy-guid"),"holder binding failed")
check(not S:BindAward("Raider-Realm",h.id,h.revision,"other-guid"),"bound holder overwritten")
check(not S:ConfirmDelivery(h.id,1),"stale delivery accepted")
local requestedGUID
function base:FindTradeItem(entry) requestedGUID=entry.guid;if entry.guid=="copy-guid" then return 0,1 end;return nil,nil,"Missing copy" end
function base:WinnerInTradeRange() return true end
local partner="Wrong-Realm"
function base:TradePartner() return partner end
local initiated,offered,cursor
InitiateTrade=function(unit) initiated=unit end
C_Container={PickupContainerItem=function() cursor=true end}
GetTradePlayerItemLink=function() return nil end
CursorHasItem=function() return cursor==true end
ClickTradeButton=function(slot) offered=slot;cursor=false end
check(S:TradeAward(h,false) and requestedGUID=="copy-guid" and initiated==base.roster[h.winner],"exact-copy trade open failed")
check(not S:TradeAward(h,true) and not offered,"wrong partner received offer")
partner=h.winner
check(S:TradeAward(h,true) and offered==1 and h.status=="pending","offer falsely confirmed delivery")
check(S:ConfirmDelivery(h.id,h.revision) and h.status=="delivered","manual delivery confirmation failed")
check(not S:AmendAward(h.id,h.revision,nil,"cancel delivered"),"delivered award rolled back")
S:ShowAwardQueue();check(S.awardUI and S.awardUI.summary.text,"award queue UI failed")
S:StartRound(S.session,271215,base.roster);S:AcceptRoll(S.session,base.me,50,1,100,base.roster);S:CloseRound(S.session,base.roster)
check(S:RecordWinner(S.session,base.roster,100),"second-copy award failed")
local second=S.session.history[#S.session.history]
check(not S:BindAward(base.me,second.id,second.revision,"copy-guid"),"same GUID assigned twice")
check(S:AmendAward(second.id,second.revision,nil,"Cancelled before delivery") and #S.session.reserves[base.me]==1,"cancellation failed to restore SR")
check(not S:AmendAward(second.id,second.revision,nil,"repeat"),"cancelled award restored SR twice")
check(S:Command("end"),"resolved run would not end")
load("LeaderRollUI.lua")
check(S:Begin(2),"leader table start failed")
S.session.locked=true;S:Command("roll 271215")
S.events.scripts.OnEvent(nil,"CHAT_MSG_SYSTEM","Leader rolls 50 (1-100)")
S.events.scripts.OnEvent(nil,"CHAT_MSG_SYSTEM","Leader rolls 99 (1-100)")
check(S.leaderRollUI and S.leaderRollUI.rows[2][1].text:find("(1)",1,true),"additional roll row missing")
check(S.leaderRollUI.rows[2][5].text:find("allowance",1,true),"extra roll not flagged")
S:Command("cancel");S:Command("end")

local combined=S:New("Leader-Realm","ranking-test",2)
S:Reserve(combined,"Nyra-Realm",{271215},"test");combined.locked=true;S:StartRound(combined,271215,base.roster)
check(S:AcceptRoll(combined,"Nyra-Realm",99,1,99,base.roster),"reserver could not opt for OS")
check(S:AcceptRoll(combined,base.me,1,1,100,base.roster),"non-reserver MS failed")
check(S:RankedRolls(combined,base.roster)[1].tier=="MS","OS reservation was incorrectly promoted to SR")
check(S:RankedRolls(combined,base.roster)[2].hasSR,"OS row lost reservation badge")
check(not S:AcceptRoll(combined,base.me,100,1,100,base.roster),"duplicate accepted")
check(not S:AcceptRoll(combined,base.me,99,1,99,base.roster),"second duplicate accepted")
local logged=combined.round.attempts
check(logged[#logged].additional==2,"second additional roll label wrong")
for i=1,25 do S:AcceptRoll(combined,base.me,99,1,100,base.roster) end
check(combined.round.attemptCounts[base.me]==20,"per-player log is unbounded")

check(S:Begin(2),"sync round setup failed")
S.session.locked=true;S:Command("roll 271215")
for _,file in ipairs({"RollUI.lua"}) do assert(loadfile(root..file,"t",env))("NauseSoftReserve",peer) end
local function latestSnapshot()
    for i=#sent,1,-1 do if sent[i].packet.action=="snapshot" then return copy(sent[i].packet) end end
end
peerBase:Packet("Leader-Realm",latestSnapshot())
check(peer.rollUI and peer.rollUI.ms.enabled and peer.rollUI.os.enabled,"remote prompt did not enable both choices")
S.events.scripts.OnEvent(nil,"CHAT_MSG_SYSTEM","Leader rolls 1 (1-100)")
S.events.scripts.OnEvent(nil,"CHAT_MSG_SYSTEM","Raider rolls 99 (1-99)")
S.events.scripts.OnEvent(nil,"CHAT_MSG_SYSTEM","Raider rolls 99 (1-99)")
peerBase:Packet("Leader-Realm",latestSnapshot())
check(peer.session.round.playerTiers["Raider-Realm"]=="OS" and #peer.session.round.attempts==3,"OS and duplicate entries did not synchronize")
local badSnapshot=latestSnapshot();badSnapshot.data.round.attempts[1].value="fake"
local before=peer.session
peerBase:Packet("Leader-Realm",badSnapshot)
check(peer.session==before,"malformed roll table accepted")
S:Command("cancel");S:Command("end")

load("Countdown.lua")
local now=1000;local clockOK=true
function base.Client:ServerTime() return now end
function base.Client:ClockReady() return clockOK end
check(S:Begin(2) and S.session.rollDuration==30,"default 30 second timer missing")
S.session.locked=true
check(S:Command("roll 271215") and S.session.round.deadline==1030,"item deadline not stamped")
local timed=S.session.round
check(not S:SetRollDuration(60) and timed.deadline==1030,"active timer extended by config")
now=1029;check(S:AcceptRoll(S.session,base.me,42,1,100,base.roster),"timely roll rejected")
now=1030
check(not S:AcceptRoll(S.session,"Raider-Realm",100,1,100,base.roster),"deadline-boundary roll accepted")
check(timed.closed and timed.winners[1]==base.me and timed.closeReason=="deadline","deadline did not select timely winner")
check(#S.session.history==0,"deadline automatically awarded item")
local rev=S.session.revision
check(not S:ExpireRound() and S.session.revision==rev,"timer closed/published twice")
check(not S:Request("pass"),"late Pass withdrew winning roll")
S:Command("cancel")
check(S:SetRollDuration(10),"idle timer config failed")
now=1100;S:Command("roll 271215")
S:AcceptRoll(S.session,base.me,50,1,99,base.roster);S:AcceptRoll(S.session,"Raider-Realm",50,1,99,base.roster)
now=1110;S.countdownTicker.scripts.OnUpdate(nil,0.11)
check(S.session.round.closed and #S.session.round.winners==2,"ticker missed tie at expiry")
now=1200;check(S:Command("reroll") and S.session.round.deadline==1210,"tie did not get fresh timer")
check(not S:AcceptRoll(S.session,"Nyra-Realm",99,1,99,base.roster),"untied player entered timed tie")
now=1209;check(S:AcceptRoll(S.session,base.me,45,1,99,base.roster),"timed tie native range failed")
now=1210;check(not S:AcceptRoll(S.session,"Raider-Realm",99,1,99,base.roster),"late tie roll accepted")
check(S.session.round.winners[1]==base.me,"late tie roll changed winner")
S:Command("cancel");check(S:SetRollDuration(0),"manual mode not configurable")
now=1300;S:Command("roll 271215");now=9999
check(S.session.round.deadline==nil and not S:ExpireRound(),"manual mode auto-closed")
check(S:AcceptRoll(S.session,base.me,10,1,100,base.roster),"manual roll rejected")
check(S:Command("close") and S.session.round.closeReason=="manual","Stop early/manual close failed")
S:Command("cancel");S:SetRollDuration(5);now=10000;S:Command("roll 271215");now=10001
check(S:Command("close") and S.session.round.closed,"stop before expiry failed")
S:Command("cancel");now=11000;S:Command("roll 271215")
clockOK=false
check(not S:AcceptRoll(S.session,base.me,99,1,100,base.roster),"clock failure accepted timed roll")
clockOK=true;now=11005;S:ExpireRound()
check(#S.session.round.winners==0,"empty expired round invented winner")
local snap=copy(S.session);snap.round.deadline=snap.round.deadline+1
check(not S:ValidSnapshot(snap),"mismatched deadline accepted")
S:Command("cancel")
check(not S:SetRollDuration(601) and not S:SetRollDuration(-1),"invalid timer setting accepted")
check(S.leaderRollUI.countdown and S.rollUI.countdown,"countdown labels missing")
check(S:Command("end"),"timed run end failed")

function base.Client:Uptime() return now end
now=20000;check(S:Begin(2) and S:SetRollDuration(30),"timer sync setup failed")
S.session.locked=true;S:Command("roll 271215")
function peerBase.Client:ClockReady() return true end
function peerBase.Client:ServerTime() return now end
for _,file in ipairs({"LeaderRollUI.lua","Countdown.lua"}) do assert(loadfile(root..file,"t",env))("NauseSoftReserve",peer) end
peerBase:Packet("Leader-Realm",latestSnapshot())
check(peer.session.round.deadline==20030,"leader deadline did not synchronize")
now=20015;peer:RenderCountdown()
check(peer.rollUI.countdown.text:find("15 seconds",1,true),"peer did not display remaining shared time")
check(not peer:SetRollDuration(60),"nonleader changed timer")
now=20030
peer:Request("pass")
base:Packet("Raider-Realm",outbound[#outbound])
check(S.session.round.closed and not S.session.round.passed["Raider-Realm"],"late Pass changed the result before ticker closure")
peerBase:Packet("Leader-Realm",latestSnapshot())
check(peer.session.round.closed and not peer.rollUI.ms.enabled and not peer.rollUI.os.enabled,"expired peer state/buttons incorrect")
S:Command("cancel");S:Command("end")
print("SOFT RESERVE PASS: "..count.." checks; imports, eligibility, stacked rolls, ties, tiers, history, transport authority, command and UI smoke checks.")
