-- Local development export of the user's pinned QuestieDB snapshot.
-- Do not publish generated data until upstream redistribution terms are verified.
local root,outRoot=assert(arg[1]),assert(arg[2])
local db,zone,loc={},{private={}},{questLookup={},npcNameLookup={},objectLookup={},itemLookup={}}
QuestieLoader={ImportModule=function(_,name) if name=="l10n" then return loc elseif name=="ZoneDB" then return zone else return db end end}
GetLocale=function() return "ruRU" end
local raw={}
for _,kind in ipairs({"Quest","Npc","Object","Item"}) do
 dofile(root.."/data/Forever/forever"..kind.."DB.lua")
 local low=kind:lower(); raw[low]=assert(loadstring(db[low.."Data"]))()
end
for _,kind in ipairs({"Quests","Npcs","Objects","Items"}) do dofile(root.."/l10n/Forever/lookup"..kind.."/ruRU.lua") end
local function lookup(t) return type(t.ruRU)=="function" and t.ruRU() or t.ruRU or {} end
local ru={quest=lookup(loc.questLookup),npc=lookup(loc.npcNameLookup),object=lookup(loc.objectLookup),item=lookup(loc.itemLookup)}
dofile(root.."/support/Forever/Zones/areaIdToUiMapId.lua")
local maps=assert(loadstring(zone.private.areaIdToUiMapId))()
local function serialize(v)
 if type(v)=="number" then assert(v==v); return string.format("%.14g",v) end
 if type(v)=="string" then return string.format("%q",v):gsub("\r", "") end
 if type(v)=="boolean" then return tostring(v) end
 if type(v)=="nil" then return "nil" end
 assert(type(v)=="table","unsupported export value")
 local keys={}; for k in pairs(v) do keys[#keys+1]=k end
 table.sort(keys,function(a,b) if type(a)==type(b) then return a<b end; return type(a)<type(b) end)
 local a={"{"}; for _,k in ipairs(keys) do a[#a+1]="["..serialize(k).."]="..serialize(v[k]).."," end
 a[#a+1]="}"; return table.concat(a)
end
local function write(path,global,value)
 local f=assert(io.open(outRoot.."/"..path,"wb")); f:write("-- Generated; source QuestieDB e0a6eaa86f181ac99262e34126bcd2ed1a1712d6; raw snapshot, no corrections.\n",global,"=",serialize(value),"\n"); f:close()
end
local function names(kind,id,row)
 local value=ru[kind][id]; local name=type(value)=="table" and value[1] or value
 return {enUS=row[1],ruRU=type(name)=="string" and name or nil}
end
local guide={schema=1,source="e0a6eaa86f181ac99262e34126bcd2ed1a1712d6",profile="raw-no-corrections",quests={},entities={npc={},object={},item={}},maps=maps,ids={}}
local qk,ik=db.questKeys,db.itemKeys
assert(qk.objectives==10 and qk.requiredSourceItems==21 and ik.questRewards==6,"schema drift")
local need={npc={},object={},item={}}
local function ref(kind,id) if type(id)=="number" and id>0 then need[kind][id]=true end end
local function refs(group,kinds,objective)
 for i,kind in ipairs(kinds) do
  for _,entry in ipairs(type(group)=="table" and group[i] or {}) do ref(kind,objective and type(entry)=="table" and entry[1] or entry) end
 end
end
for id,row in pairs(raw.quest) do
 local r={id=id,names=names("quest",id,row),level=row[qk.questLevel],minLevel=row[qk.requiredLevel],zone=row[qk.zoneOrSort],
 start=row[qk.startedBy],finish=row[qk.finishedBy],objectives=row[qk.objectives],sourceItem=row[qk.sourceItemId],requiredItems=row[qk.requiredSourceItems],
 all=row[qk.preQuestGroup],any=row[qk.preQuestSingle],exclusive=row[qk.exclusiveTo],next=row[qk.nextQuestInChain],parent=row[qk.parentQuest],breadcrumb=row[qk.breadcrumbForQuestId],
 races=row[qk.requiredRaces],classes=row[qk.requiredClasses],skill=row[qk.requiredSkill],repMin=row[qk.requiredMinRep],repMax=row[qk.requiredMaxRep],spell=row[qk.requiredSpell],
 flags=row[qk.specialFlags],reputation=row[qk.reputationReward],texts={enUS=row[qk.objectivesText],ruRU=type(ru.quest[id])=="table" and ru.quest[id][2] or nil},rewards={}}
 guide.quests[id]=r; guide.ids[#guide.ids+1]=id
 refs(r.start,{"npc","object","item"}); refs(r.finish,{"npc","object"}); refs(r.objectives,{"npc","object","item"},true)
 ref("item",r.sourceItem); for _,itemID in ipairs(r.requiredItems or {}) do ref("item",itemID) end
end
for itemID,row in pairs(raw.item) do
 for _,qid in ipairs(row[ik.questRewards] or {}) do
  if guide.quests[qid] then table.insert(guide.quests[qid].rewards,itemID); ref("item",itemID) end
 end
end
for id in pairs(need.item) do
 local row=raw.item[id]
 if row then
  local r={names=names("item",id,row),npcDrops=row[ik.npcDrops],objectDrops=row[ik.objectDrops],vendors=row[ik.vendors]}
  guide.entities.item[id]=r
  for _,n in ipairs(r.npcDrops or {}) do ref("npc",n) end
  for _,n in ipairs(r.vendors or {}) do ref("npc",n) end
  for _,n in ipairs(r.objectDrops or {}) do ref("object",n) end
 end
end
for _,kind in ipairs({"npc","object"}) do
 for id in pairs(need[kind]) do
  local row=raw[kind][id]
  if row then guide.entities[kind][id]={names=names(kind,id,row),spawns=row[db[kind.."Keys"].spawns]} end
 end
end
for id,r in pairs(guide.quests) do
 r.follow={}; table.sort(r.rewards)
end
local function follow(from,to)
 local q=guide.quests[math.abs(from)]
 if q then for _,id in ipairs(q.follow) do if id==to then return end end; q.follow[#q.follow+1]=to end
end
for id,r in pairs(guide.quests) do
 for _,prev in ipairs(r.all or {}) do follow(prev,id) end
 for _,prev in ipairs(r.any or {}) do follow(prev,id) end
 if r.next and r.next>0 then follow(id,r.next) end
end
for _,r in pairs(guide.quests) do table.sort(r.follow) end
table.sort(guide.ids)
write("QLens_Guide/Data.lua","QIQ_GUIDE_DATA",guide)
dofile(outRoot.."/QLens/QuestItemQuestsData.lua")
local titles={enUS={},ruRU={}}
for id in pairs(QIQ_QUEST_TITLES) do local q=guide.quests[id]; if q then titles.enUS[id]=q.names.enUS; titles.ruRU[id]=q.names.ruRU end end
write("QLens/Titles.lua","QIQ_TITLES",titles)
print("Guide quests: "..#guide.ids)
for kind,entities in pairs(guide.entities) do local n=0; for _ in pairs(entities) do n=n+1 end; print(kind.." entities: "..n) end
