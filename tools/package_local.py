"""Create deterministic local test packages, not a published release."""
import argparse, hashlib, json, subprocess, zipfile, sys, re
from pathlib import Path

p=argparse.ArgumentParser()
p.add_argument('--lua',required=True)
p.add_argument('--data-source',type=Path,required=True)
p.add_argument('--output',type=Path,required=True)
args=p.parse_args()
root=Path(__file__).resolve().parents[1]
out=args.output.resolve(); out.mkdir(parents=True,exist_ok=True)
pin='21be34023b72cf2ec3027cb9a61a8b72a1910857'
head=(args.data_source/'.git/HEAD').read_text().strip()
if head.startswith('ref: '): head=(args.data_source/'.git'/head[5:]).read_text().strip()
if head!=pin: raise SystemExit('Data source must be the reviewed pinned checkout')
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
inputs=[]
for kind in ['Quest','Npc','Object','Item']:
 inputs.append(f'data/Forever/forever{kind}DB.lua')
for kind in ['Quests','Npcs','Objects','Items']:
 inputs.append(f'l10n/Forever/lookup{kind}/ruRU.lua')
inputs.append('support/Forever/Zones/areaIdToUiMapId.lua')
generated=[root/f for f in ['QLens/Titles.lua','QLens_Guide/Data.lua','QLens/QuestItemQuestsData.lua','QLens/ZoneQuestIndex.lua','QLens/CombatIndex.lua']]
before={x.name:sha(x) for x in generated}
log=[]
subprocess.run([sys.executable,str(root/'tools/refresh_forever.py'),str(args.data_source.resolve())],check=True)
commands=[['tools/verify_build.lua'],['tests/run.lua'],['tests/guide.lua'],['tests/zone.lua'],['tests/combat.lua'],['tests/compatibility.lua']]
for command in commands:
 run=subprocess.run([args.lua,*command],cwd=root,capture_output=True)
 text=run.stdout.decode('utf-8',errors='replace')+run.stderr.decode('utf-8',errors='replace')
 log.append('COMMAND: '+' '.join(command)+'\n'+text)
 if run.returncode:
  (out/'BUILD-LOG.txt').write_text('\n'.join(log),encoding='utf-8')
  raise SystemExit(text)
after={x.name:sha(x) for x in generated}
if before!=after: raise SystemExit('Generated payload changed; review the diff before packaging')
log.append('Deterministic regeneration: OK\n')
runtime=[f for folder in ['QLens','QLens_Guide'] for f in (root/folder).rglob('*') if f.is_file()]
runtime.append(root/'THIRD_PARTY_NOTICES.md')
source=[f for f in root.rglob('*') if f.is_file() and '.git' not in f.relative_to(root).parts and '__pycache__' not in f.parts]
def pack(name,files):
 with zipfile.ZipFile(out/name,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as z:
  for path in sorted(files):
   entry=zipfile.ZipInfo(path.relative_to(root).as_posix(),date_time=(2026,10,10,0,0,0))
   entry.compress_type=zipfile.ZIP_DEFLATED
   z.writestr(entry,path.read_bytes())
version=re.search(r'## Version: (.+)',(root/'QLens/QLens.toc').read_text()).group(1).strip()
pack(f'QLens-{version}-LOCAL.zip',runtime)
pack(f'QLens-{version}-SOURCE.zip',source)
manifest={'version':version,'target':'Forever 1.60.1 / 16001','sourceCommit':pin,'profile':'static-corrections-derived','publication':'not authorized; local review only',
 'inputs':{name:sha(args.data_source/name) for name in inputs},'runtimeFiles':{x.relative_to(root).as_posix():{'sha256':sha(x),'bytes':x.stat().st_size} for x in runtime},
 'archives':{f.name:{'sha256':sha(f),'bytes':f.stat().st_size} for f in out.glob(f'QLens-{version}-*.zip')}}
(out/'BUILD-MANIFEST.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
(out/'BUILD-LOG.txt').write_text('\n'.join(log),encoding='utf-8')
print('All tests passed; deterministic packages created. Runtime Lua/TOC files: '+str(sum(1 for f in runtime if f.suffix in ['.lua','.toc'])))
