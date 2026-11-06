local A=QIQ
local f=CreateFrame("Frame")
f:RegisterEvent("ADDON_ACTION_BLOCKED")
f:RegisterEvent("ADDON_ACTION_FORBIDDEN")
f:SetScript("OnEvent",function(_,event,addon,action)
    if addon~="QLens" and addon~="QLens_Guide" then return end
    local db=A.Settings(); db.lastBlockedAction={event=event,action=tostring(action),version=A.version}
    print("QLens: "..event.." — "..tostring(action))
end)
SLASH_QLENSERRORS1="/qlenserrors"
SlashCmdList=SlashCmdList or {}
SlashCmdList.QLENSERRORS=function()
    local row=A.Settings().lastBlockedAction
    print(row and ("QLens "..row.version..": "..row.event.." — "..row.action) or "QLens: no blocked action recorded")
end
