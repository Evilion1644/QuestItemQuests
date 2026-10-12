from pathlib import Path
import json
from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute((root / 'QLens_Guide/Data.lua').read_text(encoding='utf-8-sig'))
data = lua.globals().QIQ_GUIDE_DATA
index = {}
details = {}
npc_names = {}
item_names = {}
ground_details = {}
ground_names = {}
ground_labels = {}
ground_source_items = {}


def add_objective(creature_id, quest_id, objective_id):
    creature_id, quest_id = int(creature_id), int(quest_id)
    index.setdefault(creature_id, set()).add(quest_id)
    details.setdefault(creature_id, {}).setdefault(quest_id, set()).add(int(objective_id))


def add_names(destination, entity_id, entity):
    names = entity and entity.names
    if names:
        en = names['enUS'] or ''
        ru = names['ruRU'] or ''
        if en or ru:
            destination[int(entity_id)] = (str(en), str(ru))


def add_ground(object_id, quest_id, objective_id):
    object_id, quest_id = int(object_id), int(quest_id)
    ground_details.setdefault(object_id, {}).setdefault(quest_id, set()).add(int(objective_id))
    add_names(ground_names, object_id, data.entities.object[object_id])


for quest_id, quest in data.quests.items():
    objectives = quest.objectives
    if not objectives:
        continue
    # QuestieDB objective groups are npc, object, item. Item objectives are
    # often the real kill signal in Vanilla: the mob drops the required item.
    npcs = objectives[1]
    if npcs:
        for _, ref in npcs.items():
            creature_id = ref[1] if hasattr(ref, 'items') else ref
            if isinstance(creature_id, (int, float)) and creature_id > 0:
                add_objective(creature_id, quest_id, creature_id)
                add_names(npc_names, creature_id, data.entities.npc[creature_id])
    objects = objectives[2]
    if objects:
        for _, ref in objects.items():
            object_id = ref[1] if hasattr(ref, 'items') else ref
            if isinstance(object_id, (int, float)) and object_id > 0:
                add_ground(object_id, quest_id, object_id)
                if hasattr(ref, 'items') and isinstance(ref[2], str):
                    ground_labels[int(object_id), int(quest_id)] = ref[2]
        source_item_id = quest.sourceItem
        if isinstance(source_item_id, (int, float)) and source_item_id > 0:
            ground_source_items.setdefault(int(source_item_id), set()).add(int(quest_id))
            add_names(item_names, source_item_id, data.entities.item[source_item_id])
    items = objectives[3]
    if items:
        entities = data.entities.item
        for _, ref in items.items():
            item_id = ref[1] if hasattr(ref, 'items') else ref
            item = entities[item_id] if isinstance(item_id, (int, float)) else None
            drops = item and item.npcDrops
            if drops:
                add_names(item_names, item_id, item)
                for _, creature_id in drops.items():
                    if isinstance(creature_id, (int, float)) and creature_id > 0:
                        add_objective(creature_id, quest_id, -item_id)
            object_drops = item and item.objectDrops
            if object_drops:
                add_names(item_names, item_id, item)
                for _, object_id in object_drops.items():
                    if isinstance(object_id, (int, float)) and object_id > 0:
                        add_ground(object_id, quest_id, -item_id)
out = ['-- Generated from QIQ_GUIDE_DATA; direct kills and quest-item drops.\nQIQ_COMBAT_OBJECTIVES={']
for creature_id, quests in sorted(index.items()):
    out.append('[%d]={%s},' % (creature_id, ','.join(str(q) for q in sorted(quests))))
out.append('}\nQIQ_COMBAT_OBJECTIVE_DETAILS={')
for creature_id, quests in sorted(details.items()):
    links = ','.join('[%d]=%s' % (quest_id, str(next(iter(refs))) if len(refs) == 1
                      else '{%s}' % ','.join(str(ref) for ref in sorted(refs)))
                     for quest_id, refs in sorted(quests.items()))
    out.append('[%d]={%s},' % (creature_id, links))
out.append('}\nQIQ_COMBAT_NPC_NAMES={')
for entity_id, names in sorted(npc_names.items()):
    out.append('[%d]={%s,%s},' % (entity_id, *(json.dumps(name, ensure_ascii=False) for name in names)))
out.append('}\nQIQ_COMBAT_ITEM_NAMES={')
for entity_id, names in sorted(item_names.items()):
    out.append('[%d]={%s,%s},' % (entity_id, *(json.dumps(name, ensure_ascii=False) for name in names)))
out.append('}\n')
out.append('QIQ_GROUND_OBJECTIVE_DETAILS={')
for object_id, quests in sorted(ground_details.items()):
    links = ','.join('[%d]=%s' % (quest_id, str(next(iter(refs))) if len(refs) == 1
                      else '{%s}' % ','.join(str(ref) for ref in sorted(refs)))
                     for quest_id, refs in sorted(quests.items()))
    out.append('[%d]={%s},' % (object_id, links))
out.append('}\nQIQ_GROUND_OBJECT_NAMES={')
for object_id, names in sorted(ground_names.items()):
    out.append('[%d]={%s,%s},' % (object_id, *(json.dumps(name, ensure_ascii=False) for name in names)))
out.append('}\nQIQ_GROUND_OBJECTIVE_LABELS={')
for object_id in sorted({key[0] for key in ground_labels}):
    labels = ','.join('[%d]=%s' % (quest_id, json.dumps(label, ensure_ascii=False))
                      for (oid, quest_id), label in sorted(ground_labels.items()) if oid == object_id)
    out.append('[%d]={%s},' % (object_id, labels))
out.append('}\nQIQ_GROUND_SOURCE_ITEMS={')
for item_id, quests in sorted(ground_source_items.items()):
    out.append('[%d]={%s},' % (item_id, ','.join(str(q) for q in sorted(quests))))
out.append('}\nQIQ_GROUND_QUEST_OBJECTS={')
quest_objects = {}
for object_id, quests in ground_details.items():
    for quest_id in quests:
        quest_objects.setdefault(quest_id, set()).add(object_id)
for quest_id, objects in sorted(quest_objects.items()):
    out.append('[%d]={%s},' % (quest_id, ','.join(str(o) for o in sorted(objects))))
out.append('}\n')
(root / 'QLens/CombatIndex.lua').write_text('\n'.join(out), encoding='utf-8')
print(f'{len(index)} creatures, {sum(len(v) for v in index.values())} quest links')
