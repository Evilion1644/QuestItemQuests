local events
local watches={[1]=true,[2]=true,[3]=false,[4]=true}
local map,combat=10,false
local objectives={
 [1]={{text="Wolf slain: 0/1",finished=false}},
 [2]={{text="Bear slain: 0/1",finished=false}},
}
local db={}
QIQ={Settings=function() return db end, Normalize=string.lower}
GetLocale=function() return "enUS" end
UnitGUID=function() return "Player-1" end
InCombatLockdown=function() return combat end
CreateFrame=function() return {RegisterEvent=function() end,SetScript=function(_,_,fn) events=fn end} end
C_Map={GetBestMapForUnit=function() return map end}
C_QuestLog={
 GetNumQuestLogEntries=function() return 4 end,
 GetInfo=function(i) return {questID=i} end,
 GetQuestWatchType=function(id) if watches[id] then return 0 end end,
 AddQuestWatch=function(id) watches[id]=true; events(nil,"QUEST_WATCH_LIST_CHANGED",id,true) end,
 RemoveQuestWatch=function(id) watches[id]=false; events(nil,"QUEST_WATCH_LIST_CHANGED",id,false) end,
 GetQuestObjectives=function(id) return objectives[id] end,
 ReadyForTurnIn=function() return false end,
 GetQuestsOnMap=function() return {} end,
}
QIQ_ZONE_QUESTS={
 [1]={objectives={{names={"Wolf"},maps={[10]=true}}},finish={[20]=true}},
 [2]={objectives={{names={"Bear"},maps={[20]=true}}},finish={[10]=true}},
 [3]={objectives={},finish={[10]=true}},
}
dofile('QLens/Features.lua')
dofile('QLens/ZoneTracking.lua')
local Z=QIQ.ZoneTracking
assert(Z.Relevant(1,10)==true and Z.Relevant(1,20)==false)
assert(Z.Relevant(2,10)==false and Z.Relevant(2,20)==true)
assert(Z.Relevant(3,10)==true and Z.Relevant(4,10)==nil)
Z.Update(); assert(watches[1] and not watches[2] and watches[3] and watches[4])
-- Manual checkbox stays until changing zones.
C_QuestLog.AddQuestWatch(2); Z.Update(); assert(watches[2])
map=20; Z.Update(); assert(not watches[1] and watches[2] and not watches[3])
-- Completion switches to turn-in location.
C_QuestLog.ReadyForTurnIn=function(id) return id==1 end
Z.Update(); assert(watches[1])
-- Restoring the exact original watch list is deferred during combat.
combat=true; QIQ.SetFeature('zoneTracking',false); assert(not watches[3])
combat=false; events(nil,'PLAYER_REGEN_ENABLED')
assert(watches[1] and watches[2] and not watches[3] and watches[4])
assert(next(db.zoneWatchStates['Player-1'].original)==nil)
-- Multiple unfinished objectives, completed ones ignored.
C_QuestLog.ReadyForTurnIn=function() return false end
QIQ_ZONE_QUESTS[1].objectives[2]={names={'Bear'},maps={[20]=true}}
objectives[1]={{text='Wolf',finished=true},{text='Bear',finished=false}}
assert(Z.Relevant(1,10)==false and Z.Relevant(1,20)==true)
objectives[1][1].finished=false; assert(Z.Relevant(1,10)==true)
objectives[1]={{text='Unknown custom objective',finished=false}}
assert(Z.Relevant(1,10)==nil)
C_QuestLog.GetNextWaypoint=function() return 30 end
assert(Z.Relevant(1,30)==nil and Z.Relevant(1,10)==nil)
C_QuestLog.GetNextWaypoint=nil
-- Saved snapshot survives module reload.
QIQ.SetFeature('zoneTracking',true); dofile('QLens/ZoneTracking.lua')
QIQ.SetFeature('zoneTracking',false)
assert(watches[1] and watches[2] and not watches[3] and watches[4])
-- Every feature can be toggled without overwriting price or shortcut settings.
db.vendorThreshold=12345; db.key='altshift'
for _,key in ipairs({'combatPriority','partyQuests','itemTooltips','craftHints','itemShortcuts','vendorHighlight','minimapButton'}) do
 assert(QIQ.FeatureEnabled(key)); QIQ.SetFeature(key,false); assert(not QIQ.FeatureEnabled(key))
 QIQ.SetFeature(key,true); assert(QIQ.FeatureEnabled(key))
end
assert(db.vendorThreshold==12345 and db.key=='altshift')
print('PASS zone relevance, delivery, completion, manual override, combat, restoration, unknown data, multi-objective, reload, feature settings')

