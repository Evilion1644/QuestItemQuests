local A,G=QIQ,QIQ.Guide
local T=A.T
local pageSize=10
local FONT="Fonts\\ARIALN.TTF"
local function setFont(text,size)
 if text:SetFont(FONT,size,"")==false then text:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",size,"") end
end
local function border(parent)
 for _,edge in ipairs({"TOP","BOTTOM","LEFT","RIGHT"}) do
  local t=parent:CreateTexture(nil,"BORDER"); t:SetColorTexture(.43,.34,.21,.65)
  if edge=="TOP" or edge=="BOTTOM" then
   t:SetHeight(1); t:SetPoint(edge.."LEFT",0,0); t:SetPoint(edge.."RIGHT",0,0)
  else
   t:SetWidth(1); t:SetPoint("TOP"..edge,0,0); t:SetPoint("BOTTOM"..edge,0,0)
  end
 end
end
local function fill(parent,r,g,b,a)
 local t=parent:CreateTexture(nil,"BACKGROUND"); t:SetAllPoints(); t:SetColorTexture(r,g,b,a or 1); return t
end
-- Baked frame decoration: no OnUpdate, animation or external artwork needed.
local function wash(parent,x,y,w,h,left,right)
 for i=0,23 do
  local f=i/23; local t=parent:CreateTexture(nil,"BACKGROUND",nil,1)
  t:SetSize(w/24+1,h); t:SetPoint("TOPLEFT",x+i*w/24,y)
  t:SetColorTexture(left[1]*(1-f)+right[1]*f,left[2]*(1-f)+right[2]*f,left[3]*(1-f)+right[3]*f,1)
 end
end
local function rule(parent,x,y,w,r,g,b)
 local t=parent:CreateTexture(nil,"ARTWORK"); t:SetSize(w,1); t:SetPoint("TOPLEFT",x,y); t:SetColorTexture(r,g,b,.6); return t
end
local function ornament(parent,x,y)
 rule(parent,x,y,38,.85,.65,.30)
 rule(parent,x,y-4,20,.52,.39,.22)
 local t=parent:CreateTexture(nil,"ARTWORK");t:SetSize(4,4);t:SetPoint("TOPLEFT",x+42,y+1);t:SetColorTexture(.96,.76,.40,1)
end
local function titleFont(text,size)
 text:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",size,"")
end
local function label(parent,text,size)
 local f=parent:CreateFontString(nil,"OVERLAY","GameFontHighlight")
 setFont(f,size or 16)
 f:SetJustifyH("LEFT"); f:SetText(text); return f
end
local function button(parent,text,width,callback)
 local b=CreateFrame("Button",nil,parent); b:SetSize(width,30)
 b.bg=fill(b,.135,.12,.095); border(b); b.text=label(b,text,16); b.text:SetPoint("CENTER")
 function b:SetText(v) self.text:SetText(v) end
 b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
 b:SetScript("OnClick",callback); return b
end
local function iconFor(id)
 if C_Item and C_Item.GetItemIconByID then return C_Item.GetItemIconByID(id) end
 if GetItemIcon then return GetItemIcon(id) end
