local A = QIQ
local Z = {}
A.ZoneTracking = Z
local lastMap, overrides, applying, pending = nil, {}, false, false
local function call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if ok then return value end
end
local function unfinished(o)
    return not o.finished and not (o.numRequired and o.numRequired > 0 and o.numFulfilled and o.numFulfilled >= o.numRequired)
end
local function contains(maps, map, areas)
    local zoneAreas = QIQ_ZONE_MAP_AREAS and QIQ_ZONE_MAP_AREAS[map]
    if areas and next(areas) and zoneAreas then
        for id in pairs(areas) do if zoneAreas[id] then return true end end
        return false
    end
    if areas and next(areas) and not zoneAreas then
        -- Instances may have no supported UI map; use localized area names.
        local zone = call(GetRealZoneText)
        if zone and zone ~= "" then
            local known = false
            for id in pairs(areas) do
                local name = call(C_Map and C_Map.GetAreaInfo, id)
                if name then known = true; if name == zone then return true end end
            end
            if known then return false end
        end
    end
    if type(maps) ~= "table" or not next(maps) then return nil end
    return maps[map] == true
end
-- nil means insufficient evidence: preserve the player's existing choice.
-- Same destination query used by QuestMapFrame_ShowQuestDetails.
-- true means ignore intermediate route waypoints; do not change map/selection.
local function zoneMap(map)
    if type(map) ~= "number" or map <= 0 then return nil end
    for _ = 1, 8 do
        local info = call(C_Map and C_Map.GetMapInfo, map)
        if not info then return map end
        if info.mapType and info.mapType <= 2 then return nil end -- world/continent
        if info.mapType ~= 5 then return map end -- keep dungeons separate
        if not info.parentMapID or info.parentMapID <= 0 or info.parentMapID == map then return map end
        map = info.parentMapID
    end
end
local function destination(id)
    return zoneMap(call(GetQuestUiMapID, id, true))
end
Z.Destination = destination
function Z.Relevant(id, map, pois)
    local api = C_QuestLog or {}
    local live = call(api.GetQuestObjectives, id)
    local data = QIQ_ZONE_QUESTS and QIQ_ZONE_QUESTS[id]
    local ready = call(api.ReadyForTurnIn or api.IsComplete or IsQuestComplete, id)
    local targetMap = destination(id)
    local currentMap = zoneMap(map)
    local native
    if targetMap and currentMap then native = targetMap == currentMap end
    if native == true then return true end
    local unfinishedCount = 0
    for _, objective in ipairs(live or {}) do
        if unfinished(objective) then unfinishedCount = unfinishedCount + 1 end
    end
    -- The live destination wins over an outdated database, including turn-ins.
    -- With several outstanding objectives, the reference may add other zones.
    if native ~= nil and (ready or unfinishedCount <= 1 or not data) then return native end
    if ready then
        local here = data and contains(data.finish, map, data.finishAreas)
        if here ~= nil then return here end
        return nil
    end
    if data and #data.objectives == 0 then
        return contains(data.finish, map, data.finishAreas) -- delivery/talk quests
    end
    if data and type(live) == "table" and #live > 0 then
        local known, uncertain = false, false
        local normalize = A.Normalize or string.lower
        for _, objective in ipairs(live) do
            if unfinished(objective) then
                local matched = false
                local text = normalize(objective.text or "")
                for _, ref in ipairs(data.objectives) do
                    -- A single live objective and single reference are unambiguous
                    -- even when Forever changes its localized wording.
                    local match = #live == 1 and #data.objectives == 1
                    for _, name in ipairs(ref.names) do
                        if name ~= "" and text:find(normalize(name), 1, true) then match = true end
                    end
                    if match then
                        matched = true
                        local here = contains(ref.maps, map, ref.areas)
                        if here then return true end
                        if here == nil then uncertain = true else known = true end
                    end
                end
                if not matched then uncertain = true end
            end
        end
        if known and not uncertain then return false end
    end
    -- Map POIs and GetNextWaypoint can point at an exit toward another zone.
    -- They are navigation hints, not proof that an objective is in this zone.
    return native
end

