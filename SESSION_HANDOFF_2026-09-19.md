# Midnight Rotation Arms Lab handoff — 2026-09-19

## Current state

- Addon: `Midnightrotationarmslab` in the retail WoW `Interface/AddOns` folder.
- Current TOC version: `0.5.0-all-dps-specs` (2026-10-29; see the 0.5.0 section at the end).
- The user runs EllesmereUI Action Bars and tests Arms Slayer and Fury Slayer in Midnight, including Silvermoon dummies and Mythic+.
- Ellesmere's Execute button glow is now detected; the remaining work is rotation tuning.
- `/midrotlab st` and `/midrotlab aoe` select modes manually. A trace's mode records that setting, so a mode mismatch does not prove the target count was wrong.

## Changes made in this session

- `0.1.148`: indexed Ellesmere action slots and used the same spell activation overlay API that Ellesmere uses for proc glows.
- `0.1.149`: made Arms' pre-Bladestorm Execute require a confirmed proc, Executioner stacks, or execute range.
- `0.1.150`: routed Arms Slayer AoE pulls through its regular AoE priority, so Sweeping Strikes and early Cleave come before Avatar, Colossus Smash, and Bladestorm.
- `0.1.151`: adjusted Fury Slayer's Recklessness priorities: preserve an active Hack and Slash strike in ST, and spend Rampage earlier in AoE while still progressing to Bladestorm.
- `0.1.153`: raised the trace limit from 2,000 to 6,000 entries, report dropped entries, and added Sudden Death source fields and combat state to recommendation traces.
- `0.1.154`: when target health is hidden, a confirmed Sudden Death proc keeps Arms Slayer on the normal ST priority rather than treating Execute usability alone as execute phase. This lets Cleave retain its Rend refresh priority. Trace `ready.cleave` now reports actual readiness; `hasCleave` separately reports the talent.
- `0.1.155`: stopped treating Ellesmere's latched Execute button glow as reliable Sudden Death confirmation; aura, overlay, and action-count signals remain trusted. In Arms Slayer ST, the ordinary 5-second Cleave/Rend maintenance slot now precedes a one-stack Sudden Death spend, while a capped proc remains urgent.
- `0.1.156`: enabled automatic target-mode selection using hostile nameplates in melee range: 1 target is ST, 2-3 are Cleave, and 4+ are AoE. Promotions stabilize for 0.25 seconds and demotions for 1.0 second to prevent flicker. Auto is enabled by the settings-version migration. Manual `/midrotlab st`, `/midrotlab cleave`, `/midrotlab aoe`, and numeric `targets` overrides remain available; `/midrotlab auto` restores automatic selection. Trace entries now include `targetSource` and `targetOverride`.
- `0.1.157`: added the missing Odyn's Fury slots to Fury Mountain Thane's cooldown-window and normal AoE priorities.
- `0.1.158`: added Whirlwind as the final Fury Mountain Thane ST filler, including during cooldown windows, after a 101-second trace recorded ten in-combat `none` recommendations where Whirlwind was the only usable tracked action.
- `0.1.159`: fixed the new Mountain Thane ST Whirlwind fallback to use the resolved `state.spell.whirlwind` ID. Version `0.1.158` referenced an undefined `WHIRLWIND_SPELL_ID`, so its fallback could never fire.
- `0.1.160`: added one opening Mortal Strike before the ST Cleave/Rend setup, matching the current Arms opener and front-loading the hit into pull buffs. A per-combat cast flag prevents the eight-second opener helper from forcing repeated Mortal Strikes.
- `0.1.161`: moved Fury Slayer AoE Whirlwind cleave refresh below the post-Bladestorm Sudden Death and Odyn's Fury slots. The previous global refresh check could repeatedly pre-empt the entire priority and starve Odyn's Fury even while it was ready.
- `0.1.162`: restored Slayer's initial AoE Whirlwind setup before Recklessness while retaining the `0.1.161` in-window starvation protection; added Mountain Thane's opening Odyn's Fury before Recklessness/Avatar; and moved ordinary Mountain Thane ST Raging/Crushing Blow below Thunder Blast and Bloodthirst while preserving the elevated Hack and Slash strike.
- `0.1.163`: moved Arms Colossus AoE Sudden Death Execute below Cleave, Colossal Might-building Mortal Strike, Demolish, Overpower, and the normal Mortal Strike slot to match the current Midnight priority and avoid delaying the Colossus/Demolish cycle.
- `0.1.164`: increased the main rotation evaluation rate from 10 Hz to 20 Hz (`0.10` to `0.05` seconds) for faster recommendation changes. The separate action-bar scan remains at 1 Hz.
- `0.1.165`: aligned Arms Slayer ST with the supplied analyzer order. Execute range now checks Heroic Strike, 2-stack Executioner's Precision Mortal Strike, 2-stack Opportunist Overpower, Sudden Death Execute, 40+ rage Execute, then Overpower. Normal ST now puts 2-stack Opportunist Overpower before Mortal Strike. Cooldowns and Bladestorm sit below the core execute-range checks, and ordinary Mortal Strike precedes ordinary Execute. Arms AoE and Colossus were not changed.
- `0.1.166`: added a rotation-wide spell recommendation latch. A displayed spell remains until the matching player `UNIT_SPELLCAST_SUCCEEDED` event, then the rotation recalculates immediately; unrelated casts do not advance it. Major state transitions clear the latch, while item/potion recommendations remain dynamic. Arms maintenance helpers no longer return Rend directly and use Cleave exclusively for requested Rend application/refresh.
- `0.1.167`: removed the `0.1.166` hold-until-cast latch at user request and restored live 20 Hz recommendation changes. Cleave-only Rend maintenance and the `0.1.165` Arms Slayer ST ordering remain active.
- `0.1.168`: raised Arms Slayer normal-ST Heroic Strike, 2-stack Opportunist Overpower, Mortal Strike, and directly usable Execute above maintenance/cooldown pre-emption. Opportunist overlay now backs up unreadable stack counts, and Arms Execute-at-rage trusts strict usability when Midnight hides rage. Cleave remains the only Rend replacement.
- `0.1.169`: added reliable Executioner's Precision detection using aura ID, aura name, and successful Arms Execute/Mortal Strike cast tracking. The inferred count caps at two, expires after 30 seconds, clears on Mortal Strike, and is saved as `ep` in recommendation traces.
- `0.1.170`: fixed severe Arms Slayer ST Bladestorm holding found in a five-minute trace. Both Slayer ST paths now release ready Bladestorm when Colossus Smash is active, Avatar is active, Colossus Smash is more than 25 seconds away, or Executioner's Precision is capped while its higher-priority Mortal Strike is unavailable. The trace had 282 ready samples but only three recommendations and four channel clusters; SimC averaged about 9.7 uses.
- `0.1.171`: added Storm Bolt resolution and Bladestorm aura-presence tracking. Arms Slayer now recommends Storm Bolt first and Wrecking Throw second during Bladestorm, before all mode-specific priorities. Wrecking Throw is also a late fallback before Slam in both Slayer ST branches.
- `0.1.172`: moved Arms Slayer's Bladestorm utility check ahead of opener logic and added a six-second successful-cast fallback for active Bladestorm detection. Storm Bolt now reliably wins during Bladestorm when usable, with Wrecking Throw remaining the fallback.
- `0.1.173`: slowed the main recommendation refresh from 0.05 seconds (20 Hz) to 0.50 seconds (2 Hz), giving each recommendation more visual stability. The action-bar scan remains at one-second intervals.
- `0.1.174`: fixed an ST opener trace where Cleave was briefly unavailable during the opening GCD, allowing Avatar/Colossus Smash to advance and permanently blocking opener Cleave behind the old Colossus-ready requirement. Cleave setup now remains eligible for the full eight-second opener whenever Rend is missing or within the ten-second setup threshold.
- `0.1.175`: changed the recommendation ticker from 0.50 to 0.25 seconds after comparison with current Vashnik performance data. Routine Arms Slayer normal-ST Cleave maintenance now waits until Rend has two seconds or less remaining instead of five; opener and pre-Colossus Cleave setup rules are unchanged.
- `0.1.176`: moved ready Mortal Strike above Opportunist Overpower in both normal and execute-range Arms Slayer ST priorities. Heroic Strike and the special two-stack Executioner's Precision Mortal Strike check remain protected. This test intentionally targets more Mortal Strike and fewer Overpower casts to better resemble the top Vashnik damage profile.
- `0.1.177`: after a Mythic Vashnik log showed 47 Cleaves in roughly 406 seconds with 99.33% Rend uptime, tightened the normal-ST pre-Colossus Cleave setup from ten seconds remaining to five. Routine maintenance remains at two seconds and opener Cleave remains immediate when Rend is missing, freeing more globals for Mortal Strike.
- `0.1.178`: reconstructed the top Mythic Vashnik source 418 opener from a saved Warcraft Logs timeline. Slayer ST now opens Cleave, Colossus Smash, Avatar, conditional Execute, then Bladestorm; the previously forced opening Mortal Strike was removed. Storm Bolt during Bladestorm and the existing item/burst recommendation system remain unchanged.
- `0.1.179`: fixed Executioner's Precision tracking and opener priority. Midnight emits paired successful-cast events (`260798` and `281000`) for one Execute; these are now deduplicated so one Execute adds one inferred stack. At a genuine two stacks, ready Mortal Strike now wins before opener Bladestorm instead of being hidden behind the opener helper.
- `0.2.0`: added the first Frost Death Knight Deathbringer profile. It resolves the active Frost buttons from the spellbook/action bars, tracks runic power, ready runes, Killing Machine, Rime, Exterminate, Pillar of Frost, Breath of Sindragosa, and Empower Rune Weapon charges, and supplies distinct 1-2 target and 3+ target priorities. At 3+ targets it substitutes Frostscythe and Glacial Advance for Obliterate and Frost Strike. Major Frost cooldowns respect the existing cooldown recommendation toggle.
- `0.2.1`: expanded Frost's class/spec cooldown window without adding potions, racials, or trinkets. Raise Dead is recommended inside Pillar, active Remorseless Winter is placed between Reaper's Mark and Pillar when available, and Frostwyrm's Fury cast tracking prevents the callback from being fired immediately; Deathbringer instead holds the recall until roughly the final three seconds of Pillar.
- `0.2.2`: made Slayer ST Rend upkeep urgent through Cleave at two seconds remaining in both normal and execute-range priorities. The execute branch previously had no Rend maintenance slot, while the normal branch allowed ordinary core GCDs to run ahead of its late maintenance check. Standalone Rend is still never recommended; a ready two-stack Executioner's Precision Mortal Strike remains protected above the execute-range Cleave refresh.
- `0.2.3`: added a 12-second successful-cast fallback for Fury Recklessness. A 2026-10-24 Slayer trace recorded `reck=false` in every recommendation despite five successful Recklessness casts, while rage was also hidden throughout. The missing window state kept the rotation in its normal priority and explains analyzer complaints about skipped 100+ rage Rampages during Recklessness. The inferred window now routes recommendations through the existing cooldown priority and its elevated Rampage checks.
- `0.3.0`: added initial Subtlety Rogue support for both Deathstalker and Trickster, with ST and 2+ target AoE paths. The profile tracks Energy, combo points, Stealth, Shadow Dance, Shadow Blades, Coup de Grace, Darkest Night, and Shadow Dance charges; resolves replacement buttons from action bars/spellbook; uses Shadowstrike/Eviscerate in ST and Shuriken Storm/Black Powder in AoE; consumes hero-tree empowered finishers with Eviscerate; and aligns Goremaw's Bite, Shadow Dance, Shadow Blades, and Secret Technique behind the existing major-cooldown toggle. Deathstalker enters Dance at low combo points before building into Secret Technique, while Trickster enters at high combo points.
- `0.3.1`: added Gloomblade resolution for Subtlety talent builds where it replaces Backstab. The active Gloomblade action is now preferred as the out-of-Dance single-target builder, with Backstab retained only as a fallback for builds that still know it; range detection and trace readiness cover both buttons.
- `0.3.2`: added immediate action-bar and keybind rescans for `UPDATE_STEALTH`, `ACTIONBAR_PAGE_CHANGED`, and `UPDATE_BONUS_ACTIONBAR`. Each page transition refreshes immediately and again after 0.05 seconds so the completed stealth-page swap is captured; this prevents Shadowstrike from inheriting a stale Gloomblade/normal-bar key label while entering or leaving Stealth, Vanish, or other paged states.
- `0.3.3`: added successful-cast fallback tracking for Subtlety Shadow Dance (six seconds) and Shadow Blades (20 seconds). The first Trickster trace recorded 73 Dance recommendations and many successful Dance events but almost always saved `dance=false`; Secret Technique was consequently never reached and Shadow Blades was recommended only twice. The inferred windows now let the priority advance from Dance to Shadow Blades, Secret Technique, and the correct Dance builders/finishers when Midnight hides the player auras.
- `0.3.4`: prevented the normal Gloomblade/Backstab fallback from running while Stealth or the inferred Shadow Dance window is active. The first successful `0.3.3` trace reached Shadow Blades and Secret Technique correctly, but brief Shadowstrike availability gaps could fall through to Gloomblade during Dance. Those moments now remain empty until Shadowstrike or a finisher becomes usable, avoiding wasted Dance globals and stealth-page keybind confusion.
- `0.3.5`: made keybind display prefer an exact spell match on the currently visible action-bar page before consulting cached spell/base-spell/name mappings. A working Trickster trace contained Shadowstrike recommendations and no Shadowstep recommendations, proving the reported Shadowstep behavior was a stale/wrong paged key label rather than rotation logic. This active-page lookup prevents a Shadowstrike recommendation from displaying the binding of a different normal or stealth-page action.
- `0.3.7`: removed the Gloomblade keybind fallback because it could label Shadowstrike with a key that does not actually activate it. Added live Ellesmere `EABButton` resolution: match the visible button's current secure action slot to Shadowstrike, then read that button's binding command. Rogue's native bonusbar binding remains authoritative for stealth.
- `0.3.8`: corrected placement of the Ellesmere lookup. It belongs in `FindVisibleActionButtonKeybindForSpell`; placing it in `GetActionSpellIDByName` referenced out-of-scope lookup variables and caused a Lua error during recommendations.
- `0.3.9`: made the Fury pull opener advance through Charge, Bloodthirst, Recklessness, Avatar, Rampage, then Bladestorm when talented and available; Mountain Thane now uses the same opener gate. If Rage is hidden, a ready Rampage can use a conservative fallback after two observed Fury rage-generating attacks since the last Rampage, and only while Recklessness is active. The trace now records `rampageGenerators` so this fallback can be audited in the next Fury run. Validate Slayer ST first, then Slayer AoE and Mountain Thane separately.
- `0.4.0`: relaxed Fury-only target detection. A visible hostile nameplate now counts when every reference-spell range result is unknown, while any definite out-of-range result still excludes it. The existing 0.25-second target-band promotion delay and other specs' stricter range handling are unchanged.
- The user's source 5 Mythic Vashnik timeline opened Avatar/trinket, Colossus Smash, Cleave, Execute, Mortal Strike, Overpower, Cleave, Overpower, Heroic Strike, Execute, Overpower, Mortal Strike, then Bladestorm. The comparison source 418 used Cleave, Colossus Smash, Avatar/trinket, Execute, then Bladestorm, confirming that `0.1.178` should eliminate the long first-Bladestorm delay.

