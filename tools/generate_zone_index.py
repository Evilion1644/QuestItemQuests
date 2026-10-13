import sys,json
from pathlib import Path
root=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(root.parent/'.tools/python'))
from lupa.lua51 import LuaRuntime
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute((root/'QLens_Guide/Data.lua').read_text(encoding='utf-8-sig'))
d=lua.globals().QIQ_GUIDE_DATA
def values(t): return list(t.values()) if t is not None else []
def areas(kind,ident):
    e=d.entities[kind][ident]
    result=set()
    if e is None: return result
    for area in (e.spawns.keys() if e.spawns is not None else []):
        if area > 0: result.add(int(area))
    if kind=='item':
        for field,other in [('npcDrops','npc'),('objectDrops','object'),('vendors','npc')]:
            for source in values(e[field]): result.update(areas(other,source))
    return result
def encode(v):
    if isinstance(v,str): return json.dumps(v,ensure_ascii=False)
    if isinstance(v,bool): return 'true' if v else 'false'
    if isinstance(v,(int,float)): return str(v)
    if isinstance(v,list): return '{'+','.join(encode(x) for x in v)+'}'
    return '{'+','.join('['+encode(k)+']='+encode(x) for k,x in v.items())+'}'
rows=[]
for qid,q in sorted(d.quests.items()):
    finish=set(); objectives=[]
    for i,kind in enumerate(['npc','object','item'],1):
        for ref in values(q.finish[i] if q.finish else None): finish.update(areas(kind,ref))
        for ref in values(q.objectives[i] if q.objectives else None):
            ident=ref if isinstance(ref,(int,float)) else ref[1]
            e=d.entities[kind][ident]
            names=values(e.names) if e is not None else []
            if not isinstance(ref,(int,float)) and isinstance(ref[2],str): names.append(ref[2])
            locations=areas(kind,ident)
            objectives.append({'names':names,'maps':{int(d.maps[a]):True for a in sorted(locations) if d.maps[a]},'areas':{a:True for a in sorted(locations)}})
    rows.append('['+str(qid)+']='+encode({'finish':{int(d.maps[a]):True for a in sorted(finish) if d.maps[a]},'finishAreas':{a:True for a in sorted(finish)},'objectives':objectives}))
by_map={}
for a,m in d.maps.items():
    if m and m>0: by_map.setdefault(int(m),{})[int(a)]=True
(root/'QLens/ZoneQuestIndex.lua').write_text('-- Generated from the bundled guide; retain dungeon area IDs even without UI maps.\nQIQ_ZONE_MAP_AREAS='+encode(by_map)+'\nQIQ_ZONE_QUESTS={\n'+',\n'.join(rows)+'\n}\n',encoding='utf-8')
print('Zone index:',len(rows),'quests')
