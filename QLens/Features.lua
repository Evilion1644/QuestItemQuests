local A = QIQ
local defaults = { zoneTracking=true, combatPriority=true, partyQuests=true,
    itemTooltips=true, craftHints=true, itemShortcuts=true, vendorHighlight=true, minimapButton=true }
function A.FeatureEnabled(key)
    local options = A.Settings().features
    if type(options) == "table" and options[key] ~= nil then return options[key] == true end
    return defaults[key] == true
end
function A.SetFeature(key, enabled)
    if defaults[key] == nil then return end
    local db = A.Settings()
    if type(db.features) ~= "table" then db.features = {} end
    db.features[key] = not not enabled
    if A.ZoneTracking then A.ZoneTracking.Schedule() end
    if A.CombatPriority and A.CombatPriority.Reset then A.CombatPriority.Reset() end
    if A.VendorPrice then A.VendorPrice.Refresh() end
    if QLensMinimapButton then QLensMinimapButton:SetShown(A.FeatureEnabled("minimapButton")) end
    if A.RefreshFeatureTooltips then A.RefreshFeatureTooltips() end
end