## What the Arms Slayer Mythic+ traces showed

- The first saved trace ran from 2026-09-18 19:48 to 20:30. Its old 2,000-entry limit retained only about 20:10 to 20:29. A long Sweeping Strikes recommendation streak was mostly AoE mode left selected with one visible hostile target and no casts. In a genuine pack, the opener recorded Sweeping Strikes, Cleave, Avatar, Colossus Smash, then Bladestorm.
- The next Arms trace ran from 20:38 to 21:01; the old cap retained only 20:48 onward. In ST with one visible target, Rend was at 2.9 seconds and Cleave was recommended at 20:50:55. When Execute became usable, the recommendation immediately changed to Execute; Rend expired and remained at zero through repeated Executes. The trace could not show whether this was a Sudden Death proc or the enemy entering execute range because target health was hidden. Version `0.1.154` addresses the confirmed-proc case.
- Those older Arms traces recorded `sdUp=true` and one Sudden Death stack on every recommendation, including pauses. The source of that signal could not be identified from those traces. Version `0.1.153` added `sdAura`, `sdOverlay`, `sdCount`, `sdCountOn`, and `sdGlow` to future traces. Do not assume the old `sdUp` value proves a real proc.
- A 95-second Arms Slayer ST validation trace was recorded from 2026-09-19 10:19:04 to 10:20:39. The first 18 recommendations were pre-combat/AoE-mode setup; the remaining 110 were ST.
- The trace proved `sdGlow=true` was stale through most of combat: `sdAura=false`, `sdCount=0`, and `sdCountOn=false` throughout, while `sdOverlay` toggled only during apparent real proc windows.
- Version `0.1.154` did remain in the normal ST list despite the stale glow, and Cleave refreshed two earlier Rend cycles. However, the stale glow still made `ShouldSpendArmsSuddenDeath` accept Execute whenever it became usable. Near 10:20:27 a genuine overlay proc also produced repeated Execute recommendations as Rend fell from 2.1 seconds to zero; Cleave did not appear until 10:20:37. Version `0.1.155` addresses both findings.
- Version `0.1.155` was validated with a 102-second Arms Slayer ST trace from 2026-09-19 10:26:00 to 10:27:42. All 138 recommendations were ST. The stale `sdGlow=true` signal remained present, but ordinary Rend maintenance consistently changed to Cleave around 5 seconds. Genuine `sdOverlay=true` windows that overlapped maintenance also changed from Execute to Cleave at 5.0 seconds, including at 10:26:38, 10:27:07, and 10:27:38. At the end, Cleave remained recommended while both Execute and Cleave were ready and the overlay was active. This validates the priority fix.
- A 1,488-second Fury Mountain Thane trace from 2026-09-19 11:38:03 to 12:02:51 validated auto switching in live play: 792 ST, 289 Cleave, and 1,016 AoE recommendations. It also exposed the AoE Odyn's Fury omission. Odyn's Fury was ready during 252 AoE recommendations but was never selected there, while it was selected normally in ST. The Mountain Thane AoE function had no Odyn's Fury branch; `0.1.157` corrects that omission.
- A 74-second Fury Slayer trace from 2026-09-19 18:01:20 to 18:02:34 contained 107 recommendations, all ST with one detected target. Recommendations included Rampage 29, Raging Blow 29, Execute 15, Crushing Blow 11, Bloodthirst 7, Whirlwind 6, and Odyn's Fury 4. Odyn's Fury was ready on six samples and selected on four; Rampage correctly displaced it on the other two. Bladestorm was never recorded ready. This trace cannot validate Fury Slayer Cleave/AoE or Bladestorm sequencing.
- A follow-up 44-second Fury Slayer ST trace from 2026-09-19 18:05:21 to 18:06:05 ran with major cooldown recommendations enabled. It validated the opener sequence `Recklessness -> Rampage -> Bladestorm` and recorded a second Bladestorm recommendation later when the ability became ready again. No code change was needed.
- A 73-second Retribution Herald of the Sun Execution Sentence AoE trace from 2026-09-22 19:19:40 to 19:20:52 contained 97 recommendations: 81 AoE and 16 post-pack ST. Auto detection held five targets in AoE, briefly saw six on the next group, then returned to ST after the pack collapsed. The opener was Execution Sentence, Blade of Justice, Wake of Ashes, Divine Toll, then Divine Storm at five Holy Power. The AoE loop produced 27 Divine Storm, 23 Blade of Justice, 7 Wake of Ashes, 7 Judgment, 6 Hammer of Wrath, 6 Templar Slash, 4 Templar Strike, and 3 Divine Toll recommendations. Holy Power spending showed no evident overcap or starvation. No clear priority defect was found in this short trace.
- A 59-second Retribution Herald of the Sun Execution Sentence ST trace from 2026-09-22 19:23:22 to 19:24:21 contained 84 ST recommendations. The opener was Avenging Wrath, Execution Sentence, Blade of Justice, Final Verdict, Wake of Ashes, Final Verdict, Divine Toll. The trace recorded 34 Final Verdict, 12 Blade of Justice, 12 Judgment, 6 Hammer of Wrath, 5 Templar Slash, 4 Wake of Ashes, 4 Templar Strike, and one Divine Toll recommendation. Holy Power was spent cleanly at four or five during the opener and at sensible lower thresholds later. Two isolated `none` samples were brief availability gaps rather than a stall. No change was needed.

