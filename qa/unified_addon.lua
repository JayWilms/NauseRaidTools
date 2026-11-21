local root=...
local client=assert(loadfile(root.."/qa/softres/alpha55_client.lua"))(root)
local a,e=client("Leader-Realm",true)
local s=a.SoftRes
assert(s and s.bundled and e.NauseSoftReserve==s and s.base==a,"missing embedded module")
assert(s.version==a.version,"module has a separate version")
assert(e.SLASH_NAUSERAIDTOOLS1=="/nrt" and e.SLASH_NAUSESR1==nil and e.SlashCmdList.NAUSESR==nil,"command registration missing")
local saved={schema=1,generation=5,history={{sentinel=true}},rollDuration=45}
e.NauseSoftReserveDB=saved
assert(s:DB()==saved and s:DB().history[1].sentinel and s:DB().generation==5,"existing saved variable replaced")
a:BuildUI()
assert(a.ui.assignments and a.ui.softResTest and s.ShowPugSetup and s.ShowResults,"unified UI did not construct")
assert(s.Deflate and s.JSON,"embedded import libraries missing")
s:ShowBrowser();assert(s.browser and s.browser:IsShown(),"embedded reservation browser failed")
assert(a:InstalledSoftResVersion()==a.version,"version check reports old companion version")
print("Unified addon: full native TOC load, one namespace/version, command hooks, saved-variable preservation and combined UI passed")

-- Public commands are window shortcuts only; legacy subcommands cannot act.
local calls={}
for _,name in ipairs({"ShowLauncher","ShowSettings","ShowMyAssignments","ShowRaidChecks","ShowResponses","ShowLootWindow","ShowLootTimers","ShowHistory","StartVersionCheck"}) do
 local action=name;a[action]=function(_,arg) calls[#calls+1]={action,arg} end
end
s.Show=function() calls[#calls+1]={"SoftRes"} end
local messages={};a.Print=function(_,message) messages[#messages+1]=message end
local slash=e.SlashCmdList.NAUSERAIDTOOLS
local cases={{"","ShowLauncher"},{"settings","ShowSettings"},{"assignments","ShowMyAssignments",false},{"raidcheck","ShowRaidChecks"},{"responses","ShowResponses"},{"loot","ShowLootWindow","timer"},{"timer","ShowLootTimers"},{"softres","SoftRes"},{"history","ShowHistory"},{"version","StartVersionCheck",true}}
for _,case in ipairs(cases) do
 calls={};slash("  "..case[1]:upper().."  ")
 assert(#calls==1 and calls[1][1]==case[2] and calls[1][2]==case[3],"wrong shortcut route: "..case[1])
end
local acted=false;s.Command=function() acted=true end;a.StartDemo=function() acted=true end;a.LeaveTest=function() acted=true end
for _,input in ipairs({"test","leave-test","diagnostics","diagnostics start","diagnostics stop","sync","takeover","versions","check","resume","pugsetup","results","softres test","softres record","softres end","softres lock","softres reserve 6460","softres stop-test"}) do
 calls={};messages={};slash(input)
 assert(not acted and #calls==0 and #messages==1 and messages[1]:find("Unknown command",1,true),"retired command still active: "..input)
end
messages={};slash("help");local help=table.concat(messages,"\n")
for _,case in ipairs(cases) do assert(help:find("/nrt"..(case[1]~="" and " "..case[1] or ""),1,true),"help omitted shortcut") end
print("Command cleanup: all window shortcuts, My Assignments context, exact parsing, help and retired aliases passed")
