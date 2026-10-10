# Data provenance — local development build

QLens author: Evilion. This file does not assign a new license to the user's addon.

The original compact index was already present in the user's 1.4.1 source. The local guide export and bilingual title dictionaries are generated from the user's existing QuestieDB Forever checkout at commit `e0a6eaa86f181ac99262e34126bcd2ed1a1712d6`. Inputs are the raw Forever Quest/Npc/Object/Item tables, ruRU lookups and native area-to-UiMap mapping. The export does not apply separate provider corrections. It is not represented as QuestieDB's effective/composed output.

Upstream projects and contributors:

- Questie/QuestieDB: https://github.com/Questie/QuestieDB
- Questie team and contributors: https://github.com/Questie/Questie
- QuestieDB provenance: https://github.com/Questie/QuestieDB/blob/e0a6eaa86f181ac99262e34126bcd2ed1a1712d6/PROVENANCE.md
- Questie's publisher provides GPL v3 terms: https://www.curseforge.com/wow/addons/questie/license

The standalone QuestieDB checkout examined during research does not contain an explicit root LICENSE. The lineage includes Questie and other upstream data sources; it must not be advertised as MIT. The exact redistribution conditions for these generated data files have not been established by this development task. Keep this artifact local for review/testing; do not publish it to GitHub/CurseForge or redistribute it until that check is completed. No code/data from All Rights Reserved tooltip addons has been incorporated.

Runtime code for the new guide is newly written in this task. Reading other addons to compare architecture did not entail copying their runtime implementation. No web guides, third-party screenshots, images or authored walkthroughs are included.

## Classic reward reference added in alpha.5

ClassicRewards.lua is derived from CMaNGOS classic-db ec4f596146be6467ea93c57397858e329e2db852 (ClassicDB_1_12_1_z2815.sql.gz), GPL-3.0. See QLens_Guide/CLASSIC-DATA-LICENSE.txt and CLASSIC-DATA-SOURCE.txt. The transformation is tools/import_classic_rewards.py. Only numeric reward facts and quest/item names are exported; original story/dialogue text is not copied. Base XP is calculated from the database using the documented CMaNGOS XP conversion; it is not current-player XP or confirmed Forever XP.

Generated walkthrough steps summarize the existing objectives, entities and item sources. They are not authored, play-tested guides and do not invent absent mechanics. Classic reference identity is checked by ID and English title, ignoring boundary whitespace and case.
