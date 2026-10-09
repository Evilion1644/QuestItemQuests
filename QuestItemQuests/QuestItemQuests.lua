local ADDON = ...
local QIQ = CreateFrame("Frame")
local staticIndex = QIQ_ITEM_QUESTS or {}
local index = {}
local objectives = {}
local activeQuests = {}
local activeQuestRows = {}
local lastResolveReason = "нет совпадения"
local menuFrame
local menuPanel
local menuButtons = {}
local ITEM_CLASS_QUEST = 12
local ACTIVE_QUEST_TITLE_COLOR = "|cff00ff80"
local INACTIVE_QUEST_TITLE_COLOR = "|cffff7070"

local function trim(s)
    s = tostring(s or "")
    s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    s = s:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    -- Item objectives are displayed as "Item name: n/m" in the quest log.
    s = s:gsub("%s*:%s*%d+%s*/%s*%d+%s*$", "")
    return s:gsub("^%s+", ""):gsub("%s+$", "")
end

-- Lua 5.1 string.lower() is ASCII-only on the Forever client. Keep the
-- comparison localised so Russian item/objective names can be matched.
local RU_CASE = {
    {"А", "а"}, {"Б", "б"}, {"В", "в"}, {"Г", "г"}, {"Д", "д"}, {"Е", "е"}, {"Ё", "ё"},
    {"Ж", "ж"}, {"З", "з"}, {"И", "и"}, {"Й", "й"}, {"К", "к"}, {"Л", "л"}, {"М", "м"},
    {"Н", "н"}, {"О", "о"}, {"П", "п"}, {"Р", "р"}, {"С", "с"}, {"Т", "т"}, {"У", "у"},
    {"Ф", "ф"}, {"Х", "х"}, {"Ц", "ц"}, {"Ч", "ч"}, {"Ш", "ш"}, {"Щ", "щ"}, {"Ъ", "ъ"},
    {"Ы", "ы"}, {"Ь", "ь"}, {"Э", "э"}, {"Ю", "ю"}, {"Я", "я"},
}
local function ruLower(s)
    s = tostring(s or "")
    for _, pair in ipairs(RU_CASE) do
        s = s:gsub(pair[1], pair[2])
    end
    return string.lower(s)
end

local deliveryWords = {
    ["отнеси"] = true, ["отнесите"] = true, ["отнес"] = true,
    ["принеси"] = true, ["принесите"] = true, ["принес"] = true,
    ["доставь"] = true, ["доставьте"] = true, ["доставил"] = true,
    ["передай"] = true, ["передайте"] = true, ["передал"] = true,
    ["отдай"] = true, ["отдайте"] = true, ["отдал"] = true,
}

-- Some Forever quest objectives do not expose an item name/link at tooltip time.
-- Keep the known relation by item ID, then verify it against the active log.
local knownItemQuests = {
    [5827] = { id = 1106, title = "Мартек Изгой" },
}

local function itemIDFromLink(link)
    return link and tonumber(tostring(link):match("item:(%d+)"))
end

local function firstTwoWords(s)
    local a, b = ruLower(trim(s)):match("^(%S+)%s+(%S+)")
    if a and b then return a .. " " .. b end
end

