local A = QIQ
local P = {}
A.VendorPrice = P

local buttons = setmetatable({}, {__mode = "k"})
local panel

local function threshold()
    local value = tonumber(A.Settings().vendorThreshold) or 0
    return math.max(0, math.floor(value))
end

local function bagAndSlot(button)
    if not button then return end
    if button.IsCached and button:IsCached() then return end
    local bag
    if button.GetBag then bag = button:GetBag() end
    if bag == nil and button.GetBagID then bag = button:GetBagID() end
    if bag == nil then bag = button.bagID or button.bag end
    if bag == nil then
        local parent = button.GetParent and button:GetParent()
        local name = parent and parent.GetName and parent:GetName()
        if name and name:match("^ContainerFrame%d+$") then bag = parent:GetID() end
        if name == "BankFrame" then bag = BANK_CONTAINER or -1 end
    end
    local slot = button.slotID or button.slotIndex or button.slot
    if type(slot) ~= "number" and button.GetID then slot = button:GetID() end
    local equipped = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
    local lastBankBag = equipped + (NUM_BANKBAGSLOTS or 0)
    local validBag = type(bag) == "number" and
        ((bag >= 0 and bag <= lastBankBag) or
         bag == (BANK_CONTAINER or -1) or
         bag == REAGENTBANK_CONTAINER or bag == KEYRING_CONTAINER)
    if validBag
        and type(slot) == "number" and slot >= 1 then
        return bag, slot
    end
end

local function itemData(button, bag, slot)
    local info = type(button.info) == "table" and button.info or nil
    local link = info and info.hyperlink
    local count = info and info.stackCount
    if C_Container and C_Container.GetContainerItemInfo then
        local live = C_Container.GetContainerItemInfo(bag, slot)
        if live then
            link = live.hyperlink or link
            count = live.stackCount or count
        end
    elseif GetContainerItemInfo then
        local _, liveCount = GetContainerItemInfo(bag, slot)
        count = liveCount or count
    end
    if not link then
        if C_Container and C_Container.GetContainerItemLink then
            link = C_Container.GetContainerItemLink(bag, slot)
        elseif GetContainerItemLink then
            link = GetContainerItemLink(bag, slot)
        end
    end
    return link, tonumber(count) or 1
end

