-- Add party quest ownership to existing world-map tooltips only.
local ru = GetLocale and GetLocale() == "ruRU"
local labels = ru and {
    title = "Задание у сопартийцев", yes = "Есть задание", no = "Нет задания",
    unknown = "Нет данных", offline = "Не в сети",
} or {
    title = "Party members on this quest", yes = "On quest", no = "Not on quest",
    unknown = "Unknown", offline = "Offline",
}
local hooked = setmetatable({}, { __mode = "k" })

local function mapQuest(tooltip)
    local owner = tooltip:GetOwner()
    local questID, onMap
    -- POI buttons can be children of a map pin; walk to the actual map.
    for _ = 1, 20 do
        if not owner then break end
        questID = questID or tonumber(owner.questID)
        if owner == WorldMapFrame then onMap = true; break end
        owner = owner.GetParent and owner:GetParent()
    end
    if onMap and questID and questID > 0 then return questID end
end

local function onQuest(unit, questID)
    if C_QuestLog and type(C_QuestLog.IsUnitOnQuest) == "function" then
        local ok, value = pcall(C_QuestLog.IsUnitOnQuest, unit, questID)
        if ok and type(value) == "boolean" then return value end
    end
    -- Older clients take a local quest-log index, NOT a quest ID.
    if type(IsUnitOnQuest) == "function" and type(GetQuestLogIndexByID) == "function" then
        local index = GetQuestLogIndexByID(questID)
        if index and index > 0 then
            local ok, value = pcall(IsUnitOnQuest, index, unit)
            if ok and (type(value) == "boolean" or value == 0 or value == 1) then
                return value == true or value == 1
            end
        end
    end
end

local function append(tooltip)
    if tooltip.qlensPartyAdded or not WorldMapFrame or not WorldMapFrame:IsShown() then return end
    if not IsInGroup or not IsInGroup() then return end
    local questID = mapQuest(tooltip)
    if not questID then return end
    local raid = IsInRaid and IsInRaid()
    local count = raid and GetNumGroupMembers() or (GetNumSubgroupMembers and GetNumSubgroupMembers() or 4)
    local rows = {}
    for i = 1, count do
        local unit = (raid and "raid" or "party") .. i
        if UnitExists(unit) and not UnitIsUnit(unit, "player") then
            local name, realm = UnitName(unit)
            if name then
                if realm and realm ~= "" then name = name .. "-" .. realm end
                local status, r, g, b = labels.unknown, .65, .65, .65
                if UnitIsConnected and not UnitIsConnected(unit) then
                    status = labels.offline
                else
                    local value = onQuest(unit, questID)
                    if value == true then status, r, g, b = labels.yes, .25, 1, .25
                    elseif value == false then status, r, g, b = labels.no, 1, .35, .35 end
                end
                rows[#rows + 1] = { name, status, r, g, b }
            end
        end
    end
    if #rows == 0 then return end
    tooltip.qlensPartyAdded = true
    tooltip:AddLine(" ")
    tooltip:AddLine("QLens: " .. labels.title, 1, .82, 0)
    for _, row in ipairs(rows) do
        tooltip:AddDoubleLine(row[1], row[2], 1, 1, 1, row[3], row[4], row[5])
    end
    tooltip:Show() -- recalculate dimensions; guarded against recursion above
end

local function install()
    for _, name in ipairs({ "WorldMapTooltip", "GameTooltip" }) do
        local tooltip = _G[name]
        if tooltip and not hooked[tooltip] then
            hooked[tooltip] = true
            tooltip:HookScript("OnTooltipCleared", function(self) self.qlensPartyAdded = nil end)
            tooltip:HookScript("OnHide", function(self) self.qlensPartyAdded = nil end)
            hooksecurefunc(tooltip, "Show", append)
        end
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", install)
install()
