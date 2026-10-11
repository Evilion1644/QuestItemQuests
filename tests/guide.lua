local failures=0
local function test(name,fn) local ok,err=pcall(fn); if ok then print("PASS "..name) else failures=failures+1; print("FAIL "..name..": "..tostring(err)) end end
GetLocale=function() return "ruRU" end
dofile("QLens/Locale.lua")
dofile("QLens/CraftIndex.lua")
dofile("QLens/Crafting.lua")
dofile("QLens/QuestItemQuestsData.lua")
dofile("QLens/Titles.lua")
QIQ.ActiveQuests={}; QIQ.Relations=QIQ_ITEM_QUESTS
-- Same Unicode normalization as the core, exercised here with real data.
local upper={"А","Б","В","Г","Д","Е","Ё","Ж","З","И","Й","К","Л","М","Н","О","П","Р","С","Т","У","Ф","Х","Ц","Ч","Ш","Щ","Ъ","Ы","Ь","Э","Ю","Я"}
local lower={"а","б","в","г","д","е","ё","ж","з","и","й","к","л","м","н","о","п","р","с","т","у","ф","х","ц","ч","ш","щ","ъ","ы","ь","э","ю","я"}
QIQ.Normalize=function(s) for i,v in ipairs(upper) do s=s:gsub(v,lower[i]) end; return s:lower() end
local completed={}
C_QuestLog={IsQuestFlaggedCompleted=function(id) return completed[id] or false end,GetQuestObjectives=function() return {} end}
dofile("QLens_Guide/Data.lua")
dofile("QLens_Guide/ClassicRewards.lua")
dofile("QLens_Guide/Model.lua")
dofile("QLens_Guide/CraftData.lua")
dofile("QLens_Guide/CraftModel.lua")
local G=QIQ.Guide
test("Full guide schema and localized core coverage",function()
 assert(#G.data.ids==4244)
 for id in pairs(QIQ_QUEST_TITLES) do assert(QIQ_TITLES.enUS[id] and G.data.quests[id]) end
 for _,q in pairs(G.data.quests) do assert(q.names.enUS and q.names.enUS~=""); for _,n in ipairs(q.follow) do assert(G.data.quests[n]) end end
end)
test("Exact ID and bilingual search",function()
 assert(G:Query("1106","all")[1]==1106 and #G:Query("1106","all")==1)
 assert(#G:Query("МАРТЕК","all")>0)
 assert(#G:Query("Martek","all")>0)
 assert(#G:Query("\"impossible needle\"","all")==0)
 assert(#G:Query("","all")==4244)
end)
test("Item filter includes reward relations",function()
 local results=G:Query("","all",9173); local found=false
 for _,id in ipairs(results) do if id==2843 then found=true end end
 assert(found)
 assert(#G:Query("","all",999999999)==0)
end)
test("History branch and limit",function()
 G:Visit(2); G:Visit(5); assert(G:Move(-1)); G:Visit(6)
 assert(#G.history==2 and G.history[2]==6 and not G:Move(1))
 for i=1,120 do G:Visit(G.data.ids[i]) end
 assert(#G.history==100 and G.cursor==100)
 assert(not G:Visit(99999999))
end)
test("Status does not infer availability",function()
 assert(G:Status(2)=="absent")
 completed[2]=true; assert(G:Status(2)=="completed")
 QIQ.ActiveQuests[2]="active"; assert(G:Status(2)=="active")
 C_QuestLog.ReadyForTurnIn=function() return true end; assert(G:Status(2)=="ready")
 QIQ.ActiveQuests={}; C_QuestLog.ReadyForTurnIn=nil; C_QuestLog.IsQuestFlaggedCompleted=nil
 assert(G:Status(2)=="unknown")
 C_QuestLog.IsQuestFlaggedCompleted=function(id) return completed[id] or false end
end)
test("Every card renders in both locales with bounded rows",function()
 for _,locale in ipairs({"ruRU","enUS"}) do
  QIQ.locale=locale
  for _,id in ipairs(G.data.ids) do
   local rows=G:Rows(id); assert(#rows>0 and #rows<=501)
   for _,row in ipairs(rows) do assert(type(row.text)=="string",id) end
  end
 end
 QIQ.locale="ruRU"
end)
test("Waypoint invalid, native success and TomTom fallback",function()
 local native,external=0,0
 C_Map={CanSetUserWaypointOnMap=function() return true end,SetUserWaypoint=function() native=native+1; return true end}
 UiMapPoint={CreateFromCoordinates=function(map,x,y) return {uiMapID=map,position={x=x,y=y}} end}
 assert(G:ShowPoint({map=1,x=.5,y=.5,name="point"}) and native==1)
 local oldPrint=print; print=function() end
 assert(not G:ShowPoint({map=1,x=5,y=.5}))
 C_Map.SetUserWaypoint=function() return false end
 TomTom={AddWaypoint=function() external=external+1; return "uid" end}
 assert(G:ShowPoint({map=1,x=.5,y=.5}) and external==1)
 TomTom=nil; C_Map=nil; assert(not G:ShowPoint({map=1,x=.5,y=.5})); print=oldPrint
end)
test("Reward reader restores selection and distinguishes choice and guaranteed items",function()
 local selected=7
 QIQ.ActiveQuests[2]=true
 C_QuestLog.GetLogIndexForQuestID=function(id) return id==2 and 3 end
 GetQuestLogSelection=function() return selected end
 SelectQuestLogEntry=function(n) selected=n end
 GetQuestLogSelectedID=function() return selected==3 and 2 or 5 end
 GetQuestLogRewardXP=function() return 1250 end
 GetQuestLogRewardMoney=function() return 1350 end
 GetNumQuestLogRewards=function() return 1 end
 GetNumQuestLogChoices=function() return 1 end
 GetQuestLogRewardInfo=function() return "Reward",123,2,1,true,100 end
 GetQuestLogChoiceInfo=function() return "Choice",456,1,2,true,101 end
 local r=G:ReadRewards(2)
 assert(selected==7 and r.xp==1250 and r.money==1350)
 assert(r.items[1].count==2 and r.choices[1].id==101)
 GetQuestLogRewardInfo=function() error("client unavailable") end
 r=G:ReadRewards(2); assert(selected==7 and r.xp==nil)
 QIQ.ActiveQuests[2]=nil
 r=G:ReadRewards(2); assert(r.money==nil and r.knownItems==nil)
 GetQuestLogRewardInfo=nil
end)
test("Reward rows show unknown rather than invented zero and preserve confirmed zero",function()
 G.rewardSnapshot={[2]={xp=0,money=0,knownItems=true,items={},choices={}}}
 local rows=G:RewardRows(2); assert(rows[2].text:find("0") and rows[3].text:find("0"))
 G.rewardSnapshot=nil; rows=G:RewardRows(2); assert(rows[2].text:find("Classic",1,true))
end)
test("Empty, partial and wrong-context client rewards cannot erase reference rewards",function()
 QIQ.ActiveQuests[1102]=true
 local selected=99
 C_QuestLog.GetLogIndexForQuestID=function(id) return id==1102 and 8 or nil end
 GetQuestLogSelection=function() return selected end
 SelectQuestLogEntry=function(i) selected=i end
 GetQuestLogSelectedID=function() return selected==8 and 1102 or 7 end
 GetQuestLogRewardXP=function() return 0 end; GetQuestLogRewardMoney=function() return 0 end
 GetNumQuestLogRewards=function() return 0 end; GetNumQuestLogChoices=function() return 0 end
 GetQuestLogRewardInfo=function() end; GetQuestLogChoiceInfo=function() end
 local r=G:ReadRewards(1102); assert(r.xp==nil and r.money==nil and not r.knownItems and selected==99)
 G.rewardSnapshot={[1102]=r}
 local function hasAllChoices()
  local found={}; for _,row in ipairs(G:RewardRows(1102)) do if row.itemID then found[row.itemID]=true end end
  assert(found[4197] and found[6742] and found[6725])
 end
 hasAllChoices()
 GetNumQuestLogChoices=function() return 3 end
 GetQuestLogChoiceInfo=function(i) if i==1 then return "Loaded",123,1,2,true,4197 end end
 r=G:ReadRewards(1102);assert(not r.knownItems and selected==99);G.rewardSnapshot[1102]=r;hasAllChoices()
 GetQuestLogSelectedID=function() return 7 end
 GetQuestLogRewardXP=function() error("wrong context was queried") end
 r=G:ReadRewards(1102);assert(r.xp==nil and selected==99)
 G.rewardSnapshot=nil;QIQ.ActiveQuests[1102]=nil
end)
test("All quests have steps; matching Classic rewards and item choices are preserved",function()
 local matched=0
 for _,id in ipairs(G.data.ids) do
  assert(#G:WalkthroughRows(id)>=3)
  local c=G:ClassicReward(id)
  if c then
   matched=matched+1
   local rows=G:RewardRows(id); assert(rows[2].text:find("Classic",1,true))
   for _,item in ipairs(c.choices) do
    assert(item.count>0 and item.name)
    local found=false; for _,qid in ipairs(G:Query("","all",item.id)) do if qid==id then found=true end end; assert(found)
   end
  end
 end
 assert(matched==4244); print("Matched Classic references: "..matched)
 assert(G:ClassicReward(875).xp==1150 and G:ClassicReward(875).money==800)
 local c=QIQ_CLASSIC_REWARDS[875]; local name=c.title;c.title="different quest";assert(not G:ClassicReward(875));c.title=name
end)
test("Additional coordinates expand; walkthrough has map links without picture placeholder",function()
 local rows=G:Rows(875); local key,point
 for _,row in ipairs(rows) do
  assert(not row.mapQuest)
  if row.action and row.action.kind=="expand" then key=row.action.key end
  if row.action and row.action.kind=="point" then point=true end
 end
 assert(key and point);G.expandedPoints={[key]=true};assert(#G:Rows(875)>#rows);G.expandedPoints=nil
end)
-- Stateful UI smoke harness. No native WoW rendering is claimed.
local function frame()
 local f={scripts={},shown=false,width=600,height=500,offset=0,text=""}
 function f:SetScript(k,v) self.scripts[k]=v end
 function f:SetSize(w,h) self.width=w; self.height=h end
 function f:GetWidth() return self.width end; function f:GetHeight() return self.height end
 function f:SetWidth(v) self.width=v end; function f:SetHeight(v) self.height=v end
 function f:Show() self.shown=true end; function f:Hide() self.shown=false; if self.scripts.OnHide then self.scripts.OnHide(self) end end
 function f:IsShown() return self.shown end
 function f:SetText(v) self.text=v; if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self) end end
 function f:GetText() return self.text end
 function f:GetStringHeight() return math.max(14,math.ceil(#self.text/65)*14) end
 function f:SetVerticalScroll(v) self.offset=v end; function f:GetVerticalScroll() return self.offset end
 function f:SetScrollChild(v) self.child=v end
 function f:SetEnabled(v) self.enabled=v end
 for _,name in ipairs({"SetTexCoord","SetFont","SetTexture","SetPoint","ClearAllPoints","SetFrameStrata","SetClampedToScreen","SetScale","EnableMouse","SetMovable","RegisterForDrag","StartMoving","StopMovingOrSizing","RegisterEvent","ClearFocus","SetAutoFocus","SetMaxLetters","SetWordWrap","SetFontObject","SetTextColor","SetJustifyH","SetAllPoints","SetColorTexture","SetHighlightTexture"}) do f[name]=function() end end
 function f:CreateFontString() return frame() end; function f:CreateTexture() return frame() end
 return f
end
CreateFrame=function() return frame() end
UIParent=frame(); UIParent:SetSize(1920,1080)
GameTooltip=frame(); C_Timer={After=function(_,fn) fn() end}
QIQ.OpenActiveQuest=function() return true end
dofile("QLens_Guide/View.lua")
test("Guide UI open, search, page, history, item filter and clear",function()
 assert(G:Open(1106)); assert(G.frame:IsShown() and G.selected==1106)
 G.search:SetText("1106"); assert(#G.results==1)
 G.search:SetText(""); G.next.scripts.OnClick(); assert(G.page==2)
 assert(G:Open(nil,9173)); assert(G.itemID==9173 and G.selected==2843)
 G.clear.scripts.OnClick(); assert(not G.itemID and #G.results==4244)
 G.frame:Hide(); assert(not G.frame:IsShown())
 assert(G:Open(2)); assert(G.selected==2)
 assert(G:Open(875)); assert(G.selected==875)
 G.tabs.rewards.scripts.OnClick(); assert(G.tab=="rewards")
 G.tabs.overview.scripts.OnClick(); assert(G.tab=="overview")
end)
test("Overview visibly includes every reference item reward for every quest",function()
 G.tab="overview";G.rewardSnapshot=nil;QIQ.ActiveQuests={}
 for _,id in ipairs(G.data.ids) do
  G.selected=id;G:RenderDetail()
  local visible={}
  for _,row in ipairs(G.detailPool) do if row:IsShown() and row.action and row.action.kind=="item" then visible[row.action.id]=true end end
  local c=G:ClassicReward(id)
  for _,group in ipairs({c.items,c.choices}) do for _,item in ipairs(group) do assert(visible[item.id],id..":"..item.id) end end
 end
end)
test("Craft data and reverse professions agree for every material",function()
 local index,count={},0
 for key,r in pairs(G.crafts) do
  count=count+1; assert(r.n.enUS and r.n.ruRU and r.id>0 and r.p>0)
  for _,v in ipairs(r.r) do
   assert(v[1]>0 and v[2]>0); index[v[1]]=index[v[1]] or {}; index[v[1]][r.p]=true
  end
 end
 assert(count==2506)
 for id,profs in pairs(index) do
  local actual={}; for _,p in ipairs(QIQ_CRAFT_INDEX[id]) do actual[p]=true; assert(profs[p]) end
  for p in pairs(profs) do assert(actual[p]) end
 end
 for id in pairs(QIQ_CRAFT_INDEX) do assert(index[id]) end
end)
test("Craft material opens without quest and preserves quantity",function()
 assert(G:Open(nil,2589)); assert(G.mode=="quests" and #G.results>0)
 assert(G.modeTabs.quests.text:GetText():find("Задания",1,true))
 assert(G.modeTabs.craft.text:GetText():find("Рецепты",1,true))
 G.modeTabs.craft.scripts.OnClick(); assert(G.mode=="craft" and #G.results>0)
 assert(not G.tabs.overview:IsShown() and not G.filterButton.enabled)
 for _,key in ipairs(G.results) do
  local found=false; for _,v in ipairs(G.crafts[key].r) do if v[1]==2589 then found=true end end; assert(found)
 end
 local r=G.crafts["197:2963"]; assert(r and r.item==2996)
 G.recipeSelected="197:2963";G:RenderDetail()
 local text=""; for _,row in ipairs(G.detailPool) do if row:IsShown() then text=text..row.text:GetText() end end
 assert(text:find("× 2",1,true) and text:find("Материалы на одно изготовление",1,true))
 G.modeTabs.quests.scripts.OnClick(); assert(G.mode=="quests" and G.tabs.overview:IsShown())
 G.modeTabs.craft.scripts.OnClick(); assert(G.mode=="craft")
 G.clear.scripts.OnClick(); assert(not G.itemID and #G.results==2506)
 G.search:SetText("ПОРТНЯЖНОЕ"); assert(#G.results>0)
 for _,key in ipairs(G.results) do assert(G.crafts[key].p==197) end
 G.search:SetText("unfindablezz"); assert(#G.results==0 and G.recipeSelected==nil and G.empty:IsShown())
 G.search:SetText("Bolt of Linen Cloth");assert(#G.results>0)
 G.listPool[1].scripts.OnClick(G.listPool[1]); assert(G.recipeSelected==G.results[1])
 G.search:SetText(""); G.next.scripts.OnClick(); assert(G.page==2)
 assert(G:Open(1106) and G.mode=="quests" and G.selected==1106)
end)
test("Mixed iron bar opens quests first and both tabs remain reachable",function()
 G:Open(nil,3575)
 assert(G.mode=="quests" and #G.results>0 and G.data.quests[G.selected])
 local count=#G:Query("","all",3575)
 assert(G.modeTabs.quests.text:GetText()==QIQ.T("questTab",count))
 G.modeTabs.craft.scripts.OnClick()
 assert(#G.results>0 and G.itemID==3575 and G.modeTabs.craft.marker:IsShown())
 G.modeTabs.quests.scripts.OnClick()
 assert(#G.results==count and G.itemID==3575 and G.modeTabs.quests.marker:IsShown())
 assert(not G.modeTabs.craft.marker:IsShown())
end)
test("Craft-only material still opens recipes",function()
 local found
 for item in pairs(QIQ_CRAFT_INDEX) do if #G:Query("","all",item)==0 then found=item; break end end
 assert(found); G:Open(nil,found); assert(G.mode=="craft" and #G.results>0)
 G.modeTabs.quests.scripts.OnClick(); assert(#G.results==0 and G.selected==nil and G.empty:IsShown())
 assert(G.empty:GetText()==QIQ.T("emptyQuestItem"))
end)
test("Active item quest preferred and direct quest navigation survives filters",function()
 local ids=G:Query("","all",3575); assert(#ids>1)
 local target=ids[#ids]; QIQ.ActiveQuests[target]="Active"
 G:Open(nil,3575); assert(G.selected==target and G.mode=="quests")
 QIQ.ActiveQuests[target]=nil
 G.search:SetText("no possible match"); G:Open(1106); assert(G.selected==1106)
 G.search:SetText("")
end)
test("Craft English locale and unknown materials",function()
 QIQ.locale="enUS"; assert(QIQ.CraftProfessions(2589):find("Tailoring",1,true))
 assert(G:CraftTitle("197:2963")=="Bolt of Linen Cloth")
 assert(#G:CraftQuery("",999999999)==0 and QIQ.CraftProfessions(999999999)==nil)
 QIQ.locale="ruRU"
end)
if failures>0 then error(failures.." guide tests failed") end
print("guide tests: OK")
