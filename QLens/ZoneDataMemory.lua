-- Share identical immutable zone sets; do not retain a second index at runtime.
local sets = {}
local function share(value)
    if type(value) ~= 'table' then return value end
    local keys = {}
    for id, present in pairs(value) do
        if type(id) ~= 'number' or present ~= true then return value end
        keys[#keys+1] = id
    end
    table.sort(keys)
    local key = table.concat(keys, ',')
    local existing = sets[key]
    if existing then return existing end
    sets[key] = value
    return value
end
for _, quest in pairs(QIQ_ZONE_QUESTS or {}) do
    quest.finish = share(quest.finish)
    quest.finishAreas = share(quest.finishAreas)
    for _, objective in ipairs(quest.objectives or {}) do
        objective.maps = share(objective.maps)
        objective.areas = share(objective.areas)
    end
end
