local A = assert(QIQ, "Locale.lua must load first")
local T = A.T
local ADDON = ... or "QLens"
local QIQ = CreateFrame("Frame")
local staticIndex = QIQ_ITEM_QUESTS or {}
local index = {}
local objectives = {}
local activeQuests = {}
local activeQuestRows = {}
local resolveCache = {}
local journalRevision = 0
local lastResolveReason = T("none")
local menuFrame
local menuPanel
local menuButtons = {}
local ITEM_CLASS_QUEST = 12
local ACTIVE_QUEST_TITLE_COLOR = "|cff00ff80"
local INACTIVE_QUEST_TITLE_COLOR = "|cffff7070"
local REL_OBJECTIVE, REL_SOURCE, REL_REQUIRED = 1, 2, 4
local REL_STARTED_BY, REL_START_QUEST, REL_RELATED, REL_REWARD = 8, 16, 32, 64
local ACTION_RELATIONS = { REL_OBJECTIVE, REL_SOURCE, REL_REQUIRED, REL_STARTED_BY, REL_START_QUEST, REL_RELATED }

local function hasRelation(mask, bit)
    mask = tonumber(mask) or 0
    return mask % (bit * 2) >= bit
end
local function hasActionRelation(mask)
    for _, bit in ipairs(ACTION_RELATIONS) do if hasRelation(mask, bit) then return true end end
    return false
end
local function isRewardOnly(mask)
    return hasRelation(mask, REL_REWARD) and not hasActionRelation(mask)
end

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
local function normalize(s) return ruLower(trim(s)) end

local deliveryWords = A.locale == "ruRU" and {
    ["отнеси"] = true, ["отнесите"] = true, ["отнес"] = true,
    ["принеси"] = true, ["принесите"] = true, ["принес"] = true,
    ["доставь"] = true, ["доставьте"] = true, ["доставил"] = true,
    ["передай"] = true, ["передайте"] = true, ["передал"] = true,
    ["отдай"] = true, ["отдайте"] = true, ["отдал"] = true,
} or {bring=true, deliver=true, take=true, ["return"]=true}

-- Some Forever quest objectives do not expose an item name/link at tooltip time.
-- Keep the known relation by item ID, then verify it against the active log.
local knownItemQuests = {
    [5827] = { id = 1106 },
}

local function itemIDFromLink(link)
    return link and tonumber(tostring(link):match("item:(%d+)"))
end

local function firstTwoWords(s)
    local a, b = ruLower(trim(s)):match("^(%S+)%s+(%S+)")
    if a and b then return a .. " " .. b end
end