## Latest saved trace

- On 2026-09-23, a clean 101-second Fury Mountain Thane ST trace was saved from 16:42:15 to 16:43:56. All 135 recommendations were ST. Odyn's Fury was recommended 17 times; while ready, it was displaced only by pre-combat Charge or one high/expiring-enrage Rampage, validating its ST placement. Ten in-combat samples recommended `none`; every one had Whirlwind ready while all higher-priority tracked actions were unavailable. Version `0.1.158` adds Whirlwind as the final ST fallback to close those gaps.
- A follow-up 81-second Mountain Thane ST trace from 16:49:07 to 16:50:28 recorded six pre-combat `none` samples and six genuine in-combat `none` samples. All six in-combat gaps again had only Whirlwind ready. This exposed an implementation error in `0.1.158`: the branch used an undefined constant instead of the resolved Whirlwind spell stored in the state. Version `0.1.159` corrects the reference; another reload and short ST trace is required to validate it.
- Version `0.1.159` was validated with a 59-second Mountain Thane ST trace from 16:58:23 to 16:59:22. It contained 86 recommendations, including one Whirlwind recommendation in the former filler slot. No in-combat `none` sample had Whirlwind or another tracked action ready. The only two `none` samples occurred during the first 1.1 seconds with an empty ready set, so the Mountain Thane ST Whirlwind fallback is working as intended.
- A 395-second Arms Slayer ST trace from 17:00:54 to 17:07:29 contained 603 recommendations, all ST. The main recommendations were Overpower 126, Mortal Strike 112, Execute 85, Cleave 72, Heroic Strike 61, and Slam 58. Rend maintenance was healthy: of 61 active recommendations at five seconds or less, 49 were Cleave and three were Rend; the only two active zero-Rend samples both recommended Cleave. All 61 recommendations recorded while the trusted Master of Warfare proc flag was active selected Heroic Strike unless an intentional higher-priority Cleave, Execute, cooldown, or Rend action won. Confirmed Sudden Death windows selected Execute 80 times and otherwise yielded to intended priorities. Most `none` samples had an empty ready set during dummy downtime; the six Bladestorm-only samples were outside Colossus Smash and reflect the deliberate Bladestorm hold. No code change was indicated.
- A 139-second Arms Slayer five-target AoE trace from 17:11:23 to 17:13:42 contained 165 recommendations, all AoE with a stable target count of five. The opener correctly ran Sweeping Strikes, Cleave/Rend application, Avatar, Colossus Smash, then Bladestorm. Sustained recommendations were Execute 47 and Cleave 35, with additional Bladestorm, Sweeping Strikes, Colossus Smash, and Overpower. Execute was continuously usable on the low-health targets, explaining why the implemented AoE priority selected it ahead of Mortal Strike; Mortal Strike casts therefore do not prove a detector failure. All 29 `none` samples had an empty ready set and occurred during target/dummy downtime. No code change was indicated.
- A Fury Slayer trace saved on 2026-09-26 contained 142 five-target AoE recommendations. The opener reached Whirlwind, Recklessness, Rampage, and Bladestorm, but Odyn's Fury was never recommended despite being recorded ready through the active sequence. The global `NeedsWhirlwindBuff` check ran before the complete AoE priority and repeatedly displaced the intended post-Bladestorm Sudden Death/Odyn's Fury block. Version `0.1.161` moves Whirlwind maintenance below that block. The saved trace remained enabled, so stop and reload after the next validation run.
- Version `0.1.161` was validated with a follow-up Fury Slayer trace containing 189 five-target AoE recommendations and 33 ST recommendations during pack downtime. Odyn's Fury was recommended four times, confirming it now reaches the active priority, while Whirlwind remained frequent enough to maintain AoE cleave. Rampage, Execute, Raging/Crushing Blow, and Bladestorm continued appearing normally. All 16 `none` samples had an empty ready set. No further code change was needed. The saved trace still had `traceEnabled=true`, so explicitly stop it before the next test.
- A follow-up Fury Slayer ST trace on 2026-09-26 contained 111 recommendations, all manual ST. It began while already in combat with Recklessness unavailable, so it does not validate the pull opener. Sustained ordering was healthy: Rampage maintained Enrage, Bladestorm was entered after Rampage, Odyn's Fury was recommended twice after burst actions, and Execute, Raging/Crushing Blow, and Bloodthirst cycled normally. All nine `none` samples had an empty ready set and occurred during Bladestorm/channel or target downtime. No code change was needed. The trace still had `traceEnabled=true`.
- SavedVariables: `C:\Games\World of Warcraft\_retail_\WTF\Account\250487950#3\SavedVariables\MidnightRotationArmsLab.lua`.
- Last checked write: 2026-09-18 21:36:56 local time. It contained 2,648 entries from 21:19 to 21:36, all **Fury - Mountain Thane** (680 AoE and 370 ST recommendations). It therefore cannot validate the Arms Slayer Rend change.
- The file had `traceEnabled=true` and no `stoppedAt` value, although it had been written by a reload. Use `/midrotlab trace stop` then `/reload` to finalize it. Starting a new trace clears the current trace.
- `settingsVersion=6` and `traceMaxEntries=6000` in this saved file confirm the newer trace instrumentation loaded. Recheck file metadata before relying on these details later; the user may have recorded another trace.