local function entries(saved)
    local api = C_QuestLog or {}
    local rows, seen = {}, {}
    local function add(id, index)
        if not id or id <= 0 or seen[id] then return end
        local watched
        if api.GetQuestWatchType then watched = call(api.GetQuestWatchType, id) ~= nil
        elseif index and index > 0 and IsQuestWatched then watched = not not IsQuestWatched(index) end
        if watched ~= nil then
            seen[id] = true
            rows[#rows+1] = {id=id, index=index, watched=watched}
        end
    end
    local count = call(api.GetNumQuestLogEntries or GetNumQuestLogEntries)
    if not count then return nil end
    for i = 1, count do
        local info = call(api.GetInfo, i)
        if not info and GetQuestLogTitle then
            local _, _, _, header, _, _, _, id = GetQuestLogTitle(i)
            info = {isHeader=header, questID=id}
        end
        if info and not info.isHeader and info.questID and info.questID > 0 then
            add(info.questID, i)
        end
    end
    -- Watch IDs are independent of which journal categories are expanded.
    for i = 1, call(api.GetNumQuestWatches or GetNumQuestWatches) or 0 do
        local id = call(api.GetQuestIDForQuestWatchIndex, i)
        if id then add(id, call(api.GetLogIndexForQuestID or GetQuestLogIndexByID, id)) end
    end
    -- Revisit hidden quests we removed ourselves when the player changes zone.
    for id in pairs(saved and saved.original or {}) do
        if call(api.IsOnQuest, id) then
            add(id, call(api.GetLogIndexForQuestID or GetQuestLogIndexByID, id))
        end
    end
    return rows
end
local function change(row, value)
    local api = C_QuestLog or {}
    local fn = value and api.AddQuestWatch or (not value and api.RemoveQuestWatch)
    if fn then call(fn, row.id)
    elseif row.index and row.index > 0 then call(value and AddQuestWatch or RemoveQuestWatch, row.index) end
end
local function state()
    local guid = call(UnitGUID, "player")
    if not guid then return nil end
    local db = A.Settings()
    db.zoneWatchStates = db.zoneWatchStates or {}
    db.zoneWatchStates[guid] = db.zoneWatchStates[guid] or {original={}}
    return db.zoneWatchStates[guid]
end
function Z.Update()
    if InCombatLockdown and InCombatLockdown() then return end
    local saved = state()
    local rows = entries(saved)
    if not rows or not saved then return end
    local enabled = A.FeatureEnabled("zoneTracking")
    local map = call(C_Map and C_Map.GetBestMapForUnit, "player")
    if enabled and not map then return end
    if map ~= lastMap then lastMap, overrides = map, {} end
    local changes = {}
    for _, row in ipairs(rows) do
        local target
        if enabled then
            if saved.original[row.id] == nil then saved.original[row.id] = row.watched end
            if overrides[row.id] == nil then target = Z.Relevant(row.id, map) end
        else target = saved.original[row.id] end
        if target ~= nil and target ~= row.watched then changes[#changes+1] = {row=row, value=target} end
    end
    applying = true
    -- Free watch slots before adding relevant quests.
    for _, c in ipairs(changes) do if not c.value then change(c.row, false) end end
    for _, c in ipairs(changes) do if c.value then change(c.row, true) end end
    applying = false
    if not enabled then
        -- Keep a failed restore pending, e.g. if the client's watch limit was reached.
        for _, row in ipairs(entries(saved) or {}) do
            if saved.original[row.id] == row.watched then saved.original[row.id] = nil end
        end
        overrides = {}
    end
    -- Do not discard unseen entries: a legacy client may have collapsed headers.
end
function Z.Schedule()
    if pending then return end
    pending = true
    local function run() pending = false; Z.Update() end
    if C_Timer and C_Timer.After then C_Timer.After(.3, run) else run() end
end
local frame = CreateFrame("Frame")
for _, event in ipairs({"PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED",
    "QUEST_LOG_UPDATE", "QUEST_POI_UPDATE", "QUEST_REMOVED", "QUEST_WATCH_LIST_CHANGED", "PLAYER_REGEN_ENABLED"}) do frame:RegisterEvent(event) end
frame:SetScript("OnEvent", function(_, event, id, added)
    if applying then return end
    if event == "QUEST_REMOVED" and id then
        local saved = state()
        if saved then saved.original[id] = nil end
        overrides[id] = nil
    end
    if event == "QUEST_WATCH_LIST_CHANGED" and id and A.FeatureEnabled("zoneTracking") then
        overrides[id] = added == true
    end
    Z.Schedule()
end)

-- Read-only diagnostics for differences in Forever's live APIs/data.
SLASH_QLENSZONE1 = "/qlenszone"
SlashCmdList = SlashCmdList or {}
SlashCmdList.QLENSZONE = function()
    local map = call(C_Map and C_Map.GetBestMapForUnit, "player")
    local rows = entries(state()) or {}
    print("QLens zone: map=" .. tostring(map) .. ", quests=" .. #rows .. ", enabled=" .. tostring(A.FeatureEnabled("zoneTracking")))
    for _, row in ipairs(rows) do
        print(row.id .. " watched=" .. tostring(row.watched) .. " destination=" .. tostring(destination(row.id)) .. " relevant=" .. tostring(map and Z.Relevant(row.id,map)) .. " manual=" .. tostring(overrides[row.id]))
    end
end
