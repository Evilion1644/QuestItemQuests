local A = QIQ
local S = {}
A.QuestSparkles = S
-- Graphics presets also have raid/engine counterparts. Only touch supported CVars.
local specs = {
    {"outlineModeShowLootEffectWhenDisabled", "1", true},
    {"graphicsOutlineMode", "0", true},
    {"raidGraphicsOutlineMode", "0"},
    {"OutlineEngineMode", "0"},
    {"RAIDOutlineEngineMode", "0"},
}
local busy, pending = false, false
local function get(name)
    local fn = C_CVar and C_CVar.GetCVar or GetCVar
    if not fn then return nil end
    local ok, value = pcall(fn, name)
    if ok and value ~= nil and value ~= "" then return tostring(value) end
end
local function equal(a,b)
    return a == b or (tonumber(a) ~= nil and tonumber(a) == tonumber(b))
end
local function set(name,value)
    if equal(get(name),value) then return true end
    local fn = C_CVar and C_CVar.SetCVar or SetCVar
    if not fn then return false end
    local ok = pcall(fn,name,value)
    return ok and equal(get(name),value)
end
local function restore(db)
    local saved=db.questSparklesOriginal
    if type(saved)~="table" then return true end
    local success=true
    -- Restore engine values last, after presets that may change them as a side effect.
    for _,spec in ipairs(specs) do
        if saved[spec[1]]~=nil and not set(spec[1],saved[spec[1]]) then success=false end
    end
    if success then db.questSparklesOriginal=nil end
    return success
end
function S.Apply()
    if busy or (InCombatLockdown and InCombatLockdown()) then return end
    local db=A.Settings()
    busy=true
    if not A.FeatureEnabled("questSparkles") then restore(db); busy=false; return end
    local values={}
    local supported=true
    for _,spec in ipairs(specs) do
        values[spec[1]]=get(spec[1])
        if spec[3] and not values[spec[1]] then supported=false end
    end
    if supported then
        if type(db.questSparklesOriginal)~="table" then db.questSparklesOriginal={} end
        -- Snapshot every original value before the first write changes a preset.
        for name,value in pairs(values) do
            if db.questSparklesOriginal[name]==nil then db.questSparklesOriginal[name]=value end
        end
        for _,spec in ipairs(specs) do
            if values[spec[1]] and not set(spec[1],spec[2]) then supported=false; break end
        end
    end
    if not supported then
        db.features=db.features or {}; db.features.questSparkles=false
        restore(db)
        print(A.locale=="ruRU" and "QLens: не удалось включить искрение. Проверьте доступность графических настроек клиента."
            or "QLens: could not enable sparkles. Check client graphics settings support.")
    end
    busy=false
    if A.Guide and A.Guide.RefreshSettingsPane then A.Guide:RefreshSettingsPane() end
end
function S.Schedule()
    if busy or pending then return end
    pending=true
    local function run() pending=false; S.Apply() end
    if C_Timer and C_Timer.After then C_Timer.After(.5,run) else run() end
end
local frame=CreateFrame("Frame")
for _,event in ipairs({"PLAYER_LOGIN","PLAYER_REGEN_ENABLED","CVAR_UPDATE"}) do frame:RegisterEvent(event) end
frame:SetScript("OnEvent",function(_,event,name)
    if busy then return end
    if event=="CVAR_UPDATE" then
        if not A.FeatureEnabled("questSparkles") then return end
        local relevant=false
        for _,spec in ipairs(specs) do if tostring(name):lower()==spec[1]:lower() then relevant=true end end
        if not relevant then return end
    end
    S.Schedule()
end)
