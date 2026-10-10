local A=assert(QIQ)
local D=assert(QIQ_GUIDE_DATA)
assert(D.schema==1,"Unsupported QIQ guide schema")
local G={data=D,history={},cursor=0,searchCache={}}
A.Guide=G
local T=A.T
local function call(fn,...)
 if type(fn)~="function" then return end
 local ok,a,b=pcall(fn,...); if ok then return a,b end
end
function G:Name(names,id)
 return names and (names[A.locale] or names.enUS) or T("quest")..tostring(id)
end
function G:Title(id) local q=D.quests[id]; return q and self:Name(q.names,id) or T("quest")..id end
function G:EntityName(kind,id)
 if kind=="item" then local name=call(C_Item and C_Item.GetItemNameByID or GetItemInfo,id); if name then return name end end
 local e=D.entities[kind] and D.entities[kind][id]
 return e and self:Name(e.names,id) or T(kind).." #"..tostring(id)
end
function G:Zone(area)
 if area and area>0 then
  local name=call(C_Map and C_Map.GetAreaInfo,area)
  if name then return name end
 end
 return "#"..tostring(area or "?")
end
function G:Status(id)
 if A.ActiveQuests[id] then
  local ready=call(C_QuestLog and C_QuestLog.ReadyForTurnIn,id)
  return ready and "ready" or "active"
 end
 local done=call(C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted or IsQuestFlaggedCompleted,id)
 if done==true then return "completed" end
 return done==false and "absent" or "unknown"
