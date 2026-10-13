local A = assert(QIQ, "Locale.lua must load first")
local priorityQuestIDs = {}
local wrappedTracker
local originalHeaderColors = {}

local function creatureID(guid)
    if type(guid) ~= "string" or not guid:find("^Creature%-") then return nil end
    local n = 0
    for part in guid:gmatch("[^%-]+") do
        n = n + 1
        if n == 6 then return tonumber(part) end
    end
end

local function markDirty()
    local tracker = _G.QuestObjectiveTracker
    if tracker and type(tracker.MarkDirty) == "function" then
        tracker:MarkDirty()
    elseif _G.ObjectiveTrackerFrame and type(ObjectiveTrackerFrame.Update) == "function" then
        ObjectiveTrackerFrame:Update()
    end
end

local function highlightBlocks(tracker)
    if type(tracker.EnumerateActiveBlocks) ~= "function" then return end
    tracker:EnumerateActiveBlocks(function(block)
        local header = block and block.HeaderText
        if not header then return end
        if block.id == priorityQuestIDs[1] then
            if not originalHeaderColors[header] then
                originalHeaderColors[header] = { header:GetTextColor() }
            end
            header:SetTextColor(1, .82, .25)
        elseif originalHeaderColors[header] then
            header:SetTextColor(unpack(originalHeaderColors[header]))
            originalHeaderColors[header] = nil
        end
    end)
end

