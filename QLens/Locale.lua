QIQ = QIQ or {}
local A = QIQ
A.version = "2.4.0"
A.locale = GetLocale and GetLocale() or "enUS"
local strings = {
 settingsTab={"Settings","Настройки"},
 combatTarget={"QUEST TARGET","ЦЕЛЬ ЗАДАНИЯ"}, combatHint={"Current objective progress","Текущий прогресс цели"},
 classicNote={"Classic reference: base XP, money and item choices; not verified for Forever. Current client values take priority. XP can change with level and server rules.","Справочные награды Classic: базовый опыт, деньги и выбор предметов. Для Forever не подтверждены; данные клиента имеют приоритет. Опыт зависит от уровня и правил сервера."},
 requiredPayment={"Required payment","Нужно заплатить"}, spellReward={"Reward spell","Заклинание награды"},
 generatedSteps={"Steps assembled from database objectives and sources. They do not cover unrecorded scripts or special mechanics. Check the live objective counter.","Шаги составлены по целям и источникам из базы. Особые механики и события могут быть не описаны. Сверяйтесь со счётчиком задания в журнале."},
 takeAt={"Start with: %s.","Получение задания: %s."}, turnInAt={"After completing the objectives, turn in at: %s.","После выполнения целей сдайте задание: %s."},
 startUnknown={"Check the quest log for how to start; the database has no starting point.","Проверьте условия получения в журнале: место начала в базе не указано."},
 finishUnknown={"Complete the quest as instructed in your log; the database has no turn-in point.","Завершите задание по указаниям журнала: место сдачи в базе не указано."},
 providedItem={"Provided item: %s. Check its tooltip for use instructions.","Выдаваемый предмет: %s. Проверьте подсказку предмета: он может понадобиться при выполнении."},
 collectStep={"Obtain the required item: %s. Quantity is specified in the quest objectives.","Добудьте предмет: %s. Требуемое количество указано в целях задания."},
 objectiveStep={"Quest target: %s. Perform the action specified in the objective above.","Цель задания: %s. Выполните действие из текста цели выше."},
 dropStep={"Possible loot source: %s. Defeat and loot if appropriate for the objective.","Источник добычи: %s. Если цель требует добыть предмет с этого противника, победите его и обыщите тело."},
 objectStep={"Item can be found in: %s.","Предмет можно найти в объекте: %s."},
 vendorStep={"Listed seller: %s. Check the merchant's inventory.","Указанный продавец: %s. Проверьте его ассортимент."},
 sourceUnknown={"No item source recorded; follow the quest text.","Источник предмета не указан: следуйте тексту задания."},
 moreSources={"More sources are listed in the objectives section below.","Другие источники перечислены ниже, в разделе целей."},
 inspectItem={"Item: hover for tooltip; click for related quests","Предмет: наведите для подсказки, нажмите для связанных заданий"},
 showOnMap={"Show on game map","Показать на игровой карте"},

 expandPoints={"Show remaining locations (%d)","Показать остальные места (%d)"}, collapsePoints={"Collapse locations","Свернуть список мест"},
 walkthrough={"Walkthrough","Как пройти задание"}, routeMap={"Route: accept, collect, return","Маршрут: взять, собрать, вернуться"},
 mapLegend={"This is a step-by-step itinerary, not a geographic map. Buttons open the game map and attempt to set a waypoint. Coordinates come from the database and may differ in Forever.","Это последовательность действий, а не карта местности. Кнопки открывают игровую карту и ставят метку, если клиент это поддерживает. Координаты из базы могут отличаться в Forever."},
 classicRewards={"Classic reference (not verified for Forever)","Справочно: Classic, не подтверждено для Forever"},
 classic875={"Base experience: 1,150. Money: 8 silver. No item rewards. Orgrimmar: +250 reputation. Your current Forever rewards above take priority; XP depends on level and server rules.","Базовый опыт: 1150. Деньги: 8 серебра. Предметов в награде нет. Оргриммар: +250 репутации. Данные вашего клиента выше имеют приоритет; опыт зависит от уровня и правил сервера."},
 mapUnavailable={"Map artwork unavailable; coordinate diagram shown.","Карта клиента недоступна; показана схема координат."},

 overview={"Overview","Описание"}, chain={"Quest chain","Цепочка"}, rewardTitle={"Rewards","Награды"},
 experience={"Experience","Опыт"}, money={"Money","Деньги"}, notKnown={"Not available yet","Пока неизвестно"},
 guaranteed={"You will receive","Вы получите"}, chooseOne={"Choose one reward","Выберите одну награду"},
 knownItems={"Reward items","Предметы награды"}, unknownCounts={"Quantity and choice are not recorded in the offline database.","Количество и выбор предметов в офлайн-базе не указаны."},
 itemsNotKnown={"Item rewards have not been loaded.","Награды-предметы пока не загружены."},
 noRewardItems={"No item rewards.","Предметов в награде нет."},
 rewardHelp={"Exact rewards are read from your active quest log. Open this card again after accepting the quest. Missing values are not zero.","Точные награды читаются из журнала взятых заданий. После принятия задания откройте карточку снова. Неизвестное значение не означает ноль."},
 faction={"Faction","Фракция"}, browseHint={"Select a quest to view its story, rewards and next steps.","Выберите задание: здесь будут цели, награды и продолжение цепочки."},

 quest={"Quest ","Задание "}, none={"No match","Нет совпадения"},
 heading={"Item quests:","Квесты предмета:"}, inactive={"No active quest","активного задания нет"},
 rewardOnly={"Quest reward; no active quest","Награда за квест; активного задания нет"},
 unknownItem={"Quest item; related quest unknown","Квестовый предмет; связанное задание не определено"},
 openHint={"%s + left click: open","%s + ЛКМ: открыть"}, guideHint={"Ctrl+Alt + left click: guide","Ctrl+Alt + ЛКМ: справочник"},
 disabled={"Shortcuts disabled; /qlens opens the guide","Сочетания отключены; /qlens открывает справочник"},
 openFailed={"Could not open quest: %s","не удалось открыть задание: %s"},
 direct={"Verified item ID link","Проверенная связь по ID предмета"}, static={"Database item ID link","Связь по ID предмета из базы"},
 exact={"Exact objective text fallback","Запасное точное совпадение цели"}, delivery={"Delivery text fallback","Запасная эвристика доставки"},
 help={"/qlens: guide; /qlens price: vendor price highlight; /qlens quest ID; /qlens item ID; /qlens key alt|altshift|off; /qlens status; /qlens debug ID","/qlens: справочник; /qlens price: подсветка по цене торговцу; /qlens quest ID; /qlens item ID; /qlens key alt|altshift|off; /qlens status; /qlens debug ID"},
 priceTitle={"Cheap items","Недорогие предметы"},
 priceNote={"Highlight stacks cheaper than this total vendor price. Zero disables.","Подсветка стопок дешевле общей цены продажи. Ноль отключает."},
 priceGold={"Gold","Золото"}, priceSilver={"Silver","Серебро"}, priceCopper={"Copper","Медь"},
 priceSave={"Save","Сохранить"}, priceOff={"Disable","Отключить"},
 priceSet={"Highlighting stacks cheaper than %d gold %d silver %d copper.","Подсветка стопок дешевле %d зол. %d сер. %d мед."},
 priceDisabled={"Cheap-item highlight disabled.","Подсветка недорогих предметов отключена."},
 priceTab={"Bag prices","Цены в сумках"},
 priceGuideTitle={"Vendor price highlight","Подсветка цены в сумках"},
 priceGuideIntro={"Items are outlined in red when the vendor price of the entire stack is below the threshold. Works in bags and bank slots.","Предметы выделяются красной рамкой, когда цена продажи всей стопки торговцу ниже порога. Работает в сумках и банке."},
 priceGuideLimit={"Price threshold","Порог цены"},
 priceGuideCurrent={"Current threshold: %s","Текущий порог: %s"},
 priceGuideInactive={"Disabled","Отключено"},
 priceGuideExample={"Example: at 1 silver, one item worth 87 copper is highlighted; a stack of 10 is not.","Пример: при пороге 1 серебро предмет за 87 медных выделится, а стопка из 10 — нет."},
 minimapHint={"Left click: guide. Right click: bag prices. Drag: move icon.","ЛКМ: справочник. ПКМ: цены в сумках. Перетащите, чтобы переместить."},
 keySet={"Shortcut: %s. Guide: Ctrl+Alt + left click (unless off).","Сочетание: %s. Справочник: Ctrl+Alt + ЛКМ (кроме off)."},
 statusLine={"%s; active quests: %d; objectives: %d; shortcut: %s","%s; активных заданий: %d; целей: %d; сочетание: %s"},
 invalid={"Enter a positive item/quest ID.","Введите положительный ID предмета/задания."},
 guideMissing={"Guide module could not be loaded: %s","Не удалось загрузить модуль справочника: %s"},
 guideTitle={"QLens — Guide","QLens — Справочник"},
 search={"Search: quest, ID, NPC, item, zone","Поиск: задание, ID, NPC, предмет, зона"},
 back={"Back","Назад"}, forward={"Forward","Вперёд"}, previous={"Previous","Предыдущая"}, next={"Next","Следующая"},
 all={"All","Все"}, active={"Active","Активные"}, completed={"Completed","Завершённые"}, absent={"Not in log","Нет в журнале"},
 ready={"Ready to turn in","Готово к сдаче"}, unknown={"Unknown","Неизвестно"},
 select={"Select a quest on the left.","Выберите задание слева."}, noResults={"No quests found.","Задания не найдены."},
 objective={"Objectives","Цели"}, start={"Start","Начало"}, finish={"Turn in","Сдача"},
 chainAll={"Prerequisites — all","Предшествующие — все"}, chainAny={"Prerequisites — one of","Предшествующие — одно из"},
 follow={"Follow-ups and related chain nodes","Продолжения и связанные узлы цепочки"}, exclusions={"Mutually exclusive","Взаимоисключающие"},
 breadcrumb={"Optional breadcrumb to","Необязательное введение к"}, parent={"Requires active quest","Требуется активное задание"},
 rewards={"Known reward items (selection/count unknown)","Известные предметы награды (выбор/количество неизвестны)"},
 repRewards={"Reputation rewards","Награды репутации"}, requirements={"Requirements","Условия"},
 level={"Level: %s; minimum: %s","Уровень: %s; минимальный: %s"},
 sourceItem={"Provided / required items","Выдаваемые / необходимые предметы"},
 npc={"NPC","NPC"}, object={"Object","Объект"}, item={"Item","Предмет"},
 noData={"Not present in this database.","В этой базе нет данных."},
 english={"English fallback","Английский текст"},
 provenance={"Offline snapshot; not all Forever changes are verified. Full walkthroughs and reward quantities are not included.","Офлайн-снимок; не все изменения Forever проверены. Подробные прохождения и количество наград не включены."},
 coords={"Locations (database coordinates)","Места (координаты из базы)"},
 pointFailed={"Waypoint unavailable. Coordinates remain in the guide.","Точка недоступна. Координаты указаны в справочнике."},
 morePoints={"… %d more locations in the database","… ещё мест в базе: %d"},
 log={"Open active quest","Открыть активное задание"},
 race={"Races: %s","Расы: %s"}, class={"Classes: %s","Классы: %s"},
 unknownAvailability={"Not in log does not mean available.","Отсутствие в журнале не означает доступность."},
 itemFilter={"Item links: %s","Связи предмета: %s"}, clear={"Clear","Сброс"},
 page={"%d quests - page %d/%d","Заданий: %d - страница %d/%d"},
 sources={"Item sources","Источники предмета"}, repeatable={"Repeatable","Повторяемое"},
 questUnavailable={"Unknown quest ID: %s","Неизвестный ID задания: %s"},
 restriction={"Requirements may be incomplete; availability is not inferred.","Условия могут быть неполными; доступность не вычисляется."},
 repMin={"Minimum reputation","Минимальная репутация"}, repMax={"Maximum reputation","Максимальная репутация"},
 skill={"Profession (ID, rank)","Профессия (ID, навык)"}, spell={"Required spell ID","ID необходимого заклинания"},
 coordsArea={"Area %s: %.1f, %.1f","Область %s: %.1f, %.1f"},
 media={"Illustrations","Иллюстрации"}, mediaEmpty={"No media pack installed.","Пакет иллюстраций не установлен."},
}
A.strings = strings
function A.T(key, ...)
 local pair=strings[key]; local value=pair and pair[A.locale=="ruRU" and 2 or 1] or key
 if select("#",...)>0 then return string.format(value,...) end
 return value
