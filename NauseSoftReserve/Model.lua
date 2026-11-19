local _, S = ...
S.version = "0.1.0-experimental.18"
S.maxPlayers, S.maxReserves = 40, 6
local function integer(n, lo, hi) return type(n)=="number" and n==math.floor(n) and n>=lo and n<=hi end
S.Integer = integer
function S:Items(items, limit)
    if type(items)~="table" or #items>limit then return nil,"Reservation limit exceeded." end
    local result,count={},0
    for k,v in pairs(items) do
        count=count+1
        if not integer(k,1,#items) or not integer(v,1,2147483647) then return nil,"Invalid item IDs." end
        result[k]=v
    end
    if count~=#items then return nil,"Invalid reservation list." end
    return result
end
function S:New(owner, id, limit)
    if not integer(limit,1,self.maxReserves) then return nil,"Choose 1–6 reserves per player." end
    return {owner=owner,id=id,revision=0,limit=limit,locked=false,reserves={},sources={},history={}}
end
function S:Reserve(session, player, items, source)
    if session.locked then return false,"Reservations are locked." end
    local clean,why=self:Items(items,session.limit)
    if not clean then return false,why end
    if not session.reserves[player] then
        local n=0;for _ in pairs(session.reserves) do n=n+1 end
        if n>=self.maxPlayers then return false,"Raid reservation capacity reached." end
    end
    session.reserves[player]=clean;session.sources[player]=source or "in-game"
    session.revision=session.revision+1
    return true
end
local priority={SR=1,MS=2,OS=3}
function S:StartRound(session,item,roster)
    if not session.locked then return false,"Lock reservations before rolling." end
    if session.round then return false,"Finish or cancel the current item first." end
    if not integer(item,1,2147483647) then return false,"Invalid item ID." end
    local pool={}
    for name in pairs(roster) do
        local count=0;for _,id in ipairs(session.reserves[name] or {}) do if id==item then count=count+1 end end
        if count>0 then pool[name]=count end
    end
    session.rollSerial=(session.rollSerial or 0)+1
    session.round={epoch=session.rollSerial,item=item,tier="MS",singlePool=true,eligible=pool,rolls={},playerTiers={},attempts={},attemptCounts={},passed={},closed=false}
    return true
end
function S:AcceptRoll(session,player,value,low,high,roster)
    local r=session.round
    if not r or r.closed then return false,"Rolling is closed." end
    if not roster[player] then return false,"Not in the raid." end
    if not integer(value,0,1000000000) or not integer(low,0,1000000000) or not integer(high,0,1000000000) then return false,"Invalid roll message." end
    if #r.attempts>=800 or (r.attemptCounts[player] or 0)>=20 then return false,"Roll log limit reached for this round." end
    local tier=high==99 and "OS" or (high==100 and ((r.eligible[player] or 0)>0 and "SR" or "MS") or "?")
    local why
    if (high~=99 and high~=100) or low~=1 or not integer(value,1,high) then why="Invalid range; use /roll 100 for MS or /roll 99 for OS."
    elseif r.passed[player] then why="Player passed."
    elseif r.tiebreak and (not r.tiePool[player] or tier~=r.tier) then why="Not eligible for this tie-break/range."
    elseif r.playerTiers[player] and r.playerTiers[player]~=tier then why="Additional roll changed MS/OS choice."
    else
        local cap=r.tiebreak and 1 or (tier=="SR" and r.eligible[player] or 1)
        if #(r.rolls[player] or {})>=cap then why="Additional roll exceeds allowance." end
    end
    local n=(r.attemptCounts[player] or 0)+1;r.attemptCounts[player]=n
    r.attempts[#r.attempts+1]={player=player,value=value,low=low,high=high,tier=tier,additional=n-1,valid=why==nil,note=why or "",serial=#r.attempts+1,hasSR=(r.eligible[player] or 0)>0}
    if why then return false,why,true end
    r.playerTiers[player]=tier;r.rolls[player]=r.rolls[player] or {};table.insert(r.rolls[player],value)
    return true
end
function S:RankedRolls(session,roster)
    local r=session.round;local rows={}
    if not r then return rows end
    for _,entry in ipairs(r.attempts or {}) do
        local e={};for k,v in pairs(entry) do e[k]=v end
        e.valid=e.valid and not r.passed[e.player] and roster[e.player]~=nil
        if r.passed[e.player] then e.note="Passed" elseif not roster[e.player] then e.note="Not in raid" end
        rows[#rows+1]=e
    end
    table.sort(rows,function(a,b)
        if a.valid~=b.valid then return a.valid==true end
        local pa,pb=priority[a.tier] or 4,priority[b.tier] or 4
        if pa~=pb then return pa<pb end
        if a.value~=b.value then return a.value>b.value end
        return a.serial<b.serial
    end)
    return rows
end
function S:CloseRound(session,roster)
    local r=session.round;if not r or r.closed then return false,"No open roll." end
    local rows=self:RankedRolls(session,roster);r.closed=true;r.best=0;r.winners={}
    local top=rows[1]
    if top and top.valid then
        r.tier=top.tier;r.best=top.value
        local seen={}
        for _,entry in ipairs(rows) do
            if entry.valid and entry.tier==top.tier and entry.value==top.value and not seen[entry.player] then
                seen[entry.player]=true;r.winners[#r.winners+1]=entry.player
            end
        end
    end
    table.sort(r.winners);return true
end
function S:Reroll(session)
    local r=session.round
    if not r or not r.closed or #r.winners<2 then return false,"No tied roll to resolve." end
    if #(r.tieHistory or {})>=10 then return false,"Tie-break limit reached; cancel and review this item." end
    r.tieHistory=r.tieHistory or {};r.tieHistory[#r.tieHistory+1]={tier=r.tier,best=r.best,winners=r.winners}
    local pool={};for _,name in ipairs(r.winners) do pool[name]=true end
    session.rollSerial=(session.rollSerial or 0)+1;r.epoch=session.rollSerial
    r.tiePool=pool;r.tiebreak=true;r.closed=false;r.rolls={};r.playerTiers={};r.passed={};r.attempts={};r.attemptCounts={};r.winners=nil
    return true
end
function S:NextTier()
    return false,"MS and OS are collected together. There are no separate tier rounds."
end
function S:RecordWinner(session, roster, timestamp)
    local r=session.round
    if not r or not r.closed or #r.winners~=1 then return false,"Close the round and resolve any tie first." end
    local name=r.winners[1]
    if not roster[name] then return false,"Winner left the raid; cancel and restart this item." end
    session.history[#session.history+1]={item=r.item,winner=name,roll=r.best,tier=r.tier,time=timestamp}
    if #session.history>500 then table.remove(session.history,1) end
    if r.tier=="SR" then
        local items=session.reserves[name] or {}
        for i,id in ipairs(items) do if id==r.item then table.remove(items,i);break end end
    end
    session.round=nil;session.revision=session.revision+1
    return true
end