local function putPrioritiesFirst(entries, questIDOf)
    if #priorityQuestIDs == 0 then return entries end
    local byID, moved, result = {}, {}, {}
    for _, entry in ipairs(entries) do
        local questID = questIDOf(entry)
        if questID then byID[questID] = entry end
    end
    for _, questID in ipairs(priorityQuestIDs) do
        local entry = byID[questID]
        if entry and not moved[entry] then
            result[#result + 1] = entry
            moved[entry] = true
        end
    end
    for _, entry in ipairs(entries) do
        if not moved[entry] then result[#result + 1] = entry end
    end
    return result
end

local function installSortHook()
    local tracker = _G.QuestObjectiveTracker
    if not tracker or wrappedTracker == tracker then return end
    if type(tracker.BuildQuestWatchInfos) == "function" then
        local original = tracker.BuildQuestWatchInfos
        tracker.BuildQuestWatchInfos = function(self, ...)
            local infos = original(self, ...)
            if type(infos) ~= "table" then return infos end
            return putPrioritiesFirst(infos, function(info)
                local quest = info and info.quest
                return quest and type(quest.GetID) == "function" and quest:GetID()
            end)
        end
    elseif type(tracker.EnumQuestWatchData) == "function" then
        local original = tracker.EnumQuestWatchData
        tracker.EnumQuestWatchData = function(self, func)
            if #priorityQuestIDs == 0 then return original(self, func) end
            local quests = {}
            original(self, function(_, quest)
                quests[#quests + 1] = quest
                return true
            end)
            for _, quest in ipairs(putPrioritiesFirst(quests, function(entry)
                return entry and type(entry.GetID) == "function" and entry:GetID()
            end)) do
                if not func(self, quest) then return end
            end
        end
    else
        return
    end
    if hooksecurefunc and type(tracker.Update) == "function" then
        hooksecurefunc(tracker, "Update", highlightBlocks)
    end
    wrappedTracker = tracker
end

local function setPriority(questID)
    if A.FeatureEnabled and not A.FeatureEnabled("combatPriority") then return end
    if priorityQuestIDs[1] == questID then return end
    for i = #priorityQuestIDs, 1, -1 do
        if priorityQuestIDs[i] == questID then table.remove(priorityQuestIDs, i) end
    end
    table.insert(priorityQuestIDs, 1, questID)
    installSortHook()
    markDirty()
end

local function objectiveIncomplete(objective)
    if objective.finished then return false end
    local fulfilled = tonumber(objective.numFulfilled)
    local required = tonumber(objective.numRequired)
    if required and required > 0 and fulfilled and fulfilled >= required then return false end
    local current, total = tostring(objective.text or ""):match("(%d+)%s*/%s*(%d+)%s*$")
    if current and total and tonumber(current) >= tonumber(total) then return false end
    return true
end

local function isCreatureStillNeeded(creature, questID)
    if not (C_QuestLog and type(C_QuestLog.GetQuestObjectives) == "function") then return false end
    if type(C_QuestLog.IsComplete) == "function" then
        local ok, complete = pcall(C_QuestLog.IsComplete, questID)
        if ok and complete then return false end
    end
    local refs = QIQ_COMBAT_OBJECTIVE_DETAILS and QIQ_COMBAT_OBJECTIVE_DETAILS[creature]
    refs = refs and refs[questID]
    if not refs then return false end
    if type(refs) == "number" then refs = { refs } end
    local ok, objectives = pcall(C_QuestLog.GetQuestObjectives, questID)
    if not ok or type(objectives) ~= "table" then return false end
    local normalize = A.Normalize or string.lower
    for _, ref in ipairs(refs) do
        local names = ref > 0 and QIQ_COMBAT_NPC_NAMES and QIQ_COMBAT_NPC_NAMES[ref]
            or ref < 0 and QIQ_COMBAT_ITEM_NAMES and QIQ_COMBAT_ITEM_NAMES[-ref]
        if names then
            local en, ru = names[1], names[2]
            for _, objective in ipairs(objectives) do
                if objective and objective.text and objectiveIncomplete(objective) then
                    local text = normalize(objective.text)
                    if (en and en ~= "" and text:find(normalize(en), 1, true)) or
                       (ru and ru ~= "" and text:find(normalize(ru), 1, true)) then
                        return true
                    end
                end
            end
        end
    end
    return false
end

local function activeQuest(id)
    if C_QuestLog and type(C_QuestLog.IsOnQuest) == "function" then
        local ok, active = pcall(C_QuestLog.IsOnQuest, id)
        if ok and type(active) == "boolean" then return active end
    end
    return A.ActiveQuests and A.ActiveQuests[id]
end

local function activeIDs()
    local api = C_QuestLog or {}
    local ids, seen = {}, {}
    local function add(id)
        if id and id > 0 and not seen[id] then seen[id]=true; ids[#ids+1]=id end
    end
    -- Watch IDs work even when the journal category is collapsed.
    if api.GetNumQuestWatches and api.GetQuestIDForQuestWatchIndex then
        for i=1,api.GetNumQuestWatches() do add(api.GetQuestIDForQuestWatchIndex(i)) end
    end
    if api.GetNumQuestLogEntries and api.GetInfo then
        for i=1,api.GetNumQuestLogEntries() do
            local info=api.GetInfo(i)
            if info and not info.isHeader then add(info.questID) end
        end
    end
    for id in pairs(A.ActiveQuests or {}) do add(id) end
    return ids
end

local function promoteLiveTarget(name)
    if type(name) ~= "string" or name == "" then return false end
    local api = C_QuestLog
    if not api or type(api.GetQuestObjectives) ~= "function" then return false end
    local normalize = A.Normalize or string.lower
    name = normalize(name)
    for _, id in ipairs(activeIDs()) do
        local ok, objectives = pcall(api.GetQuestObjectives, id)
        if ok and type(objectives)=="table" then
            for _, objective in ipairs(objectives) do
                local kind = tostring(objective.type or ""):lower()
                if (kind == "monster" or kind == "kill") and objectiveIncomplete(objective) then
                    local text = normalize(objective.text or "")
                    local first, last = text:find(name, 1, true)
                    local before = first and (first == 1 or text:sub(first-1,first-1):match("[%s%p]"))
                    local after = last and (last == #text or text:sub(last+1,last+1):match("[%s%p]"))
                    if before and after then setPriority(id); return true end
                end
            end
        end
    end
    return false
end

local function tooltipText(text)
    text = tostring(text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    text = text:gsub("|T.-|t", ""):gsub("|A.-|a", "")
    return (A.Normalize or string.lower)(text)
end

local function promoteTooltip(guid)
    if not (C_TooltipInfo and type(C_TooltipInfo.GetUnit)=="function") then return false end
    local unit
    for _, token in ipairs({"target", "mouseover"}) do
        if UnitGUID(token)==guid then unit=token; break end
    end
    if not unit then return false end
    local ok, data=pcall(C_TooltipInfo.GetUnit,unit)
    if not ok or type(data)~="table" or type(data.lines)~="table" then return false end
    local api=C_QuestLog or {}
    if not api.GetQuestObjectives then return false end
    for _, id in ipairs(activeIDs()) do
        local title=api.GetTitleForQuestID and api.GetTitleForQuestID(id)
        title=title or (A.ActiveQuests and A.ActiveQuests[id])
        if type(title)=="string" then
            local objectives=api.GetQuestObjectives(id)
            local start
            for i,line in ipairs(data.lines) do
                if tooltipText(line.leftText)==tooltipText(title) then start=i; break end
            end
            if start then
                -- Require both our quest title and an unfinished objective.
                -- A title alone could belong to a party member's progress.
                for i=start+1,math.min(start+1+#(objectives or {}),#data.lines) do
                    local line=tooltipText(data.lines[i].leftText)
                    for _, objective in ipairs(objectives or {}) do
                        if objectiveIncomplete(objective) and line~="" and line==tooltipText(objective.text) then
                            setPriority(id); return true
                        end
                    end
                end
            end
        end
    end
    return false
end

local progress = {}
local function checkProgress(promote)
    if not (C_QuestLog and C_QuestLog.GetQuestObjectives) then return end
    local nextProgress = {}
    for _, id in ipairs(activeIDs()) do
        local ok, objectives = pcall(C_QuestLog.GetQuestObjectives,id)
        if ok and type(objectives)=="table" then
            local snapshot={}
            for i, objective in ipairs(objectives) do
                local text=tostring(objective.text or "")
                local fulfilled=tonumber(objective.numFulfilled) or tonumber(text:match("(%d+)%s*/%s*%d+%s*$"))
                local key=tostring(objective.type)..":"..text:gsub("%d+%s*/%s*%d+", "#/#")
                snapshot[i]={key=key, count=fulfilled, finished=objective.finished==true}
                local old=progress[id] and progress[id][i]
                if promote and old and old.key==key and
                   ((fulfilled and old.count and fulfilled>old.count) or (not old.finished and objective.finished==true)) then
                    setPriority(id)
                end
            end
            nextProgress[id]=snapshot
        else nextProgress[id]=progress[id] end -- transient API failure is not removal
    end
    progress=nextProgress
end

local function promoteTarget(guid, name)
    local creature = creatureID(guid)
    if not creature then return end
    if not name and UnitGUID and UnitName and UnitGUID("target") == guid then name=UnitName("target") end
    if promoteLiveTarget(name) then return end
    if promoteTooltip(guid) then return end
    local quests = creature and QIQ_COMBAT_OBJECTIVES and QIQ_COMBAT_OBJECTIVES[creature]
    if not quests then return end
    for _, questID in ipairs(quests) do
        if activeQuest(questID) and isCreatureStillNeeded(creature, questID) then
            setPriority(questID)
            return
        end
    end
end

local function isGroundStillNeeded(objectID, questID)
    if not (C_QuestLog and type(C_QuestLog.GetQuestObjectives) == "function") then return false end
    if type(C_QuestLog.IsComplete) == "function" then
        local ok, complete = pcall(C_QuestLog.IsComplete, questID)
        if ok and complete then return false end
    end
    local refs = QIQ_GROUND_OBJECTIVE_DETAILS and QIQ_GROUND_OBJECTIVE_DETAILS[objectID]
    refs = refs and refs[questID]
    if not refs then return false end
    if type(refs) == "number" then refs = { refs } end
    local ok, objectives = pcall(C_QuestLog.GetQuestObjectives, questID)
    if not ok or type(objectives) ~= "table" then return false end
    local normalize = A.Normalize or string.lower
    local objectNames = QIQ_GROUND_OBJECT_NAMES and QIQ_GROUND_OBJECT_NAMES[objectID]
    local labels = QIQ_GROUND_OBJECTIVE_LABELS and QIQ_GROUND_OBJECTIVE_LABELS[objectID]
    for _, ref in ipairs(refs) do
        local names = ref > 0 and objectNames or QIQ_COMBAT_ITEM_NAMES and QIQ_COMBAT_ITEM_NAMES[-ref]
        local label = ref > 0 and labels and labels[questID]
        for _, objective in ipairs(objectives) do
            if objective and objective.text then
                local text = normalize(objective.text)
                local matched = label and text:find(normalize(label), 1, true)
                if names then
                    for _, name in ipairs(names) do
                        if name ~= "" and text:find(normalize(name), 1, true) then matched = true end
                    end
                end
                if matched and objectiveIncomplete(objective) then return true end
            end
        end
    end
    -- Some localized object objectives describe the action, not the object's
    -- name (for example, "Gaea seed planted"). A single live row is exact.
    if #objectives == 1 then return objectiveIncomplete(objectives[1]) end
    local onlyObjectRow
    for _, objective in ipairs(objectives) do
        if objective and tostring(objective.type or ""):lower() == "object" then
            if onlyObjectRow then return false end
            onlyObjectRow = objective
        end
    end
    return onlyObjectRow and objectiveIncomplete(onlyObjectRow) or false
end

local groundObjectsByName, groundSourceItemsByName
local function groundNameIndexes()
    if groundObjectsByName then return end
    groundObjectsByName, groundSourceItemsByName = {}, {}
    local normalize = A.Normalize or string.lower
    local function add(index, name, id)
        if type(name) ~= "string" or name == "" then return end
        local key = normalize(name)
        index[key] = index[key] or {}
        index[key][#index[key] + 1] = id
    end
    for objectID, names in pairs(QIQ_GROUND_OBJECT_NAMES or {}) do
        for _, name in ipairs(names) do add(groundObjectsByName, name, objectID) end
    end
    for itemID in pairs(QIQ_GROUND_SOURCE_ITEMS or {}) do
        local names = QIQ_COMBAT_ITEM_NAMES and QIQ_COMBAT_ITEM_NAMES[itemID]
        if names then
            for _, name in ipairs(names) do add(groundSourceItemsByName, name, itemID) end
        end
    end
end

local function promoteGroundObject(objectID)
    local quests = QIQ_GROUND_OBJECTIVE_DETAILS and QIQ_GROUND_OBJECTIVE_DETAILS[objectID]
    if not quests or not A.ActiveQuests then return false end
    for questID in pairs(quests) do
        if activeQuest(questID) and isGroundStillNeeded(objectID, questID) then
            setPriority(questID)
            return true
        end
    end
    return false
end

local function promoteGroundSourceItem(itemID)
    for _, questID in ipairs(QIQ_GROUND_SOURCE_ITEMS[itemID] or {}) do
        if activeQuest(questID) then
            for _, objectID in ipairs(QIQ_GROUND_QUEST_OBJECTS[questID] or {}) do
                if isGroundStillNeeded(objectID, questID) then
                    setPriority(questID)
                    return true
                end
            end
        end
    end
    return false
end

local function promoteGroundName(name)
    if type(name) ~= "string" or name == "" then return end
    groundNameIndexes()
    local key = (A.Normalize or string.lower)(name)
    for _, objectID in ipairs(groundObjectsByName[key] or {}) do
        if promoteGroundObject(objectID) then return end
    end
    for _, itemID in ipairs(groundSourceItemsByName[key] or {}) do
        if promoteGroundSourceItem(itemID) then return end
    end
    -- Item-use casts can have a spell name different from the item name.
    for itemID, quests in pairs(QIQ_GROUND_SOURCE_ITEMS or {}) do
        local active = false
        for _, questID in ipairs(quests) do
            if activeQuest(questID) then active = true; break end
        end
        if active then
            local spellName
            if type(GetItemSpell) == "function" then
                local ok, value = pcall(GetItemSpell, itemID)
                if ok then spellName = value end
            elseif C_Item and type(C_Item.GetItemSpell) == "function" then
                local ok, value = pcall(C_Item.GetItemSpell, itemID)
                if ok then spellName = value end
            end
            if spellName and (A.Normalize or string.lower)(spellName) == key then
                if promoteGroundSourceItem(itemID) then return end
            end
        end
    end
end

local function gameObjectID(guid)
    if type(guid) ~= "string" or not guid:find("^GameObject%-") then return nil end
    local n = 0
    for part in guid:gmatch("[^%-]+") do
        n = n + 1
        if n == 6 then return tonumber(part) end
    end
end

local function promoteLootSource()
    if type(GetNumLootItems) ~= "function" or type(GetLootSourceInfo) ~= "function" then return end
    for slot = 1, GetNumLootItems() do
        local ok, guid = pcall(GetLootSourceInfo, slot)
        local objectID = ok and gameObjectID(guid)
        if objectID then promoteGroundObject(objectID) end
    end
end

local function prunePriorities()
    if not A.ActiveQuests then return end
    local changed = false
    for i = #priorityQuestIDs, 1, -1 do
        if not activeQuest(priorityQuestIDs[i]) then
            table.remove(priorityQuestIDs, i)
            changed = true
        end
    end
    if changed then markDirty() end
end

local frame = CreateFrame("Frame")
for _, event in ipairs({
    "ADDON_LOADED", "PLAYER_LOGIN", "COMBAT_LOG_EVENT_UNFILTERED",
    "PLAYER_REGEN_DISABLED", "PLAYER_TARGET_CHANGED",
    "QUEST_LOG_UPDATE", "UNIT_SPELLCAST_SENT", "UNIT_SPELLCAST_START",
    "LOOT_READY", "LOOT_OPENED", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED",
}) do frame:RegisterEvent(event) end

frame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" or event == "PLAYER_LOGIN" then
        installSortHook()
        if event == "PLAYER_LOGIN" then checkProgress(false) end
        return
    end
    if event == "PLAYER_ENTERING_WORLD" then checkProgress(false); installSortHook(); return end
    if event == "PLAYER_REGEN_ENABLED" then installSortHook(); markDirty(); return end
    if event == "QUEST_LOG_UPDATE" then
        local function refresh()
            checkProgress(not A.FeatureEnabled or A.FeatureEnabled("combatPriority"))
            prunePriorities()
        end
        if C_Timer and C_Timer.After then C_Timer.After(0,refresh) else refresh() end
        return
    end
    if A.FeatureEnabled and not A.FeatureEnabled("combatPriority") then return end
    if event == "PLAYER_REGEN_DISABLED" then promoteTarget(UnitGUID("target")); return end
    if event == "PLAYER_TARGET_CHANGED" then
        if UnitAffectingCombat("player") then promoteTarget(UnitGUID("target")) end
        return
    end
    if event == "UNIT_SPELLCAST_SENT" then
        local unit, target = ...
        if unit == "player" then promoteGroundName(target) end
        return
    end
    if event == "UNIT_SPELLCAST_START" then
        local unit = ...
        if unit == "player" and type(UnitCastingInfo) == "function" then
            promoteGroundName(UnitCastingInfo("player"))
        end
        return
    end
    if event == "LOOT_READY" or event == "LOOT_OPENED" then
        promoteLootSource()
        return
    end
    local _, subevent, _, sourceGUID, _, _, _, destGUID, destName = CombatLogGetCurrentEventInfo()
    if sourceGUID ~= UnitGUID("player") and sourceGUID ~= UnitGUID("pet") then return end
    if subevent == "SWING_DAMAGE" or subevent == "RANGE_DAMAGE" or
       subevent == "SPELL_DAMAGE" or subevent == "SPELL_PERIODIC_DAMAGE" or
       subevent == "DAMAGE_SHIELD" then
        promoteTarget(destGUID, destName)
    end
end)

A.CombatPriority = { promoteTarget = promoteTarget, promoteGroundName = promoteGroundName,
    promoteGroundObject = promoteGroundObject, creatureID = creatureID }

function A.CombatPriority.Reset()
    if not A.FeatureEnabled("combatPriority") then priorityQuestIDs = {}; markDirty() end
end
