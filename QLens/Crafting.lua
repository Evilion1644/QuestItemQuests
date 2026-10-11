local A=QIQ
local strings={
 questSection={"QUESTS","ЗАДАНИЯ"}, professionSection={"CRAFTING PROFESSIONS","ПРОФЕССИИ"},
 questTab={"Quests (%d)","Задания (%d)"}, recipeTab={"Recipes (%d)","Рецепты (%d)"},
 questCard={"QUEST","ЗАДАНИЕ"}, recipeCard={"RECIPE","РЕЦЕПТ"},
 searchLabel={"Search by name or ID…","Поиск по названию или ID…"},
 questList={"Related quests","Связанные задания"}, recipeList={"Recipes using this material","Рецепты с этим материалом"},
 craftFootnote={"Forever reference. Some recipes may not be available to learn.","Справочник Forever. Некоторые рецепты могут быть недоступны для изучения."},
 emptyQuestItem={"No quests found for this item. See the Recipes tab for crafting uses.","Заданий для этого предмета не найдено. Применение в крафте — во вкладке «Рецепты»."},
 craft={"Crafting","Крафт"}, quests={"Quests","Задания"},
 craftUses={"Used in: %s","Используется: %s"},
 craftHint={"Ctrl+Alt+click: recipes and quests","Ctrl+Alt+ЛКМ: рецепты и задания"},
 craftPage={"%d recipes - page %d/%d","Рецептов: %d - страница %d/%d"},
 craftSearch={"Search recipes, professions or materials","Поиск рецептов, профессий или материалов"},
 craftSelect={"Select a recipe","Выберите рецепт"},
 craftAll={"All professions","Все профессии"},
 craftReagents={"Materials per craft","Материалы на одно изготовление"},
 craftResult={"Result: %s","Результат: %s"},
 craftRank={"Required skill: %d%s","Требуемый навык: %d%s"},
 craftBorrowed={" (Classic reference)"," (справочно: Classic)"},
 craftUnknownRank={"Required skill: unknown","Требуемый навык: неизвестен"},
 craftSource={"Forever recipe snapshot (1.60.1.69977). Recipe presence does not guarantee it can be learned. Classic skill requirements are marked separately.","Рецепты из данных Forever 1.60.1.69977. Наличие рецепта не гарантирует возможность изучения. Требования навыка из Classic отмечены отдельно."},
 craftEmpty={"No matching recipes in this snapshot.","В этом снимке нет подходящих рецептов."},
 craftMaterial={"Used as a material: %s","Материал для рецептов: %s"},
 craftAmount={"Required material: %s × %d","Требуется материала: %s × %d"},
}
for key,value in pairs(strings) do A.strings[key]=value end
local professions={
 [164]={"Blacksmithing","Кузнечное дело"}, [165]={"Leatherworking","Кожевничество"},
 [171]={"Alchemy","Алхимия"}, [185]={"Cooking","Кулинария"},
 [186]={"Mining","Горное дело"}, [197]={"Tailoring","Портняжное дело"},
 [202]={"Engineering","Инженерное дело"}, [333]={"Enchanting","Наложение чар"},
 [129]={"First Aid","Первая помощь"}, [356]={"Fishing","Рыбная ловля"},
}
function A.ProfessionName(id)
 local names=professions[id]; return names and names[A.locale=="ruRU" and 2 or 1] or ("#"..tostring(id))
end
function A.CraftProfessions(itemID)
 local ids=QIQ_CRAFT_INDEX and QIQ_CRAFT_INDEX[tonumber(itemID)]
 if not ids then return end
 local names={}; for _,id in ipairs(ids) do names[#names+1]=A.ProfessionName(id) end
 table.sort(names); return table.concat(names,", ")
end
