local A = QIQ

local function angleFromCursor()
    local x, y = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    local centerX, centerY = Minimap:GetCenter()
    x, y = x / scale - centerX, y / scale - centerY
    if x == 0 then return y >= 0 and 90 or 270 end
    local angle = math.deg(math.atan(y / x))
    if x < 0 then angle = angle + 180
    elseif y < 0 then angle = angle + 360 end
    return angle % 360
end

local function position(button, angle)
    local radians = math.rad(angle)
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(radians) * 80, math.sin(radians) * 80)
end

local function createButton()
    if not Minimap or _G.QLensMinimapButton then return end
    local button = CreateFrame("Button", "QLensMinimapButton", Minimap)
    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(Minimap:GetFrameLevel() + 5)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetSize(24, 24)
    background:SetPoint("CENTER")
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18)
    icon:SetPoint("CENTER")
    icon:SetTexture("Interface\\Icons\\INV_Misc_Spyglass_03")
    icon:SetTexCoord(.08, .92, .08, .92)
    local ring = button:CreateTexture(nil, "OVERLAY")
    ring:SetSize(50, 50)
    -- The visible circle is offset inside this game texture.
    ring:SetPoint("TOPLEFT", button, "TOPLEFT")
    ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    position(button, tonumber(A.Settings().minimapAngle) or 225)
    if A.FeatureEnabled and not A.FeatureEnabled("minimapButton") then button:Hide() end
    button:SetScript("OnDragStart", function(self)
        self.dragging = true
        self.dragged = true
        self:SetScript("OnUpdate", function(s)
            local angle = angleFromCursor()
            A.Settings().minimapAngle = angle
            position(s, angle)
        end)
    end)
    button:SetScript("OnDragStop", function(self)
        self.dragging = false
        self:SetScript("OnUpdate", nil)
        if C_Timer and C_Timer.After then
            C_Timer.After(.15, function() self.dragged = false end)
        end
    end)
    button:SetScript("OnClick", function(self, mouseButton)
        if self.dragged then self.dragged = false; return end
        if A.OpenGuide() and mouseButton == "RightButton" and A.Guide then
            A.Guide:SetMode("prices")
        end
    end)
    button:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("QLens", 1, .82, .43)
        GameTooltip:AddLine(A.T("minimapHint"), .8, .85, .9, true)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", createButton)
