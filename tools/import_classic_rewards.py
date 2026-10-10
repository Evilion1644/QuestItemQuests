import gzip,re,json,hashlib,math
from pathlib import Path
root=Path(__file__).resolve().parents[1]
src=Path(__import__('sys').argv[1]); s=gzip.open(src,'rt',encoding='utf-8').read()
schema=s[s.index('CREATE TABLE `quest_template`'):]; schema=schema[:schema.index(') ENGINE=')]
cols=re.findall(r'^  `([^`]+)`',schema,re.M)
# SQL tuple scanner: quoted commas, parentheses and MySQL escapes are data.
def tuples(text):
 row=[]; value=[]; quoted=False; escape=False; active=False
 for c in text:
  if quoted:
   if escape: value.append({'n':'\n','r':'\r','t':'\t','0':'\0'}.get(c,c)); escape=False
   elif c=='\\': escape=True
   elif c=="'": quoted=False
   else:value.append(c)
  elif c=="'":quoted=True
  elif c=='(' and not active: active=True;row=[];value=[]
  elif active and c in ',)':
   row.append(''.join(value));value=[]
   if c==')':yield row;active=False
  elif active:value.append(c)
 assert not quoted and not active
out={}
for line in s.splitlines():
 if not line.startswith('INSERT INTO `quest_template` VALUES '):continue
 for row in tuples(line.split(' VALUES ',1)[1]):
  assert len(row)==len(cols),(len(row),len(cols))
  q=dict(zip(cols,row));num=lambda k:int(q[k]); level=num('QuestLevel'); cap=num('RewMoneyMaxLevel')
  divisor=6 if level>=65 else {64:4.8,63:3.6,62:2.4,61:1.2}.get(level,.6)
  xp=math.ceil(round(cap/divisor,6)) if level>0 else 0
  def items(prefix,n):return [{'id':num(prefix+'Id'+str(i)),'count':num(prefix+'Count'+str(i))} for i in range(1,n+1) if num(prefix+'Id'+str(i))]
  out[num('entry')]={'title':q['Title'],'xp':xp,'money':max(0,num('RewOrReqMoney')),'cost':max(0,-num('RewOrReqMoney')),'items':items('RewItem',4),'choices':items('RewChoiceItem',6),'spell':num('RewSpell'),'cast':num('RewSpellCast')}
item_schema=s[s.index('CREATE TABLE `item_template`'):];item_schema=item_schema[:item_schema.index(') ENGINE=')]
item_cols=re.findall(r'^  `([^`]+)`',item_schema,re.M)
item_names={}
for line in s.splitlines():
 if line.startswith('INSERT INTO `item_template` VALUES '):
  for row in tuples(line.split(' VALUES ',1)[1]):
   assert len(row)==len(item_cols)
   item=dict(zip(item_cols,row));item_names[int(item['entry'])]=item['name']
for q in out.values():
 for item in q['items']+q['choices']:item['name']=item_names.get(item['id'],'Item #'+str(item['id']))
assert out[875]['xp']==1150 and out[875]['money']==800
assert out[6]['choices'] and not out[875]['choices']
def lua(v):
 if isinstance(v,str): return json.dumps(v,ensure_ascii=False)
 if isinstance(v,int):return str(v)
 if isinstance(v,list):return '{'+','.join(lua(x) for x in v)+'}'
 return '{'+','.join('['+lua(k)+']='+lua(vv) for k,vv in v.items())+'}'
header='-- Classic reference only; NOT verified Forever rewards.\n-- CMaNGOS classic-db ec4f596146be6467ea93c57397858e329e2db852, GPL-3.0; see CLASSIC-DATA-LICENSE.txt.\n'
(root/'QLens_Guide/ClassicRewards.lua').write_text(header+'QIQ_CLASSIC_REWARDS='+lua(out)+'\n',encoding='utf-8')
(root/'QLens_Guide/CLASSIC-DATA-SOURCE.txt').write_text('Source: https://github.com/cmangos/classic-db/blob/ec4f596146be6467ea93c57397858e329e2db852/Full_DB/ClassicDB_1_12_1_z2815.sql.gz\nSHA256: '+hashlib.sha256(src.read_bytes()).hexdigest()+'\nRegenerate: python tools/import_classic_rewards.py PATH_TO_SQL_GZ\nXP: full base value from RewMoneyMaxLevel and QuestLevel; no player-level or server-rate adjustment. Formula: cmangos/mangos-classic src/game/Quests/QuestDef.cpp Quest::XPValue.\n',encoding='utf-8')
print('Classic reference quests:',len(out))