local function makeBorder(button)
    if button.QLensCheapBorder then return button.QLensCheapBorder end
    local edges = {}
    local function edge(point1, x1, y1, point2, x2, y2, width, height)
        local texture = button:CreateTexture(nil, "OVERLAY", nil, 7)
        texture:SetColorTexture(1, 0.11, 0.12, 0.95)
        texture:SetPoint(point1, button, point1, x1, y1)
        texture:SetPoint(point2, button, point2, x2, y2)
        if width then texture:SetWidth(width) end
        if height then texture:SetHeight(height) end
        texture:Hide()
        edges[#edges + 1] = texture
    end
    -- Place the border just inside the slot, over Bagnon's quality border.
    edge("TOPLEFT", 1, -1, "TOPRIGHT", -1, -1, nil, 3)
    edge("BOTTOMLEFT", 1, 1, "BOTTOMRIGHT", -1, 1, nil, 3)
    edge("TOPLEFT", 1, -1, "BOTTOMLEFT", 1, 1, 3, nil)
    edge("TOPRIGHT", -1, -1, "BOTTOMRIGHT", -1, 1, 3, nil)
    local tint = button:CreateTexture(nil, "OVERLAY", nil, 6)
    tint:SetColorTexture(0.75, 0.03, 0.04, 0.18)
    tint:SetPoint("TOPLEFT", button, "TOPLEFT", 3, -3)
    tint:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -3, 3)
    tint:Hide()
    edges[#edges + 1] = tint
    button.QLensCheapBorder = edges
    return edges
end

local function showBorder(button, visible)
    local edges = button.QLensCheapBorder
    if not edges and visible then edges = makeBorder(button) end
    if edges then
        for _, texture in ipairs(edges) do
            if visible then texture:Show() else texture:Hide() end
        end
    end
end

local function updateButton(button)
    local bag, slot = bagAndSlot(button)
    if not bag or threshold() == 0 then showBorder(button, false); return end
    local link, count = itemData(button, bag, slot)
    if not link then showBorder(button, false); return end
    local getInfo = C_Item and C_Item.GetItemInfo or GetItemInfo
    if type(getInfo) ~= "function" then showBorder(button, false); return end
    local price = select(11, getInfo(link))
    showBorder(button, type(price) == "number" and price > 0 and price * count < threshold())
end

function P.Refresh()
    for button in pairs(buttons) do updateButton(button) end
end

local function watchButton(button)
    if not button then return end
    local bag = bagAndSlot(button)
    if not bag then return end
    buttons[button] = true
    updateButton(button)
end

local function scanFrame(frame, depth)
    if depth > 8 or not frame or not frame.IsShown or not frame:IsShown() then return end
    if frame.GetObjectType and frame:GetObjectType() == "Button" then watchButton(frame) end
    if frame.GetChildren then
        local children = {frame:GetChildren()}
        for _, child in ipairs(children) do scanFrame(child, depth + 1) end
    end
end

function P.Scan()
    scanFrame(UIParent, 0)
end

local function scheduleScan()
    if C_Timer and C_Timer.After then C_Timer.After(0, P.Scan)
    else P.Scan() end
end

local function setThreshold(value)
    A.Settings().vendorThreshold = value
    P.Refresh()
    scheduleScan()
end

P.GetThreshold = threshold
P.SetThreshold = setThreshold

local function textAt(parent, value, x, y, size, r, g, b)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    label:SetText(value)
    if size then label:SetFont(STANDARD_TEXT_FONT, size) end
    if r then label:SetTextColor(r, g, b) end
    return label
end

local function makePanel()
    local frame = CreateFrame("Frame", "QLensVendorPriceFrame", UIParent)
    frame:SetSize(370, 205)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.035, 0.055, 0.09, 0.97)
    local top = frame:CreateTexture(nil, "BORDER")
    top:SetPoint("TOPLEFT", 1, -1)
    top:SetPoint("TOPRIGHT", -1, -1)
    top:SetHeight(3)
    top:SetColorTexture(0.85, 0.58, 0.18, 1)
    textAt(frame, A.T("priceTitle"), 18, -20, 17, 1, 0.79, 0.4)
    textAt(frame, A.T("priceNote"), 18, -51, 12, 0.75, 0.81, 0.89)

    local inputs = {}
    local names = {"priceGold", "priceSilver", "priceCopper"}
    for i = 1, 3 do
        local x = 22 + (i - 1) * 114
        textAt(frame, A.T(names[i]), x, -78, 12, 0.88, 0.88, 0.88)
        local input = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
        input:SetSize(82, 26)
        input:SetPoint("TOPLEFT", x + 3, -98)
        input:SetAutoFocus(false)
        input:SetNumeric(true)
        input:SetMaxLetters(7)
        input:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        inputs[i] = input
    end
    frame.inputs = inputs
    local save = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    save:SetSize(126, 29)
    save:SetPoint("BOTTOMLEFT", 18, 17)
    save:SetText(A.T("priceSave"))
    save:SetScript("OnClick", function()
        local gold = math.min(9999999, tonumber(inputs[1]:GetText()) or 0)
        local silver = math.min(99, tonumber(inputs[2]:GetText()) or 0)
        local copper = math.min(99, tonumber(inputs[3]:GetText()) or 0)
        local value = gold * 10000 + silver * 100 + copper
        setThreshold(value)
        print(value == 0 and A.T("priceDisabled") or A.T("priceSet", gold, silver, copper))
        frame:Hide()
    end)
    local disable = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    disable:SetSize(126, 29)
    disable:SetPoint("LEFT", save, "RIGHT", 8, 0)
    disable:SetText(A.T("priceOff"))
    disable:SetScript("OnClick", function() setThreshold(0); print(A.T("priceDisabled")); frame:Hide() end)
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 0, 0)
    frame:Hide()
    return frame
end

function P.Open()
    if not panel then panel = makePanel() end
    local value = threshold()
    panel.inputs[1]:SetText(tostring(math.floor(value / 10000)))
    panel.inputs[2]:SetText(tostring(math.floor(value / 100) % 100))
    panel.inputs[3]:SetText(tostring(value % 100))
    panel:Show()
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("BAG_UPDATE")
events:RegisterEvent("BAG_UPDATE_DELAYED")
events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        if hooksecurefunc then
            for _, name in ipairs({"SetItemButtonQuality", "SetItemButtonTexture", "SetItemButtonCount"}) do
                if type(_G[name]) == "function" then hooksecurefunc(name, watchButton) end
            end
            if BagBrother and BagBrother.ContainerItem then
                hooksecurefunc(BagBrother.ContainerItem, "Update", watchButton)
            end
        end
        scheduleScan()
    else
        P.Refresh()
        if event == "BAG_UPDATE_DELAYED" then scheduleScan() end
    end
end)