## Next check

1. Reload to activate `0.1.178`; run a fresh Arms Slayer ST trace/log and verify the opener reaches Cleave, Colossus Smash, Avatar, conditional Execute when available, Bladestorm, and Storm Bolt during Bladestorm. Then compare Mortal Strike, Overpower, and Cleave casts per minute; targets remain roughly 17-18 Mortal Strikes, 8-9 Overpowers, and about 5 Cleaves per minute while keeping Rend above 95%.
2. Fury Slayer ST Bladestorm behavior is validated. Run a Fury Slayer trace against 2-3 and 4+ targets if its Cleave/AoE behavior needs validation.
3. Run a short Fury Mountain Thane AoE trace and confirm Odyn's Fury is recommended while ready, both inside and outside Recklessness/Avatar windows.
4. Auto target switching is user-validated. Manual fallbacks remain `/midrotlab st`, `/midrotlab cleave`, and `/midrotlab aoe`; return with `/midrotlab auto`.
5. Retribution Herald AoE and ST both have clean short validations. A longer dungeon trace would be needed to audit uncommon proc and cooldown edge cases.
4. For AoE, explicitly set `/midrotlab aoe` before a pack; return to ST for single targets. A short trace is sufficient to test the priority.

The current guide used for the Arms and Fury audits is Wowhead's Midnight rotation guide: [Arms](https://www.wowhead.com/guide/classes/warrior/arms/rotation-cooldowns-pve-dps) and [Fury](https://www.wowhead.com/guide/classes/warrior/fury/rotation-cooldowns-pve-dps). The addon follows priority lists, so each recommendation is reevaluated after casts and state changes.


