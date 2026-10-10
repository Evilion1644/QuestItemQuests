-- Generates QuestItemQuestsData.lua from QuestieDB Forever.
-- Usage: lua tools/generate_qiq_index.lua <QuestieDB root> [output file]
local questieRoot = (arg and arg[1]) or "../QuestieDB"
local outputPath = (arg and arg[2]) or "QLens/QuestItemQuestsData.lua"
questieRoot = questieRoot:gsub("\\", "/"):gsub("/$", "")
local QuestieDB = {}
local l10n = { questLookup = {} }
QuestieLoader = { ImportModule = function(_, name)
    if name == "l10n" then return l10n end
    return QuestieDB
end }
GetLocale = function() return "ruRU" end

dofile(questieRoot .. "/data/Forever/foreverQuestDB.lua")
dofile(questieRoot .. "/data/Forever/foreverItemDB.lua")
local quests = assert(loadstring(QuestieDB.questData))()
local items = assert(loadstring(QuestieDB.itemData))()
dofile(questieRoot .. "/l10n/Forever/lookupQuests/ruRU.lua")
local ruLookup = l10n.questLookup.ruRU
local ruTitles = type(ruLookup) == "function" and ruLookup() or (ruLookup or {})

local qk, ik = assert(QuestieDB.questKeys), assert(QuestieDB.itemKeys)
local STARTED_BY_ITEM, OBJECTIVE_ITEM = 3, 3
local RELATION = { objective=1, source=2, required=4, startedBy=8, startQuest=16, related=32, reward=64 }
local map = {}
local function add(itemID, questID, kind)
    itemID, questID = tonumber(itemID), tonumber(questID)
    if not itemID or not questID or itemID <= 0 or questID <= 0 then return end
    map[itemID] = map[itemID] or {}
    map[itemID][questID] = map[itemID][questID] or {}
    map[itemID][questID][kind] = true
end
local function addList(list, questID, kind)
    if type(list) ~= "table" then return end
    for _, itemID in ipairs(list) do add(itemID, questID, kind) end
end
local function addObjectiveItems(group, questID)
    if type(group) ~= "table" then return end
    for _, entry in ipairs(group) do
        if type(entry) == "table" then add(entry[1], questID, "objective") else add(entry, questID, "objective") end
    end
end

for questID, q in pairs(quests) do
    local startedBy = q[qk.startedBy]
    if type(startedBy) == "table" then addList(startedBy[STARTED_BY_ITEM], questID, "startedBy") end
    local objectives = q[qk.objectives]
    if type(objectives) == "table" then
        addObjectiveItems(objectives[OBJECTIVE_ITEM], questID)
    end
    add(q[qk.sourceItemId], questID, "source")
    addList(q[qk.requiredSourceItems], questID, "required")
end
for itemID, item in pairs(items) do
    add(itemID, item[ik.startQuest], "startQuest")
    if type(item[ik.questRewards]) == "table" then
        for _, questID in ipairs(item[ik.questRewards]) do add(itemID, questID, "reward") end
    end
    if type(item[ik.relatedQuests]) == "table" then
        for _, questID in ipairs(item[ik.relatedQuests]) do add(itemID, questID, "related") end
    end
end

local kinds = {"objective", "source", "required", "startedBy", "startQuest", "related", "reward"}
local bit = RELATION
local itemIDs = {}
for itemID, relations in pairs(map) do
    assert(items[itemID], "relation references unknown itemID " .. itemID)
    for questID in pairs(relations) do assert(quests[questID], "relation references unknown questID " .. questID) end
    itemIDs[#itemIDs + 1] = itemID
end
table.sort(itemIDs)
local out = assert(io.open(outputPath, "w"))
out:write("-- AUTO GENERATED from work/QuestieDB/data/Forever; do not edit.\n")
out:write("QIQ_ITEM_QUESTS = {\n")
for _, itemID in ipairs(itemIDs) do
    local questIDs = {}
    for questID, kindsForQuest in pairs(map[itemID]) do
        local mask = 0
        for _, kind in ipairs(kinds) do if kindsForQuest[kind] then mask = mask + bit[kind] end end
        questIDs[#questIDs + 1] = {id=questID, mask=mask}
    end
    table.sort(questIDs, function(a,b) return a.id < b.id end)
    out:write("[", itemID, "]={")
    for i, row in ipairs(questIDs) do
        if i > 1 then out:write(",") end
        out:write("{", row.id, ",", row.mask, "}")
    end
    out:write("},\n")
end
out:write("}\n")
local function luaString(value)
    value = tostring(value or "")
    value = value:gsub("\\", "\\\\"):gsub("\"", "\\\""):gsub("\r", "\\r"):gsub("\n", "\\n")
    return '"' .. value .. '"'
end
local titleIDs = {}
for _, rows in pairs(map) do
    for questID in pairs(rows) do titleIDs[questID] = true end
end
local titleList = {}
for questID in pairs(titleIDs) do titleList[#titleList + 1] = questID end
table.sort(titleList)
out:write("QIQ_QUEST_TITLES = {\n")
for _, questID in ipairs(titleList) do
    local localized = ruTitles[questID]
    local title = type(localized) == "table" and localized[1] or nil
    if type(title) ~= "string" or title == "" then
        local q = quests[questID]
        title = type(q) == "table" and q[qk.name] or nil
    end
    if type(title) == "string" and title ~= "" then
        out:write("[", questID, "]=", luaString(title), ",\n")
    else
        out:write("[", questID, "]=nil,\n")
    end
end
out:write("}\n")
out:write("QIQ_QUEST_CLASS_IDS = {\n")
local classIDs = {}
for itemID, item in pairs(items) do if item[ik.class] == 12 then classIDs[#classIDs + 1] = itemID end end
table.sort(classIDs)
for _, itemID in ipairs(classIDs) do
    out:write("[", itemID, "]=true,\n")
end
out:write("}\n")
out:close()
print("items", #itemIDs)
local relations = 0
for _, rows in pairs(map) do
    for _ in pairs(rows) do relations = relations + 1 end
end
print("relations", relations)
print("output", outputPath)
