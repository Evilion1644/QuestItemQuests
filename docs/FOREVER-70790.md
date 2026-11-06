# Forever release compatibility — 2026-11-06

Base: GitHub origin/main 36e4023 (v2.5.0), fetched before edits.
Target installed client: 1.60.1.70790, product wowf, _forever_.
UI reference: Gethe/wow-ui-source forever eac30af, exact build 70790.

## Findings and repairs
- CombatLogDocumentation marks COMBAT_LOG_EVENT_UNFILTERED restricted. UnitDocumentation marks identity/name values potentially secret. Registration/read failures and secret GUID/name inputs previously interrupted priority processing. Now skip inaccessible inputs and retain objective-progress fallback. Tracker hooks/explicit refresh wait until out of combat.
- ContainerFrame.lua uses modern ItemButton/GetBagID and SetItemButtonQuality. Price highlighting previously scanned all UIParent descendants without forbidden-frame checks and only recognized Button. Limit scanning to bag/bank windows, recognize ItemButton, skip forbidden frames, and install BagBrother hooks when loaded later.
- Party tooltip hook assumed legacy OnTooltipCleared exists. Check script support and forbidden state. Skip secret party names. Item tooltips also skip forbidden/secret input and prefer C_Item.GetItemInfo.
- Remove sparkle module, feature flag and checkbox. LegacySettings is one-time migration of backed-up CVars; it preserves player changes, does not enforce any graphics policy and retries incomplete restore on login/out of combat.

## Audited unchanged contracts
QuestObjectiveTracker.BuildQuestWatchInfos / EnumQuestWatchData retain their signatures. GetQuestUiMapID(id, true) remains the native destination query in QuestMapFrame. C_QuestLog.IsUnitOnQuest(unit,id), objectives and watch APIs remain available. Guide, crafting, shortcuts, minimap and locale code reviewed; existing tests cover guide/search/navigation/rewards, crafting, click delegation, tooltips, zone filtering, settings and priority.

## Validation and limits
All addon Lua files compile in Lua 5.1; both TOC file lists resolve. Existing core/guide/zone/combat tests and 10 release safeguards pass. New tests/compatibility.lua covers restricted combat APIs/identity, modern item buttons, forbidden frames, empty slots, late bag addon loading, party tooltip script absence, and settings migration. CI includes it.
No live character session was controlled; no exact user error/stack trace was available. These are reproducible compatibility defects, not proof they explain every reported symptom. Other installed bag addons (Bagnon and Baganator) were not disabled or modified. Offline quest/crafting reference data is not a complete release database; new quests must rely on native data. No GitHub/CurseForge release authorized in this request; changes remain local for validation.

## Follow-up: 2.6.1
User reproduced blocked-action dialog and empty item guide on 2.6.0. Do not treat 2.6.0 as game-verified. Restricted event registration must be omitted on secret-value clients entirely, not wrapped in pcall. Diagnostic /qlenserrors captures the exact blocked action if other restrictions remain.
User /qlenszone evidence: map 1454; quest 914 watched=true, destination=nil, relevant=nil, manual=nil. Incomplete reference location on one gem caused the old preserve-unknown behavior. Zone tracking now includes only confirmed relevant quests automatically, with manual opt-in until zone change and restoration when disabled.
Guide now shares live item resolution and overlays missing active quest IDs with current quest text/objectives. Includes collapsed journal enumeration and regression tests for unknown item/quest IDs. No invented offline coordinates/rewards for new quests.

## Follow-up: 2.6.2 full data refresh and rewards
Modern QuestMapFrame selects quests through C_QuestLog.SetSelectedQuest; legacy selection globals may still exist but identify a different/stub context. Prefer modern selection/identity, restore previous selection, refresh on asynchronous quest/item data events and keep successful fields on partial item loads. Regression tests cover both contexts.
Full corrected Forever export uses QuestieDB 21be340 (5233 quests, 5887 indexed items, 8791 relations), not the old raw 4244-quest seed. All five derived payloads regenerated twice with identical hashes. Source corrections include new release quest/item IDs; seven dangling source relations excluded. Full Lua, guide/zone/combat/compatibility and release tests passed; no live validation yet.