## 0.4.1 Slayer priority, cleanup and Midnight API workarounds (2026-10-29)

Backups: `*.bak-v041-cleanup-reorder-20261029`.

Housekeeping
- TOC Interface now `120000,120001,120005,120007,120100,120105,120107` (live 12.1.5 = 120105, PTR 12.1.7 = 120107). Removed the invalid `120500`. Author set to Reece; Notes reflect the multi-spec scope.
- Removed 12 overridden duplicate definitions (RecommendArmsSlayer x3, RecommendArmsColossus x3, RecommendFurySlayer x2, RecommendFuryMountainThane x2, RecommendFuryOpener x2) plus 41 helpers only those copies used (old Arms Method/Live paths, old Ret helpers, Twin Fangs, etc.). Engine.lua 8,169 -> ~6,760 lines. Live behaviour of those specs is unchanged because Lua only kept the last definition.
- Removed the dead COMBAT_LOG_EVENT_UNFILTERED handler and RecordRecentDamageTarget (12.x blocks CLEU). The recent-damage target count is now documented as always 0.

Arms Slayer priorities (Method Midnight 12.1.5)
- Normal ST: Cleave at <=2s Rend > Avatar > Colossus Smash/Warbreaker > Execute (2 SD or 4 Executioner) > Heroic Strike > Mortal Strike > Bladestorm (release rules) > Execute (1 SD / usable) > 2-stack Opportunist Overpower > pre-Colossus Cleave at 5s > Overpower > Wrecking Throw > Slam.
- Execute range: Cleave at <=2s > Heroic Strike > Avatar > Colossus Smash > Execute (2 SD or 4 Executioner) > Mortal Strike at 2 Executioner's Precision > Bladestorm > Execute (1 SD or 40+ rage) > Overpower > any usable Execute > Mortal Strike (late filler) > Wrecking Throw > Slam. Plain Mortal Strike no longer beats Execute in execute range (reverts 0.1.176 there).
- ARMS_COOLDOWN_SYNC_WINDOW 10s -> 3s, because Avatar can now see estimated Colossus cooldowns in combat.
- Opener, AoE and Colossus branches unchanged.