local function isDeliveryObjective(text, itemName)
    local objectiveText = ruLower(trim(text))
    local itemPrefix = firstTwoWords(itemName)
    local start = itemPrefix and objectiveText:find(itemPrefix, 1, true)
    if not start then return false end
    local before = start > 1 and objectiveText:sub(start - 1, start - 1) or " "
    local after = objectiveText:sub(start + #itemPrefix, start + #itemPrefix)
    if not before:match("%s") or (after ~= "" and not after:match("[%s%p]")) then return false end
    for word in objectiveText:gmatch("%S+") do
        word = word:gsub("^%p+", ""):gsub("%p+$", "")
        if deliveryWords[word] then return true end
    end
    return false
end

local function addQuest(qid, title)
    if not (C_QuestLog and C_QuestLog.GetQuestObjectives) then return end
    local ok, questObjectives = pcall(C_QuestLog.GetQuestObjectives, qid)
    if not ok or type(questObjectives) ~= "table" then return end
    for _, obj in ipairs(questObjectives) do
        if type(obj) == "table" then
            local text = trim(obj.text)
            if text ~= "" then
                local record = { id = qid, title = title or ("Квест " .. qid), text = text, type = tostring(obj.type or "") }
                objectives[#objectives + 1] = record
                if ruLower(record.type) == "item" then
                    index[text] = index[text] or {}
                    local seen = false
                    for _, q in ipairs(index[text]) do
                        if q.id == qid then seen = true break end
                    end
                    if not seen then index[text][#index[text] + 1] = record end
                end
            end
        end
    end
end

local function rebuild()
    wipe(index)
    wipe(objectives)
    wipe(activeQuests)
    wipe(activeQuestRows)
    if not (C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo) then return end
    local count = C_QuestLog.GetNumQuestLogEntries()
    for i = 1, count do
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHeader and info.questID and info.questID > 0 then
            activeQuests[info.questID] = info.title or ("Квест " .. info.questID)
            activeQuestRows[#activeQuestRows + 1] = { index = i, id = info.questID, title = info.title or ("Квест " .. info.questID) }
            addQuest(info.questID, info.title)
        end
    end
end

local function resolveKnownActive(itemID, diagnostics)
    local known = itemID and knownItemQuests[itemID]
    if not known then return end
    if activeQuests[known.id] then
        diagnostics[#diagnostics + 1] = "прямая связь itemID " .. itemID .. " -> questID " .. known.id
        return { id = known.id, title = activeQuests[known.id] }
    end
    for _, row in ipairs(activeQuestRows) do
        if ruLower(trim(row.title)) == ruLower(known.title) then
            diagnostics[#diagnostics + 1] = "связь itemID " .. itemID .. " -> активный questID " .. row.id .. " по названию"
            return { id = row.id, title = row.title, index = row.index }
        end
    end
end

local function staticRows(itemID)
    local rows = staticIndex[tonumber(itemID)]
    if type(rows) ~= "table" then return end
    return rows
end

local function staticQuestTitle(questID)
    local title = QIQ_QUEST_TITLES and QIQ_QUEST_TITLES[tonumber(questID)]
    if type(title) == "string" and title ~= "" then return title end
    return "Квест ID: " .. tostring(questID)
end

-- The single resolver used by tooltip, click, /qiq debug and /qiq test.
-- itemID is authoritative; name/link are optional enrichment only.
local function resolveItem(itemID, link, suppliedName)
    itemID = tonumber(itemID)
    local name = trim(suppliedName or "")
    local found, seen, reasons = {}, {}, {}
    for _, row in ipairs(staticRows(itemID) or {}) do
        -- Reward-only links identify a quest item, but do not make it a
        -- current objective and must never become Shift-click actions.
        if activeQuests[row[1]] and (row[2] or 0) ~= 64 then
            found[#found + 1] = { id = row[1], title = activeQuests[row[1]], mask = row[2] }
            seen[row[1]] = true
            reasons[#reasons + 1] = "статическая связь itemID"
        end
    end
    local known = resolveKnownActive(itemID, reasons)
    if known and not seen[known.id] then found[#found + 1], seen[known.id] = known, true end
    local function addRecords(records, reason)
        for _, q in ipairs(records or {}) do
            if not seen[q.id] then
                seen[q.id] = true
                found[#found + 1] = { id = q.id, title = q.title }
                reasons[#reasons + 1] = reason
            end
        end
    end
    if name ~= "" then
        addRecords(index[name], "точная item-цель")
    end
    for _, record in ipairs(objectives) do
        if not seen[record.id] and name ~= "" and isDeliveryObjective(record.text, name) then
            addRecords({ record }, "эвристика доставки")
        end
    end
    if #found > 0 then
        lastResolveReason = table.concat(reasons, ", ")
        return found, name, reasons
    end
    lastResolveReason = "нет совпадения"
    return nil, name, reasons
end

local function itemClassID(itemID)
    if not itemID then return end
    local providers = {}
    if C_Item and C_Item.GetItemInfoInstant then providers[#providers + 1] = C_Item.GetItemInfoInstant end
    if GetItemInfoInstant then providers[#providers + 1] = GetItemInfoInstant end
    for _, instant in ipairs(providers) do
        local ok, _, _, _, _, _, classID = pcall(instant, itemID)
        if ok and tonumber(classID) then return tonumber(classID) end
    end
end

local function isQuestItem(itemID)
    return itemClassID(itemID) == ITEM_CLASS_QUEST or (QIQ_QUEST_CLASS_IDS and QIQ_QUEST_CLASS_IDS[tonumber(itemID)] == true)
end

local function hasStaticRelation(itemID, questItem)
    for _, row in ipairs(staticRows(itemID) or {}) do
        if (row[2] or 0) ~= 64 or questItem then return true end
    end
    return false
end

local function questListFor(link, directItemID, directName)
    local itemID = tonumber(directItemID) or itemIDFromLink(link)
    local name = directName
    if (not name or trim(name) == "") and GetItemInfo then
        -- Prefer numeric lookup, but never make it the only source of identity.
        name = GetItemInfo(itemID or link)
    end
    return resolveItem(itemID, link, name)
end

local function appendTooltip(tooltip, link, itemID, itemName)
    if not tooltip or (not link and not itemID) then return end
    itemID = tonumber(itemID)
    if not itemID or itemID <= 0 then itemID = itemIDFromLink(link) end
    local list = questListFor(link, itemID, itemName)
    local key = link or ("item:" .. tostring(itemID))
    if tooltip.__QIQLink == key then return end
    local static = staticRows(itemID)
    local questItem = isQuestItem(itemID)
    if not list and not hasStaticRelation(itemID, questItem) and not questItem then return end
    tooltip.__QIQLink = key
    tooltip:AddLine(" ")
    tooltip:AddLine("|cff80c0ffКвесты предмета:|r")
    if list then
        for _, q in ipairs(list) do tooltip:AddDoubleLine(ACTIVE_QUEST_TITLE_COLOR .. q.title .. "|r", "|cffaaaaaaShift+ЛКМ — открыть|r") end
    elseif static then
        local rewardOnly = true
        for _, row in ipairs(static) do if (row[2] or 0) ~= 64 then rewardOnly = false break end end
        tooltip:AddLine(rewardOnly and "|cffffd200Награда за квест; активного задания нет|r" or "|cffffd200активного задания нет|r")
        for _, row in ipairs(static) do tooltip:AddLine(INACTIVE_QUEST_TITLE_COLOR .. staticQuestTitle(row[1]) .. "|r") end
    else
        tooltip:AddLine("|cffffd200Квестовый предмет; связанное задание не определено|r")
    end
    tooltip:Show()
end

local function tooltipItem(tooltip, data)
    local link = data and (data.hyperlink or data.link)
    local itemID = itemIDFromLink(link) or (data and tonumber(data.id))
    if itemID and itemID <= 0 then itemID = nil end
    local itemName = data and (data.name or data.itemName)
    if not itemID then itemID = itemIDFromLink(link) end
    if not link and itemID and GetItemInfo then
        local _, itemLink = GetItemInfo(itemID)
        link = itemLink
    end
    if not link and tooltip.GetItem then local _, itemLink = tooltip:GetItem(); link = itemLink end
    if (not itemID or itemID <= 0) and link then itemID = itemIDFromLink(link) end
    appendTooltip(tooltip, link, itemID, itemName)
end

local tooltips = { GameTooltip, ItemRefTooltip, ShoppingTooltip1, ShoppingTooltip2, WorldMapTooltip }
for _, tooltip in ipairs(tooltips) do
    if tooltip then
        if tooltip.HasScript and tooltip:HasScript("OnHide") then
            tooltip:HookScript("OnHide", function(self) self.__QIQLink = nil end)
        end
        if tooltip.HasScript and tooltip:HasScript("OnTooltipCleared") then
            tooltip:HookScript("OnTooltipCleared", function(self) self.__QIQLink = nil end)
        end
        if tooltip.HasScript and tooltip:HasScript("OnTooltipSetItem") then
            tooltip:HookScript("OnTooltipSetItem", function(self) tooltipItem(self) end)
        end
    end
end
if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, tooltipItem)
end

local function openQuest(q)
    if not (q and q.id and activeQuests[q.id] and QuestMapFrame_OpenToQuestDetails) then return false end
    local ok = pcall(QuestMapFrame_OpenToQuestDetails, q.id)
    return ok
end

local function chooseQuest(list)
    if #list == 1 then return openQuest(list[1]) end
    if #list < 2 or not QuestMapFrame_OpenToQuestDetails then return false end
    if not menuFrame then
        menuFrame = CreateFrame("Frame", ADDON .. "Menu", UIParent)
        menuFrame:SetFrameStrata("DIALOG")
        menuFrame:SetAllPoints(UIParent)
        menuFrame:EnableMouse(true)
        menuFrame:SetScript("OnMouseDown", function(self) self:Hide() end)
        UISpecialFrames = UISpecialFrames or {}
        UISpecialFrames[#UISpecialFrames + 1] = ADDON .. "Menu"
    end
    for _, button in ipairs(menuButtons) do button:Hide() end
    local width, height = 260, 26 * #list + 12
    menuPanel = menuPanel or CreateFrame("Frame", nil, menuFrame)
    menuPanel:SetSize(width, height)
    menuPanel:ClearAllPoints()
    local cursorX, cursorY = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale() or 1
    cursorX, cursorY = cursorX / scale, cursorY / scale
    local uiWidth, uiHeight = UIParent:GetWidth(), UIParent:GetHeight()
    cursorX = math.max(0, math.min(cursorX, uiWidth - width))
    cursorY = math.max(0, math.min(cursorY, uiHeight - height))
    menuPanel:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", cursorX, cursorY)
    menuPanel:EnableMouse(true)
    menuPanel:SetScript("OnMouseDown", function() end)
    if not menuPanel.background then
        menuPanel.background = menuPanel:CreateTexture(nil, "BACKGROUND")
        menuPanel.background:SetAllPoints()
        menuPanel.background:SetColorTexture(0.03, 0.03, 0.03, 0.96)
    end
    for i, q in ipairs(list) do
        local button = menuButtons[i]
        if not button then
            button = CreateFrame("Button", nil, menuPanel)
            button:SetNormalFontObject(GameFontNormal)
            menuButtons[i] = button
        end
        button:SetSize(width - 12, 22)
        button:ClearAllPoints()
        button:SetPoint("TOP", menuPanel, "TOP", 0, -6 - (i - 1) * 26)
        button:SetText(q.title)
        local quest = q
        button:SetScript("OnClick", function() menuFrame:Hide(); openQuest(quest) end)
        button:Show()
    end
    menuPanel:Show()
    menuFrame:Show()
    return true
end

local function containerLink(bag, slot)
    if type(bag) ~= "number" or type(slot) ~= "number" then return end
    local ok, link
    if C_Container and C_Container.GetContainerItemLink then
        ok, link = pcall(C_Container.GetContainerItemLink, bag, slot)
    elseif GetContainerItemLink then
        ok, link = pcall(GetContainerItemLink, bag, slot)
    end
    if ok then return link end
end

local function sameItemLink(a, b)
    if not a or not b then return false end
    if a == b then return true end
    local aid, bid = tostring(a):match("item:(%d+)"), tostring(b):match("item:(%d+)")
    return aid and bid and aid == bid
end

local function bagSlotForCandidate(candidate, wanted)
    if not candidate then return end
    local slot = candidate.GetID and candidate:GetID()
    if type(slot) ~= "number" then return end
    local bag
    if candidate.GetBag then bag = candidate:GetBag() end
    if type(bag) ~= "number" and candidate.GetBagID then bag = candidate:GetBagID() end
    if type(bag) ~= "number" then bag = candidate.bagID or candidate.bag end
    if type(bag) ~= "number" then
        local parent = candidate.GetParent and candidate:GetParent()
        if parent and parent.GetID then bag = parent:GetID() end
    end
    local shown = containerLink(bag, slot)
    if sameItemLink(shown, wanted) then return bag, slot end
end

local function bagSlotForFocus(focus, wanted)
    local frame = focus
    for _ = 1, 6 do
        if not frame then break end
        local bag, slot = bagSlotForCandidate(frame, wanted)
        if bag ~= nil and slot ~= nil then return bag, slot end
        frame = frame.GetParent and frame:GetParent()
    end
end

local originalHandle = HandleModifiedItemClick
if originalHandle then
    HandleModifiedItemClick = function(link, ...)
        local button = ...
        local explicitButton = type(button) == "string" and (button == "LeftButton" or button == "RightButton" or button == "MiddleButton")
        if explicitButton and button ~= "LeftButton" then return originalHandle(link, ...) end
        if not explicitButton then
            if not GetMouseButtonClicked then return originalHandle(link, ...) end
            local ok, clicked = pcall(GetMouseButtonClicked)
            if not ok or clicked ~= "LeftButton" then return originalHandle(link, ...) end
        end
        local keyboardFocus = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
        local chatEditing = keyboardFocus and keyboardFocus.IsObjectType and keyboardFocus:IsObjectType("EditBox")
        if IsShiftKeyDown and IsShiftKeyDown() and link and not chatEditing then
            local focus = GetMouseFocus and GetMouseFocus()
            local bag, slot = bagSlotForFocus(focus, link)
            if not (bag and slot) and GetMouseFoci then
                for _, candidate in ipairs(GetMouseFoci() or {}) do
                    bag, slot = bagSlotForFocus(candidate, link)
                    if bag and slot then break end
                end
            end
            if bag ~= nil and slot ~= nil then
                local list = questListFor(link, itemIDFromLink(link))
                if list and chooseQuest(list) then return true end
            end
        end
        return originalHandle(link, ...)
    end
end

QIQ:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" or event == "QUEST_LOG_UPDATE" or event == "QUEST_ACCEPTED" or event == "QUEST_REMOVED" or event == "QUEST_TURNED_IN" then rebuild() end
end)
QIQ:RegisterEvent("PLAYER_LOGIN")
QIQ:RegisterEvent("QUEST_LOG_UPDATE")
QIQ:RegisterEvent("QUEST_ACCEPTED")
QIQ:RegisterEvent("QUEST_REMOVED")
QIQ:RegisterEvent("QUEST_TURNED_IN")

SLASH_QUESTITEMQUESTS1 = "/qiq"
SlashCmdList.QUESTITEMQUESTS = function(message)
    local raw = trim(message)
    local command = ruLower(raw:match("^(%S+)") or "")
    if command == "status" then
        local questCount, objectiveCount = 0, #objectives
        for _ in pairs(activeQuests) do questCount = questCount + 1 end
        print("|cff80c0ffQuest Item Quests|r 1.4.1: активных квестов " .. questCount .. ", целей " .. objectiveCount .. ", точных item-целей " .. (function() local n=0; for _ in pairs(index) do n=n+1 end; return n end)() .. ", статических item-связей " .. (function() local n=0; for _ in pairs(staticIndex) do n=n+1 end; return n end)())
        return
    end
    if command == "debug" or command == "test" then
        local arg = trim(raw:sub(#(raw:match("^%S+") or "") + 1))
        local link
        if arg ~= "" then
            local itemID = arg:match("item:(%d+)") or arg:match("^(%d+)$")
            if not itemID then
                print("|cffff8080Quest Item Quests debug|r не распознана ссылка предмета: " .. arg)
                return
            end
            link = "item:" .. itemID
        end
        if not link then
            local focus = GetMouseFocus and GetMouseFocus()
            link = focus and focus.GetItemLink and focus:GetItemLink()
            if not link and GameTooltip and GameTooltip.GetItem then local _, itemLink = GameTooltip:GetItem(); link = itemLink end
        end
        local itemID = itemIDFromLink(link)
        lastResolveReason = "нет совпадения"
        local numericName, numericLink, shortName, shortResolvedLink
        if itemID and GetItemInfo then
            numericName, numericLink = GetItemInfo(itemID)
            shortName, shortResolvedLink = GetItemInfo("item:" .. itemID)
        end
        local shortLink = itemID and ("item:" .. itemID) or link
        local list, resolvedName, reasons
        if itemID then
            list, resolvedName, reasons = questListFor(shortLink, itemID, numericName)
        end
        local known = itemID and knownItemQuests[itemID]
        print("|cff80c0ffQuest Item Quests " .. command .. "|r item link=" .. tostring(link) .. ", itemID=" .. tostring(itemID) .. ", reason=" .. tostring(lastResolveReason) .. ", version=1.4.1")
        print("  GetItemInfo(number): name=" .. tostring(numericName) .. " link=" .. tostring(numericLink))
        print("  GetItemInfo(shortLink): name=" .. tostring(shortName) .. " link=" .. tostring(shortResolvedLink) .. " input=" .. tostring(shortLink))
        print("  known mapping: " .. (known and ("itemID " .. itemID .. " -> questID " .. known.id .. ", title " .. known.title) or "нет"))
        if command == "test" then
            print("  active quest log rows:")
            for _, row in ipairs(activeQuestRows) do
                print("    index=" .. tostring(row.index) .. " questID=" .. tostring(row.id) .. " title=" .. tostring(row.title) .. " normalized=" .. ruLower(trim(row.title)))
            end
            if known and C_QuestLog and C_QuestLog.GetLogIndexForQuestID then
                local ok, knownIndex = pcall(C_QuestLog.GetLogIndexForQuestID, known.id)
                print("  GetLogIndexForQuestID(" .. known.id .. "): " .. (ok and tostring(knownIndex) or "error"))
            end
            local detected = {}
            for _, row in ipairs(activeQuestRows) do
                if known and ruLower(trim(row.title)) == ruLower(known.title) then detected[#detected + 1] = row end
            end
            print("  detected active title: " .. (#detected > 0 and (detected[1].title .. " (questID " .. detected[1].id .. ")") or "нет"))
        end
        if list then
            for _, q in ipairs(list) do
                local rowInfo = ""
                for _, row in ipairs(activeQuestRows) do if row.id == q.id then rowInfo = " index=" .. row.index break end end
                print("  active questID=" .. q.id .. " title=" .. tostring(q.title) .. rowInfo)
            end
        else
            print("  mapping outcome: нет активного совпадения")
        end
        if command == "test" and itemID then
            print("  mapping outcome: " .. (list and "совпадение найдено" or "нет совпадения") .. "; numeric name=" .. tostring(resolvedName))
        end
        return
    end
    print("|cff80c0ffQuest Item Quests|r команды: /qiq status, /qiq debug [itemID], /qiq test [itemID]")
end