-- Real screenshot regression: Barrens map can display a navigation pin for
-- Unrefined Ore Sample even though its target is in Thousand Needles.
dofile('QLens/ZoneQuestIndex.lua')
objectives[1153]={{text='Unrefined Ore Sample: 0/1',finished=false}}
C_QuestLog.GetNextWaypoint=function() return 1413 end
assert(Z.Relevant(1153,1413,{[1153]=true})==false)
assert(Z.Relevant(1153,1441)==true)
-- Shadowfang Keep objectives retain their area despite missing UI map IDs.
objectives[1013]={{text='Forever-localized book name',finished=false}}
objectives[1014]={{text='Head of Arugal: 0/1',finished=false}}
assert(Z.Relevant(1013,1413)==false)
assert(Z.Relevant(1014,1413)==false)
C_Map.GetAreaInfo=function(id) if id==209 then return 'Shadowfang Keep' end end
GetRealZoneText=function() return 'Shadowfang Keep' end
assert(Z.Relevant(1013,99999)==true)
-- Collapsed log hides quests from GetInfo, but not from the watch list.
db.zoneWatchStates=nil
watches={[1153]=true,[1013]=true}
C_QuestLog.GetNumQuestLogEntries=function() return 1 end
C_QuestLog.GetInfo=function() return {isHeader=true} end
C_QuestLog.GetNumQuestWatches=function() local n=0; for _,v in pairs(watches) do if v then n=n+1 end end; return n end
C_QuestLog.GetQuestIDForQuestWatchIndex=function(index) local n=0; for id,v in pairs(watches) do if v then n=n+1; if n==index then return id end end end end
C_QuestLog.IsOnQuest=function(id) return watches[id]~=nil end
map=1413; QIQ.SetFeature('zoneTracking',true)
assert(not watches[1153] and not watches[1013])
map=1441; QIQ.ZoneTracking.Update(); assert(watches[1153] and not watches[1013])
QIQ.SetFeature('zoneTracking',false); assert(watches[1153] and watches[1013])
print('PASS screenshot regressions: proxy POI, dungeon area, localized wording, collapsed journal, rewatch and restore')

-- Arbitrary, database-independent quest IDs and localized titles.
local custom=999991
local destinations={[custom]=1416,[999992]=1441,[999993]=2099}
GetQuestUiMapID=function(id,ignoreWaypoints)
 assert(ignoreWaypoints==true) -- without this, a route exit can be mistaken for a target
 return destinations[id] or 0
end
objectives[custom]={{text='Any localized objective: 0/6',finished=false}}
assert(Z.Relevant(custom,1441)==false)
assert(Z.Relevant(custom,1416)==true)
assert(Z.Relevant(999992,1441)==true and Z.Relevant(999992,1416)==false)
assert(Z.Relevant(999993,2099)==true and Z.Relevant(999993,1441)==false)
-- Destination updates when the server switches to turn-in; no cached name/ID rule.
C_QuestLog.ReadyForTurnIn=function(id) return id==custom end
destinations[custom]=1458
assert(Z.Relevant(custom,1416)==false and Z.Relevant(custom,1458)==true)
-- Updated live quests take precedence over old Classic reference locations.
destinations[1153]=1416
assert(Z.Relevant(1153,1441)==false and Z.Relevant(1153,1416)==true)
-- Micro maps normalize to their zone; dungeon maps do not normalize to entrances.
C_Map.GetMapInfo=function(id)
 if id==888 then return {mapType=5,parentMapID=1416} end
 if id==2099 then return {mapType=4,parentMapID=1416} end
 if id==12 then return {mapType=2} end
 return {mapType=3}
end
assert(Z.Relevant(custom,888)==false)
destinations[custom]=888; assert(Z.Relevant(custom,1416)==true)
assert(Z.Relevant(999993,1416)==false)
destinations[custom]=12; assert(Z.Relevant(custom,1416)==nil)
-- Missing/error/zero native data use the reference or preserve unknown state.
GetQuestUiMapID=function() error('not loaded') end
assert(Z.Relevant(custom,1441)==nil and Z.Relevant(1153,1441)==true)
GetQuestUiMapID=function() return 0 end
assert(Z.Relevant(custom,1441)==nil)
-- Every bundled quest and a new ID follow the same native destination rule.
C_QuestLog.ReadyForTurnIn=function() return false end
C_QuestLog.GetQuestObjectives=function() return {{text='Live objective',finished=false}} end
GetQuestUiMapID=function(id,ignore) assert(ignore); return 1441 end
local total=0
for id in pairs(QIQ_ZONE_QUESTS) do
 assert(Z.Relevant(id,1441)==true and Z.Relevant(id,1413)==false)
 total=total+1
end
assert(Z.Relevant(123456789,1441)==true)
print('PASS native destinations for '..total..' reference IDs plus unknown quests, stages, map hierarchy, fallback and errors')
