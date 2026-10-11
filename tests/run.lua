local failures=0
local function test(name,fn) local ok,err=pcall(fn); if ok then print("PASS "..name) else failures=failures+1; print("FAIL "..name..": "..tostring(err)) end end

QIQ_ITEM_QUESTS={
 [100]={{1,1}}, [101]={{1,64}}, [102]={{1,66}}, [103]={{1,8}}, [104]={{1,10}},
 [105]={{1,2},{2,4}}, [106]={{1,16}}, [107]={{1,32}}, [108]={{1,1},{1,2}}, [111]={{1,64}},
 [113]={{1,1},{2,64}},
 [114]={{1,1},{2,1},{3,1},{4,1},{5,1},{6,1},{7,1},{8,1},{9,1},{10,1}},
}
QIQ_QUEST_TITLES={[1]="Первый квест",[2]="Второй квест",[3]="Квест 3",[4]="Квест 4",[5]="Квест 5",[6]="Квест 6",[7]="Квест 7",[8]="Квест 8",[9]="Квест 9",[10]="Квест 10"}
QIQ_QUEST_CLASS_IDS={[100]=true,[101]=true,[102]=true,[103]=true,[104]=true,[105]=true,[106]=true,[107]=true,[108]=true,[109]=true,[113]=true,[114]=true}
QIQ_TEST_MODE=true
local frames,mainFrame,companions,buttons,namedFrames={},nil,{},{},{}
local function frame(kind)
 local f={kind=kind,scripts={},lines={},shown=false}
 function f:SetScript(n,fn) self.scripts[n]=fn end; function f:RegisterEvent(e) self.events=self.events or {}; self.events[e]=true end
 function f:HasScript(n) return n=="OnHide" or n=="OnTooltipCleared" or n=="OnTooltipSetItem" end; function f:HookScript(n,fn) self.hookCounts=self.hookCounts or {}; self.hookCounts[n]=(self.hookCounts[n] or 0)+1; self.scripts[n]=fn end
 function f:AddLine(s) self.lines[#self.lines+1]=s end; function f:AddDoubleLine(a,b) self.lines[#self.lines+1]=a.."|"..b end
 function f:ClearLines() self.lines={} end; function f:ClearAllPoints() self.point=nil end; function f:SetPoint(...) self.point={...} end; function f:SetOwner(owner) self.owner=owner end; function f:Show() self.shown=true end; function f:Hide() self.shown=false end
 function f:SetClampedToScreen(value) self.clamped=value end; function f:GetHeight() return self.fakeHeight or (24+#self.lines*16) end; function f:GetBottom() return self.bottom or 400 end; function f:GetTop() return self.top or 500 end
 function f:SetFrameStrata() end; function f:SetAllPoints() end; function f:EnableMouse() end; function f:SetSize() end; function f:SetNormalFontObject() end; function f:SetText() end
 function f:GetParent() return self.parent end; function f:CreateTexture() return {SetAllPoints=function() end,SetColorTexture=function() end} end
 frames[#frames+1]=f; return f
end
function CreateFrame(kind,name,parent) local f=frame(kind); f.name=name; f.parent=parent; if name then namedFrames[name]=f end; if not mainFrame then mainFrame=f elseif kind=="GameTooltip" then companions[#companions+1]=f elseif kind=="Button" then buttons[#buttons+1]=f end; return f end
function wipe(t) for k in pairs(t) do t[k]=nil end end
UIParent={GetEffectiveScale=function() return 1 end,GetWidth=function() return 800 end,GetHeight=function() return 600 end}
GameTooltip=frame("owner"); ItemRefTooltip=nil; ShoppingTooltip1=frame("owner2"); ShoppingTooltip2=nil; WorldMapTooltip=nil
function GameTooltip:GetItem() return self.itemName,self.itemLink end
local modernPostCall
TooltipDataProcessor={AddTooltipPostCall=function(_,callback) modernPostCall=callback end}
Enum={TooltipDataType={Item=1}}
local questRows,objectiveByQuest={},{}
C_QuestLog={GetNumQuestLogEntries=function() return #questRows end,GetInfo=function(i) return questRows[i] end,GetQuestObjectives=function(id) return objectiveByQuest[id] or {} end}
local names={[100]="РУССКИЙ ПРЕДМЕТ",[109]=nil,[110]="API quest item",[111]="Ordinary reward",[112]=nil,[113]="Mixed item"}; GetItemInfo=function(id) id=tonumber(tostring(id):match("%d+")); local n=names[id]; return n,n and ("item:"..id) end
local classCalls=0
C_Item={GetItemInfoInstant=function(id) classCalls=classCalls+1; return id,nil,nil,nil,nil,(id==110 or QIQ_QUEST_CLASS_IDS[id]) and 12 or 0 end}
SlashCmdList={}; local originalCalls,opened,nativeError,nativeRecords=0,0,false,{}
HandleModifiedItemClick=function(link,...)
 local record={link=link,n=select("#",...),...}; nativeRecords[#nativeRecords+1]=record; originalCalls=originalCalls+1
 if nativeError then error("native failure") end
 return "original"
end
IsAltKeyDown=function() return true end; GetMouseButtonClicked=function() return "LeftButton" end
local shownLink="item:100"; C_Container={GetContainerItemLink=function() return shownLink end}
local bagButton={GetID=function() return 1 end,GetBag=function() return 0 end}; GetMouseFocus=function() return bagButton end
local openedIDs={}; QuestMapFrame_OpenToQuestDetails=function(id) opened=opened+1; openedIDs[#openedIDs+1]=id end; GetCursorPosition=function() return 1,1 end; GameFontNormal={}
GetLocale=function() return "ruRU" end
IsShiftKeyDown=function() return false end
IsControlKeyDown=function() return false end
dofile("QLens/Locale.lua")
dofile("QLens/CraftIndex.lua")
dofile("QLens/Crafting.lua")
dofile("QLens/QuestItemQuests.lua")
local API=assert(QuestItemQuests_TestAPI)
local function companionFor(owner) for _,c in ipairs(companions) do if c.owner==owner then return c end end end
local function event(e,...) mainFrame.scripts.OnEvent(mainFrame,e,...) end
local function active(...)
 questRows={}; for i,id in ipairs({...}) do questRows[i]={questID=id,title=QIQ_QUEST_TITLES[id]} end; event("QUEST_LOG_UPDATE")
end
test("all actionable masks and reward-only",function() for _,m in ipairs({1,2,4,6,8,9,10,16,32,66}) do assert(API.hasActionRelation(m),m) end; assert(not API.hasActionRelation(64)); assert(API.isRewardOnly(64)); assert(not API.isRewardOnly(66)) end)
test("one active and reward exclusion",function() active(1); assert(#assert(API.resolveItem(100,"","РУССКИЙ ПРЕДМЕТ"))==1); assert(API.resolveItem(101,"","reward")==nil); assert(#assert(API.resolveItem(102,"","both"))==1) end)
test("multiple active and duplicate suppression",function() active(1,2); assert(#assert(API.resolveItem(105,"","multi"))==2); active(1); assert(#assert(API.resolveItem(108,"","dup"))==1) end)
test("resolver and tooltip relation masks",function()
 active(1)
 for _,id in ipairs({103,104,106,107}) do assert(#assert(API.resolveItem(id,"","mask"))==1,"resolver item "..id) end
 active()
 for _,id in ipairs({103,104,106,107}) do GameTooltip.itemName="mask"; GameTooltip.itemLink="item:"..id; GameTooltip.scripts.OnTooltipSetItem(GameTooltip); local c=companions[#companions]; assert(table.concat(c.lines," "):find("Первый квест"),"tooltip item "..id) end
end)
test("Russian normalized exact objective",function() objectiveByQuest[1]={{type="item",text="Русский предмет: 0/1"}}; active(1); assert(#assert(API.resolveItem(999,"","рУсСкИй ПрЕдМеТ"))==1) end)
test("journal revision invalidates cache",function() active(1); assert(API.resolveItem(100,"","x")); local r=API.getRevision(); active(); assert(API.getRevision()>r and API.resolveItem(100,"","x")==nil) end)
test("companion leaves owner lines intact, clamps and refreshes",function() active(); GameTooltip.lines={"foreign"}; GameTooltip.itemName="РУССКИЙ ПРЕДМЕТ"; GameTooltip.itemLink="item:100"; GameTooltip.scripts.OnTooltipSetItem(GameTooltip); assert(#GameTooltip.lines==1 and GameTooltip.lines[1]=="foreign"); local c=companions[#companions]; assert(c and c.shown and c.clamped==true and table.concat(c.lines," "):find("активного задания нет")); assert(c.point[1]=="TOPLEFT"); active(1); assert(table.concat(c.lines," "):find("Первый квест")); GameTooltip.bottom=10; GameTooltip.top=100; GameTooltip.itemLink="item:103"; GameTooltip.itemName="mask"; active(); GameTooltip.scripts.OnTooltipSetItem(GameTooltip); assert(c.point[1]=="BOTTOMLEFT"); GameTooltip.bottom,GameTooltip.top=nil,nil end)
test("large companion uses estimated height",function() active(); local c=companionFor(GameTooltip); c.fakeHeight=20; GameTooltip.bottom=180; GameTooltip.top=300; GameTooltip.itemLink="item:114"; GameTooltip.itemName="many"; GameTooltip.scripts.OnTooltipSetItem(GameTooltip); assert(#c.lines>=13 and c.point[1]=="BOTTOMLEFT"); c.fakeHeight=nil; GameTooltip.bottom,GameTooltip.top=nil,nil end)
test("modern dynamic tooltip lifecycle prevents resurrection",function()
 assert(type(modernPostCall)=="function")
 local owner=frame("modern"); modernPostCall(owner,{hyperlink="item:100",name="РУССКИЙ ПРЕДМЕТ"}); local c=companionFor(owner)
 assert(c and c.shown and owner.hookCounts.OnHide==1 and owner.hookCounts.OnTooltipCleared==1 and not owner.hookCounts.OnTooltipSetItem)
 owner.scripts.OnHide(owner); assert(not c.shown); active(1); assert(not c.shown,"hidden owner resurrected")
 modernPostCall(owner,{hyperlink="item:100",name="РУССКИЙ ПРЕДМЕТ"}); assert(c.shown and owner.hookCounts.OnHide==1 and owner.hookCounts.OnTooltipCleared==1)
 owner.scripts.OnTooltipCleared(owner); assert(not c.shown); active(); assert(not c.shown,"cleared owner resurrected")
end)
test("late GetItemInfo dynamic-only refresh",function()
 objectiveByQuest[2]={{type="item",text="Поздняя цель: 0/1"}}; names[112]=nil; active(2)
 ShoppingTooltip1.itemName=nil; ShoppingTooltip1.itemLink="item:112"; function ShoppingTooltip1:GetItem() return self.itemName,self.itemLink end
 local before=#companions; ShoppingTooltip1.scripts.OnTooltipSetItem(ShoppingTooltip1); assert(#companions==before,"pending tooltip rendered too early")
 names[112]="Поздняя цель"; event("GET_ITEM_INFO_RECEIVED",112,true); local c=companions[#companions]
 assert(#companions==before+1 and c.shown and table.concat(c.lines," "):find("Второй квест"),"late info did not resolve dynamic objective")
end)
test("mixed static hides separate reward-only quest",function() active(); GameTooltip.itemName=names[113]; GameTooltip.itemLink="item:113"; GameTooltip.scripts.OnTooltipSetItem(GameTooltip); local c=companionFor(GameTooltip); local all=table.concat(c.lines,"\n"); assert(all:find("Первый квест") and not all:find("Второй квест"),all) end)
test("actionable static skips class API",function() active(); local before=classCalls; GameTooltip.itemName="mask"; GameTooltip.itemLink="item:103"; GameTooltip.scripts.OnTooltipSetItem(GameTooltip); assert(classCalls==before) end)
test("instant class fallback and ordinary reward",function() active(); GameTooltip.itemName=names[110]; GameTooltip.itemLink="item:110"; GameTooltip.scripts.OnTooltipSetItem(GameTooltip); local c=companionFor(GameTooltip); assert(c.shown); GameTooltip.itemName=names[111]; GameTooltip.itemLink="item:111"; GameTooltip.scripts.OnTooltipSetItem(GameTooltip); assert(not c.shown) end)
test("normal, unknown and both chat focus branches delegate",function() active(1); shownLink="item:100"; local before=originalCalls; IsAltKeyDown=function() return false end; assert(HandleModifiedItemClick(shownLink,"LeftButton")=="original"); IsAltKeyDown=function() return true end; shownLink="item:999"; assert(HandleModifiedItemClick(shownLink,"LeftButton")=="original"); shownLink="item:100"; ChatEdit_GetActiveWindow=function() return {} end; assert(HandleModifiedItemClick(shownLink,"LeftButton")=="original"); ChatEdit_GetActiveWindow=nil; GetCurrentKeyBoardFocus=function() return {IsObjectType=function(_,kind) return kind=="EditBox" end} end; assert(HandleModifiedItemClick(shownLink,"LeftButton")=="original"); GetCurrentKeyBoardFocus=nil; assert(originalCalls==before+4) end)
test("throwing bag and focus APIs delegate with exact varargs",function()
 active(1); shownLink="item:100"; IsAltKeyDown=function() return true end; local before=originalCalls
 local oldGetBag=bagButton.GetBag; bagButton.GetBag=function() error("bag failure") end
 assert(HandleModifiedItemClick(shownLink,"LeftButton","token",nil,7)=="original"); local r=nativeRecords[#nativeRecords]
 assert(r.link==shownLink and r.n==4 and r[1]=="LeftButton" and r[2]=="token" and r[3]==nil and r[4]==7)
 bagButton.GetBag=oldGetBag; local oldFocus=GetMouseFocus; GetMouseFocus=function() error("focus failure") end
 assert(HandleModifiedItemClick(shownLink,"LeftButton","focus-token")=="original"); r=nativeRecords[#nativeRecords]; assert(r.n==2 and r[2]=="focus-token")
 GetMouseFocus=function() return nil end; GetMouseFoci=function() error("foci failure") end
 assert(HandleModifiedItemClick(shownLink,"LeftButton","foci-token")=="original"); r=nativeRecords[#nativeRecords]; assert(r.n==2 and r[2]=="foci-token")
 GetMouseFocus=oldFocus; GetMouseFoci=nil
 nativeError=true; local ok,err=pcall(HandleModifiedItemClick,shownLink,"RightButton","native-token"); nativeError=false
 assert(not ok and tostring(err):find("native failure"),"native error was swallowed"); assert(originalCalls==before+4,"unexpected native call count")
end)
test("open error and false delegate",function() active(1); shownLink="item:100"; local before=originalCalls; QuestMapFrame_OpenToQuestDetails=function() error("boom") end; assert(HandleModifiedItemClick(shownLink,"LeftButton")=="original"); QuestMapFrame_OpenToQuestDetails=function() return false end; assert(HandleModifiedItemClick(shownLink,"LeftButton")=="original"); assert(originalCalls==before+2) end)
test("successful alt click consumes",function() active(1); shownLink="item:100"; QuestMapFrame_OpenToQuestDetails=function(id) opened=opened+1; openedIDs[#openedIDs+1]=id end; local before=opened; local result=HandleModifiedItemClick(shownLink,"LeftButton"); assert(result==true and opened==before+1,"result="..tostring(result).." opened="..opened.." before="..before) end)
test("multiple menu selects every quest and preserves failures",function()
 active(1,2); shownLink="item:105"; openedIDs={}; QuestMapFrame_OpenToQuestDetails=function(id) openedIDs[#openedIDs+1]=id end
 assert(HandleModifiedItemClick(shownLink,"LeftButton")==true); local first=#buttons-1; assert(buttons[first] and buttons[first+1]); buttons[first].scripts.OnClick(); assert(openedIDs[#openedIDs]==1)
 assert(HandleModifiedItemClick(shownLink,"LeftButton")==true); buttons[first+1].scripts.OnClick(); assert(openedIDs[#openedIDs]==2)
 local nativePrint,diagnostics=print,{}; print=function(s) diagnostics[#diagnostics+1]=s end
 QuestMapFrame_OpenToQuestDetails=function() return false end; assert(HandleModifiedItemClick(shownLink,"LeftButton")==true); buttons[first].scripts.OnClick(); assert(namedFrames.QLensMenu.shown)
 QuestMapFrame_OpenToQuestDetails=function() error("menu error") end; buttons[first+1].scripts.OnClick(); assert(namedFrames.QLensMenu.shown); print=nativePrint
 assert(#diagnostics==2 and diagnostics[1]:find("не удалось") and diagnostics[2]:find("не удалось"))
end)
test("nil tooltip gap does not skip later tooltip",function() assert(ShoppingTooltip1.scripts.OnTooltipSetItem) end)

test("Shift and Ctrl alone do not intercept; exact modifiers",function()
 active(1); shownLink="item:100"
 IsAltKeyDown=function() return false end; IsShiftKeyDown=function() return true end
 assert(HandleModifiedItemClick(shownLink,"LeftButton")=="original")
 IsShiftKeyDown=function() return false end; IsControlKeyDown=function() return true end
 assert(HandleModifiedItemClick(shownLink,"LeftButton")=="original")
 IsAltKeyDown=function() return true end; IsShiftKeyDown=function() return true end
 assert(HandleModifiedItemClick(shownLink,"LeftButton")=="original")
 IsControlKeyDown=function() return false end; IsShiftKeyDown=function() return false end
end)
test("Configurable altshift and off",function()
 local before=opened; QuestMapFrame_OpenToQuestDetails=function() opened=opened+1 end
 QuestItemQuestsDB.key="altshift"
 assert(HandleModifiedItemClick(shownLink,"LeftButton")=="original")
 IsShiftKeyDown=function() return true end
 assert(HandleModifiedItemClick(shownLink,"LeftButton")==true and opened==before+1)
 QuestItemQuestsDB.key="off"
 assert(HandleModifiedItemClick(shownLink,"LeftButton")=="original")
 QuestItemQuestsDB.key="alt"; IsShiftKeyDown=function() return false end
end)
test("Guide chord passes item ID and respects bag validation",function()
 local old=QIQ.OpenGuide; local got
 QIQ.OpenGuide=function(_,id) got=id; return true end
 IsControlKeyDown=function() return true end
 assert(HandleModifiedItemClick(shownLink,"LeftButton")==true and got==100)
 got=nil; assert(HandleModifiedItemClick("item:105","LeftButton")=="original" and not got)
 QIQ.OpenGuide=old; IsControlKeyDown=function() return false end
end)
test("Authoritative IDs skip conflicting text fallback",function()
 objectiveByQuest[2]={{type="item",text="Wrong name: 0/1"}}
 active(1,2)
 local rows=assert(API.resolveItem(100,"","Wrong name"))
 assert(#rows==1 and rows[1].id==1)
end)
test("Known delivery ID never matches another quest by Russian title",function()
 questRows={{questID=998,title="Мартек Изгой"}}; event("QUEST_LOG_UPDATE")
 assert(API.resolveItem(5827,"","")==nil)
 questRows={{questID=1106,title="Martek the Exiled"}}; event("QUEST_LOG_UPDATE")
 assert(API.resolveItem(5827,"","")[1].id==1106)
end)
test("Localized static title and UI",function()
 active(); QIQ.locale="enUS"; QIQ_TITLES={enUS={[1]="First quest"},ruRU={[1]="Первый квест"}}
 GameTooltip.itemName="x"; GameTooltip.itemLink="item:100"; GameTooltip.scripts.OnTooltipSetItem(GameTooltip)
 local c=companionFor(GameTooltip); assert(table.concat(c.lines," "):find("QUESTS") and table.concat(c.lines," "):find("First quest"))
 QIQ.locale="ruRU"; QIQ_TITLES=nil
end)
test("Localization placeholders agree",function()
 for key,pair in pairs(QIQ.strings) do
  local function placeholders(s) local t={}; for v in s:gmatch("%%[sd]") do t[#t+1]=v end; return table.concat(t) end
  assert(pair[1] and pair[2] and placeholders(pair[1])==placeholders(pair[2]),key)
 end
end)
test("QLens command alias and renamed Guide loader",function()
 assert(SLASH_QUESTITEMQUESTS1=="/qiq" and SLASH_QUESTITEMQUESTS2=="/qlens")
 local oldGuide,oldAddons=QIQ.Guide,C_AddOns
 QIQ.Guide=nil
 C_AddOns={LoadAddOn=function(name) assert(name=="QLens_Guide"); QIQ.Guide={}; return true end}
 assert(QIQ.LoadGuide())
 QIQ.Guide=oldGuide; C_AddOns=oldAddons
end)
test("Craft material tooltip lists every profession without unknown quest warning",function()
 active()
 GameTooltip.itemName="Льняной материал"; GameTooltip.itemLink="item:2589"
 GameTooltip.scripts.OnTooltipSetItem(GameTooltip)
 local c=companionFor(GameTooltip); assert(c and c.shown)
 local text=table.concat(c.lines," ")
 for _,id in ipairs(QIQ_CRAFT_INDEX[2589]) do assert(text:find(QIQ.ProfessionName(id),1,true)) end
 assert(text:find("Ctrl+Alt",1,true)); assert(not text:find(QIQ.T("unknownItem"),1,true))
 assert(not QIQ.Guide,"hover must not load full guide")
 GameTooltip.scripts.OnHide(GameTooltip); assert(not c.shown)
end)
test("Craft and active quest coexist in the same tooltip",function()
 QIQ_CRAFT_INDEX[100]={165,197}; active(1)
 GameTooltip.itemName="РУССКИЙ ПРЕДМЕТ"; GameTooltip.itemLink="item:100"
 GameTooltip.scripts.OnTooltipSetItem(GameTooltip)
 local lines=companionFor(GameTooltip).lines
 local text=table.concat(lines," ")
 local questStart=text:find("ЗАДАНИЯ",1,true); local profStart=text:find("ПРОФЕССИИ",1,true)
 assert(questStart and profStart and questStart<profStart)
 local gap=false; for _,line in ipairs(lines) do if line==" " then gap=true end end; assert(gap)
 assert(text:find("Первый квест",1,true) and text:find("Кожевничество",1,true) and text:find("Портняжное дело",1,true))
 QIQ_CRAFT_INDEX[100]=nil
end)
if failures>0 then error(failures.." runtime tests failed") end
print("runtime tests: OK")
