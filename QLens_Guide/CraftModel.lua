local A,G=QIQ,QIQ.Guide
local T=A.T
G.crafts=QIQ_CRAFT_DATA or {}
local itemRequests={}
function G:CraftItemName(id)
 local name
 if C_Item and C_Item.GetItemNameByID then name=C_Item.GetItemNameByID(id) end
 if not name and GetItemInfo then name=GetItemInfo(id) end
 if name then return name end
 if C_Item and C_Item.RequestLoadItemDataByID and not itemRequests[id] then
  itemRequests[id]=true; C_Item.RequestLoadItemDataByID(id)
 end
 return self:EntityName("item",id)
end
function G:CraftTitle(key)
 local r=self.crafts[key]; return r and (r.n[A.locale] or r.n.enUS) or T("craftSelect")
end
function G:CraftQuery(text,itemID)
 local words={}; for w in A.Normalize(text or ""):gmatch("%S+") do words[#words+1]=w end
 if not self.craftIndex then
  self.craftIndex={}; self.craftIDs={}
  for key,r in pairs(self.crafts) do
   self.craftIDs[#self.craftIDs+1]=key
   for _,v in ipairs(r.r) do
    self.craftIndex[v[1]]=self.craftIndex[v[1]] or {}; table.insert(self.craftIndex[v[1]],key)
   end
  end
 end
 local result={}
 local materialNames={}
 for _,key in ipairs(itemID and (self.craftIndex[itemID] or {}) or self.craftIDs) do
  local r=self.crafts[key]; local keep=true
  if #words>0 then
   local parts={r.n.enUS,r.n.ruRU,A.ProfessionName(r.p),tostring(r.id)}
   for _,v in ipairs(r.r) do
    -- Search must not request hundreds of uncached items from the server.
    materialNames[v[1]]=materialNames[v[1]] or self:EntityName("item",v[1])
    parts[#parts+1]=materialNames[v[1]]; parts[#parts+1]=tostring(v[1])
   end
   local hay=A.Normalize(table.concat(parts," "))
   for _,w in ipairs(words) do if not hay:find(w,1,true) then keep=false; break end end
  end
  if keep then result[#result+1]=key end
 end
 table.sort(result,function(a,b)
  local ap,bp=A.ProfessionName(self.crafts[a].p),A.ProfessionName(self.crafts[b].p)
  if ap~=bp then return ap<bp end
  local an,bn=self:CraftTitle(a),self:CraftTitle(b)
  return an==bn and a<b or an<bn
 end)
 return result
end
function G:CraftRows(key)
 local r=self.crafts[key]; if not r then return {} end
 local rows={}
 if self.itemID then
  for _,v in ipairs(r.r) do if v[1]==self.itemID then
   rows[#rows+1]={text=T("craftAmount",self:CraftItemName(v[1]),v[2]),heading=true}
  end end
 end
 rows[#rows+1]={text=r.rank>0 and T("craftRank",r.rank,r.borrowed and T("craftBorrowed") or "") or T("craftUnknownRank")}
 if r.item>0 then rows[#rows+1]={text=T("craftResult",self:CraftItemName(r.item)),itemID=r.item,action={kind="item",id=r.item}} end
 rows[#rows+1]={text=T("craftReagents"),heading=true}
 for _,v in ipairs(r.r) do
  rows[#rows+1]={text=self:CraftItemName(v[1]).." × "..v[2],itemID=v[1],action={kind="item",id=v[1]}}
 end
 rows[#rows+1]={text=T("craftFootnote"),muted=true}
 return rows
end
