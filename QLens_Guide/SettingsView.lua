local A, G = QIQ, QIQ.Guide
local ru = A.locale == "ruRU"
local options = {
 {"questSparkles", "Искрение квестовых предметов", "Quest item sparkles",
  "Искры вместо контуров. При отключении вернём прежние настройки; для исчезновения искр может понадобиться перезапуск игры.",
  "Sparkles replace outlines. Disabling restores previous settings; removing the effect may require a game restart."},
 {"zoneTracking", "Задания рядом со мной", "Quests in my current zone",
  "Ставит галочки по месту целей и сдачи. При отключении возвращает прежний список.",
  "Tracks quests by objective and turn-in location. Disabling restores your previous watch list."},
 {"combatPriority", "Нужное задание — наверх списка", "Relevant quest at the top",
  "Поднимает задание при бое с нужной целью или взаимодействии с квестовым объектом.",
  "Moves a quest up when fighting its target or interacting with its quest object."},
 {"partyQuests", "Задания у сопартийцев", "Party quest status",
  "В подсказке значка на большой карте показывает, у кого в группе есть это задание.",
  "Shows who in your group has the quest when you hover its world-map marker."},
 {"itemTooltips", "Задания в подсказках предметов", "Item quest tooltips",
  "Показывает, для каких заданий нужен предмет и какие из них уже взяты.",
  "Shows quests related to an item and which ones are already in your log."},
 {"craftHints", "Профессии в подсказках материалов", "Material profession hints",
  "Показывает профессии, для которых нужен материал. Справочник рецептов доступен всегда.",
  "Shows professions that use a material. The recipe guide remains available."},
 {"itemShortcuts", "Открывать задания и справочник по клику", "Item click shortcuts",
  "Alt + клик — задание; Ctrl + Alt + клик — справочник. Выбранное сочетание сохраняется.",
  "Alt-click opens a quest; Ctrl-Alt-click opens the guide. Your chosen shortcut is preserved."},
 {"vendorHighlight", "Подсветка дешёвых предметов", "Highlight low-value items",
  "Выделяет стопки дешевле заданной цены продажи торговцу. Порог — на вкладке «Цены».",
  "Highlights stacks below your vendor sell-price threshold. Set the threshold on Bag Prices."},
 {"minimapButton", "Значок QLens у миникарты", "QLens minimap button",
  "Открывает справочник. Если значок скрыт, используйте команду /qlens.",
  "Opens the guide. You can always use /qlens if the icon is hidden."},
}
local function text(parent, value, size, x, y, width)
    local f = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f:SetFont("Fonts\\ARIALN.TTF", size, "")
    f:SetJustifyH("LEFT"); f:SetPoint("TOPLEFT", x, y); f:SetWidth(width)
    f:SetWordWrap(true); f:SetText(value)
    return f
end
function G:CreateSettingsPane(parent)
    local pane = CreateFrame("Frame", nil, parent)
    pane:SetSize(992, 620); pane:SetPoint("TOPLEFT", 20, -113)
    pane:SetFrameLevel(parent:GetFrameLevel()+20); pane:EnableMouse(true)
    local bg = pane:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(.045,.062,.066,1)
    text(pane, ru and "Настройки QLens" or "QLens settings", 25, 24, -18, 930):SetTextColor(1,.83,.54)
    text(pane, ru and "Изменения сохраняются сразу. В бою список заданий обновится после его окончания."
        or "Changes are saved immediately. During combat, quest tracking changes wait until combat ends.", 15, 24, -54, 938)
    self.featureChecks = {}
    local scroll=CreateFrame("ScrollFrame",nil,pane,"UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT",0,-88); scroll:SetPoint("BOTTOMRIGHT",-28,66)
    local content=CreateFrame("Frame",nil,scroll); content:SetSize(950,#options*72)
    scroll:SetScrollChild(content)
    for i, option in ipairs(options) do
        local key = option[1]
        local y = -(i-1)*72
        local check = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
        check:SetSize(30,30); check:SetPoint("TOPLEFT",22,y)
        text(content, option[ru and 2 or 3], 18, 61, y-3, 875):SetTextColor(1,.88,.62)
        text(content, option[ru and 4 or 5], 14, 61, y-27, 875):SetTextColor(.75,.81,.82)
        check:SetScript("OnClick", function(s) A.SetFeature(key, s:GetChecked()); self:RefreshSettingsPane() end)
        self.featureChecks[key] = check
    end
    text(pane, ru and "Ручная галочка действует до смены локации. Если место задания неизвестно, его галочка не меняется."
        or "Manual tracking choices last until you change zones. Unknown quest locations keep their current watch state.",
        14, 24, -570, 938):SetTextColor(.64,.75,.78)
    self.settingsPane = pane; pane:Hide()
end
function G:RefreshSettingsPane()
    for key, check in pairs(self.featureChecks or {}) do check:SetChecked(A.FeatureEnabled(key)) end
end
