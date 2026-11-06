"""Rebuild all quest indexes from pinned QuestieDB static corrections + derived passes.
Usage: python tools/refresh_forever.py /path/to/QuestieDB
Requires lupa.lua51. No downloads or game changes.
"""
import os, sys, subprocess, runpy
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
PIN='21be34023b72cf2ec3027cb9a61a8b72a1910857'
sys.path.insert(0,str(ROOT.parent/'.tools/python'))
from lupa.lua51 import LuaRuntime

def refresh(source):
 source=Path(source).resolve()
 revision=subprocess.check_output(['git','-c',f'safe.directory={source.as_posix()}','-C',str(source),'rev-parse','HEAD'],text=True).strip()
 if revision!=PIN: raise SystemExit('Expected reviewed QuestieDB commit '+PIN)
 lua=LuaRuntime();lua.execute('os.setlocale("C")')
 previous=Path.cwd()
 try:
  os.chdir(source)
  lua.execute('local c=dofile("src/config.lua"); for _,f in ipairs(c.flavors) do if f.name=="Forever" then QLENS_EXPORT_CORRECTED=dofile("generator/flavor.lua").load(f); break end end; assert(QLENS_EXPORT_CORRECTED)')
  os.chdir(ROOT)
  for name,out in [('generate_qiq_index.lua',ROOT/'QLens/QuestItemQuestsData.lua'),('generate_guide.lua',ROOT)]:
   lua.globals().arg=lua.table_from({1:source.as_posix(),2:out.as_posix(),3:PIN})
   lua.execute((ROOT/'tools'/name).read_text(encoding='utf-8'))
  for name in ['generate_zone_index.py','generate_combat_index.py']: runpy.run_path(str(ROOT/'tools'/name),run_name='__main__')
 finally: os.chdir(previous)
if __name__=='__main__': refresh(sys.argv[1])
