"""Extract only Forever recipes/reagents and enUS/ruRU names from pinned MIT data."""
from pathlib import Path
import hashlib
import json
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'source/ProfessionDB'
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute('''core={}; names={}; borrowed={}; locale="enUS"
lib={IsGameVersion=function(_,v) return v=="Forever" end,
LoadEnchantsCore=function() end, LoadEnchantsNames=function() end,
LoadCore=function(_,p,t) core[p]=t end,
LoadNames=function(_,p,t) names[locale]=names[locale] or {}; names[locale][p]=t end,
LoadBorrowed=function(_,field,game,ids) if field=="requiredSkill" then for _,id in ipairs(ids) do borrowed[id]=true end end end}
LibStub=function() return lib end; GetLocale=function() return locale end''')
files = []
for path in sorted((SOURCE / 'Data/Forever/_core').glob('*.lua')):
    if 'lib:LoadCore(' in path.read_text(encoding='utf-8-sig'):
        files.append(path)
        lua.execute(path.read_text(encoding='utf-8-sig'))
for locale in ['enUS', 'ruRU']:
    lua.globals().locale = locale
    for path in files:
        lua.execute((SOURCE / 'Data/Forever' / locale / path.name).read_text(encoding='utf-8-sig'))

def quote(s):
    return json.dumps(s, ensure_ascii=False)

records, index = [], {}
for prof, recipes in sorted(lua.globals().core.items()):
    for spell, r in sorted(recipes.items()):
        reagents = sorted((int(k), int(v)) for k, v in (r.reagents.items() if r.reagents else []) if k > 0 and v > 0)
        if not reagents:
            continue  # A skill without consumed items is not a material use.
        names = {}
        for locale in ['enUS', 'ruRU']:
            entry = lua.globals().names[locale][prof][spell]
            names[locale] = entry.name if entry and entry.name else str(spell)
        for item, count in reagents:
            index.setdefault(item, set()).add(int(prof))
        records.append((f'{prof}:{spell}', '{id=%d,p=%d,n={enUS=%s,ruRU=%s},item=%d,rank=%d,borrowed=%s,r={%s}}' % (
            spell, prof, quote(names['enUS']), quote(names['ruRU']), r.craftedItemId or 0,
            r.requiredSkill or 0, 'true' if lua.globals().borrowed[spell] else 'false',
            ','.join('{%d,%d}' % pair for pair in reagents))))
assert len(records) > 2000 and len(index) > 500
assert len({r[0] for r in records}) == len(records), 'Recipe spell belongs to multiple professions'
header = '-- Generated from LibProfessionDB v1.9.1, Forever build 1.60.1.69977. MIT; see CRAFT-DATA-LICENSE.txt.\n'
(ROOT / 'QLens/CraftIndex.lua').write_text(header + 'QIQ_CRAFT_INDEX={\n' + '\n'.join('[%d]={%s},' % (i, ','.join(map(str, sorted(p)))) for i, p in sorted(index.items())) + '\n}\n', encoding='utf-8')
(ROOT / 'QLens_Guide/CraftData.lua').write_text(header + 'QIQ_CRAFT_DATA={\n' + '\n'.join('[%s]=%s,' % (quote(k), v) for k, v in sorted(records)) + '\n}\n', encoding='utf-8')
for folder in ['QLens', 'QLens_Guide']:
    (ROOT / folder / 'CRAFT-DATA-LICENSE.txt').write_bytes((SOURCE / 'LICENSE').read_bytes())
print(f'{len(records)} reagent-using recipes, {len(index)} materials, {len(list(lua.globals().core.items()))} professions')
print('Source ZIP SHA256:', hashlib.sha256((ROOT / 'ProfessionDB-v1.9.1.zip').read_bytes()).hexdigest())