API workarounds
- Cast-based cooldown estimates: every successful player cast is timestamped (ID, base ID, name). When Midnight hides cooldown times but `isActive` is true, remaining = last cast + learned duration (read out of combat) or base cooldown, minimum 0.25s. Previously this returned math.huge, so "Colossus ready soon" and the ">25s away" Bladestorm release could never fire in combat.
- Real GCD: read from spell 61304 (never secret) instead of a fixed 1.5s.
- Rage band: when rage is hidden, C_Spell.IsSpellUsable's not-enough-resource flag across known rage spells gives `rage >= low` and `rage < high`. "Execute at 40+ rage" now returns false when a <=40 cost spell is short on rage (enables Overpower under 40 rage).
- C_AssistedCombat.GetNextCastSpell: recorded every tick; confirms a Sudden Death proc when target health is readable and outside execute range; fills in-combat `none` recommendations when usable (`/midrotlab assist on|off`, default on).
- SPELL_ACTIVATION_OVERLAY_GLOW_SHOW/HIDE now tracked as an extra proc signal (15s staleness cap).

New trace fields: `bliz`, `blizMatch`, `blizFallback`, `blizSd`, `rageLo`, `rageHi`, `gcd`, `csCd`/`csCdEst`, `avatarCd`/`avatarCdEst`, `bsCd`/`bsCdEst`, `sdGlowEvt`. `/midrotlab dump` prints a second "API:" line with the same data (`~` marks an estimated cooldown).

