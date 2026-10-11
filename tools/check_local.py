from pathlib import Path
from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parents[1]
for folder in ['QLens', 'QLens_Guide']:
    toc = root / folder / (folder + '.toc')
    for line in toc.read_text(encoding='utf-8-sig').splitlines():
        if line and not line.startswith('#'):
            assert (root / folder / line).is_file(), line
lua = LuaRuntime(unpack_returned_tuples=True)
for path in [*root.glob('QLens/*.lua'), *root.glob('QLens_Guide/*.lua')]:
    lua.execute('assert(loadstring(...))', path.read_text(encoding='utf-8-sig'))
print('All TOC entries and Lua 5.1 syntax OK', flush=True)
for suite in ['tests/run.lua', 'tests/guide.lua']:
    runtime = LuaRuntime(unpack_returned_tuples=True)
    runtime.execute('os.setlocale("C")')  # WoW's byte-oriented Lua string routines.
    runtime.execute(f'dofile("{suite}")')
