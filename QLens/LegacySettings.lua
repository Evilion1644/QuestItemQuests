-- One-time upgrade cleanup; QLens no longer controls quest sparkle settings.
local A = QIQ
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:SetScript("OnEvent", function()
    if InCombatLockdown and InCombatLockdown() then return end
    local db = A.Settings()
    if type(db.features)=="table" then db.features.questSparkles=nil end
    local saved = db.questSparklesOriginal
    if type(saved)~="table" then return end
    local get = C_CVar and C_CVar.GetCVar or GetCVar
    local set = C_CVar and C_CVar.SetCVar or SetCVar
    if not get or not set then return end
    local specs={{"outlineModeShowLootEffectWhenDisabled","1"},{"graphicsOutlineMode","0"},
        {"raidGraphicsOutlineMode","0"},{"OutlineEngineMode","0"},{"RAIDOutlineEngineMode","0"}}
    local pending={}
    -- Snapshot first: changing a graphics preset can also change engine CVars.
    for _,spec in ipairs(specs) do
        local name,owned=spec[1],spec[2]
        if saved[name]~=nil then
            local ok,current=pcall(get,name)
            if ok and current~=nil then
                if tonumber(current)==tonumber(owned) then pending[name]=saved[name]
                else pending[name]=current end -- preserve newer choices across preset side effects
            end
        end
    end
    for _,spec in ipairs(specs) do
        local name=spec[1]
        if pending[name]~=nil then
            local readBefore,before=pcall(get,name)
            local ok=readBefore and tostring(before)==tostring(pending[name])
            if not ok then ok=pcall(set,name,pending[name]) end
            local read,current=pcall(get,name)
            if ok and read and tostring(current)==tostring(pending[name]) then saved[name]=nil end
        end
    end
    if not next(saved) then db.questSparklesOriginal=nil end
end)