Validation so far: syntax-checked; smoke-tested with stubbed WoW APIs (cooldown estimate, rage band, GCD, fallback, trace and dump all executed). Not yet tested in game.

Next check
1. `/reload`; confirm no Lua errors. If `bliz` is always nil, enable Assisted Highlight in Blizzard's combat options and retest.
2. Clean Arms Slayer ST trace: check Avatar/Colossus Smash are cast on cooldown, `csCdEst=true` values count down sensibly, `rageLo/rageHi` populate in combat, and execute-range Overpower appears when `rageHi <= 40`.
3. Run `/midrotlab dump` during a Sudden Death proc: compare SDGlowEvt, overlay and BlizSD.
4. Compare `blizMatch` rate as a rough sanity metric (Blizzard's list is simpler, so 100% is not the goal).


## 0.5.0 All DPS specs via data-driven SpecEngine (2026-10-29)

Backups: `*.bak-v050-all-dps-specs-20261029`.

Architecture
- New `SpecEngine.lua` plus one profile file per class in `Specs\` (DeathKnight, DemonHunter, Druid, Evoker, Hunter, Mage, Monk, Priest, Rogue, Shaman, Warlock). Loaded after Engine.lua.
- The hand-written engines still own Arms, Fury, Retribution, Beast Mastery, Frost DK and Subtlety. Every other DPS spec falls through to SpecEngine.
- Engine.lua exposes its helpers as `addon.EngineInternals`. It also calls SpecEngine from the state builders, GetRecommendationForState, GetProfileLabel, UNIT_SPELLCAST_SUCCEEDED, PLAYER_TARGET_CHANGED and PLAYER_REGEN_ENABLED.
- Spells are resolved by name (with override detection through C_Spell.GetOverrideSpell), not hard-coded IDs.
- Profile entry format: `{ "spellKey", when = function(s) ... end, hero = "...", talent = "...", aoe/cleave/st flags, note = "..." }`. Lists are `precombat`, `st`, `aoe` and optional `fallback`. Entries with `major = true` spells obey `/midrotlab cooldowns`.
- Signals available to conditions:
  - `s:ready()`, `s:cd()` (cast-estimated), `s:charges()` (out of combat only), `s:castCount()` (button counts)
  - `s:proc()` (aura, overlay glow or glow event), `s:buff()`/`s:dot()`/`s:refreshable()` (inferred from your casts per target GUID, pandemic-aware)
  - `s:counter()` (cast-counted stacks), `s:auraStacks()` (never-secret auras: Maelstrom Weapon, Tip of the Spear, Icicles)
  - `s:resource*()` (readable secondary power), `s:powerAtLeast()` (primary power or usability band), `s:hpBelow()`, `s:hero()`, `s:talent()`, `s:lastCast()`, `s:since()`
- Windwalker uses `comboStrikes = true`, which stops the same ability being recommended twice in a row.

Specs and sources (12.1.5 unless noted)
- Method: Havoc, Devourer, Balance, Feral, Devastation, Augmentation, Marksmanship, Survival, Arcane, Fire, Frost, Windwalker, Shadow, Assassination, Elemental, Enhancement, Affliction, Destruction.
- Icy Veins: Unholy (12.0.5), Outlaw (Season 1), Demonology (Season 1).

Known limits
- These lists start from the guides and have not been tuned in game. Expect per-spec tuning from traces, as was done for Arms.
- Hidden state, approximated:
  - Fire's Heating Up has no glow.
  - Arcane Salvo / Cumulative Power stacks use button counts if shown.
  - Unholy Lesser Ghouls and Demonology Wild Imps are counted from casts.
  - Outlaw Roll the Bones stage is unknown.
  - Most charge counts are hidden in combat.
- DoT timers only cover the current target; multi-dotting still needs manual target swaps.
- Devourer spec ID 1480 is unverified; the profile also matches by spec name "Devourer".

Debugging
- `/midrotlab dump` prints a "Spec:" line with the profile key and the exact priority entry that fired (`Why=st#7 putrefy`), plus any Lua error from a condition.
- Traces record `spec`, `specWhy` and `specErr`.

Next check
1. `/reload` on each class you play; confirm the profile label shows (for example "Shadow - Archon") and there are no Lua errors.
2. Run a short ST and AoE trace per spec, then tune the priority entries using `specWhy`.


## 0.5.1 Fury hidden-rage Rampage fix (2026-10-31)

- WoWAnalyzer (Fury Slayer ST, 55.6% accuracy) flagged two mistakes: skipped Rampage above 100 rage during Recklessness (57%) and skipped Rampage above 100 rage outside it (33%).
- Cause: rage is hidden in combat, and `ShouldFuryRampageAtHighRage` only had a slow fallback that needed 2 generators during Recklessness. Outside Recklessness it never fired.
- Fix: Rampage turns usable at exactly 80 rage. The addon now tracks when that happens (resource-only usability, so range does not reset it) and treats rage as 100+ once either of these is true:
  - one rage generator has been cast since then, or
  - Rampage has sat usable for 0.75s in Recklessness/Avatar, or 1.5s otherwise.
- Slayer ST order now matches the analyzer list:
  - Cooldown window: Enrage-missing Rampage now comes first.
  - Outside cooldowns: Enrage Rampage > capped Sudden Death > Crushing Blow > Rampage 100+ > Odyn's Fury > Execute > Raging Blow > Rampage > Bloodthirst.
- Mountain Thane also benefits, because it shares `ShouldFuryRampageHighOrExpiring`.
- New trace fields: `rampageUsableFor`, `rampageGenSinceUsable`.
- Next: rerun the same Fury Slayer ST log and compare the analyzer's accuracy and the two Rampage mistakes.


## 0.5.2-0.5.3 Rage probe and running rage estimate (2026-10-31)

Rage probe results on live 12.1.5 (Fury, 15s of combat):
- UnitPower and UnitPowerPercent for rage are hidden, even out of combat. Attack speed is hidden too.
- UNIT_POWER_FREQUENT still fires on every rage change (~3.5/s, power type readable). About 1/3 of those were not near a cast, so they are auto-attacks.
- Spell rage costs and the IsSpellUsable "not enough resource" flag stay readable in combat.
- GetSpellPowerCost reported 50 for Rampage; the user confirms Rampage costs 80. RageModel overrides it to 80.
- Assisted Highlight suggested Whirlwind 60/60 times and Rampage never, so it is useless as a rage signal.

RageModel.lua (0.5.3) keeps a running rage estimate:
- Adds known generator amounts on casts (doubled during Recklessness) and subtracts exact costs on spenders.
- Treats unexplained rage-change events as auto-attacks.
- Snaps to a known value whenever a spender's "not enough rage" flag flips or contradicts the estimate, and learns the auto-attack gain from those corrections.
- In simulation: mean error 5-8 rage.

Wiring:
- Fury's Rampage-at-100 check and Arms' Execute-at-rage check use the estimate.
- `/midrotlab rage` toggles a draggable readout showing real rage (displayed only, never read) next to the estimate.
- `/midrotlab rage status` prints the model's numbers.
- Traces record `rageEst` and `rageAutoGain`; the dump API line shows `RageEst`.

Next: compare the readout's two numbers during a pull. If the estimate drifts, tune the GENERATION table in RageModel.lua.


## 0.5.4 Fury Slayer rebuilt from top Mythic raid logs (2026-10-31)

Source: Archon, Mythic Vashnik, 11 top parses on 12.1.5 (412K-361K DPS). I read the cast timelines of the top four.

Findings:
- Rampage is spent every time it is usable: 22.3 CPM on the boss and the top damage ability.
- Inside Recklessness, top players strictly alternate Rampage and Crushing Blow, with Execute dropped in.
- Recklessness lasts 24s (the addon assumed 12s) and is recast roughly every 40s.
- Recklessness goes out at 7-11s, after the first Rampage. It is not used on the first GCD.
- Opener: Charge, Raging Blow x1-2, Bloodthirst, (Whirlwind with adds), Rampage, then Recklessness with potion/trinket.
- Odyn's Fury and Bladestorm are pressed together in the back half of Recklessness (about 5-10s left), roughly every 23-25s.
- No Avatar casts. Bloodthirst is low (2.8 CPM) and Bloodbath is 5.0. Raging Blow (10.2) and Crushing Blow (8.5) are the main builders.

Changes:
- FURY_RECKLESSNESS_DURATION 12 -> 24; RageModel's Recklessness window is also 24s.
- New Slayer opener (Mountain Thane keeps the old shared one): Charge > Rampage if usable > Raging Blow > Bloodthirst until the first Rampage, then Recklessness.
- New Slayer ST priority:
  - Recklessness (outside the window), then Avatar if talented.
  - Rampage whenever usable.
  - Odyn's Fury and Bladestorm: inside Recklessness only with 10s or less left; outside it on cooldown, unless Recklessness is about to come back.
  - Then Crushing Blow > Execute > Raging Blow > Bloodbath > Bloodthirst > Whirlwind.
- Slayer AoE and Mountain Thane are unchanged.

Next: rerun the same pull and compare against the WoWAnalyzer result (55.6% accuracy) and the top-log CPM: Rampage ~22, RB+CB ~19, Execute ~6.


## 0.5.5 Fury Slayer opener and burst from Ula'tek logs (2026-10-31)

Source: Archon, Ula'tek Mythic (9 parses) and Heroic (13 parses), 12.1.5.
- Recklessness goes out at 0.7-2s, with Charge, and again every 40-45s. Duration is 24s (one sampled player had 18s, probably a different talent).
- Bladestorm ~2.5-4.5s in (start of Recklessness), then Odyn's Fury ~8s. After that Rampage and Crushing Blow alternate (with Execute) until Recklessness fades, then Raging Blow / Bloodthirst until Rampage is usable again.
- Boss-only CPM on Heroic: Rampage 15.7, Raging Blow 6.1, Crushing Blow 5.0, Bloodbath 4.0, Execute 3.2. That is the same Rampage ~= Raging Blow + Crushing Blow ratio as Vashnik.
- Conclusion: Vashnik's late Recklessness (7-11s) and late Bladestorm were fight-specific (adds).

Changes:
- Slayer opener: Charge > (Whirlwind buff in AoE) > Recklessness > Avatar, then the normal priority.
- Bladestorm and Odyn's Fury are on cooldown again (Bladestorm first). Outside Recklessness they are held only if it is about to come back.
- Rampage stays whenever usable.
