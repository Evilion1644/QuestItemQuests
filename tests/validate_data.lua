local path = (arg and arg[1]) or "QLens/QuestItemQuestsData.lua"
dofile(path)
assert(type(QIQ_ITEM_QUESTS)=="table" and type(QIQ_QUEST_TITLES)=="table" and type(QIQ_QUEST_CLASS_IDS)=="table")
local allowed, itemCount, relationCount, masks = 127, 0, 0, {}
for itemID, rows in pairs(QIQ_ITEM_QUESTS) do
    assert(type(itemID)=="number" and itemID>0 and itemID%1==0, "invalid itemID")
    assert(type(rows)=="table", "invalid rows for "..itemID)
    itemCount=itemCount+1
    local seen={}
    for _,row in ipairs(rows) do
        local questID,mask=row[1],row[2]
        assert(type(questID)=="number" and questID>0 and questID%1==0, "invalid questID")
        assert(type(mask)=="number" and mask>0 and mask<=allowed and mask%1==0, "invalid mask")
        assert(not seen[questID], "duplicate questID "..questID.." for item "..itemID)
        assert(type(QIQ_QUEST_TITLES[questID])=="string" and QIQ_QUEST_TITLES[questID]~="", "missing title "..questID)
        seen[questID]=true; relationCount=relationCount+1; masks[mask]=(masks[mask] or 0)+1
    end
end
local classCount=0
for itemID,value in pairs(QIQ_QUEST_CLASS_IDS) do assert(type(itemID)=="number" and itemID>0 and value==true); classCount=classCount+1 end
assert(itemCount==5887, "unexpected item count "..itemCount)
assert(relationCount==8791, "unexpected relation count "..relationCount)
assert(classCount==3331, "unexpected class count "..classCount)
local expectedMasks={[1]=3488,[2]=868,[3]=1,[4]=184,[24]=36,[33]=344,[26]=171,[18]=1,[66]=2,[56]=2,[58]=18,[25]=4,[32]=12,[34]=120,[36]=24,[35]=2,[10]=1,[57]=157,[64]=3347,[96]=9}
for mask,count in pairs(expectedMasks) do assert(masks[mask]==count,"mask distribution changed: "..mask) end
for mask in pairs(masks) do assert(expectedMasks[mask],"unexpected relation mask") end
print("data validation: OK (items="..itemCount..", relations="..relationCount..", quest-class="..classCount..")")
