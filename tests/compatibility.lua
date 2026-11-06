-- Regression cases from the Forever 1.60.1.70790 API contract.
local handler
CreateFrame=function() return {RegisterEvent=function() end,SetScript=function(_,_,fn) handler=fn end} end
local db={features={questSparkles=true},questSparklesOriginal={graphicsOutlineMode='2',OutlineEngineMode='2',outlineModeShowLootEffectWhenDisabled='0'}}
QIQ={Settings=function() return db end}
local values={graphicsOutlineMode='0',OutlineEngineMode='3',outlineModeShowLootEffectWhenDisabled='1'}
local writes=0
C_CVar={GetCVar=function(n) return values[n] end,SetCVar=function(n,v) writes=writes+1;values[n]=v end}
dofile('QLens/LegacySettings.lua');handler()
assert(values.graphicsOutlineMode=='2' and values.OutlineEngineMode=='3' and values.outlineModeShowLootEffectWhenDisabled=='0')
assert(db.questSparklesOriginal==nil and db.features.questSparkles==nil)
handler();assert(writes==2)
print('PASS removal migration restores owned values once and preserves newer settings')

local token={}
issecretvalue=function(v) return rawequal(v,token) end
local frames={}
local attemptedRestricted=false
CreateFrame=function() local f={RegisterEvent=function(_,e) if e=='COMBAT_LOG_EVENT_UNFILTERED' then attemptedRestricted=true; error('restricted event') end end,SetScript=function(_,_,fn) handler=fn end};return f end
QIQ={FeatureEnabled=function() return true end,ActiveQuests={}}
UnitGUID=function() return token end
UnitName=function() return token end
UnitAffectingCombat=function() return token end
C_QuestLog={GetNumQuestLogEntries=function() return 0 end,GetNumQuestWatches=function() return 0 end}
QuestObjectiveTracker=nil
CombatLogGetCurrentEventInfo=function() error('restricted read') end
dofile('QLens/CombatPriority.lua');assert(not attemptedRestricted, 'pcall cannot suppress blocked-action popup')
handler(nil,'PLAYER_LOGIN');handler(nil,'PLAYER_TARGET_CHANGED');handler(nil,'PLAYER_REGEN_DISABLED');handler(nil,'COMBAT_LOG_EVENT_UNFILTERED')
assert(QIQ.CombatPriority.creatureID(token)==nil)
C_CombatLog={IsCombatLogRestricted=function() return true end};handler(nil,'COMBAT_LOG_EVENT_UNFILTERED')
print('PASS unavailable combat event/read and secret identity leave module operational')

local hooks={}
hooksecurefunc=function(a,b,c) hooks[type(a)=='string' and a or b]=c or b end
SetItemButtonQuality=function() end
local checked=0
local function forbidden() return {IsForbidden=function() return true end,IsShown=function() error('forbidden frame inspected') end} end
UIParent={GetChildren=function() error('must not scan entire UI') end}
local texture=function() return {SetColorTexture=function() end,SetPoint=function() end,SetWidth=function() end,SetHeight=function() end,Hide=function(self) self.visible=false end,Show=function(self) self.visible=true end} end
local button={GetObjectType=function() return 'ItemButton' end,IsShown=function() return true end,GetBagID=function() return 0 end,GetID=function() return 1 end,CreateTexture=texture}
ContainerFrameCombinedBags={IsShown=function() return true end,GetChildren=function() return forbidden(),button end}
C_Container={GetContainerItemInfo=function() checked=checked+1;return {hyperlink='item:123',stackCount=2} end}
C_Item={GetItemInfo=function() return nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,10 end}
C_Timer={After=function(_,fn) fn() end}
QIQ={Settings=function() return {vendorThreshold=25} end,FeatureEnabled=function() return true end}
CreateFrame=function() return {RegisterEvent=function() end,SetScript=function(_,_,fn) handler=fn end} end
dofile('QLens/VendorPrice.lua');handler(nil,'PLAYER_LOGIN')
assert(checked>0 and button.QLensCheapBorder[1].visible)
C_Container.GetContainerItemInfo=function() return nil end
handler(nil,'BAG_UPDATE');assert(not button.QLensCheapBorder[1].visible)
BagBrother={ContainerItem={Update=function() end}}
handler(nil,'ADDON_LOADED');assert(hooks.Update)
print('PASS modern ItemButton, forbidden frames, empty slot cleanup and late bag addon hook')

GameTooltip={IsForbidden=function() return true end,HookScript=function() error('forbidden tooltip hook') end}
WorldMapTooltip={HasScript=function() return false end,HookScript=function(_,name) assert(name~='OnTooltipCleared') end}
QIQ={};dofile('QLens/PartyQuestTooltip.lua')
print('PASS party tooltip missing legacy script and forbidden tooltip')
