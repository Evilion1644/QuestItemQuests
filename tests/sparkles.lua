local path='QLens/'
local names={'outlineModeShowLootEffectWhenDisabled','graphicsOutlineMode','raidGraphicsOutlineMode','OutlineEngineMode','RAIDOutlineEngineMode'}
local function setup(saved,missing,fail)
 local db=saved or {}; local values={}; for i,n in ipairs(names) do values[n]=tostring(i+1) end
 if missing then values[missing]=nil end
 local original={}; for n,v in pairs(values) do original[n]=v end
 local callback,queue,writes,combat=nil,{},0,false
 QIQ={Settings=function() return db end}; C_CVar={GetCVar=function(n) return values[n] end,SetCVar=function(n,v)
  if n==fail and v=='0' then error('rejected') end
  values[n]=v; writes=writes+1; if callback then callback(nil,'CVAR_UPDATE',n) end
 end}
 CreateFrame=function() return {RegisterEvent=function() end,SetScript=function(_,_,fn) callback=fn end} end
 C_Timer={After=function(_,fn) queue[#queue+1]=fn end}; InCombatLockdown=function() return combat end
 dofile(path..'Features.lua'); dofile(path..'QuestSparkles.lua')
 local function flush() local q=queue; queue={}; for _,fn in ipairs(q) do fn() end; assert(#queue==0,'recursive scheduling') end
 return db,values,original,function(e,n) callback(nil,e,n);flush() end,flush,function(v) combat=v end,function() return writes end
end
local db,v,orig,event,flush,combat,writes=setup()
assert(QIQ.FeatureEnabled('questSparkles'));event('PLAYER_LOGIN')
for i,n in ipairs(names) do assert(v[n]==(i==1 and '1' or '0')) end
assert(db.questSparklesOriginal[names[2]]==orig[names[2]])
v[names[2]]='2';event('CVAR_UPDATE',names[2]);assert(v[names[2]]=='0')
QIQ.SetFeature('questSparkles',false);flush();for n,val in pairs(orig) do assert(v[n]==val) end
assert(db.questSparklesOriginal==nil)
dofile(path..'Features.lua');assert(not QIQ.FeatureEnabled('questSparkles'))
local before=writes();event('PLAYER_LOGIN');assert(writes()==before)
QIQ.SetFeature('questSparkles',true);combat(true);flush();assert(v[names[2]]==orig[names[2]])
combat(false);event('PLAYER_REGEN_ENABLED');assert(v[names[2]]=='0')
dofile(path..'QuestSparkles.lua');event('PLAYER_LOGIN');QIQ.SetFeature('questSparkles',false);flush()
for n,val in pairs(orig) do assert(v[n]==val,'reload restore') end
for _,missing in ipairs({names[1],names[2]}) do
 db,v,orig,event,flush,combat,writes=setup(nil,missing);event('PLAYER_LOGIN');assert(not QIQ.FeatureEnabled('questSparkles'));assert(writes()==0)
end
db,v,orig,event=setup(nil,names[5]);event('PLAYER_LOGIN');assert(QIQ.FeatureEnabled('questSparkles'));assert(v[names[2]]=='0')
db,v,orig,event=setup(nil,nil,names[2]);event('PLAYER_LOGIN');assert(not QIQ.FeatureEnabled('questSparkles'))
for n,val in pairs(orig) do assert(v[n]==val,'failed write rollback') end
print('PASS sparkles defaults, saved opt-out, preset reset, restore, combat, reload, unsupported CVars, optional CVars and rollback')