end
function A.Settings()
 if type(QuestItemQuestsDB)~="table" then QuestItemQuestsDB={} end
 if QuestItemQuestsDB.key~="alt" and QuestItemQuestsDB.key~="altshift" and QuestItemQuestsDB.key~="off" then QuestItemQuestsDB.key="alt" end
 return QuestItemQuestsDB
end
function A.KeyName() return A.Settings().key=="altshift" and "Alt+Shift" or A.Settings().key=="off" and "off" or "Alt" end
function A.ClickAction()
 if A.Settings().key=="off" or (A.FeatureEnabled and not A.FeatureEnabled("itemShortcuts")) then return end
 local alt=IsAltKeyDown and IsAltKeyDown()
 local shift=IsShiftKeyDown and IsShiftKeyDown()
 local ctrl=IsControlKeyDown and IsControlKeyDown()
 if alt and ctrl and not shift then return "guide" end
 if alt and not ctrl and (not not shift)==(A.Settings().key=="altshift") then return "quest" end
end
function A.LoadGuide()
 if A.Guide then return true end
 local loader=C_AddOns and C_AddOns.LoadAddOn or LoadAddOn
 if loader then
  local ok,result,reason=pcall(loader,"QLens_Guide")
  if ok and result and A.Guide then return true end
  print(A.T("guideMissing",tostring(reason or result)))
 else print(A.T("guideMissing","LoadAddOn")) end
 return false
end
function A.OpenGuide(id,itemID)
 if A.LoadGuide() then
  local ok,result=pcall(A.Guide.Open,A.Guide,id,itemID)
  if ok then return result end
  print(A.T("guideMissing",tostring(result)))
 end
 return false
end
