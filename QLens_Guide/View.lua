local A,G=QIQ,QIQ.Guide
local T=A.T
local pageSize=10
local function fill(parent,r,g,b,a)
 local t=parent:CreateTexture(nil,"BACKGROUND"); t:SetAllPoints(); t:SetColorTexture(r,g,b,a or 1); return t
end
local function label(parent,text,size)
 local f=parent:CreateFontString(nil,"OVERLAY","GameFontHighlight")
 f:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",size or 15,"")
 f:SetJustifyH("LEFT"); f:SetText(text); return f
end
local function button(parent,text,width,callback)
 local b=CreateFrame("Button",nil,parent); b:SetSize(width,30)
 b.bg=fill(b,.14,.16,.19); b.text=label(b,text,14); b.text:SetPoint("CENTER")
 function b:SetText(v) self.text:SetText(v) end
 b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
 b:SetScript("OnClick",callback); return b
end
local function iconFor(id)
 if C_Item and C_Item.GetItemIconByID then return C_Item.GetItemIconByID(id) end
 if GetItemIcon then return GetItemIcon(id) end
end
function G:RenderDetail()
 for _,row in ipairs(self.detailPool) do row:Hide() end
 local q=self.selected and self.data.quests[self.selected]
 self.cardTitle:SetText(q and self:Title(self.selected) or T("select"))
 self.cardMeta:SetText(q and (T("level",tostring(q.level or "?"),tostring(q.minLevel or "?")).."  /  "..self:Zone(q.zone).."  /  "..T(self:Status(self.selected))) or T("browseHint"))
 for key,b in pairs(self.tabs) do b.bg:SetColorTexture(key==self.tab and .32 or .12,key==self.tab and .25 or .14,key==self.tab and .12 or .17,1) end
 local rows=q and (self.tab=="rewards" and self:RewardRows(self.selected) or self:Rows(self.selected)) or {}
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
  if (record.tab or "overview")==self.tab and not (self.tab=="overview" and i<=3) then
   n=n+1
   local row=self.detailPool[n]
   if not row then
    row=CreateFrame("Button",nil,self.content)
    row.text=label(row,""); row.text:SetWordWrap(true)
    row.icon=row:CreateTexture(nil,"ARTWORK"); row.icon:SetSize(36,36); row.icon:SetPoint("LEFT",10,0)
    row.bg=fill(row,.13,.15,.18)
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
   row.bg:SetColorTexture(record.heading and .20 or .11,record.heading and .18 or .13,record.heading and .13 or .16,1)
   local left=icon and 58 or 12
   row:SetWidth(self.detailWidth); row.text:ClearAllPoints(); row.text:SetPoint("TOPLEFT",left,-10)
   row.text:SetWidth(self.detailWidth-left-16)
   row.text:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",record.heading and 18 or 16,"")
   if record.heading then row.text:SetTextColor(1,.82,.45)
   elseif record.action then row.text:SetTextColor(.52,.83,1)
   else row.text:SetTextColor(.94,.94,.90) end
   row.text:SetText(record.text)
   local height=math.max(icon and 54 or 38,row.text:GetStringHeight()+20)
   if record.heading then y=y+12 end
   row:SetHeight(height); row:ClearAllPoints(); row:SetPoint("TOPLEFT",0,-y); y=y+height+5; row:Show()
  end
 end
 if n==0 then self.empty:SetText(q and T("noData") or T("browseHint")); self.empty:Show() else self.empty:Hide() end
 self.content:SetHeight(math.max(y,1)); self.scroll:SetVerticalScroll(0)
 self.back:SetEnabled(self.cursor>1); self.forward:SetEnabled(self.cursor<#self.history)
 self:RenderList()
end
function G:RenderList()
 local pages=math.max(1,math.ceil(#self.results/pageSize)); self.page=math.max(1,math.min(self.page or 1,pages))
 for i,b in ipairs(self.listPool) do
  local id=self.results[(self.page-1)*pageSize+i]; b.questID=id
  if id then
   local q=self.data.quests[id]
   b.text:SetText(self:Title(id)); b.meta:SetText((q.level and "["..q.level.."]  " or "")..T(self:Status(id)))
   b.bg:SetColorTexture(id==self.selected and .27 or .11,id==self.selected and .23 or .13,id==self.selected and .15 or .16,1)
   b:Show()
  else b:Hide() end
 end
 self.counter:SetText(#self.results==0 and T("noResults") or T("page",#self.results,self.page,pages))
 self.prev:SetEnabled(self.page>1); self.next:SetEnabled(self.page<pages)
end
function G:Refresh()
 self.results=self:Query(self.search:GetText(),self.filter,self.itemID); self:RenderList()
 self.itemLabel:SetText(self.itemID and T("itemFilter",self:EntityName("item",self.itemID)) or T("search"))
end
function G:CreateWindow()
 local f=CreateFrame("Frame","QuestItemQuestsGuide",UIParent)
 f:SetSize(1040,720); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG"); f:SetClampedToScreen(true)
 local scale=math.min(1,(UIParent:GetWidth()-24)/1040,(UIParent:GetHeight()-24)/720)
 if scale>0 then f:SetScale(scale) end
 f:EnableMouse(true); f:SetMovable(true); f:RegisterForDrag("LeftButton")
 f:SetScript("OnDragStart",f.StartMoving); f:SetScript("OnDragStop",f.StopMovingOrSizing)
 fill(f,.055,.065,.08)
 local header=CreateFrame("Frame",nil,f); header:SetPoint("TOPLEFT",1,-1); header:SetSize(1038,54); fill(header,.17,.14,.09)
 local emblem=header:CreateTexture(nil,"ARTWORK"); emblem:SetSize(34,34); emblem:SetPoint("LEFT",16,0); emblem:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
 local title=label(header,T("guideTitle"),21); title:SetPoint("LEFT",62,0); title:SetTextColor(1,.83,.48)
 local close=CreateFrame("Button",nil,f,"UIPanelCloseButton"); close:SetPoint("TOPRIGHT",-5,-8); close:SetScript("OnClick",function() f:Hide() end)
 UISpecialFrames=UISpecialFrames or {}; table.insert(UISpecialFrames,"QuestItemQuestsGuide")
 self.frame=f; self.filter="all"; self.tab="overview"; self.page=1; self.listPool={}; self.detailPool={}; self.results={}; self.tabs={}
 self.search=CreateFrame("EditBox",nil,f,"InputBoxTemplate"); self.search:SetSize(560,28); self.search:SetPoint("TOPLEFT",24,-68)
 self.search:SetAutoFocus(false); self.search:SetMaxLetters(160); self.search:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",16,"")
 self.search:SetScript("OnEscapePressed",function(s) s:ClearFocus() end)
 self.search:SetScript("OnEnterPressed",function(s) s:ClearFocus(); G:Refresh() end)
 self.search:SetScript("OnTextChanged",function()
  self.page=1; self.searchRevision=(self.searchRevision or 0)+1; local revision=self.searchRevision
  if C_Timer and C_Timer.After then C_Timer.After(.2,function() if revision==self.searchRevision and f:IsShown() then self:Refresh() end end) else self:Refresh() end
 end)
 local modes={"all","active","completed","absent"}; local mode=1
 self.filterButton=button(f,T("all"),180,function() mode=mode%#modes+1; self.filter=modes[mode]; self.filterButton:SetText(T(self.filter)); self.page=1; self:Refresh() end)
 self.filterButton:SetPoint("TOPLEFT",608,-66)
 self.clear=button(f,T("clear"),110,function() self.itemID=nil; self.page=1; self.search:SetText(""); self:Refresh() end); self.clear:SetPoint("TOPLEFT",802,-66)
 self.itemLabel=label(f,"",13); self.itemLabel:SetPoint("TOPLEFT",20,-107); self.itemLabel:SetWidth(990)
 local divider=f:CreateTexture(nil,"ARTWORK"); divider:SetColorTexture(.35,.29,.17,1); divider:SetSize(1,550); divider:SetPoint("TOPLEFT",327,-142)
 for i=1,pageSize do
  local b=CreateFrame("Button",nil,f); b:SetSize(292,47); b:SetPoint("TOPLEFT",20,-144-(i-1)*49); b.bg=fill(b,.11,.13,.16)
  b.text=label(b,"",15); b.text:SetPoint("TOPLEFT",10,-5); b.text:SetWidth(272); b.text:SetWordWrap(false)
  b.meta=label(b,"",12); b.meta:SetPoint("BOTTOMLEFT",10,6); b.meta:SetTextColor(.72,.69,.59)
  b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight"); b:SetScript("OnClick",function(s) if s.questID then self:Open(s.questID) end end); self.listPool[i]=b
 end
 self.prev=button(f,T("previous"),136,function() self.page=self.page-1; self:RenderList() end); self.prev:SetPoint("BOTTOMLEFT",20,44)
 self.next=button(f,T("next"),136,function() self.page=self.page+1; self:RenderList() end); self.next:SetPoint("BOTTOMLEFT",176,44)
 self.counter=label(f,"",12); self.counter:SetPoint("BOTTOMLEFT",20,22); self.counter:SetWidth(300)
 self.back=button(f,"<",34,function() if self:Move(-1) then self:CaptureRewards(); self:RenderDetail() end end); self.back:SetPoint("TOPLEFT",345,-139)
 self.forward=button(f,">",34,function() if self:Move(1) then self:CaptureRewards(); self:RenderDetail() end end); self.forward:SetPoint("TOPLEFT",383,-139)
 self.cardTitle=label(f,"",23); self.cardTitle:SetPoint("TOPLEFT",430,-143); self.cardTitle:SetWidth(460)
 local ok,portrait=pcall(CreateFrame,"PlayerModel",nil,f)
 if ok and portrait and portrait.SetCreature then
  self.portrait=portrait; portrait:SetSize(95,100); portrait:SetPoint("TOPRIGHT",-25,-135)
  if portrait.SetPortraitZoom then portrait:SetPortraitZoom(1) end
  if portrait.SetCamDistanceScale then portrait:SetCamDistanceScale(1) end
 end
 self.cardMeta=label(f,"",13); self.cardMeta:SetPoint("TOPLEFT",345,-207); self.cardMeta:SetWidth(655); self.cardMeta:SetTextColor(.78,.75,.65)
 for i,key in ipairs({"overview","rewards","chain","requirements"}) do
  local tabKey=key
  local b=button(f,T(key=="rewards" and "rewardTitle" or key),157,function() self.tab=tabKey; if tabKey=="rewards" then self:CaptureRewards() end; self:RenderDetail() end)
  b:SetPoint("TOPLEFT",345+(i-1)*164,-246); self.tabs[key]=b
 end
 self.scroll=CreateFrame("ScrollFrame",nil,f,"UIPanelScrollFrameTemplate"); self.scroll:SetPoint("TOPLEFT",345,-288); self.scroll:SetPoint("BOTTOMRIGHT",-35,22)
 self.detailWidth=650; self.content=CreateFrame("Frame",nil,self.scroll); self.content:SetSize(self.detailWidth,1); self.scroll:SetScrollChild(self.content)
 self.empty=label(self.content,"",17); self.empty:SetPoint("TOPLEFT",15,-20); self.empty:SetWidth(610)
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
 if itemID then self.itemID=itemID; self.page=1; self.search:SetText("") end
 if id then self:Visit(id) end
 self.frame:Show(); self:Refresh()
 if itemID and self.results[1] then self:Visit(self.results[1]) elseif itemID then self.selected=nil end
 self:CaptureRewards(); self:RenderDetail(); return true
end
