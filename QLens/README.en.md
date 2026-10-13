# QLens 2.4.0

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
- /qlens price: configure the vendor price threshold for entire stacks.
- /qlens status and /qlens debug 5827: diagnostics.

Shift or Ctrl without Alt are not intercepted. Unrecognized bag clicks delegate to the original handler.

## Rewards and limitations

In alpha.6, empty or partial client responses no longer hide reference rewards. The overview and rewards tab both include all reward items and choices. Valid client values take priority.

Classic rewards are explicitly labelled reference data, not verified Forever rewards. Base XP excludes player-level and server-rate adjustments. Generated steps summarize database objectives and sources, not play-tested authored walkthroughs or undocumented mechanics. Coordinates require in-game verification. A quest missing from the log is not necessarily available.

QuestieDB Forever input is pinned to e0a6eaa86f181ac99262e34126bcd2ed1a1712d6; separate corrections are not applied. See THIRD_PARTY_NOTICES.md and the Guide's CLASSIC-DATA-* files for data provenance and redistribution notes. No network downloads occur during gameplay.

This is a release build. Automated tests do not replace in-game verification. Sources, generators and release instructions are in Evilion1644/QuestItemQuests on GitHub.

## Professions and recipes

Material tooltips list every consuming profession once. Ctrl+Alt+click opens
the item guide. Persistent Quests (N) and Recipes (N) tabs expose both sections.
Items with quest links open Quests first, preferring an active quest; other
materials open Recipes.
/qlens item 2589 opens Linen Cloth uses; /qlens then Crafting browses all recipes.
Cards show profession, result and reagent quantities per craft. Clear removes
the material filter. Search accepts bilingual recipe names, localized profession
names, spell/material IDs and material names known to the client or quest guide.
Data: 2506 profession/recipe entries, 593 materials, Forever 1.60.1.69977.
Presence does not imply learnability. Borrowed Classic skill requirements are
labelled. Recipes are not restricted to professions known by the character.
Version 2.4.0 includes the profession/recipe data and interface update.

UI update: labelled quest/profession tooltip sections, persistent counted
tabs, Arial Narrow with fallback, bordered controls, higher-contrast selection
and content spacing that adapts to long titles.

## Quest priority in the regular objective tracker

When QLens recognizes a creature needed for an unfinished active quest objective, it moves that quest to the top of the regular tracker. The quest remains there after combat. A newly recognized quest takes first place and shifts earlier priorities down. Completed objectives do not trigger a new promotion. Known quest objects and ground pickups are supported when the client exposes enough interaction data. Detection depends on database links and the live quest log.

## Bag prices and minimap button

The guide's third tab, Bag Prices, lets you set a gold/silver/copper threshold. A red outline marks stacks whose total vendor sell value is strictly below the threshold. It uses the whole stack value, not the price per item; items without a known vendor price are not marked. Zero disables highlighting. Standard bags, bank slots, and compatible bag interfaces including Bagnon are supported. Auction prices are not used.

Left-click the QLens minimap button to open the guide or right-click to open Bag Prices. The separate price window remains available through `/qlens price`.

## Party quests on the world map

Hover a quest marker on the world map to see whether each party member has that quest. Unknown and offline statuses are shown separately. Solo tooltips stay unchanged. Party members do not need QLens: status comes from the game client.

## Settings and zone quest tracking

The Settings tab provides eight feature switches. Automatic zone tracking is enabled by default and uses the client quest destination, ignoring intermediate route waypoints. Reference data supplements multiple objectives and acts as fallback. Unknown locations preserve the current watch state. Manual changes last until the zone changes; disabling restores the original watch list. Changes wait until combat ends. Use /qlenszone for diagnostics.
