local handler, enabled, count = nil, true, 0
local ids={700001,700002}
local objectives={
 [700001]={{type="item",text="Strange egg: 0/1",numFulfilled=0,numRequired=1}},
 [700002]={{type="monster",text="Визгливая гарпия - убито: 5/5",finished=true},
 {type="monster",text="Визгливая бродяжница - убито: 4/5",numFulfilled=4,numRequired=5}},
}
local name="Визгливая бродяжница"
local guid="Creature-0-1-1-1-999999-000001"
local quest=function(id) return {GetID=function() return id end} end
QuestObjectiveTracker={BuildQuestWatchInfos=function() return {{quest=quest(ids[1])},{quest=quest(ids[2])}} end,
 MarkDirty=function() count=count+1 end}
QIQ={ActiveQuests={},Normalize=function(s) return s end, FeatureEnabled=function() return enabled end}
C_QuestLog={GetNumQuestWatches=function() return #ids end,GetQuestIDForQuestWatchIndex=function(i) return ids[i] end,
 GetNumQuestLogEntries=function() return 1 end,GetInfo=function() return {isHeader=true} end,
 GetQuestObjectives=function(id) return objectives[id] end,IsOnQuest=function(id) return objectives[id]~=nil end}
CreateFrame=function() return {RegisterEvent=function() end,SetScript=function(_,_,fn) handler=fn end} end
UnitGUID=function(unit) return unit=="player" and "Player-1" or guid end
UnitName=function() return name end
UnitAffectingCombat=function() return true end
C_Timer={After=function(_,fn) fn() end}
CombatLogGetCurrentEventInfo=function() return 0,"SWING_DAMAGE",false,"Player-1",nil,nil,nil,guid,name end
dofile('QLens/CombatPriority.lua')
handler(nil,'PLAYER_LOGIN')
handler(nil,'COMBAT_LOG_EVENT_UNFILTERED')
assert(QuestObjectiveTracker:BuildQuestWatchInfos()[1].quest:GetID()==700002)
assert(count==1)
handler(nil,'QUEST_LOG_UPDATE') -- collapsed journal must not erase priority
assert(QuestObjectiveTracker:BuildQuestWatchInfos()[1].quest:GetID()==700002)
enabled=false;QIQ.CombatPriority.Reset()
handler(nil,'PLAYER_TARGET_CHANGED');assert(QuestObjectiveTracker:BuildQuestWatchInfos()[1].quest:GetID()==700001)
enabled=true
objectives[700002][2].numFulfilled=5
handler(nil,'COMBAT_LOG_EVENT_UNFILTERED');assert(QuestObjectiveTracker:BuildQuestWatchInfos()[1].quest:GetID()==700001)
objectives[700002][2].numFulfilled=4
name='Визгливая бродяжниц' -- must not match partial words
handler(nil,'COMBAT_LOG_EVENT_UNFILTERED');assert(QuestObjectiveTracker:BuildQuestWatchInfos()[1].quest:GetID()==700001)
name='Визгливая бродяжница'
handler(nil,'PLAYER_REGEN_DISABLED');assert(QuestObjectiveTracker:BuildQuestWatchInfos()[1].quest:GetID()==700002)
objectives[700002]=nil;handler(nil,'QUEST_LOG_UPDATE')
assert(QuestObjectiveTracker:BuildQuestWatchInfos()[1].quest:GetID()==700001)
-- Existing database item-drop path still works with an empty ActiveQuests cache.
QIQ_COMBAT_OBJECTIVES={[999999]={700002}}
QIQ_COMBAT_OBJECTIVE_DETAILS={[999999]={[700002]={-123}}}
QIQ_COMBAT_ITEM_NAMES={[123]={'Quest drop','Квестовый предмет'}}
objectives[700002]={{type='item',text='Quest drop: 1/2',numFulfilled=1,numRequired=2}}
QIQ.CombatPriority.promoteTarget(guid,name)
assert(QuestObjectiveTracker:BuildQuestWatchInfos()[1].quest:GetID()==700002)
print('PASS custom mob/quest IDs, collapsed log, persistence, disabled switch, completed objective, name boundaries, quest removal, static drop fallback')

-- Unknown item quests are identified from the native target tooltip.
QIQ_COMBAT_OBJECTIVES={}
enabled=false;QIQ.CombatPriority.Reset();enabled=true
C_QuestLog.GetTitleForQuestID=function(id) return id==700002 and 'New Forever quest' or 'Other quest' end
C_TooltipInfo={GetUnit=function() return {lines={{leftText='New Forever quest'},{leftText='Quest drop: 1/2'}}} end}
handler(nil,'COMBAT_LOG_EVENT_UNFILTERED')
assert(QuestObjectiveTracker:BuildQuestWatchInfos()[1].quest:GetID()==700002)
enabled=false;QIQ.CombatPriority.Reset();enabled=true
C_TooltipInfo.GetUnit=function() return {lines={{leftText='Party-only quest'},{leftText='Quest drop: 1/2'}}} end
handler(nil,'COMBAT_LOG_EVENT_UNFILTERED')
assert(QuestObjectiveTracker:BuildQuestWatchInfos()[1].quest:GetID()==700001)
C_TooltipInfo.GetUnit=function() error('transient tooltip error') end
handler(nil,'COMBAT_LOG_EVENT_UNFILTERED')
assert(QuestObjectiveTracker:BuildQuestWatchInfos()[1].quest:GetID()==700001)

-- Progress fallback is independent of creature, quest, item IDs and tooltip availability.
C_TooltipInfo=nil
handler(nil,'PLAYER_ENTERING_WORLD')
objectives[700002][1].numFulfilled=2
objectives[700002][1].text='Quest drop: 2/2'
handler(nil,'QUEST_LOG_UPDATE')
assert(QuestObjectiveTracker:BuildQuestWatchInfos()[1].quest:GetID()==700002)
handler(nil,'PLAYER_REGEN_ENABLED')
assert(QuestObjectiveTracker:BuildQuestWatchInfos()[1].quest:GetID()==700002)
enabled=false;QIQ.CombatPriority.Reset()
objectives[700002][1].numFulfilled=3;objectives[700002][1].text='Quest drop: 3/4'
handler(nil,'QUEST_LOG_UPDATE')
enabled=true;handler(nil,'QUEST_LOG_UPDATE')
assert(QuestObjectiveTracker:BuildQuestWatchInfos()[1].quest:GetID()==700001)
-- Newly accepted quest must not be mistaken for progress.
objectives[700002]={{type='object',text='New object: 1/3',numFulfilled=1,numRequired=3}}
handler(nil,'QUEST_LOG_UPDATE')
assert(QuestObjectiveTracker:BuildQuestWatchInfos()[1].quest:GetID()==700001)
objectives[700002][1].text='New object: 2/3';objectives[700002][1].numFulfilled=2
handler(nil,'QUEST_LOG_UPDATE')
assert(QuestObjectiveTracker:BuildQuestWatchInfos()[1].quest:GetID()==700002)
-- The alternate tracker API obeys the same stable order and early-stop contract.
QuestObjectiveTracker={EnumQuestWatchData=function(self,fn)
 for _,id in ipairs(ids) do if not fn(self,quest(id)) then return end end
end,MarkDirty=function() end}
handler(nil,'ADDON_LOADED')
local visited={}
QuestObjectiveTracker:EnumQuestWatchData(function(_,q) visited[#visited+1]=q:GetID(); return false end)
assert(#visited==1 and visited[1]==700002)
print('PASS native tooltip, party-only rejection, API error, generic item/object progress, after-combat order, disabled changes, new objectives, alternate tracker API')
