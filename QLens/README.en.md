# QLens 2.0.0-alpha.6

Author: Evilion. World of Warcraft: Forever 1.60.1, Interface 16001. Formerly QuestItemQuests.

QLens adds item quest tooltips and an offline Russian/English guide covering 4,244 quests: objectives, starting and finishing locations, related items, chains, coordinates and reference rewards.

## Installation

Exit WoW. Back up the old QuestItemQuests and QuestItemQuests_Guide folders outside Interface/AddOns, then remove those old folders. Extract both QLens and QLens_Guide into Interface/AddOns and enable them. The Guide loads on demand; Questie is not required. Do not enable the old and new addons together.

To retain the selected shortcut, while WoW is closed copy WTF/Account/<account>/SavedVariables/QuestItemQuests.lua to QLens.lua in the same directory. Back up any existing QLens.lua first. The variable inside remains QuestItemQuestsDB. Without migration, the shortcut defaults to Alt-click.

## Controls

- Alt-click a bag item: open an active quest or choose from multiple quests.
- Ctrl-Alt-click: open the guide for that item.
- /qlens: open the guide. The legacy /qiq command also works.
- /qlens quest 1106 or /qlens item 5827: open a quest or related items.
- /qlens key alt|altshift|off: configure shortcuts.
- /qlens status and /qlens debug 5827: diagnostics.

Shift or Ctrl without Alt are not intercepted. Unrecognized bag clicks delegate to the original handler.

## Rewards and limitations

In alpha.6, empty or partial client responses no longer hide reference rewards. The overview and rewards tab both include all reward items and choices. Valid client values take priority.

Classic rewards are explicitly labelled reference data, not verified Forever rewards. Base XP excludes player-level and server-rate adjustments. Generated steps summarize database objectives and sources, not play-tested authored walkthroughs or undocumented mechanics. Coordinates require in-game verification. A quest missing from the log is not necessarily available.

QuestieDB Forever input is pinned to e0a6eaa86f181ac99262e34126bcd2ed1a1712d6; separate corrections are not applied. See THIRD_PARTY_NOTICES.md and the Guide's CLASSIC-DATA-* files for data provenance and redistribution notes. No network downloads occur during gameplay.

This is an alpha build. Automated tests do not replace in-game verification. Sources, generators and release instructions are in Evilion1644/QuestItemQuests on GitHub.
