local files={
 "QLens/Locale.lua","QLens/QuestItemQuests.lua","QLens/QuestItemQuestsData.lua","QLens/Titles.lua",
 "QLens_Guide/ClassicRewards.lua","QLens_Guide/Data.lua","QLens_Guide/Model.lua","QLens_Guide/View.lua","tools/generate_guide.lua","tools/generate_qiq_index.lua",
}
for _,path in ipairs(files) do assert(loadfile(path),path) end
print("Lua 5.1 syntax: OK ("..#files.." files)")
dofile("tests/validate_data.lua")