end
function G:RenderDetail()
 if self.mode=="prices" or self.mode=="settings" then return end
 for _,row in ipairs(self.detailPool) do row:Hide() end
 local craft=self.mode=="craft"
 local q=not craft and self.selected and self.data.quests[self.selected]
 local recipe=craft and self.crafts[self.recipeSelected]
 self.cardTitle:SetText(craft and self:CraftTitle(self.recipeSelected) or q and self:Title(self.selected) or T("select"))
 titleFont(self.cardTitle,24)
 self.cardTitle:SetTextColor(1,.91,.72)
 self.cardTitle:SetWidth(640)
 self.cardKind:SetText(T(craft and "recipeCard" or "questCard"))
 self.cardKind:SetTextColor(craft and .45 or 1,craft and .85 or .81,craft and .95 or .4)
 self.cardMeta:SetText(craft and (recipe and A.ProfessionName(recipe.p) or T("craftSelect")) or q and (T("level",tostring(q.level or "?"),tostring(q.minLevel or "?")).."  /  "..self:Zone(q.zone).."  /  "..T(self:Status(self.selected))) or T("browseHint"))
 local titleHeight=self.cardTitle:GetStringHeight()
 local metaY=218+math.max(28,titleHeight)+10
 self.cardMeta:ClearAllPoints(); self.cardMeta:SetPoint("TOPLEFT",345,-metaY)
 local tabsY=metaY+self.cardMeta:GetStringHeight()+17
 for i,key in ipairs({"overview","rewards","chain","requirements"}) do
  self.tabs[key]:ClearAllPoints(); self.tabs[key]:SetPoint("TOPLEFT",345+(i-1)*164,-tabsY)
 end
 self.scroll:ClearAllPoints(); self.scroll:SetPoint("TOPLEFT",345,-(tabsY+(craft and 0 or 43))); self.scroll:SetPoint("BOTTOMRIGHT",-35,22)
 for key,b in pairs(self.tabs) do
  if craft then b:Hide() else b:Show() end
  b.bg:SetColorTexture(key==self.tab and .26 or .085,key==self.tab and .205 or .092,key==self.tab and .12 or .095,1)
  b.text:SetTextColor(key==self.tab and 1 or .71,key==self.tab and .86 or .76,key==self.tab and .54 or .75)
 end
 local rows=craft and self:CraftRows(self.recipeSelected) or q and (self.tab=="rewards" and self:RewardRows(self.selected) or self:Rows(self.selected)) or {}
 if self.portrait then
  self.portrait:Hide()
  local npc=q and ((q.finish and q.finish[1] and q.finish[1][1]) or (q.start and q.start[1] and q.start[1][1]))
  if type(npc)=="number" and self.portrait.SetCreature then
   local ok=pcall(self.portrait.SetCreature,self.portrait,npc)
   if ok then self.portrait:Show() end
  end
 end
 if q and self.tab=="overview" then
  local rewards=self:RewardRows(self.selected)
  for i,row in ipairs(rewards) do row.tab="overview"; table.insert(rows,3+i,row) end
 end
 local y,n=0,0
 for i,record in ipairs(rows) do
  -- The title and metadata live in a fixed header, not in the scrolling body.
  if craft or ((record.tab or "overview")==self.tab and not (self.tab=="overview" and i<=3)) then
   n=n+1
   local row=self.detailPool[n]
   if not row then
    row=CreateFrame("Button",nil,self.content)
    row.text=label(row,""); row.text:SetWordWrap(true)
    row.icon=row:CreateTexture(nil,"ARTWORK"); row.icon:SetSize(36,36); row.icon:SetPoint("LEFT",10,0)
    row.bg=fill(row,.13,.15,.18)
    row.rule=row:CreateTexture(nil,"ARTWORK"); row.rule:SetHeight(1); row.rule:SetPoint("BOTTOMLEFT",12,0); row.rule:SetPoint("BOTTOMRIGHT",-12,0); row.rule:SetColorTexture(.60,.45,.23,.5)
    row:SetScript("OnClick",function(s)
     local action=s.action; if not action then return end
     if action.kind=="quest" then G:Open(action.id)
     elseif action.kind=="log" then if not A.OpenActiveQuest(action.id) then print(T("openFailed",G:Title(action.id))) end
     elseif action.kind=="expand" then
      G.expandedPoints=G.expandedPoints or {}; G.expandedPoints[action.key]=not G.expandedPoints[action.key]
      local offset=G.scroll:GetVerticalScroll(); G:RenderDetail(); G.scroll:SetVerticalScroll(math.min(offset,math.max(0,G.content:GetHeight()-G.scroll:GetHeight())))
     elseif action.kind=="point" then G:ShowPoint(action.point)
     elseif action.kind=="item" then G:Open(nil,action.id) end
    end)
    row:SetScript("OnEnter",function(s)
     if s.action and s.action.kind=="item" and GameTooltip and GameTooltip.SetHyperlink then
      GameTooltip:SetOwner(s,"ANCHOR_RIGHT"); GameTooltip:SetHyperlink("item:"..s.action.id); GameTooltip:Show()
     end
    end)
    row:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
    self.detailPool[n]=row
   end
   row.action=record.action
   local itemID=record.itemID or (record.action and record.action.kind=="item" and record.action.id)
   local icon=record.icon or (itemID and iconFor(itemID))
   if itemID and not icon then icon="Interface\\Icons\\INV_Misc_QuestionMark" end
   if icon then row.icon:SetTexture(icon); row.icon:Show() else row.icon:Hide() end
   if record.heading then
    row.bg:SetColorTexture(.19,.155,.10,.35); row.rule:Show()
   elseif icon or record.action then
    row.bg:SetColorTexture(.105,.15,.155,.75); row.rule:Hide()
   else
    row.bg:SetColorTexture(0,0,0,0); row.rule:Hide()
   end
   local left=icon and 58 or 12
   row:SetWidth(self.detailWidth); row.text:ClearAllPoints(); row.text:SetPoint("TOPLEFT",left,-10)
   row.text:SetWidth(self.detailWidth-left-16)
   setFont(row.text,record.muted and 14 or 17)
   if record.heading then titleFont(row.text,17) end
   if record.muted then row.text:SetTextColor(.67,.74,.81)
   elseif record.heading then row.text:SetTextColor(1,.87,.58)
   elseif record.action then row.text:SetTextColor(.50,.88,.85)
   else row.text:SetTextColor(.87,.86,.79) end
   row.text:SetText(record.text)
   local height=math.max(icon and 54 or 38,row.text:GetStringHeight()+20)
   if record.heading and n>1 then y=y+14 end
   row:SetHeight(height); row:ClearAllPoints(); row:SetPoint("TOPLEFT",0,-y); y=y+height+5; row:Show()
  end
 end
 if n==0 then self.empty:SetText(craft and T("craftEmpty") or q and T("noData") or self.itemID and T("emptyQuestItem") or T("browseHint")); self.empty:Show() else self.empty:Hide() end
 self.content:SetHeight(math.max(y,1)); self.scroll:SetVerticalScroll(0)
 self.back:SetEnabled(not craft and self.cursor>1); self.forward:SetEnabled(not craft and self.cursor<#self.history)
 self:RenderList()
end
function G:RenderList()
 if self.mode=="prices" or self.mode=="settings" then return end
 local pages=math.max(1,math.ceil(#self.results/pageSize)); self.page=math.max(1,math.min(self.page or 1,pages))
 for i,b in ipairs(self.listPool) do
  local id=self.results[(self.page-1)*pageSize+i]; b.questID=self.mode~="craft" and id or nil; b.recipeID=self.mode=="craft" and id or nil
  if id then
   if self.mode=="craft" then
    local r=self.crafts[id]; b.text:SetText(self:CraftTitle(id)); b.meta:SetText(A.ProfessionName(r.p))
   else
    local q=self.data.quests[id]
    b.text:SetText(self:Title(id)); b.meta:SetText((q.level and "["..q.level.."]  " or "")..T(self:Status(id)))
   end
   local selected=id==(self.mode=="craft" and self.recipeSelected or self.selected)
   b.bg:SetColorTexture(selected and .255 or .10,selected and .205 or .105,selected and .12 or .105,selected and 1 or .65)
   local resultItem=self.mode=="craft" and self.crafts[id].item or 0
   local texture=self.mode=="craft" and (resultItem>0 and iconFor(resultItem) or "Interface\\Icons\\Trade_Engineering") or "Interface\\Icons\\INV_Misc_Note_01"
   b.icon:SetTexture(texture or "Interface\\Icons\\Trade_Engineering")
   if selected then b.marker:Show() else b.marker:Hide() end
   b.text:SetTextColor(selected and 1 or .92,selected and .9 or .95,selected and .64 or .99)
   b:Show()
  else b:Hide() end
 end
 self.counter:SetText(#self.results==0 and T("noResults") or T(self.mode=="craft" and "craftPage" or "page",#self.results,self.page,pages))
 self.prev:SetEnabled(self.page>1); self.next:SetEnabled(self.page<pages)
end
function G:RefreshPricePane()
 local value=A.VendorPrice.GetThreshold()
 self.priceInputs[1]:SetText(tostring(math.floor(value/10000)))
 self.priceInputs[2]:SetText(tostring(math.floor(value/100)%100))
 self.priceInputs[3]:SetText(tostring(value%100))
 local formatted=value==0 and T("priceGuideInactive") or GetCoinTextureString and GetCoinTextureString(value) or
  string.format("%d %s  %d %s  %d %s",math.floor(value/10000),T("priceGold"),math.floor(value/100)%100,T("priceSilver"),value%100,T("priceCopper"))
 self.priceStatus:SetText(T("priceGuideCurrent",formatted))
end
function G:Refresh()
 self:ShowPriceView(self.mode=="prices" or self.mode=="settings")
 if self.mode=="settings" then self:RefreshSettingsPane() end
 if self.mode=="prices" then self:RefreshPricePane() end
 self:StyleModeTabs()
 if self.mode=="prices" or self.mode=="settings" then return end
 local craft=self.mode=="craft"
 self.results=craft and self:CraftQuery(self.search:GetText(),self.itemID) or self:Query(self.search:GetText(),self.filter,self.itemID)
 self.filterButton:SetEnabled(not craft)
 self.filterButton:SetText(T(craft and "craftAll" or self.filter))
 local quests=self:Query("","all",self.itemID)
 local recipes=self:CraftQuery("",self.itemID)
 self.modeTabs.quests:SetText(T("questTab",#quests)); self.modeTabs.craft:SetText(T("recipeTab",#recipes))
 self.listHeading:SetText(T(craft and "recipeList" or "questList"))
 if self.search:GetText()=="" then self.searchHint:Show() else self.searchHint:Hide() end
 self.itemLabel:SetText(self.itemID and T(craft and "craftMaterial" or "itemFilter",craft and self:CraftItemName(self.itemID) or self:EntityName("item",self.itemID)) or T(craft and "craftSearch" or "search"))
 if craft then
  local found=false; for _,id in ipairs(self.results) do if id==self.recipeSelected then found=true; break end end
  if not found then self.recipeSelected=self.results[1] end
  self:RenderDetail()
 else
  local found=false; for _,id in ipairs(self.results) do if id==self.selected then found=true; break end end
  if not found then self.selected=self.results[1] end
  self:RenderDetail()
 end
end
function G:ShowPriceView(active)
 if active then
  for _,control in ipairs(self.browseControls) do control:Hide() end
  self.pricePane:SetShown(self.mode=="prices")
  self.settingsPane:SetShown(self.mode=="settings")
 else
  self.pricePane:Hide()
  self.settingsPane:Hide()
  for _,control in ipairs(self.browseControls) do control:Show() end
 end
end
function G:StyleModeTabs()
 for mode,b in pairs(self.modeTabs) do
  local selected=mode==(self.mode or "quests")
  local r,g,bl=1,.77,.35
  if mode=="craft" then r,g,bl=.35,.85,.79 end
  if mode=="prices" then r,g,bl=1,.55,.38 end
  b.bg:SetColorTexture(selected and r*.28 or .09,selected and g*.28 or .11,selected and bl*.28 or .12,1)
  b.marker:SetColorTexture(r,g,bl,1)
  b.text:SetTextColor(selected and 1 or .75,selected and .9 or .82,selected and .62 or .9)
  if selected then b.marker:Show() else b.marker:Hide() end
 end
end
function G:SetMode(mode)
 self.mode=mode; self.page=1; self.search:SetText(""); self:Refresh(); if mode~="prices" then self:RenderDetail() end
end
function G:CreateWindow()
 local f=CreateFrame("Frame","QuestItemQuestsGuide",UIParent)
 f:SetSize(1040,760); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG"); f:SetClampedToScreen(true)
 local scale=math.min(1,(UIParent:GetWidth()-24)/1040,(UIParent:GetHeight()-24)/760)
 if scale>0 then f:SetScale(scale) end
 f:EnableMouse(true); f:SetMovable(true); f:RegisterForDrag("LeftButton")
 f:SetScript("OnDragStart",f.StartMoving); f:SetScript("OnDragStop",f.StopMovingOrSizing)
 fill(f,.045,.062,.066); border(f)
 wash(f,1,-1,1038,58,{.20,.155,.095},{.045,.10,.115})
 wash(f,12,-183,308,553,{.10,.105,.10},{.065,.08,.085})
 wash(f,334,-182,681,553,{.070,.092,.095},{.045,.065,.075})
 ornament(f,18,-7); ornament(f,18,-748)
 rule(f,20,-179,990,.49,.39,.23)
 rule(f,20,-680,292,.49,.39,.23)
 local header=CreateFrame("Frame",nil,f); header:SetPoint("TOPLEFT",1,-1); header:SetSize(1038,54); fill(header,0,0,0,0)
 local emblem=header:CreateTexture(nil,"ARTWORK"); emblem:SetSize(38,38); emblem:SetPoint("LEFT",16,0); emblem:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
 local title=label(header,T("guideTitle"),21); titleFont(title,22); title:SetPoint("LEFT",66,0); title:SetTextColor(1,.86,.56)
 local sigil=header:CreateTexture(nil,"ARTWORK"); sigil:SetSize(110,48);sigil:SetPoint("RIGHT",-54,0)
 sigil:SetTexture("Interface\\QuestFrame\\UI-QuestLogTitleHighlight")
 if sigil.SetVertexColor then sigil:SetVertexColor(.28,.65,.64,.20) end
 self.modeTabs={}
 for i,mode in ipairs({"quests","craft","prices","settings"}) do
  local target=mode
  local b=button(f,T(mode=="quests" and "quests" or mode=="craft" and "craft" or mode=="prices" and "priceTab" or "settingsTab"),240,function() self:SetMode(target) end)
  b:SetSize(240,36)
  local icon=b:CreateTexture(nil,"ARTWORK");icon:SetSize(24,24);icon:SetPoint("LEFT",12,0)
  icon:SetTexture(mode=="quests" and "Interface\\Icons\\INV_Misc_Note_01" or mode=="craft" and "Interface\\Icons\\Trade_BlackSmithing" or mode=="prices" and "Interface\\Icons\\INV_Misc_Coin_01" or "Interface\\Icons\\Trade_Engineering")
  b.text:ClearAllPoints();b.text:SetPoint("CENTER",12,0)
  b:SetPoint("TOPLEFT",20+(i-1)*248,-65)
  b.marker=b:CreateTexture(nil,"OVERLAY"); b.marker:SetColorTexture(1,.79,.35,1)
  b.marker:SetHeight(3); b.marker:SetPoint("BOTTOMLEFT",1,0); b.marker:SetPoint("BOTTOMRIGHT",-1,0)
  self.modeTabs[mode]=b
 end
 local close=CreateFrame("Button",nil,f,"UIPanelCloseButton"); close:SetPoint("TOPRIGHT",-5,-8); close:SetScript("OnClick",function() f:Hide() end)
 UISpecialFrames=UISpecialFrames or {}; table.insert(UISpecialFrames,"QuestItemQuestsGuide")
 self.frame=f; self.filter="all"; self.tab="overview"; self.page=1; self.listPool={}; self.detailPool={}; self.results={}; self.tabs={}
 self.search=CreateFrame("EditBox",nil,f,"InputBoxTemplate"); self.search:SetSize(560,28); self.search:SetPoint("TOPLEFT",24,-117)
 self.search:SetAutoFocus(false); self.search:SetMaxLetters(160); setFont(self.search,17)
 self.searchHint=label(f,T("searchLabel"),16); self.searchHint:SetPoint("TOPLEFT",30,-124); self.searchHint:SetTextColor(.6,.68,.77)
 self.search:SetScript("OnEscapePressed",function(s) s:ClearFocus() end)
 self.search:SetScript("OnEnterPressed",function(s) s:ClearFocus(); G:Refresh() end)
 self.search:SetScript("OnTextChanged",function()
  self.page=1; self.searchRevision=(self.searchRevision or 0)+1; local revision=self.searchRevision
  if C_Timer and C_Timer.After then C_Timer.After(.2,function() if revision==self.searchRevision and f:IsShown() then self:Refresh() end end) else self:Refresh() end
 end)
 local modes={"all","active","completed","absent"}; local mode=1
 self.filterButton=button(f,T("all"),180,function() mode=mode%#modes+1; self.filter=modes[mode]; self.filterButton:SetText(T(self.filter)); self.page=1; self:Refresh() end)
 self.filterButton:SetPoint("TOPLEFT",608,-115)
 self.clear=button(f,T("clear"),110,function() self.itemID=nil; self.page=1; self.search:SetText(""); self:Refresh(); self:RenderDetail() end); self.clear:SetPoint("TOPLEFT",802,-115)
 self.itemLabel=label(f,"",13); self.itemLabel:SetPoint("TOPLEFT",20,-160); self.itemLabel:SetWidth(990)
 local divider=f:CreateTexture(nil,"ARTWORK"); divider:SetColorTexture(.35,.29,.17,1); divider:SetSize(1,546); divider:SetPoint("TOPLEFT",327,-190)
 self.listHeading=label(f,"",15); self.listHeading:SetPoint("TOPLEFT",20,-192); self.listHeading:SetTextColor(.78,.68,.46)
 for i=1,pageSize do
  local b=CreateFrame("Button",nil,f); b:SetSize(292,44); b:SetPoint("TOPLEFT",20,-216-(i-1)*46); b.bg=fill(b,.11,.13,.16)
  b.marker=b:CreateTexture(nil,"OVERLAY"); b.marker:SetColorTexture(1,.79,.35,1); b.marker:SetWidth(3); b.marker:SetPoint("TOPLEFT",0,0); b.marker:SetPoint("BOTTOMLEFT",0,0)
  b.icon=b:CreateTexture(nil,"ARTWORK");b.icon:SetSize(26,26);b.icon:SetPoint("LEFT",10,0)
  b.text=label(b,"",17); b.text:SetPoint("TOPLEFT",46,-5); b.text:SetWidth(234); b.text:SetWordWrap(false)
  b.meta=label(b,"",14); b.meta:SetPoint("BOTTOMLEFT",46,6); b.meta:SetTextColor(.64,.73,.72)
  b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight"); b:SetScript("OnClick",function(s)
   if s.recipeID then self.recipeSelected=s.recipeID; self:RenderDetail()
   elseif s.questID then self:Open(s.questID) end
  end); self.listPool[i]=b
 end
 self.prev=button(f,T("previous"),136,function() self.page=self.page-1; self:RenderList() end); self.prev:SetPoint("BOTTOMLEFT",20,44)
 self.next=button(f,T("next"),136,function() self.page=self.page+1; self:RenderList() end); self.next:SetPoint("BOTTOMLEFT",176,44)
 self.counter=label(f,"",12); self.counter:SetPoint("BOTTOMLEFT",20,22); self.counter:SetWidth(300)
 self.back=button(f,"<",34,function() if self:Move(-1) then self:CaptureRewards(); self:RenderDetail() end end); self.back:SetPoint("TOPLEFT",924,-185)
 self.forward=button(f,">",34,function() if self:Move(1) then self:CaptureRewards(); self:RenderDetail() end end); self.forward:SetPoint("TOPLEFT",962,-185)
 self.cardKind=label(f,"",14); self.cardKind:SetPoint("TOPLEFT",345,-192)
 self.cardTitle=label(f,"",23); self.cardTitle:SetPoint("TOPLEFT",345,-218); self.cardTitle:SetWidth(640)
 self.cardMeta=label(f,"",16); self.cardMeta:SetPoint("TOPLEFT",345,-207); self.cardMeta:SetWidth(655); self.cardMeta:SetTextColor(.62,.77,.75)
 for i,key in ipairs({"overview","rewards","chain","requirements"}) do
  local tabKey=key
  local b=button(f,T(key=="rewards" and "rewardTitle" or key),157,function() self.tab=tabKey; if tabKey=="rewards" then self:CaptureRewards() end; self:RenderDetail() end)
  b:SetPoint("TOPLEFT",345+(i-1)*164,-246); self.tabs[key]=b
 end
 self.scroll=CreateFrame("ScrollFrame",nil,f,"UIPanelScrollFrameTemplate"); self.scroll:SetPoint("TOPLEFT",345,-288); self.scroll:SetPoint("BOTTOMRIGHT",-35,22)
 self.detailWidth=650; self.content=CreateFrame("Frame",nil,self.scroll); self.content:SetSize(self.detailWidth,1); self.scroll:SetScrollChild(self.content)
 self.empty=label(self.content,"",17); self.empty:SetPoint("TOPLEFT",15,-20); self.empty:SetWidth(610)
 local pane=CreateFrame("Frame",nil,f); pane:SetSize(992,620); pane:SetPoint("TOPLEFT",20,-113); pane:EnableMouse(true)
 pane:SetFrameLevel(f:GetFrameLevel()+20)
 fill(pane,.045,.062,.066); border(pane)
 wash(pane,1,-1,990,72,{.18,.13,.09},{.07,.12,.13})
 local priceIcon=pane:CreateTexture(nil,"ARTWORK"); priceIcon:SetSize(42,42); priceIcon:SetPoint("TOPLEFT",24,-16); priceIcon:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
 local priceTitle=label(pane,T("priceGuideTitle"),26); titleFont(priceTitle,26); priceTitle:SetPoint("TOPLEFT",78,-22); priceTitle:SetTextColor(1,.83,.54)
 local intro=label(pane,T("priceGuideIntro"),18); intro:SetPoint("TOPLEFT",28,-100); intro:SetWidth(915); intro:SetWordWrap(true); intro:SetTextColor(.8,.85,.84)
 local card=CreateFrame("Frame",nil,pane); card:SetSize(624,245); card:SetPoint("TOPLEFT",28,-180); fill(card,.09,.12,.13,.94); border(card)
 local cardTitle=label(card,T("priceGuideLimit"),19); cardTitle:SetPoint("TOPLEFT",22,-20); cardTitle:SetTextColor(1,.84,.57)
 self.priceInputs={}
 for i,key in ipairs({"priceGold","priceSilver","priceCopper"}) do
  local x=24+(i-1)*190
  local caption=label(card,T(key),16); caption:SetPoint("TOPLEFT",x,-66); caption:SetTextColor(.82,.84,.81)
  local input=CreateFrame("EditBox",nil,card,"InputBoxTemplate"); input:SetSize(146,30); input:SetPoint("TOPLEFT",x+3,-92)
  input:SetAutoFocus(false); input:SetNumeric(true); input:SetMaxLetters(7); setFont(input,19)
  input:SetScript("OnEscapePressed",function(s) s:ClearFocus() end)
  self.priceInputs[i]=input
 end
 local save=button(card,T("priceSave"),148,function()
  local inputs=self.priceInputs
  local gold=math.min(9999999,tonumber(inputs[1]:GetText()) or 0)
  local silver=math.min(99,tonumber(inputs[2]:GetText()) or 0)
  local copper=math.min(99,tonumber(inputs[3]:GetText()) or 0)
  A.VendorPrice.SetThreshold(gold*10000+silver*100+copper)
  self:RefreshPricePane()
 end); save:SetPoint("BOTTOMLEFT",24,22)
 local disable=button(card,T("priceOff"),148,function() A.VendorPrice.SetThreshold(0); self:RefreshPricePane() end)
 disable:SetPoint("LEFT",save,"RIGHT",16,0)
 self.priceStatus=label(pane,"",18); self.priceStatus:SetPoint("TOPLEFT",28,-457); self.priceStatus:SetTextColor(.9,.8,.55)
 local example=label(pane,T("priceGuideExample"),17); example:SetPoint("TOPLEFT",28,-495); example:SetWidth(900); example:SetWordWrap(true); example:SetTextColor(.66,.76,.8)
 self.pricePane=pane; pane:Hide()
 self:CreateSettingsPane(f)
 self.browseControls={self.search,self.searchHint,self.filterButton,self.clear,self.itemLabel,divider,self.listHeading,
  self.prev,self.next,self.counter,self.back,self.forward,self.cardKind,self.cardTitle,self.cardMeta,self.scroll}
 for _,row in ipairs(self.listPool) do table.insert(self.browseControls,row) end
 for _,tab in pairs(self.tabs) do table.insert(self.browseControls,tab) end
 f:SetScript("OnHide",function() self.search:ClearFocus() end)
 local events=CreateFrame("Frame")
 for _,event in ipairs({"QUEST_LOG_UPDATE","QUEST_TURNED_IN","GET_ITEM_INFO_RECEIVED"}) do events:RegisterEvent(event) end
 events:SetScript("OnEvent",function()
  if not f:IsShown() or self.pendingRefresh then return end
  self.pendingRefresh=true
  local function refresh()
   self.pendingRefresh=false
   if f:IsShown() then local offset=self.scroll:GetVerticalScroll(); self:Refresh(); self:RenderDetail(); self.scroll:SetVerticalScroll(math.min(offset,math.max(0,self.content:GetHeight()-self.scroll:GetHeight()))) end
  end
  if C_Timer and C_Timer.After then C_Timer.After(.1,refresh) else refresh() end
 end)
end
function G:CaptureRewards()
 if self.selected then self.rewardSnapshot=self.rewardSnapshot or {}; self.rewardSnapshot[self.selected]=self:ReadRewards(self.selected) end
end
function G:Open(id,itemID)
 if id and not self.data.quests[id] then print(T("questUnavailable",tostring(id))); return false end
 if not self.frame then self:CreateWindow() end
 if id then self.mode="quests" end
 if itemID then
  self.filter="all"
  self.mode=#self:Query("","all",itemID)>0 and "quests" or A.CraftProfessions(itemID) and "craft" or "quests"
 end
 if itemID then self.itemID=itemID; self.page=1; self.search:SetText("") end
 self.frame:Show(); self:Refresh()
 if self.mode=="prices" or self.mode=="settings" then return true end
 if id then self:Visit(id) end
 if self.mode~="craft" then
  if itemID and self.results[1] then
   local nextID=self.results[1]
   for _,qid in ipairs(self.results) do if A.ActiveQuests[qid] then nextID=qid; break end end
   self:Visit(nextID)
  elseif itemID then self.selected=nil end
 end
 self:CaptureRewards(); self:RenderDetail(); return true
end