end
function G:SearchText(q)
 if self.searchCache[q.id] then return self.searchCache[q.id] end
 local t={tostring(q.id),q.names.enUS or "",q.names.ruRU or "",self:Zone(q.zone)}
 for _,group in ipairs({q.start or {},q.finish or {},q.objectives or {}}) do
  for i,kind in ipairs({"npc","object","item"}) do
   for _,ref in ipairs(group[i] or {}) do
    local id=type(ref)=="table" and ref[1] or ref
    local e=D.entities[kind][id]
    if e then t[#t+1]=e.names.enUS or ""; t[#t+1]=e.names.ruRU or "" end
   end
  end
 end
 local text=A.Normalize(table.concat(t," ")); self.searchCache[q.id]=text; return text
end
function G:Query(text,filter,itemID)
 local words={}; for w in A.Normalize(text or ""):gmatch("%S+") do words[#words+1]=w end
 local itemSet
 if itemID then
  itemSet={}; for _,row in ipairs(A.Relations[itemID] or {}) do itemSet[row[1]]=true end
  if not self.referenceItemQuests then
   self.referenceItemQuests={}
   for _,questID in ipairs(D.ids) do
    local c=self:ClassicReward(questID)
    if c then for _,group in ipairs({c.items,c.choices}) do for _,item in ipairs(group) do
     self.referenceItemQuests[item.id]=self.referenceItemQuests[item.id] or {}; self.referenceItemQuests[item.id][questID]=true
    end end end
   end
  end
  for questID in pairs(self.referenceItemQuests[itemID] or {}) do itemSet[questID]=true end
 end
 local exactID=tonumber(text)
 local result={}
 for _,id in ipairs(D.ids) do
  local keep=not itemSet or itemSet[id]
  if keep and exactID then keep=id==exactID end
  if keep and not exactID and #words>0 then
   local hay=self:SearchText(D.quests[id])
   for _,word in ipairs(words) do if not hay:find(word,1,true) then keep=false; break end end
  end
  if keep and filter and filter~="all" then
   local state=self:Status(id)
   keep=(filter=="active" and (state=="active" or state=="ready")) or
        (filter=="completed" and state=="completed") or
        (filter=="absent" and not A.ActiveQuests[id])
  end
  if keep then result[#result+1]=id end
 end
 return result
end
function G:Visit(id)
 if not D.quests[id] then return false end
 if self.history[self.cursor]~=id then
  for n=#self.history,self.cursor+1,-1 do self.history[n]=nil end
  self.history[#self.history+1]=id
  if #self.history>100 then table.remove(self.history,1) end
  self.cursor=#self.history
 end
 self.selected=id; return true
end
function G:Move(delta)
 local index=self.cursor+delta
 if index<1 or index>#self.history then return false end
 self.cursor=index; self.selected=self.history[index]; return true
end
function G:ShowPoint(p)
 if not p.map or p.map<=0 or p.x<0 or p.x>1 or p.y<0 or p.y>1 then print(T("pointFailed")); return false end
 if WorldMapFrame and WorldMapFrame.SetMapID then
  if ShowUIPanel then call(ShowUIPanel,WorldMapFrame) else call(WorldMapFrame.Show,WorldMapFrame) end
  call(WorldMapFrame.SetMapID,WorldMapFrame,p.map)
 end
 if C_Map and call(C_Map.CanSetUserWaypointOnMap,p.map) then
  local point=UiMapPoint and call(UiMapPoint.CreateFromCoordinates,p.map,p.x,p.y)
  if point and call(C_Map.SetUserWaypoint,point) then
   call(C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint,true)
   if WorldMapFrame and WorldMapFrame.SetMapID then call(WorldMapFrame.SetMapID,WorldMapFrame,p.map); call(WorldMapFrame.Show,WorldMapFrame) end
   return true
  end
 end
 if TomTom and TomTom.AddWaypoint then
  local uid=call(TomTom.AddWaypoint,TomTom,p.map,p.x,p.y,{title=p.name,persistent=false,minimap=true,world=true})
  if uid then return true end
 end
 print(T("pointFailed")); return false
end
-- Read only an explicitly selected active quest and always restore the journal selection.
function G:ReadRewards(id)
 local result={items={},choices={}}
 if not A.ActiveQuests[id] then return result end
 -- Reward globals read the legacy quest-log selection, not necessarily the
 -- quest selected by the modern map/quest UI. Prefer the same context as QuestInfo.
 local legacy=type(GetQuestLogSelection)=="function" and type(SelectQuestLogEntry)=="function" and type(GetQuestLogSelectedID)=="function"
 local modern=C_QuestLog and type(C_QuestLog.SetSelectedQuest)=="function" and type(C_QuestLog.GetSelectedQuest)=="function"
 local index=call(C_QuestLog and C_QuestLog.GetLogIndexForQuestID or GetQuestLogIndexByID,id)
 if not legacy and not modern then return result end
 local previous=call(legacy and GetQuestLogSelection or C_QuestLog.GetSelectedQuest)
 local setter=legacy and SelectQuestLogEntry or C_QuestLog.SetSelectedQuest
 if previous==nil or (legacy and (not index or index<=0)) then return result end
 local ok=pcall(function()
  setter(legacy and index or id)
  -- Do not trust a different UI's selected ID as proof of the reward context.
  if call(GetQuestLogSelectedID)~=id then return end
  if call(C_QuestLog and C_QuestLog.ShouldShowQuestRewards,id)==false then return end
  local xp=call(GetQuestLogRewardXP)
  local money=call(GetQuestLogRewardMoney)
  local function items(countFn,infoFn)
   local count=call(countFn); local out={}
   if type(count)~="number" or count<0 or count>100 or count%1~=0 or type(infoFn)~="function" then return nil end
   for i=1,count do
    local name,texture,quantity,quality,usable,itemID=infoFn(i)
    if type(itemID)~="number" or itemID<=0 or type(quantity)~="number" or quantity<=0 or not name then return nil end
    out[#out+1]={name=name,texture=texture,count=quantity,quality=quality,id=itemID}
   end
   return out
  end
  local guaranteed=items(GetNumQuestLogRewards,GetQuestLogRewardInfo)
  local choices=items(GetNumQuestLogChoices,GetQuestLogChoiceInfo)
  if guaranteed and choices and #guaranteed+#choices>0 then
   result.items=guaranteed; result.choices=choices; result.knownItems=true
  end
  -- Zero XP is also the stub result on this client. An entirely empty reply is
  -- not evidence of zero rewards. Keep the labelled offline reference visible.
  if type(xp)=="number" and xp>0 then result.xp=xp end
  if type(money)=="number" and (money>0 or (money==0 and (result.knownItems or result.xp))) then result.money=money end
 end)
 pcall(setter,previous)
 if not ok then return {items={},choices={}} end
 return result
end
function G:ClassicReward(id)
 local q=D.quests[id]; local c=QIQ_CLASSIC_REWARDS and QIQ_CLASSIC_REWARDS[id]
 if c and q and c.title:lower():match("^%s*(.-)%s*$")==q.names.enUS:lower():match("^%s*(.-)%s*$") then return c end
end
function G:RewardRows(id)
 local q=D.quests[id]
 local reward=self.rewardSnapshot and self.rewardSnapshot[id] or {items={},choices={}}
 local classic=self:ClassicReward(id)
 local rows={}
 local function add(text,extra)
  local row=extra or {}; row.text=text; row.tab="rewards"; rows[#rows+1]=row
 end
 local function money(n)
  return string.format(A.locale=="ruRU" and "%d зол.  %d сер.  %d мед." or "%dg  %ds  %dc",math.floor(n/10000),math.floor(n/100)%100,n%100)
 end
 add(T("rewardTitle"),{heading=true})
 local xp=type(reward.xp)=="number" and tostring(reward.xp) or classic and (classic.xp.." (Classic)") or T("notKnown")
 local coins=type(reward.money)=="number" and money(reward.money) or classic and (money(classic.money).." (Classic)") or T("notKnown")
 add(T("experience")..": "..xp,{icon="Interface\\Icons\\XP_Icon"})
 add(T("money")..": "..coins,{icon="Interface\\Icons\\INV_Misc_Coin_02"})
 local function itemRows(items,key)
  if #items==0 then return end
  add(T(key),{heading=true})
  for _,v in ipairs(items) do
   add(((v.id and D.entities.item[v.id] and self:EntityName("item",v.id)) or v.name or (v.id and self:EntityName("item",v.id)) or T("item"))..(v.count and " ×"..v.count or ""),
    {icon=v.texture,itemID=v.id,action=v.id and {kind="item",id=v.id}})
  end
 end
 itemRows(reward.items,"guaranteed"); itemRows(reward.choices,"chooseOne")
 if not reward.knownItems then
  if classic then
   add(T("classicRewards"),{heading=true})
   itemRows(classic.items,"guaranteed"); itemRows(classic.choices,"chooseOne")
   if #classic.items==0 and #classic.choices==0 then add(T("noRewardItems").." (Classic)") end
  elseif #q.rewards>0 then
   add(T("knownItems"),{heading=true})
   for _,itemID in ipairs(q.rewards) do add(self:EntityName("item",itemID),{itemID=itemID,action={kind="item",id=itemID}}) end
   add(T("unknownCounts"))
  else add(T("itemsNotKnown")) end
 elseif #reward.items==0 and #reward.choices==0 then add(T("noRewardItems")) end
 if type(reward.xp)~="number" or type(reward.money)~="number" then add(T("rewardHelp")) end
 if classic then
  add(T("classicNote"))
  if classic.cost>0 then add(T("requiredPayment")..": "..money(classic.cost).." (Classic)") end
  if classic.spell>0 or classic.cast>0 then add(T("spellReward")..": #"..(classic.spell>0 and classic.spell or classic.cast).." (Classic)") end
 end
 if q.reputation and #q.reputation>0 then
  add(T("repRewards"),{heading=true})
  for _,rep in ipairs(q.reputation) do
   local info=call(C_Reputation and C_Reputation.GetFactionDataByID,rep[1])
   local name=info and info.name or call(GetFactionInfoByID,rep[1]) or (T("faction").." #"..rep[1])
   add(name..": +"..rep[2])
  end
 end
 return rows
end
local function sortedKeys(t)
 local keys={}; for k in pairs(t or {}) do keys[#keys+1]=k end; table.sort(keys); return keys
end
function G:WalkthroughRows(id)
 local q=D.quests[id]; if not q then return {} end
 local rows={}; local ru=A.locale=="ruRU"; local step=0
 local function add(text,action,heading)
  rows[#rows+1]={text=text,action=action,heading=heading,tab="overview"}
 end
 local function numbered(text) step=step+1; add(step..". "..text) end
 local function place(kind,entityID)
  local e=D.entities[kind][entityID]
  for _,area in ipairs(sortedKeys(e and e.spawns)) do
   for _,xy in ipairs(e.spawns[area]) do
    if xy[1]>=0 and xy[1]<=100 and xy[2]>=0 and xy[2]<=100 and D.maps[area] then
     local name=self:EntityName(kind,entityID)
     add(T("showOnMap")..": "..name.." - "..self:Zone(area)..string.format(" (%.1f, %.1f)",xy[1],xy[2]),{kind="point",point={map=D.maps[area],x=xy[1]/100,y=xy[2]/100,name=name}})
     return
    end
   end
  end
 end
 local function endpoints(group,key)
  local found=false
  for i,kind in ipairs({"npc","object","item"}) do
   for _,entityID in ipairs(group and group[i] or {}) do
    if type(entityID)=="number" then
     numbered(T(key,self:EntityName(kind,entityID)))
     if kind=="item" then add(T("inspectItem"),{kind="item",id=entityID}) else place(kind,entityID) end
     found=true
    end
   end
  end
  if not found then numbered(T(key=="takeAt" and "startUnknown" or "finishUnknown")) end
 end
 add(T("walkthrough"),nil,true)
 add(T("generatedSteps"))
 endpoints(q.start,"takeAt")
 if q.sourceItem then add(T("providedItem",self:EntityName("item",q.sourceItem)),{kind="item",id=q.sourceItem}) end
 local texts=q.texts[A.locale] or q.texts.enUS
 if texts then for _,text in ipairs(texts) do if text~="" then numbered(text) end end end
 for i,kind in ipairs({"npc","object","item"}) do
  for _,ref in ipairs(q.objectives and q.objectives[i] or {}) do
   local entityID=type(ref)=="table" and ref[1] or ref
   if type(entityID)=="number" then
    numbered(T(kind=="item" and "collectStep" or "objectiveStep",self:EntityName(kind,entityID)))
    if kind=="item" then
     add(T("inspectItem"),{kind="item",id=entityID})
     local item=D.entities.item[entityID]; local sources=0
     for _,group in ipairs({{ids=item and item.npcDrops,kind="npc",key="dropStep"},{ids=item and item.objectDrops,kind="object",key="objectStep"},{ids=item and item.vendors,kind="npc",key="vendorStep"}}) do
      for _,source in ipairs(group.ids or {}) do
       sources=sources+1
       if sources<=6 then add(T(group.key,self:EntityName(group.kind,source))); place(group.kind,source) end
      end
     end
     if sources==0 then add(T("sourceUnknown")) elseif sources>6 then add(T("moreSources")) end
    else place(kind,entityID) end
   end
  end
 end
 endpoints(q.finish,"turnInAt")
 return rows
end
function G:Rows(id)
 local q=D.quests[id]; if not q then return {{text=T("questUnavailable",tostring(id))}} end
 local rows={}
 local omitted=false
 local tab="overview"
 local function add(text,action,heading)
  if #rows>=500 then omitted=true; return end
  rows[#rows+1]={text=tostring(text),action=action,heading=heading,tab=tab}
 end
 local function section(key)
  if key=="requirements" then tab="requirements" end
  add(T(key),nil,true)
 end
 local function locations(kind,entityID)
  local entity=D.entities[kind][entityID]; local total,shown=0,0
  local key=kind..":"..entityID; local expanded=self.expandedPoints and self.expandedPoints[key]
  for _,area in ipairs(sortedKeys(entity and entity.spawns)) do
   for _,xy in ipairs(entity.spawns[area]) do
    if type(xy[1])=="number" and type(xy[2])=="number" and xy[1]>=0 and xy[1]<=100 and xy[2]>=0 and xy[2]<=100 then
     total=total+1
     if shown<(expanded and 100 or 2) then
      shown=shown+1
      local point={map=D.maps[area],x=xy[1]/100,y=xy[2]/100,name=self:EntityName(kind,entityID)}
      add("    "..self:Zone(area)..string.format(": %.1f, %.1f",xy[1],xy[2]),point.map and point.map>0 and {kind="point",point=point} or nil)
     end
    end
   end
  end
  if total>shown then add(T("expandPoints",total-shown),{kind="expand",key=key}) end
  if expanded then add(T("collapsePoints"),{kind="expand",key=key}) end
 end
 local function entity(kind,entityID,withSources)
  add(T(kind)..": "..self:EntityName(kind,entityID),kind=="item" and {kind="item",id=entityID} or nil)
  if kind~="item" then locations(kind,entityID)
  elseif withSources then
   local e=D.entities.item[entityID]
   if e then
    for _,group in ipairs({{kind="npc",ids=e.npcDrops},{kind="npc",ids=e.vendors},{kind="object",ids=e.objectDrops}}) do
     for _,source in ipairs(group.ids or {}) do add("  "..T("sources")..": "..self:EntityName(group.kind,source)); locations(group.kind,source) end
    end
   end
  end
 end
 local function refs(group,objective)
  local n=0
  for i,kind in ipairs({"npc","object","item"}) do
   for _,ref in ipairs(group and group[i] or {}) do
    local entityID=objective and type(ref)=="table" and ref[1] or ref
    if type(entityID)=="number" then entity(kind,entityID,objective); n=n+1 end
   end
  end
  if n==0 then add(T("noData")) end
 end
 local function chain(key,ids)
  if not ids or #ids==0 then return end
  tab="chain"; section(key)
  for _,questID in ipairs(ids) do
   local target=math.abs(questID)
   add(self:Title(target)..(questID<0 and " *" or ""),{kind="quest",id=target})
  end
 end
 add(self:Title(id),nil,true)
 add(T(self:Status(id)).." • #"..id)
 add(T("level",tostring(q.level or "?"),tostring(q.minLevel or "?")).." - "..self:Zone(q.zone))
 if q.flags and q.flags%2==1 then add(T("repeatable")) end
 if A.ActiveQuests[id] then add(T("log"),{kind="log",id=id}) else add(T("unknownAvailability")) end
 for _,row in ipairs(self:WalkthroughRows(id)) do rows[#rows+1]=row end
 section("objective")
 local live=call(C_QuestLog and C_QuestLog.GetQuestObjectives,id)
 if A.ActiveQuests[id] and type(live)=="table" and #live>0 then
  for _,o in ipairs(live) do add(o.text or "") end
 else
  local texts=q.texts[A.locale] or q.texts.enUS
  if not q.texts[A.locale] and A.locale=="ruRU" and texts then add(T("english")) end
  if texts and #texts>0 then for _,text in ipairs(texts) do if text~="" then add(text) end end else add(T("noData")) end
 end
 refs(q.objectives,true)
 section("start"); refs(q.start)
 section("finish"); refs(q.finish)
 if q.sourceItem or (q.requiredItems and #q.requiredItems>0) then
  section("sourceItem"); if q.sourceItem then entity("item",q.sourceItem) end
  for _,itemID in ipairs(q.requiredItems or {}) do entity("item",itemID) end
 end
 chain("chainAll",q.all); chain("chainAny",q.any); chain("follow",q.follow); chain("exclusions",q.exclusive)
 if q.parent then chain("parent",{q.parent}) end
 if q.breadcrumb then chain("breadcrumb",{q.breadcrumb}) end
 section("requirements")
 local function masks(mask,kind)
  if not mask or mask==0 then return end
  local values={}
  for bit=0,39 do
   if math.floor(mask/2^bit)%2==1 then
    local info=call(C_CreatureInfo and (kind=="race" and C_CreatureInfo.GetRaceInfo or C_CreatureInfo.GetClassInfo),bit+1)
    values[#values+1]=info and (info.raceName or info.className) or "#"..(bit+1)
   end
  end
  add(T(kind,table.concat(values,", ")))
 end
 masks(q.races,"race"); masks(q.classes,"class")
 for _,field in ipairs({"skill","repMin","repMax"}) do if q[field] then add(T(field)..": "..table.concat(q[field],", ")) end end
 if q.spell then add(T("spell")..": "..q.spell) end
 add(T("restriction"))
 for _,row in ipairs(self:RewardRows(id)) do if #rows<500 then rows[#rows+1]=row else omitted=true end end
 if omitted then rows[#rows+1]={text=A.locale=="ruRU" and "Показаны первые 500 строк карточки." or "Showing the first 500 detail rows."} end
 return rows
end