local function isDeliveryObjective(text, itemName, normalizedText)
    local objectiveText = normalizedText or normalize(text)
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
                local record = { id = qid, title = title or (T("quest") .. qid), text = text,
                    normalizedText = normalize(text), type = tostring(obj.type or "") }
                objectives[#objectives + 1] = record
                if ruLower(record.type) == "item" then
                    local key = record.normalizedText
                    index[key] = index[key] or {}
                    local seen = false
                    for _, q in ipairs(index[key]) do
                        if q.id == qid then seen = true break end
                    end
                    if not seen then index[key][#index[key] + 1] = record end
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
    wipe(resolveCache)
    journalRevision = journalRevision + 1
    if not (C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo) then return end
    local count = C_QuestLog.GetNumQuestLogEntries()
    for i = 1, count do
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHeader and info.questID and info.questID > 0 then
            activeQuests[info.questID] = info.title or (T("quest") .. info.questID)
            local activeTitle = info.title or (T("quest") .. info.questID)
            activeQuestRows[#activeQuestRows + 1] = { index = i, id = info.questID, title = activeTitle, normalizedTitle = normalize(activeTitle) }
            addQuest(info.questID, info.title)
        end
    end
end

local function resolveKnownActive(itemID, diagnostics)
    local known = itemID and knownItemQuests[itemID]
    if not known then return end
    if activeQuests[known.id] then
        diagnostics[#diagnostics + 1] = T("direct") .. ": " .. itemID .. " -> " .. known.id
        return { id = known.id, title = activeQuests[known.id] }
    end

end

local function staticRows(itemID)
    local rows = staticIndex[tonumber(itemID)]
    if type(rows) ~= "table" then return end
    return rows
end

local function staticQuestTitle(questID)
    local titles = QIQ_TITLES and (QIQ_TITLES[A.locale] or QIQ_TITLES.enUS) or QIQ_QUEST_TITLES
    local title = titles and titles[tonumber(questID)]
    title = title or (QIQ_TITLES and QIQ_TITLES.enUS[tonumber(questID)])
    if type(title) == "string" and title ~= "" then return title end
    return T("quest") .. tostring(questID)
end

-- The single resolver used by tooltip, click, /qiq debug and /qiq test.
-- itemID is authoritative; name/link are optional enrichment only.
local function resolveItem(itemID, link, suppliedName)
    itemID = tonumber(itemID)
    local name = trim(suppliedName or "")
    local normalizedName = normalize(name)
    local cacheKey = tostring(itemID or 0) .. "\031" .. normalizedName
    local cached = resolveCache[cacheKey]
    if cached and cached.revision == journalRevision then
        lastResolveReason = cached.reason
        return cached.list, name, cached.reasons
    end
    local found, seen, reasons = {}, {}, {}
    for _, row in ipairs(staticRows(itemID) or {}) do
        -- Reward-only links identify a quest item, but do not make it a
        -- current objective and must never become Alt-click actions.
        if activeQuests[row[1]] and hasActionRelation(row[2]) and not seen[row[1]] then
            found[#found + 1] = { id = row[1], title = activeQuests[row[1]], mask = row[2] }
            seen[row[1]] = true
            reasons[#reasons + 1] = T("static")
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
    if #found == 0 and normalizedName ~= "" then
        addRecords(index[normalizedName], T("exact"))
    end
    if #found == 0 then
    for _, record in ipairs(objectives) do
        if not seen[record.id] and normalizedName ~= "" and isDeliveryObjective(record.text, name, record.normalizedText) then
            addRecords({ record }, T("delivery"))
        end
    end
    end
    if #found > 0 then
        lastResolveReason = table.concat(reasons, ", ")
        resolveCache[cacheKey] = { revision=journalRevision, list=found, reasons=reasons, reason=lastResolveReason }
        return found, name, reasons
    end
    lastResolveReason = T("none")
    resolveCache[cacheKey] = { revision=journalRevision, list=nil, reasons=reasons, reason=lastResolveReason }
    return nil, name, reasons
end

local function itemClassID(itemID)
    if not itemID then return end
    if C_Item and type(C_Item.GetItemInfoInstant) == "function" then
        local ok, _, _, _, _, _, classID = pcall(C_Item.GetItemInfoInstant, itemID)
        if ok and tonumber(classID) then return tonumber(classID) end
    end
    if type(GetItemInfoInstant) == "function" then
        local ok, _, _, _, _, _, classID = pcall(GetItemInfoInstant, itemID)
        if ok and tonumber(classID) then return tonumber(classID) end
    end
end

local function isQuestItem(itemID)
    if QIQ_QUEST_CLASS_IDS and QIQ_QUEST_CLASS_IDS[tonumber(itemID)] == true then return true end
    return itemClassID(itemID) == ITEM_CLASS_QUEST
end

local function hasStaticRelation(itemID, questItem)
    for _, row in ipairs(staticRows(itemID) or {}) do
        if hasActionRelation(row[2]) or (questItem and isRewardOnly(row[2])) then return true end
    end
    return false
end
local function hasActionableStatic(itemID)
    for _, row in ipairs(staticRows(itemID) or {}) do if hasActionRelation(row[2]) then return true end end
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

-- The addon owns a companion tooltip and never clears or appends to a tooltip
-- owned by Blizzard or another addon. This also allows an in-place journal refresh.
local companions, trackedTooltips, lifecycleHooked, itemHooked = {}, {}, {}, {}
local companionSerial = 0
local function companionFor(owner)
    if companions[owner] then return companions[owner] end
    companionSerial = companionSerial + 1
    local ok, companion = pcall(CreateFrame, "GameTooltip", ADDON .. "CompanionTooltip" .. companionSerial, UIParent, "GameTooltipTemplate")
    if ok and companion then
        if companion.SetClampedToScreen then companion:SetClampedToScreen(true) end
        companions[owner] = companion
        return companion
    end
end
local function hideCompanion(owner, preserveTracking)
    local companion = companions[owner]
    if companion and companion.Hide then companion:Hide() end
    if not preserveTracking then trackedTooltips[owner] = nil end
    owner.__QIQLink = nil
end
local function appendTooltip(tooltip, link, itemID, itemName, force)
    if not tooltip or (not link and not itemID) then return end
    itemID = tonumber(itemID)
    if not itemID or itemID <= 0 then itemID = itemIDFromLink(link) end
    if not itemID then return end
    local name = trim(itemName)
    if name == "" and GetItemInfo then local ok, value = pcall(GetItemInfo, itemID); if ok then name = value or "" end end
    local key = tostring(itemID) .. "\031" .. normalize(name) .. "\031" .. journalRevision
    if not force and tooltip.__QIQLink == key then return end
    local questEnabled = not A.FeatureEnabled or A.FeatureEnabled("itemTooltips")
    local list = questEnabled and questListFor(link, itemID, name)
    local static = questEnabled and staticRows(itemID)
    local actionableStatic = hasActionableStatic(itemID)
    -- Static actionable relations already establish visibility; avoid a class API call in this hot path.
    local questItem = questEnabled and (actionableStatic or isQuestItem(itemID))
    local craft = (not A.FeatureEnabled or A.FeatureEnabled("craftHints")) and A.CraftProfessions and A.CraftProfessions(itemID)
    if not list and not (questEnabled and hasStaticRelation(itemID, questItem)) and not questItem and not craft then
        if name == "" then
            trackedTooltips[tooltip] = { link=link, itemID=itemID, name="", pending=true }
            hideCompanion(tooltip, true)
        else
            hideCompanion(tooltip)
        end
        return
    end
    local companion = companionFor(tooltip)
    if not companion then return end
    if companion.SetOwner then companion:SetOwner(tooltip, "ANCHOR_NONE") end
    if companion.ClearLines then companion:ClearLines() end
    companion:AddLine("|cff80c0ffQLens|r")
    local lineCount = 1
    local hasQuests = questEnabled and (list or hasStaticRelation(itemID, questItem) or questItem)
    if hasQuests then
        companion:AddLine("|cffffd580" .. T("questSection") .. "|r")
        lineCount=lineCount+1
    end
    if list then
        for _, q in ipairs(list) do companion:AddDoubleLine(ACTIVE_QUEST_TITLE_COLOR .. q.title .. "|r", A.Settings().key=="off" and "" or "|cffaaaaaa" .. T("openHint", A.KeyName()) .. "|r"); lineCount = lineCount + 1 end
    elseif static and hasStaticRelation(itemID, questItem) then
        local rewardOnly = true
        for _, row in ipairs(static) do if hasActionRelation(row[2]) then rewardOnly = false break end end
        companion:AddLine(rewardOnly and "|cffffd200" .. T("rewardOnly") .. "|r" or "|cffffd200" .. T("inactive") .. "|r")
        lineCount = lineCount + 1
        local seen = {}
        for _, row in ipairs(static) do
            local visible = rewardOnly and isRewardOnly(row[2]) or (not rewardOnly and hasActionRelation(row[2]))
            if visible and not seen[row[1]] then companion:AddLine(INACTIVE_QUEST_TITLE_COLOR .. staticQuestTitle(row[1]) .. "|r"); seen[row[1]] = true; lineCount = lineCount + 1 end
        end
    elseif questItem then
        companion:AddLine("|cffffd200" .. T("unknownItem") .. "|r")
        lineCount = lineCount + 1
    end
    if craft then
        companion:AddLine(" ")
        companion:AddLine("|cff80dce8" .. T("professionSection") .. "|r")
        companion:AddLine(craft,.9,.94,.98,true)
        lineCount=lineCount+2+math.max(1,math.ceil(#craft/60))
    end
    companion:AddLine(" "); lineCount=lineCount+1
    companion:AddLine("|cffaaaaaa" .. T(A.Settings().key=="off" and "disabled" or craft and "craftHint" or "guideHint") .. "|r"); lineCount=lineCount+1
    tooltip.__QIQLink = key
    trackedTooltips[tooltip] = { link=link, itemID=itemID, name=name }
    companion:Show()
    if companion.ClearAllPoints then companion:ClearAllPoints() end
    if companion.SetPoint then
        local height = companion.GetHeight and tonumber(companion:GetHeight()) or 0
        height = math.max(height or 0, 24 + lineCount * 16)
        local ownerBottom = tooltip.GetBottom and tonumber(tooltip:GetBottom()) or nil
        local ownerTop = tooltip.GetTop and tonumber(tooltip:GetTop()) or nil
        local uiHeight = UIParent and UIParent.GetHeight and tonumber(UIParent:GetHeight()) or nil
        if ownerBottom and ownerBottom >= height + 2 then
            companion:SetPoint("TOPLEFT", tooltip, "BOTTOMLEFT", 0, -2)
        elseif ownerTop and uiHeight and uiHeight - ownerTop >= height + 2 then
            companion:SetPoint("BOTTOMLEFT", tooltip, "TOPLEFT", 0, 2)
        else
            companion:SetPoint("TOPLEFT", tooltip, "BOTTOMLEFT", 0, -2)
        end
    end
end

local function hookTooltipLifecycle(tooltip)
    if not tooltip or lifecycleHooked[tooltip] then return end
    lifecycleHooked[tooltip] = true
    if tooltip.HasScript and tooltip.HookScript then
        if tooltip:HasScript("OnHide") then tooltip:HookScript("OnHide", hideCompanion) end
        if tooltip:HasScript("OnTooltipCleared") then tooltip:HookScript("OnTooltipCleared", hideCompanion) end
    end
end

local function tooltipItem(tooltip, data)
    -- TooltipDataProcessor can introduce frames not present during addon load.
    -- Add lifecycle cleanup lazily, without registering another item callback.
    hookTooltipLifecycle(tooltip)
    local link = data and (data.hyperlink or data.link)
    local itemID = itemIDFromLink(link) or (data and tonumber(data.id))
    if itemID and itemID <= 0 then itemID = nil end
    local itemName = data and (data.name or data.itemName)
    if not itemID then itemID = itemIDFromLink(link) end
    if not link and itemID and GetItemInfo then
        local _, itemLink = GetItemInfo(itemID)
        link = itemLink
    end
    if tooltip.GetItem then
        local ok, tooltipName, itemLink = pcall(tooltip.GetItem, tooltip)
        if ok then itemName = itemName or tooltipName; link = link or itemLink end
    end
    if (not itemID or itemID <= 0) and link then itemID = itemIDFromLink(link) end
    appendTooltip(tooltip, link, itemID, itemName)
end

local function hookTooltip(tooltip)
    if tooltip and not itemHooked[tooltip] then
        itemHooked[tooltip] = true
        hookTooltipLifecycle(tooltip)
        if tooltip.HasScript and tooltip:HasScript("OnTooltipSetItem") then
            tooltip:HookScript("OnTooltipSetItem", function(self) tooltipItem(self) end)
        end
    end
end
-- Explicit calls avoid an ipairs nil-gap dropping all later tooltip frames.
hookTooltip(GameTooltip); hookTooltip(ItemRefTooltip); hookTooltip(ShoppingTooltip1); hookTooltip(ShoppingTooltip2); hookTooltip(WorldMapTooltip)
if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, tooltipItem)
end
local function refreshTracked(itemID)
    local pending = {}
    for tooltip, state in pairs(trackedTooltips) do pending[#pending + 1] = { tooltip=tooltip, state=state } end
    for _, row in ipairs(pending) do
        local tooltip, state = row.tooltip, row.state
        if not itemID or state.itemID == itemID then appendTooltip(tooltip, state.link, state.itemID, state.name, true) end
    end
end

local function openQuest(q)
    if not (q and q.id and activeQuests[q.id] and QuestMapFrame_OpenToQuestDetails) then return false end
    local ok, result = pcall(QuestMapFrame_OpenToQuestDetails, q.id)
    return ok and result ~= false
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
        button:SetScript("OnClick", function()
            if openQuest(quest) then
                menuFrame:Hide()
            else
                menuFrame:Show()
                if print then print("|cffff8080QLens:|r " .. T("openFailed", tostring(quest.title))) end
            end
        end)
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

local function isChatEditing()
    if type(ChatEdit_GetActiveWindow) == "function" then
        local ok, editBox = pcall(ChatEdit_GetActiveWindow)
        if ok and editBox then return true end
    end
    if type(GetCurrentKeyBoardFocus) == "function" then
        local ok, focus = pcall(GetCurrentKeyBoardFocus)
        if ok and focus and focus.IsObjectType then
            local typeOK, isEditBox = pcall(focus.IsObjectType, focus, "EditBox")
            if typeOK and isEditBox then return true end
        end
    end
    return false
end

local originalHandle = HandleModifiedItemClick
if originalHandle then
    HandleModifiedItemClick = function(link, ...)
        local args = { n=select("#", ...), ... }
        local function intercept()
            local button = args[1]
            local explicitButton = type(button) == "string" and (button == "LeftButton" or button == "RightButton" or button == "MiddleButton")
            if explicitButton and button ~= "LeftButton" then return false end
            if not explicitButton then
                if type(GetMouseButtonClicked) ~= "function" then return false end
                local clicked = GetMouseButtonClicked()
                if clicked ~= "LeftButton" then return false end
            end
            local action=A.ClickAction()
            if not action or not link or isChatEditing() then return false end
            local focus = type(GetMouseFocus) == "function" and GetMouseFocus() or nil
            local bag, slot = bagSlotForFocus(focus, link)
            if (bag == nil or slot == nil) and type(GetMouseFoci) == "function" then
                for _, candidate in ipairs(GetMouseFoci() or {}) do
                    bag, slot = bagSlotForFocus(candidate, link)
                    if bag ~= nil and slot ~= nil then break end
                end
            end
            if bag ~= nil and slot ~= nil then
                if action=="guide" then return A.OpenGuide(nil,itemIDFromLink(link)) end
                local list = questListFor(link, itemIDFromLink(link))
                if list and chooseQuest(list) then return true end
            end
            return false
        end
        local ok, consumed = pcall(intercept)
        if ok and consumed then return true end
        return originalHandle(link, unpack(args, 1, args.n))
    end
end

QIQ:SetScript("OnEvent", function(_, event, itemID, success)
    if event == "GET_ITEM_INFO_RECEIVED" then
        if success ~= false then wipe(resolveCache); refreshTracked(tonumber(itemID)) end
    elseif event == "PLAYER_LOGIN" or event == "QUEST_LOG_UPDATE" or event == "QUEST_ACCEPTED" or event == "QUEST_REMOVED" or event == "QUEST_TURNED_IN" then
        rebuild()
        refreshTracked()
    end
end)
QIQ:RegisterEvent("PLAYER_LOGIN")
QIQ:RegisterEvent("QUEST_LOG_UPDATE")
QIQ:RegisterEvent("QUEST_ACCEPTED")
QIQ:RegisterEvent("QUEST_REMOVED")
QIQ:RegisterEvent("QUEST_TURNED_IN")
pcall(QIQ.RegisterEvent, QIQ, "GET_ITEM_INFO_RECEIVED")

A.ActiveQuests = activeQuests
A.OpenActiveQuest = function(id) return openQuest({id=id}) end
A.Normalize = normalize
A.Title = staticQuestTitle
A.Relations = staticIndex
SLASH_QUESTITEMQUESTS1 = "/qiq"
SLASH_QUESTITEMQUESTS2 = "/qlens"
SlashCmdList.QUESTITEMQUESTS = function(message)
    local raw=trim(message)
    local command,arg=raw:match("^(%S+)%s*(.*)$")
    command=(command or ""):lower()
    if command=="" or command=="guide" then A.OpenGuide(); return end
    if command=="quest" or command=="item" then
        local id=tonumber(arg:match("^(%d+)$")) or tonumber(arg:match("item:(%d+)"))
        if not id or id<1 then print(T("invalid")); return end
        if command=="quest" then A.OpenGuide(id) else A.OpenGuide(nil,id) end
        return
    end
    if command=="key" then
        if arg~="alt" and arg~="altshift" and arg~="off" then print(T("help")); return end
        A.Settings().key=arg; refreshTracked(); print(T("keySet",A.KeyName())); return
    end
    if command=="price" then A.VendorPrice.Open(); return end
    if command=="status" then
        local n=0; for _ in pairs(activeQuests) do n=n+1 end
        print(T("statusLine",A.version,n,#objectives,A.KeyName())); return
    end
    if command=="debug" or command=="test" then
        local id=tonumber(arg:match("^(%d+)$")) or tonumber(arg:match("item:(%d+)"))
        if not id then print(T("invalid")); return end
        local list,_,reasons=questListFor("item:"..id,id)
        print("QIQ "..A.version.." itemID="..id..": "..lastResolveReason)
        for _,q in ipairs(list or {}) do print("  "..q.id..": "..q.title) end
        return
    end
    print(T("help"))
end

if QIQ_TEST_MODE then
    QuestItemQuests_TestAPI = {
        rebuild = rebuild, resolveItem = resolveItem, tooltipItem = tooltipItem,
        hasActionRelation = hasActionRelation, isRewardOnly = isRewardOnly,
        getRevision = function() return journalRevision end,
    }
end

function A.RefreshFeatureTooltips()
    for tooltip in pairs(companions) do
        tooltip.__QIQLink = nil
        hideCompanion(tooltip)
    end
end
